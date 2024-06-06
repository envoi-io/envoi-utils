#!/usr/bin/env bash

log() {
  echo "$1"
}

verbose() {
  [[ "$VERBOSE" == "true" ]] && echo -e "\033[0;33m$1\033[0m"  # yellow
}
# Define the list of dependencies
dependencies=("aws")

# Iterate over the commands and check their availability
for cmd in "${dependencies[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd command was not found."
		all_dependencies_met=false
  fi
done

if [ "$all_dependencies_met" == false ]; then
	exit 1
fi

ENVOI_DEPLOYMENT_NAME=${ENVOI_DEPLOYMENT_NAME:-envoi}

# MYSQL Secret
export ENVOI_MYSQL_SECRET_NAME=${ENVOI_MYSQL_SECRET_NAME:-"${ENVOI_DEPLOYMENT_NAME}/mysql"}

# Check to see if secret exists
ENVOI_MYSQL_SECRET_DESCRIPTION=$(aws secretsmanager describe-secret --secret-id $ENVOI_MYSQL_SECRET_NAME 2>/dev/null)
if [[ -n "$ENVOI_MYSQL_SECRET_DESCRIPTION" ]]; then
  log "Secret $ENVOI_MYSQL_SECRET_NAME already exists"
  ENVOI_MYSQL_SECRET_CONTENTS=$(aws secretsmanager get-secret-value --secret-id $ENVOI_MYSQL_SECRET_NAME --query SecretString --output text)
  ENVOI_MYSQL_MASTER_USERNAME=$(echo $ENVOI_MYSQL_SECRET_CONTENTS | jq -r .username)
  ENVOI_MYSQL_MASTER_PASSWORD=$(echo $ENVOI_MYSQL_SECRET_CONTENTS | jq -r .password)
  ENVOI_MYSQL_SECRET_ARN=$(echo $ENVOI_MYSQL_SECRET_DESCRIPTION | jq -r .ARN)
else
  if [[ -n "$ENVOI_DEPLOY_SHOULD_CREATE_MYSQL_SECRET" && "$ENVOI_DEPLOY_SHOULD_CREATE_MYSQL_SECRET" == "true" ]]; then
    #  Only printable ASCII characters besides '/', '@', '"', ' ' may be used
    ENVOI_MYSQL_MASTER_PASSWORD=${ENVOI_MYSQL_MASTER_PASSWORD:-$(aws secretsmanager get-random-password --require-each-included-type --password-length 20 --exclude-characters '/@" ' | jq -r .RandomPassword)}
    ENVOI_MYSQL_SECRET_CONTENTS=$(jq -n --arg MYSQL_username "$ENVOI_MYSQL_MASTER_USERNAME" --arg MYSQL_password "$ENVOI_MYSQL_MASTER_PASSWORD" '{username: $MYSQL_username, password: $MYSQL_password}')
    log "Creating secret $ENVOI_MYSQL_SECRET_NAME"
    ENVOI_MYSQL_SECRET_ARN=$(aws secretsmanager create-secret --name $ENVOI_MYSQL_SECRET_NAME --secret-string "$ENVOI_MYSQL_SECRET_CONTENTS" --query ARN --output text)
  fi
fi
verbose "ENVOI_MYSQL_SECRET_CONTENTS: $ENVOI_MYSQL_SECRET_CONTENTS"

export ENVOI_MYSQL_MASTER_PASSWORD
export ENVOI_MYSQL_SECRET_CONTENTS
export ENVOI_MYSQL_SECRET_ARN

# POSTGRES Secret
export ENVOI_POSTGRES_SECRET_NAME=${ENVOI_POSTGRES_SECRET_NAME:-"${ENVOI_DEPLOYMENT_NAME}/postgres"}

# Check to see if secret exists
ENVOI_POSTGRES_SECRET_DESCRIPTION=$(aws secretsmanager describe-secret --secret-id $ENVOI_POSTGRES_SECRET_NAME 2>/dev/null)
if [[ -n $ENVOI_POSTGRES_SECRET_DESCRIPTION ]]; then
  log "Secret $ENVOI_POSTGRES_SECRET_NAME already exists"
  ENVOI_POSTGRES_SECRET_CONTENTS=$(aws secretsmanager get-secret-value --secret-id $ENVOI_POSTGRES_SECRET_NAME --query SecretString --output text)
  ENVOI_POSTGRES_MASTER_USERNAME=$(echo $ENVOI_POSTGRES_SECRET_CONTENTS | jq -r .username)
  ENVOI_POSTGRES_MASTER_PASSWORD=$(echo $ENVOI_POSTGRES_SECRET_CONTENTS | jq -r .password)
  ENVOI_POSTGRES_SECRET_ARN=$(echo $ENVOI_POSTGRES_SECRET_DESCRIPTION | jq -r .ARN)
else
  if [[ -n "$ENVOI_DEPLOY_SHOULD_CREATE_POSTGRES_SECRET" && "$ENVOI_DEPLOY_SHOULD_CREATE_POSTGRES_SECRET" == "true" ]]; then
    ENVOI_POSTGRES_MASTER_PASSWORD=${ENVOI_POSTGRES_MASTER_PASSWORD:-$(aws secretsmanager get-random-password --require-each-included-type --password-length 20 | jq -r .RandomPassword)}
    ENVOI_POSTGRES_SECRET_CONTENTS=$(jq -n --arg POSTGRES_username "$ENVOI_POSTGRES_MASTER_USERNAME" --arg POSTGRES_password "$ENVOI_POSTGRES_MASTER_PASSWORD" '{username: $POSTGRES_username, password: $POSTGRES_password}')
    log "Creating secret $ENVOI_POSTGRES_SECRET_NAME"
    ENVOI_POSTGRES_SECRET_ARN=$(aws secretsmanager create-secret --name $ENVOI_POSTGRES_SECRET_NAME --secret-string "$ENVOI_POSTGRES_SECRET_CONTENTS" --query ARN --output text)
  fi
fi
verbose "ENVOI_POSTGRES_SECRET_CONTENTS: $ENVOI_POSTGRES_SECRET_CONTENTS"

export ENVOI_POSTGRES_MASTER_PASSWORD
export ENVOI_POSTGRES_SECRET_CONTENTS
export ENVOI_POSTGRES_SECRET_ARN

# MONGO Secret
export ENVOI_MONGO_SECRET_NAME=${ENVOI_MONGO_SECRET_NAME:-"${ENVOI_DEPLOYMENT_NAME}/mongo"}

# Check to see if secret exists
ENVOI_MONGO_SECRET_DESCRIPTION=$(aws secretsmanager describe-secret --secret-id "$ENVOI_MONGO_SECRET_NAME" 2>/dev/null)
if [[ -n $ENVOI_MONGO_SECRET_DESCRIPTION ]]; then
  log "Secret $ENVOI_MONGO_SECRET_NAME already exists"
  ENVOI_MONGO_SECRET_CONTENTS=$(aws secretsmanager get-secret-value --secret-id "$ENVOI_MONGO_SECRET_NAME" --query SecretString --output text)
  ENVOI_MONGO_MASTER_USERNAME=$(echo $ENVOI_MONGO_SECRET_CONTENTS | jq -r .username)
  ENVOI_MONGO_MASTER_PASSWORD=$(echo $ENVOI_MONGO_SECRET_CONTENTS | jq -r .password)
  ENVOI_MONGO_SECRET_ARN=$(echo $ENVOI_MONGO_SECRET_DESCRIPTION | jq -r .ARN)
else
  if [[ -n "$ENVOI_DEPLOY_SHOULD_CREATE_MONGO_SECRET" && "$ENVOI_DEPLOY_SHOULD_CREATE_MONGO_SECRET" == "true" ]]; then
    ENVOI_MONGO_MASTER_PASSWORD=${ENVOI_MONGO_MASTER_PASSWORD:-$(aws secretsmanager get-random-password --require-each-included-type --password-length 20 | jq -r .RandomPassword)}
    ENVOI_MONGO_SECRET_CONTENTS=$(jq -n --arg mongo_username "$ENVOI_MONGO_MASTER_USERNAME" --arg mongo_password "$ENVOI_MONGO_MASTER_PASSWORD" '{username: $mongo_username, password: $mongo_password}')
    log "Creating secret $ENVOI_MONGO_SECRET_NAME"
    ENVOI_MONGO_SECRET_ARN=$(aws secretsmanager create-secret --name $ENVOI_MONGO_SECRET_NAME --secret-string "$ENVOI_MONGO_SECRET_CONTENTS" --query ARN --output text)
  fi
fi
verbose "ENVOI_MONGO_SECRET_CONTENTS: $ENVOI_MONGO_SECRET_CONTENTS"

export ENVOI_MONGO_MASTER_PASSWORD
export ENVOI_MONGO_SECRET_CONTENTS
export ENVOI_MONGO_SECRET_ARN

echo "{\"mysql\": \"$ENVOI_MYSQL_SECRET_ARN\", \"postgres\": \"$ENVOI_POSTGRES_SECRET_ARN\", \"mongo\": \"$ENVOI_MONGO_SECRET_ARN\"}"
