#!/usr/bin/env bash

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

ENVOI_APOSTGRES_MASTER_USERNAME=${ENVOI_APOSTGRES_MASTER_USERNAME:-admin}
ENVOI_APOSTGRES_MASTER_PASSWORD=${ENVOI_APOSTGRES_MASTER_PASSWORD}
ENVOI_APOSTGRES_CLUSTER_IDENTIFIER=${ENVOI_APOSTGRES_CLUSTER_IDENTIFIER:-sample-cluster}
ENVOI_APOSTGRES_INSTANCE_IDENTIFIER=${ENVOI_APOSTGRES_INSTANCE_IDENTIFIER:-sample-instance}
ENVOI_APOSTGRES_SUBNET_GROUP_NAME=${ENVOI_APOSTGRES_SUBNET_GROUP_NAME:-default}
# ENVOI_APOSTGRES_SECURITY_GROUP_IDS=${ENVOI_APOSTGRES_SECURITY_GROUP_IDS
ENVOI_APOSTGRES_CLUSTER_PARAMETER_GROUP_NAME=${ENVOI_APOSTGRES_CLUSTER_PARAMETER_GROUP_NAME:-envoi-apostgres14-default}
ENVOI_APOSTGRES_ENGINE=${ENVOI_APOSTGRES_ENGINE:-aurora-postgresql}
ENVOI_APOSTGRES_ENGINE_VERSION=${ENVOI_APOSTGRES_ENGINE_VERSION:-14.11}

command_out=(aws rds create-db-cluster)

while [[ $# -gt 0 ]]
do
  case "$1" in
    --engine)
      shift
      ENVOI_APOSTGRES_ENGINE=$1
      shift
      ;;
      --engine-version)
      shift
      ENVOI_APOSTGRES_ENGINE_VERSION=$1
      shift
      ;;
      --master-username)
      shift
      ENVOI_APOSTGRES_MASTER_USERNAME=$1
      shift
      ;;
      --master-user-password)
      shift
      ENVOI_APOSTGRES_MASTER_PASSWORD=$1
      shift
      ;;
      --cluster-identifier)
      shift
      ENVOI_APOSTGRES_CLUSTER_IDENTIFIER=$1
      shift
      ;;
      --instance-identifier)
      shift
      ENVOI_APOSTGRES_INSTANCE_IDENTIFIER=$1
      shift
      ;;
      --subnet-group-name)
      shift
      ENVOI_APOSTGRES_SUBNET_GROUP_NAME=$1
      shift
      ;;
      --security-group-ids)
      shift
      ENVOI_APOSTGRES_SECURITY_GROUP_IDS=$1
      shift
      ;;
      --parameter-group-name)
      shift
      ENVOI_APOSTGRES_CLUSTER_PARAMETER_GROUP_NAME=$1
      shift
      ;;
    *)
    command_out+=("$1")
    shift
    ;;      
  esac
done

if [ -z "$ENVOI_APOSTGRES_MASTER_PASSWORD" ]; then
  echo "Error: ENVOI_APOSTGRES_MASTER_PASSWORD must be set or --master-user-password is required."
  exit 1
fi

if [ -n "$ENVOI_APOSTGRES_MASTER_PASSWORD" ]; then
  command_out+=("--master-user-password" "$ENVOI_APOSTGRES_MASTER_PASSWORD")
fi

if [ -n "$ENVOI_APOSTGRES_MASTER_USERNAME" ]; then
  command_out+=("--master-username" "$ENVOI_APOSTGRES_MASTER_USERNAME")
fi

if [ -n "$ENVOI_APOSTGRES_CLUSTER_IDENTIFIER" ]; then
  command_out+=("--db-cluster-identifier" "$ENVOI_APOSTGRES_CLUSTER_IDENTIFIER")
fi

if [ -n "$ENVOI_APOSTGRES_INSTANCE_IDENTIFIER" ]; then
  command_out+=("--db-instance-identifier" "$ENVOI_APOSTGRES_INSTANCE_IDENTIFIER")
fi

if [ -n "$ENVOI_APOSTGRES_SUBNET_GROUP_NAME" ]; then
  command_out+=("--db-subnet-group-name" "$ENVOI_APOSTGRES_SUBNET_GROUP_NAME")
fi

if [ -n "$ENVOI_APOSTGRES_SECURITY_GROUP_IDS" ]; then
  command_out+=("--vpc-security-group-ids" "$ENVOI_APOSTGRES_SECURITY_GROUP_IDS")
fi

if [ -n "$ENVOI_APOSTGRES_CLUSTER_PARAMETER_GROUP_NAME" ]; then
  command_out+=("--db-cluster-parameter-group-name" "$ENVOI_APOSTGRES_CLUSTER_PARAMETER_GROUP_NAME")
fi

if [ -n "$ENVOI_APOSTGRES_ENGINE" ]; then
  command_out+=("--engine" "$ENVOI_APOSTGRES_ENGINE")
fi

if [ -n "$ENVOI_APOSTGRES_ENGINE_VERSION" ]; then
  command_out+=("--engine-version" "$ENVOI_APOSTGRES_ENGINE_VERSION")
fi

create_default_cluster_parameter_group() {
  local cluster_parameter_group_name=$1
  local cluster_parameter_group_family=$2
  local cluster_parameter_group_description=$3
  # aws rds create-db-cluster-parameter-group \
  # --db-cluster-parameter-group-name envoi-apostgres-default \
  # --db-parameter-group-family aurora-postgresql14 \
  # --description "Envoi Aurora PostgreSQL Default Cluster Parameter Group"
  aws rds create-db-cluster-parameter-group \
    --db-cluster-parameter-group-name "$cluster_parameter_group_name" \
    --db-parameter-group-family "$cluster_parameter_group_family" \
    --description "$cluster_parameter_group_description"
}

# shellcheck disable=SC2068
${command_out[@]}
