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
  cat <<EOF
  Usage: $0 [options]

  Options:
  --help
    Display this help and exit

  --db-cluster-identifier
    Defaults to the value of the ENVOI_DOCDB_CLUSTER_IDENTIFIER environment variable

  --db-instance-identifier
    Defaults to the value of the ENVOI_DOCDB_INSTANCE_IDENTIFIER environment variable

  --availability-zone
    Defaults to the value of the ENVOI_DOCDB_AVAILABILITY_ZONE environment variable

  --db-instance-class
    Defaults to the value of the ENVOI_DOCDB_DB_INSTANCE_CLASS environment variable

  --engine
    Can also be set using the ENVOI_DOCDB_ENGINE environment variable
    Default: docdb
    

EOF
}

command_out=(aws docdb create-db-instance)

ENVOI_DOCDB_ENGINE=${ENVOI_DOCDB_ENGINE:-"docdb"}
export DB_INSTANCE_IDENTIFIER=${ENVOI_DOCDB_INSTANCE_IDENTIFIER:-"envoi"}
export DB_CLUSTER_IDENTIFIER=${ENVOI_DOCDB_CLUSTER_IDENTIFIER:-"envoi"}
# export DB_INSTANCE_CLASS=${ENVOI_DOCDB_DB_INSTANCE_CLASS:-""}

while [[ $# -gt 0 ]]
do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --db-cluster-identifier)
      ENVOI_DOCDB_CLUSTER_IDENTIFIER=$2
      # argiments_out+=["--db-cluster-identifier" $2]
      shift
      shift
      ;;
    --db-instance-identifier)
      ENVOI_DOCDB_INSTANCE_IDENTIFIER=$2
      # argiments_out+=["--db-instance-identifier" $2]
      shift
      shift
      ;;
    --availability-zone)
      ENVOI_DOCDB_AVAILABILITY_ZONE=$2
      # command_out+=["--availability-zone" $2]
      shift
      shift
      ;;
    --db-instance-class)
      ENVOI_DOCDB_DB_INSTANCE_CLASS=$2
      # command_out+=["--db-instance-class" $2]
      shift
      shift
      ;;
    --engine)
      ENVOI_DOCDB_ENGINE=$2
      # command_out+=["--engine" $2]
      shift
      shift
      ;;
    *)
      command_out+=("$1")
      shift
      ;;
  esac
done

# If set
if [ -n "$ENVOI_DOCDB_CLUSTER_IDENTIFIER" ]; then
  command_out+=("--db-cluster-identifier" $ENVOI_DOCDB_CLUSTER_IDENTIFIER)
fi

if [ -n "$ENVOI_DOCDB_INSTANCE_IDENTIFIER" ]; then
  command_out+=("--db-instance-identifier" $ENVOI_DOCDB_INSTANCE_IDENTIFIER)
fi

if [ -n "$ENVOI_DOCDB_AVAILABILITY_ZONE" ]; then
  command_out+=("--availability-zone" $ENVOI_DOCDB_AVAILABILITY_ZONE)
fi

if [ -n "$ENVOI_DOCDB_DB_INSTANCE_CLASS" ]; then
  command_out+=("--db-instance-class" $ENVOI_DOCDB_DB_INSTANCE)
fi

if [ -n "$ENVOI_DOCDB_ENGINE" ]; then
  command_out+=("--engine" "$ENVOI_DOCDB_ENGINE")
fi

${command_out[@]}
