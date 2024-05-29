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

function usage {
  echo "Usage: $0 <domain-name>"
}

# Delete OpenSearch Domain
DOMAIN_NAME=$1

if [ -z "$DOMAIN_NAME" ]
then
  usage
  exit 1
fi

aws opensearch delete-domain  --domain-name $DOMAIN_NAME
