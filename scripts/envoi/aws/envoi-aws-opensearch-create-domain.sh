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

# envoi-cloud-infrastructure aws opensearch create-domain | create-domain | backup-domain | restore-domain
# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/es/create-elasticsearch-domain.html

# Create OpenSearch Domain
ENVOI_OS_DOMAIN_NAME=${ENVOI_OS_DOMAIN_NAME:-"envoi-analytics"}
ENVOI_OS_ENGINE_VERSION=${ENVOI_OS_ENGINE_VERSION:-"OpenSearch_1.2"}
ENVOI_OS_INSTANCE_TYPE=${ENVOI_OS_INSTANCE_TYPE:-"r6g.large.search"}
ENVOI_OS_INSTANCE_COUNT=${ENVOI_OS_INSTANCE_COUNT:-2}
ENVOI_OS_EBS_VOLUME_TYPE=${ENVOI_OS_EBS_VOLUME_TYPE:-"gp3"}
ENVOI_OS_EBS_VOLUME_SIZE=${ENVOI_OS_EBS_VOLUME_SIZE:-100}
ENVOI_OS_EBS_IOPS=${ENVOI_OS_EBS_IOPS:-3500}
ENVOI_OS_EBS_THROUGHPUT=${ENVOI_OS_EBS_THROUGHPUT:-125}

command_out=(aws opensearch create-domain)

while [[ $# -gt 0 ]]
do
    case "$1" in
        --domain-name)
          shift
          ENVOI_OS_DOMAIN_NAME=$1
          ;;
        --engine-version)
          shift
          ENVOI_OS_ENGINE_VERSION=$1
          ;;
        --instance-type)
          shift
          ENVOI_OS_INSTANCE_TYPE=$1
          ;;
        --instance-count)
          shift
          ENVOI_OS_INSTANCE_COUNT=$1
          ;;
        --ebs-volume-type)
          shift
          ENVOI_OS_EBS_VOLUME_TYPE=$1
          ;;
        --ebs-volume-size)
          shift
          ENVOI_OS_EBS_VOLUME_SIZE=$1
          ;;
        --ebs-iops)
          shift
          ENVOI_OS_EBS_IOPS=$1
          ;;
        --ebs-throughput)
          shift
          ENVOI_OS_EBS_THROUGHPUT=$1
          ;;
        --access-policies)
          shift
          ENVOI_OS_ACCESS_POLICY=$1
          ;;
        --tags)
          shift
          ENVOI_OS_TAGS=$1
          ;;
        *)
          command_out+=("$1")
          shift
          ;;
    esac
done

if [ -n "$ENVOI_OS_DOMAIN_NAME" ]; then
  command_out+=("--domain-name" $ENVOI_OS_DOMAIN_NAME)
fi

if [ -n "$ENVOI_OS_ENGINE_VERSION" ]; then
  command_out+=("--engine-version" $ENVOI_OS_ENGINE_VERSION)
fi

if [ -n "$ENVOI_OS_INSTANCE_TYPE" ]; then
  command_out+=("--instance-type" $ENVOI_OS_INSTANCE_TYPE)
fi

if [ -n "$ENVOI_OS_INSTANCE_COUNT" ]; then
  command_out+=("--instance-count" $ENVOI_OS_INSTANCE_COUNT)
fi

if [ -n "$ENVOI_OS_EBS_VOLUME_TYPE" ]; then
  command_out+=("--ebs-volume-type" $ENVOI_OS_EBS_VOLUME_TYPE)
fi

if [ -n "$ENVOI_OS_EBS_VOLUME_SIZE" ]; then
  command_out+=("--ebs-volume-size" $ENVOI_OS_EBS_VOLUME_SIZE)
fi

if [ -n "$ENVOI_OS_EBS_IOPS" ]; then
  command_out+=("--ebs-iops" $ENVOI_OS_EBS_IOPS)
fi

if [ -n "$ENVOI_OS_EBS_THROUGHPUT" ]; then
  command_out+=("--ebs-throughput" $ENVOI_OS_EBS_THROUGHPUT)
fi

if [ -n "$ENVOI_OS_ACCESS_POLICY" ]; then
  command_out+=("--access-policies" $ENVOI_OS_ACCESS_POLICY)
fi

if [ -n "$ENVOI_OS_TAGS" ]; then
  command_out+=("--tags" $ENVOI_OS_TAGS)
fi

${command_out[@]}
