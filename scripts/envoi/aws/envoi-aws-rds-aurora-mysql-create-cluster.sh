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

DB_MASTER_USERNAME=${DB_MASTER_USERNAME:-admin}
DB_MASTER_PASSWORD=${DB_MASTER_PASSWORD}
DB_CLUSTER_IDENTIFIER=${DB_CLUSTER_IDENTIFIER:-sample-cluster}
DB_INSTANCE_IDENTIFIER=${DB_INSTANCE_IDENTIFIER:-sample-instance}
DB_SUBNET_GROUP_NAME=${DB_SUBNET_GROUP_NAME:-default}
# DB_SECURITY_GROUP_IDS=${DB_SECURITY_GROUP_IDS
DB_PARAMETER_GROUP_NAME=${DB_PARAMETER_GROUP_NAME:-default}
DB_ENGINE=${DB_ENGINE:-aurora-mysql}
DB_ENGINE_VERSION=${DB_ENGINE_VERSION:-5.7}


if [ -z "$DB_MASTER_PASSWORD" ]; then
  echo "Error: DB_MASTER_PASSWORD is not set."
  exit 1
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

aws rds create-db-cluster \
    --db-cluster-identifier $DB_CLUSTER_IDENTIFIER \
    --engine $DB_ENGINE \
    --engine-version $DB_ENGINE_VERSION \
    --master-username $DB_MASTER_USERNAME \
    --master-user-password $DB_MASTER_PASSWORD \
    --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
    --vpc-security-group-ids $DB_SECURITY_GROUP_IDS \
    --db-parameter-group-name $DB_PARAMETER_GROUP_NAME
    