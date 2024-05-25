#!/usr/bin/env bash

MONGO_ATLAS_DEFAULT_PROJECT_NAME="Envoi"
MONGO_ATLAS_DEFAULT_CLUSTER_NAME="envoi-dev4"
MONGO_ATLAS_DEFAULT_CLUSTER_PROVIDER_NAME="aws"
MONGO_ATLAS_DEFAULT_CLUSTER_PROVIDER_REGION="us-east-1"
MONGO_ATLAS_DEFAULT_CLUSTER_PROVIDER_TIER="M2"

function log {
  echo $1
}

# Define the list of commands
commands=("atlas" "jq")

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

function create_project {
  declare -n PROJECT_REF=$1

  read -p "Enter the name of the project you want to create: ($MONGO_ATLAS_DEFAULT_PROJECT_NAME)" MONGO_ATLAS_PROJECT_NAME_ENTERED
  export MONGO_ATLAS_PROJECT_NAME=${MONGO_ATLAS_PROJECT_NAME:-$MONGO_ATLAS_PROJECT_NAME_ENTERED}

  CREATE_PROJECT_RESPONSE=$(atlas projects create $MONGO_ATLAS_PROJECT_NAME --output json)
  PROJECT_REF=$CREATE_PROJECT_RESPONSE
}

function select_or_create_project {
  declare -n PROJECT_REF=$1
  
  projects=$(atlas projects list)

  if [ -z "$projects" ]; then
    create_project PROJECT
    PROJECT_REF=$PROJECT
    return 0
  fi
}

# Authenticate to MongoDB Atlas
atlas auth login

select_or_create_project MONGO_ATLAS_PROJECT

MONGO_ATLAS_PROJECT_ID=$(echo "$MONGO_ATLAS_PROJECT" | jq -r '.id')

read -p "Enter the name of the cluster you want to create: ($MONGO_ATLAS_DEFAULT_CLUSTER_NAME)" MONGO_ATLAS_CLUSTER_NAME_ENTERED
export MONGO_ATLAS_CLUSTER_NAME=${MONGO_ATLAS_DEFAULT_CLUSTER_NAME:-$MONGO_ATLAS_CLUSTER_NAME_ENTERED}

export MONGO_ATLAS_CLUSTER_PROVIDER_NAME=${MONGO_ATLAS_DEFAULT_CLUSTER_PROVIDER_NAME}
export MONGO_ATLAS_CLUSTER_PROVIDER_REGION=${MONGO_ATLAS_DEFAULT_CLUSTER_PROVIDER_REGION}
export MONGO_ATLAS_CLUSTER_PROVIDER_TIER=${MONGO_ATLAS_DEFAULT_CLUSTER_PROVIDER_TIER}

# Deploy a free cluster named myCluster for the project with the ID from above and tag "env=dev":
CLUSTER_CREATE_REPSONSE=$(atlas cluster create $MONGO_ATLAS_CLUSTER_NAME --projectId $MONGO_ATLAS_PROJECT_ID --provider $MONGO_ATLAS_CLUSTER_PROVIDER_NAME --region $MONGO_ATLAS_CLUSTER_PROVIDER_REGION --tier $MONGO_ATLAS_CLUSTER_PROVIDER_TIER)
log "Cluster Created: $CLUSTER_CREATE_REPSONSE"
