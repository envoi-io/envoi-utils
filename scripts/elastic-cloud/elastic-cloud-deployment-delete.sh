#!/usr/bin/env bash

# Define the list of commands
commands=("ecctl")

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

# envoi-cloud-infrastructure elastic deployment create | delete | backup | restore
# https://www.elastic.co/guide/en/ecctl/current/ecctl_deployment_create.html#ecctl_deployment_create

# ecctl deployment create --name my-deployment --deployment-template=aws-io-optimized-v2 --region=us-east-1

ecctl deployment delete $*
