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

# Create Cluster Instance
# export DEPLOYMENT_DOCDB_CREATE_INSTANCE_OUTPUT=$(aws docdb create-db-instance --engine docdb --db-cluster-identifier DEPLOY_DOCDB_CLUSTER_IDENTIFIER --db-instance-identifier $DEPLOY_DOCDB_INSTANCE_IDENTIFIER --availability-zone $DEPLOY_DOCDB_AVAILABILITY_ZONE --db-instance-class $DEPLOY_DOCDB_DB_INSTANCE_CLASS)

# echo $DEPLOYMENT_DOCDB_CREATE_INSTANCE_OUTPUT

aws docdb create-db-instance $*