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

ENVOI_DOCDB_AVAILABILITY_ZONE=${ENVOI_DOCDB_AVAILABILITY_ZONE:-us-east-1a}
ENVOI_DOCDB_MASTER_USERNAME=${ENVOI_DOCDB_MASTER_USERNAME:-dbadmin}
# ENVOI_DOCDB_MASTER_USER_PASSWORD=${ENVOI_DOCDB_MASTER_USER_PASSWORD:-password}
ENVOI_DOCDB_CLUSTER_IDENTIFIER=${ENVOI_DOCDB_CLUSTER_IDENTIFIER:-envoi}

command_out=(aws docdb create-db-cluster)

while [[ $# -gt 0 ]]
do
  case "$1" in
    --availability-zone)
      ENVOI_DOCDB_AVAILABILITY_ZONE=$2
      shift
      shift
      ;;
    --db-cluster-identifier)
      ENVOI_DOCDB_CLUSTER_IDENTIFIER=$2
      shift
      shift
      ;;
    --master-username)
      ENVOI_DOCDB_MASTER_USERNAME=$2
      shift
      shift
      ;;
    --master-user-password)
      ENVOI_DOCDB_MASTER_USER_PASSWORD=$2
      shift
      shift
      ;;
    *)
      $command_out+=($1)
      shift
      ;;
  esac
done

if [ -z "$ENVOI_DOCDB_MASTER_USER_PASSWORD" ]
then
  echo "Error: ENVOI_DOCDB_MASTER_USER_PASSWORD must be set or --master-user-password is required"
  exit 1
fi

if [ -n "$ENVOI_DOCDB_MASTER_USER_PASSWORD" ]
then
  $command_out+=("--master-user-password" "$ENVOI_DOCDB_MASTER_USER_PASSWORD")
fi

if [ -n "$ENVOI_DOCDB_MASTER_USERNAME" ]
then
  $command_out+=("--master-username" "$ENVOI_DOCDB_MASTER_USERNAME")
fi

if [ -n "$ENVOI_DOCDB_AVAILABILITY_ZONE" ]
then
  $command_out+=("--availability-zone" "$ENVOI_DOCDB_AVAILABILITY_ZONE")
fi

if [ -n "$ENVOI_DOCDB_CLUSTER_IDENTIFIER" ]
then
  $command_out+=("--db-cluster-identifier" "$ENVOI_DOCDB_CLUSTER_IDENTIFIER")
fi

${command_out[@]}
