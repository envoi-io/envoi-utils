#!/usr/bin/env bash

log() {
  echo "$1" >&2
}

verbose() {
  [[ "$VERBOSE" == "true" ]] && echo -e "\033[0;33m$1\033[0m" >&2 # yellow
}

# Define the list of dependencies
dependencies=("aws")

# Iterate over the commands and check their availability
for cmd in "${dependencies[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd command was not found."
		all_dependencies_met=false
  fi
done

if [ "$all_dependencies_met" == false ]; then
	exit 1
fi

ENVOI_AMYSQL_MASTER_USERNAME=${ENVOI_AMYSQL_MASTER_USERNAME:-dbadmin}
ENVOI_AMYSQL_MASTER_PASSWORD=${ENVOI_AMYSQL_MASTER_PASSWORD}
ENVOI_AMYSQL_CLUSTER_IDENTIFIER=${ENVOI_AMYSQL_CLUSTER_IDENTIFIER:-envoi}
ENVOI_AMYSQL_INSTANCE_IDENTIFIER=${ENVOI_AMYSQL_INSTANCE_IDENTIFIER:-envoi}
ENVOI_AMYSQL_SUBNET_GROUP_NAME=${ENVOI_AMYSQL_SUBNET_GROUP_NAME:-default}
# ENVOI_AMYSQL_SECURITY_GROUP_IDS=${ENVOI_AMYSQL_SECURITY_GROUP_IDS
ENVOI_AMYSQL_PARAMETER_GROUP_NAME=${ENVOI_AMYSQL_PARAMETER_GROUP_NAME:-envoi-aurora-mysql8-0-default}
ENVOI_AMYSQL_ENGINE=${ENVOI_AMYSQL_ENGINE:-aurora-mysql}
ENVOI_AMYSQL_ENGINE_VERSION=${ENVOI_AMYSQL_ENGINE_VERSION:-8.0}

command_out=(aws rds create-db-cluster --output json  --no-cli-pager)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-cluster-identifier)
      shift
      ENVOI_AMYSQL_CLUSTER_IDENTIFIER=$1
      shift
      ;;
      --engine)
      shift
      ENVOI_AMYSQL_ENGINE=$1
      shift
      ;;
      --engine-version)
      shift
      ENVOI_AMYSQL_ENGINE_VERSION=$1
      shift
      ;;
      --master-username)
      shift
      ENVOI_AMYSQL_MASTER_USERNAME=$1
      shift
      ;;
      --master-user-password)
      shift
      ENVOI_AMYSQL_MASTER_PASSWORD=$1
      shift
      ;;
      --db-subnet-group-name)
      shift
      ENVOI_AMYSQL_SUBNET_GROUP_NAME=$1
      shift
      ;;
      --security-group-ids)
      shift
      ENVOI_AMYSQL_SECURITY_GROUP_IDS=$1
      shift
      ;;
      --db-parameter-group-name)
      shift
      ENVOI_AMYSQL_PARAMETER_GROUP_NAME=$1
      shift
      ;;
      --parameter-group-family)
      shift
      ENVOI_AMYSQL_PARAMETER_GROUP_FAMILY=$1
      shift
      ;;
    *)
      command_out+=($1)
      shift
      ;;
  esac
done      

if [ -z "$ENVOI_AMYSQL_MASTER_PASSWORD" ]; then
  echo "Error: ENVOI_AMYSQL_MASTER_PASSWORD must be set or --master-user-password is required."
  exit 1
fi

if [ -z "$ENVOI_AMYSQL_MASTER_PASSWORD" ]; then
  echo "Error: ENVOI_AMYSQL_MASTER_PASSWORD must be set or --master-user-password is required."
  exit 1
fi

if [ -n "$ENVOI_AMYSQL_MASTER_PASSWORD" ]; then
  command_out+=("--master-user-password" "$ENVOI_AMYSQL_MASTER_PASSWORD")
fi

if [ -n "$ENVOI_AMYSQL_MASTER_USERNAME" ]; then
  command_out+=("--master-username" "$ENVOI_AMYSQL_MASTER_USERNAME")
fi

if [ -n "$ENVOI_AMYSQL_CLUSTER_IDENTIFIER" ]; then
  command_out+=("--db-cluster-identifier" "$ENVOI_AMYSQL_CLUSTER_IDENTIFIER")
fi

if [ -n "$ENVOI_AMYSQL_ENGINE" ]; then
  command_out+=("--engine" "$ENVOI_AMYSQL_ENGINE")
fi

if [ -n "$ENVOI_AMYSQL_ENGINE_VERSION" ]; then
  command_out+=("--engine-version" "$ENVOI_AMYSQL_ENGINE_VERSION")
fi

if [ -n "$ENVOI_AMYSQL_SUBNET_GROUP_NAME" ]; then
  command_out+=("--db-subnet-group-name" "$ENVOI_AMYSQL_SUBNET_GROUP_NAME")
fi

if [ -n "$ENVOI_AMYSQL_SECURITY_GROUP_IDS" ]; then
  command_out+=("--vpc-security-group-ids" "$ENVOI_AMYSQL_SECURITY_GROUP_IDS")
fi

if [ -n "$ENVOI_AMYSQL_PARAMETER_GROUP_NAME" ]; then
  command_out+=("--db-cluster-parameter-group-name" "$ENVOI_AMYSQL_PARAMETER_GROUP_NAME")
fi

# envoi-cloud-infrastructure aws database aws rds create-db-cluster --engine aurora-mysql
# aws rds create-db-cluster \
#     --db-cluster-identifier sample-cluster \
#     --engine aurora-mysql \
#     --engine-version 5.7 \
#     --master-username admin \
#     --master-user-password secret99 \
#     --db-subnet-group-name default \
#     --vpc-security-group-ids sg-0b9130572daf3dc16

# https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/CHAP_SettingUp_Aurora.html
log "Creating Aurora MySQL cluster..."
verbose "Running command: aws ${command_out[@]}"
${command_out[@]}
