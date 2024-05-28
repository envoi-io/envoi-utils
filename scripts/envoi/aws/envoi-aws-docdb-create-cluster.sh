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

# envoi-cloud-infrastructure aws database aws docdb create-db-cluster --engine docdb
# Create Cluster
# export DEPLOYMENT_DOCDB_CREATE_CLUSTER_OUTPUT=$(aws docdb create-db-cluster --engine docdb --deletion-protection --master-username "${DEPLOY_DOCDB_MASTER_USERNAME}" --master-user-password "${DEPLOY_DOCDB_MASTER_USER_PASSWORD}" --db-cluster-identifier $DEPLOY_DOCDB_CLUSTER_IDENTIFIER)

aws docdb create-db-cluster $*
