#!/usr/bin/env bash

# Get location of the script file
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ENVOI_CONFIG_FILE_PATH=${ENVOI_CONFIG_FILE_PATH:-"${SCRIPT_DIR}/config.sh"}
VERBOSE=${VERBOSE:-false}

log() {
  echo "$1"
}

error() {
  echo -e "\033[0;31m$1\033[0m"
}

verbose() {
  [[ "$VERBOSE" == "true" ]] && echo -e "\033[0;33m$1\033[0m"  # yellow
}

usage() {
  cat <<EOF
  Usage: $0 [options]

  Options:
  --config-file
    Path to the config file. Default: ${ENVOI_CONFIG_FILE_PATH}
EOF
}

# Define the list of dependencies
dependencies=("aws" "jq")

# Iterate over the commands and check their availability
for cmd in "${dependencies[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    error "Error: $cmd command was not found."
		all_dependencies_met=false
  fi
done

if [ "$all_dependencies_met" == false ]; then
	exit 1
fi

while [[ $# -gt 0 ]]
do
  case "$1" in
    --config-file)
      shift
      ENVOI_CONFIG_FILE_PATH=$1
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Error: Invalid argument $1"
      exit 1
      ;;
  esac
done

# Source Config
# shellcheck disable=SC1090
source "${ENVOI_CONFIG_FILE_PATH}"

# Create Secrets
source "${SCRIPT_DIR}/envoi-aws-create-secrets.sh"

# Create IAM Roles

# Create DynamoDB Tables

# Create VPC
if [ -z "$ENVOI_VPC_ID" ]; then
#  CREATE_VPC_OUTPUT=$("${SCRIPT_DIR}/envoi-aws-vpc-create.sh")
#  export ENVOI_VPC_ID=$(echo "$CREATE_VPC_OUTPUT" | jq -r '.Vpc.VpcId')
  source "${SCRIPT_DIR}/envoi-aws-vpc-create.sh"
  if [ -z "$ENVOI_VPC_ID" ]; then
    error "Error: Failed to create VPC"
    exit 1
  fi
fi

# Create DocumentDB Cluster
if [[ "$ENVOI_DEPLOY_SHOULD_CREATE_DOCDB" == "true" ]]; then
  export ENVOI_DOCDB_MASTER_USER_PASSWORD=${ENVOI_DOCDB_MASTER_USER_PASSWORD:-${ENVOI_MONGO_MASTER_PASSWORD}}
  CREATE_DOCDB_CLUSTER_RESPONSE=$("${SCRIPT_DIR}/envoi-aws-docdb-create-cluster.sh")
  ENVOI_DOCDB_CLUSTER_DETAILS=$(echo "$CREATE_DOCDB_CLUSTER_RESPONSE" | jq -r '.DBCluster')
  if [[ -z "$ENVOI_DOCDB_CLUSTER_DETAILS" ]]; then
    echo "Error: Failed to create DocumentDB Cluster"
    echo "Response: $CREATE_DOCDB_CLUSTER_RESPONSE"
    exit 1
  fi

  log "DocumentDB Cluster Details: $ENVOI_DOCDB_CLUSTER_DETAILS"
  ENVOI_DOCDB_CLUSTER_ENDPOINT=$(echo "$ENVOI_DOCDB_CLUSTER_DETAILS" | jq -r '.Endpoint')
  ENVOI_DOCDB_CLUSTER_PORT=$(echo "$ENVOI_DOCDB_CLUSTER_DETAILS" | jq -r '.Port')
  ENVOI_DOCDB_MASTER_USERNAME=$(echo "$ENVOI_DOCDB_CLUSTER_DETAILS" | jq -r '.MasterUsername')
  ENVOI_DOCDB_SECRET_CONTENTS=$(jq -n \
  --arg docdb_username "$ENVOI_DOCDB_MASTER_USERNAME" \
  --arg docdb_password "$ENVOI_DOCDB_MASTER_PASSWORD" \
  --arg docdb_cluster_endpoint "$ENVOI_DOCDB_CLUSTER_ENDPOINT" \
  --arg docdb_cluster_port "$ENVOI_DOCDB_CLUSTER_PORT" \
  '{"engine": "mongo", "host": $docdb_cluster_endpoint, "port": $docdb_cluster_port, "username": $docdb_username, "password": $docdb_password, "ssl": true}')


  log "Updating DocumentDB Cluster Secret"
  UPDATE_DOCDB_SECRET_RESPONSE=$(aws secretsmanager update-secret --secret-id "$ENVOI_MONGO_SECRET_NAME" --secret-string "$ENVOI_DOCDB_SECRET_CONTENTS")

  # Create DocumentDB Instance
  CREATE_DOCDB_INSTANCE_RESPONSE=$("${SCRIPT_DIR}/envoi-aws-docdb-create-instance.sh")
fi

if [[ "$ENVOI_DEPLOY_SHOULD_CREATE_RDS_AURORA_MYSQL" == "true" ]]; then
  # Create Aurora MySQL Cluster
  ENVOI_AMYSQL_MASTER_PASSWORD=${ENVOI_AMYSQL_MASTER_PASSWORD:-${ENVOI_MYSQL_MASTER_PASSWORD}}
  CREATE_AMYSQL_CLUSTER_RESPONSE=$("${SCRIPT_DIR}/envoi-aws-rds-aurora-mysql-create-cluster.sh")
  ENVOI_AMYSQL_CLUSTER_DETAILS=$(echo "$CREATE_AMYSQL_CLUSTER_RESPONSE" | jq -r '.DBCluster')
  if [[ -z "$ENVOI_AMYSQL_CLUSTER_DETAILS" ]]; then
    error "Error: Failed to create Aurora MySQL Cluster"
    error "Response: $CREATE_AMYSQL_CLUSTER_RESPONSE"
    exit 1
  fi
  log "Aurora MySQL Cluster Response: $CREATE_AMYSQL_CLUSTER_RESPONSE"
  ENVOI_AMYSQL_CLUSTER_ENDPOINT=$(echo "$ENVOI_AMYSQL_CLUSTER_DETAILS" | jq -r '.Endpoint')
  ENVOI_AMYSQL_CLUSTER_PORT=$(echo "$ENVOI_AMYSQL_CLUSTER_DETAILS" | jq -r '.Port')
  ENVOI_AMYSQL_MASTER_USERNAME=$(echo "$ENVOI_AMYSQL_CLUSTER_DETAILS" | jq -r '.MasterUsername')
  ENVOI_AMYSQL_SECRET_CONTENTS=$(jq -n \
  --arg amysql_username "$ENVOI_AMYSQL_MASTER_USERNAME" \
  --arg amysql_password "$ENVOI_AMYSQL_MASTER_PASSWORD" \
  --arg amysql_cluster_endpoint "$ENVOI_AMYSQL_CLUSTER_ENDPOINT" \
  --arg amysql_cluster_port "$ENVOI_AMYSQL_CLUSTER_PORT" \
  '{"engine": "mysql", "host": $amysql_cluster_endpoint, "port": $amysql_cluster_port, "username": $amysql_username, "password": $amysql_password}')

  # Update Aurora MySQL Cluster Secret
  UPDATE_AMYSQL_CLUSTER_SECRET_RESPONSE=$(aws secretsmanager update-secret --secret-id "$ENVOI_MYSQL_SECRET_NAME" --secret-string "$ENVOI_AMYSQL_SECRET_CONTENTS")

  # Create Aurora MySQL Instance
  # CREATE_AMYSQL_INSTANCE_RESPONSE=$("${SCRIPT_DIR}/envoi-aws-rds-aurora-mysql-create-instance.sh")
  #if [[ -z "$CREATE_AMYSQL_INSTANCE_RESPONSE" ]]; then
  #  echo "Error: Failed to create Aurora MySQL Instance"
  #  exit 1
  #fi
fi

if [[ "$ENVOI_DEPLOY_SHOULD_CREATE_RDS_AURORA_POSTGRES" == "true" ]]; then
  # Create Aurora PostgreSQL Cluster
  ENVOI_APOSTGRES_MASTER_PASSWORD=${ENVOI_APOSTGRES_MASTER_PASSWORD:-${ENVOI_POSTGRES_MASTER_PASSWORD}}
  CREATE_APOSTGRES_CLUSTER_RESPONSE=$("${SCRIPT_DIR}/envoi-aws-rds-aurora-postgres-create-cluster.sh")
  ENVOI_APOSTGRES_CLUSTER_DETAILS=$(echo "$CREATE_APOSTGRES_CLUSTER_RESPONSE" | jq -r '.DBCluster')
  if [[ -z "$ENVOI_APOSTGRES_CLUSTER_DETAILS" ]]; then
    error "Error: Failed to create Aurora PostgreSQL Cluster"
    error "Response: $CREATE_APOSTGRES_CLUSTER_RESPONSE"
    exit 1
  fi
  ENVOI_APOSTGRES_CLUSTER_ENDPOINT=$(echo "$ENVOI_APOSTGRES_CLUSTER_DETAILS" | jq -r '.Endpoint')
  ENVOI_APOSTGRES_CLUSTER_PORT=$(echo "$ENVOI_APOSTGRES_CLUSTER_DETAILS" | jq -r '.Port')
  ENVOI_APOSTGRES_MASTER_USERNAME=$(echo "$ENVOI_APOSTGRES_CLUSTER_DETAILS" | jq -r '.MasterUsername')
  ENVOI_APOSTGRES_SECRET_CONTENTS=$(jq -n \
  --arg apostgres_username "$ENVOI_APOSTGRES_MASTER_USERNAME" \
  --arg apostgres_password "$ENVOI_APOSTGRES_MASTER_PASSWORD" \
  --arg apostgres_cluster_endpoint "$ENVOI_APOSTGRES_CLUSTER_ENDPOINT" \
  --arg apostgres_cluster_port "$ENVOI_APOSTGRES_CLUSTER_PORT" \
  '{"engine": "postgres", "host": $apostgres_cluster_endpoint, "port": $apostgres_cluster_port, "username": $apostgres_username, "password": $apostgres_password}')

  # Update Aurora PostgreSQL Cluster Secret
  UPDATE_APOSTGRES_CLUSTER_SECRET_RESPONSE=$(aws secretsmanager update-secret --secret-id "$ENVOI_POSTGRES_SECRET_NAME" --secret-string "$ENVOI_APOSTGRES_SECRET_CONTENTS")

  # Create Aurora PostgreSQL Instance
  # CREATE_APOSTGRES_INSTANCE_RESPONSE=$("${SCRIPT_DIR}/envoi-aws-rds-aurora-postgres-create-instance.sh")
fi

# Create OpenSearch Domain
#CREATE_OS_DOMAIN_RESPONSE=$("${SCRIPT_DIR}/envoi-aws-opensearch-create-domain.sh")
