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

# function usage {
#   cat <<EOF
#   Usage: $0 [options]

#   Options:
#   --help
#   --db-cluster-identifier
#   --db-instance-identifier
#   --availability-zone
#   --db-instance-class
#   --engine
#   --engine-version
#   --master-username
#   --master-user-password
#   --db-subnet-group-name
#   --backup-retention-period
#   --db-parameter-group-name
#   --backup-window
#   --preferred-maintenance-window
#   --multi-az
#   --engine-mode
#   --skip-final-snapshot
#   --skip-final-snapshot-identifier
#   --final-snapshot-identifier
#   --final-snapshot-retention-period
#   --final-snapshot-window
#   --iam-database-authentication-enabled
#   --iam-database-authentication-username
#   --iam-database-authentication-password
#   --iam-database-authentication-database-name
#   --iam-database-authentication-schema
#   --iam-database-authentication-table-name
#   --iam-database-authentication-role-arn
#   --iam-database-authentication-kms-key-id
#   --iam-database-authentication-kms-key-arn
#   --iam-database-authentication-secret-arn
#   --iam-database-authentication-secret-access-key
#   --iam-database-authentication-access-key-id
#   --iam-database-authentication-access-key-secret
#   --iam-database-authentication-access-key-region
#   --iam-database-authentication-access-key-service
#   --iam-database-authentication-access-key-account
#   --iam-database-authentication-access-key-user
#   --iam-database-authentication-access-key-session
#   --iam-database-authentication-access-key-expiration
#   --iam-database-authentication-access-key-session-token
#   --iam-database-authentication-access-key-session-expiration
#   --iam-database-authentication-access-key-session-token-expiration
# EOF
# }

function usage {
  cat <<EOF
  Usage: $0 [options]

  Options:
  --help
    Display this help and exit

  --db-cluster-identifier
    Defaults to the value of the DEPLOY_DOCDB_CLUSTER_IDENTIFIER environment variable

  --db-instance-identifier
    Defaults to the value of the DEPLOY_DOCDB_INSTANCE_IDENTIFIER environment variable

  --availability-zone
    Defaults to the value of the DEPLOY_DOCDB_AVAILABILITY_ZONE environment variable

  --db-instance-class
    Defaults to the value of the DEPLOY_DOCDB_DB_INSTANCE_CLASS environment variable

  --engine
    Can also be set using the DEPLOY_DOCDB_ENGINE environment variable
    Default: docdb
    

EOF
}

command_out=(aws docdb create-db-instance)

DEPLOY_DOCDB_ENGINE=${DEPLOY_DOCDB_ENGINE:-docdb}
# export DB_INSTANCE_IDENTIFIER=${DEPLOY_DOCDB_INSTANCE_IDENTIFIER:-""}
# export DB_CLUSTER_IDENTIFIER=${DEPLOY_DOCDB_CLUSTER_IDENTIFIER:-""}
# export DB_INSTANCE_CLASS=${DEPLOY_DOCDB_DB_INSTANCE_CLASS:-""}

while [[ $# -gt 0 ]]
do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --db-cluster-identifier)
      DEPLOY_DOCDB_CLUSTER_IDENTIFIER=$2
      # argiments_out+=["--db-cluster-identifier" $2]
      shift
      shift
      ;;
    --db-instance-identifier)
      DEPLOY_DOCDB_INSTANCE_IDENTIFIER=$2
      # argiments_out+=["--db-instance-identifier" $2]
      shift
      shift
      ;;
    --availability-zone)
      DEPLOY_DOCDB_AVAILABILITY_ZONE=$2
      # command_out+=["--availability-zone" $2]
      shift
      shift
      ;;
    --db-instance-class)
      DEPLOY_DOCDB_DB_INSTANCE_CLASS=$2
      # command_out+=["--db-instance-class" $2]
      shift
      shift
      ;;
    --engine)
      DEPLOY_DOCDB_ENGINE=$2
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
if [ -n "$DEPLOY_DOCDB_CLUSTER_IDENTIFIER" ]; then
  command_out+=("--db-cluster-identifier" $DEPLOY_DOCDB_CLUSTER_IDENTIFIER)
fi

if [ -n "$DEPLOY_DOCDB_INSTANCE_IDENTIFIER" ]; then
  command_out+=("--db-instance-identifier" $DEPLOY_DOCDB_INSTANCE_IDENTIFIER)
fi

if [ -n "$DEPLOY_DOCDB_AVAILABILITY_ZONE" ]; then
  command_out+=("--availability-zone" $DEPLOY_DOCDB_AVAILABILITY_ZONE)
fi

if [ -n "$DEPLOY_DOCDB_DB_INSTANCE_CLASS" ]; then
  command_out+=("--db-instance-class" $DEPLOY_DOCDB_DB_INSTANCE)
fi

if [ -n "$DEPLOY_DOCDB_ENGINE" ]; then
  command_out+=("--engine" "$DEPLOY_DOCDB_ENGINE")
fi

# Create Cluster Instance
# export DEPLOYMENT_DOCDB_CREATE_INSTANCE_OUTPUT=$(aws docdb create-db-instance \
# --engine docdb --db-cluster-identifier DEPLOY_DOCDB_CLUSTER_IDENTIFIER 
# --db-instance-identifier $DEPLOY_DOCDB_INSTANCE_IDENTIFIER 
# --availability-zone $DEPLOY_DOCDB_AVAILABILITY_ZONE 
# --db-instance-class $DEPLOY_DOCDB_DB_INSTANCE_CLASS)

# echo $DEPLOYMENT_DOCDB_CREATE_INSTANCE_OUTPUT

${command_out[@]}