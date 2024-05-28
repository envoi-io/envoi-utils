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

# envoi-cloud-infrastructure aws secretsmanager create-secret
# aws secretsmanager create-secret --name MyTestSecret --description "My test secret created with the CLI." --secret-string "{\"user\":\"diegor\",\"password\":\"EXAMPLE-PASSWORD\"}"


function usage() {
  echo "Usage: $0 <secret-name> <secret-string>"
  exit 1
}

while [[ $# -gt 0 ]]
do
  case "$1" in
    -h|--help)
      usage
      ;;
    *)
    secret_name="$1"
    secret_string="$2"
    ;;
    esac
    shift
    ;;
done


 - # I need a one to one map of create-secret arguments as arguments for this script
# create-secret
# --name <value>
# [--client-request-token <value>]
# [--description <value>]
# [--kms-key-id <value>]
# [--secret-binary <value>]
# [--secret-string <value>]
# [--tags <value>]
# [--add-replica-regions <value>]
# [--force-overwrite-replica-secret | --no-force-overwrite-replica-secret]
# [--debug]
# [--output <value>]
# [--query <value>]
# [--profile <value>]
# [--region <value>]
# [--cli-auto-prompt]
# [--no-cli-auto-prompt]

# Handle Command Line Arguments

aws secretsmanager create-secret --name $secret_name --secret-string $secret_string
