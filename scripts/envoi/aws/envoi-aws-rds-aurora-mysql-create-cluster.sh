#!/usr/bin/env bash

# Define the list of commands
commands=("aws")

# Iterate over the commands and check their availability
for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is not available."
		DEPENDENCIES_MET=false
  fi
done

if [ "$DEPENDENCIES_MET" == false ]; then
	exit 1
fi

ENVOI_AMYSQL_MASTER_USERNAME=${ENVOI_AMYSQL_MASTER_USERNAME:-admin}
ENVOI_AMYSQL_MASTER_PASSWORD=${ENVOI_AMYSQL_MASTER_PASSWORD}
ENVOI_AMYSQL_CLUSTER_IDENTIFIER=${ENVOI_AMYSQL_CLUSTER_IDENTIFIER:-sample-cluster}
ENVOI_AMYSQL_INSTANCE_IDENTIFIER=${ENVOI_AMYSQL_INSTANCE_IDENTIFIER:-sample-instance}
ENVOI_AMYSQL_SUBNET_GROUP_NAME=${ENVOI_AMYSQL_SUBNET_GROUP_NAME:-default}
# ENVOI_AMYSQL_SECURITY_GROUP_IDS=${ENVOI_AMYSQL_SECURITY_GROUP_IDS
ENVOI_AMYSQL_PARAMETER_GROUP_NAME=${ENVOI_AMYSQL_PARAMETER_GROUP_NAME:-default}
ENVOI_AMYSQL_ENGINE=${ENVOI_AMYSQL_ENGINE:-aurora-mysql}
ENVOI_AMYSQL_ENGINE_VERSION=${ENVOI_AMYSQL_ENGINE_VERSION:-5.7}


if [ -z "$ENVOI_AMYSQL_MASTER_PASSWORD" ]; then
  echo "Error: ENVOI_AMYSQL_MASTER_PASSWORD is not set."
  exit 1
fi

command_out=(aws rds create-db-cluster)

while [[ $# -gt 0 ]]
do
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
      --parameter-group-name)
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
  echo "Error: ENVOI_AMYSQL_MASTER_PASSWORD is not set."
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
  command_out+=("--db-parameter-group-name" "$ENVOI_AMYSQL_PARAMETER_GROUP_NAME")
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

${command_out[@]}