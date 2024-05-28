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

function usage() {
  echo "Usage: $0 <domain-name>"
  exit 1
}

while [[ $# -gt 0 ]]
do
  case "$1" in
    -h|--help)
      usage
      ;;
    *)
    domain_name="$1"
    ;;
    esac
    shift
    ;;
done

if [ -z "$domain_name" ]
then
  usage
  exit 1
fi

# Delete Elastic Search Domain
aws es delete-elasticsearch-domain --domain-name $domain_name
