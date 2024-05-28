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

OS_DOMAIN_NAME=${OS_DOMAIN_NAME:-"envoi-analytics"}
OS_ENGINE_VERSION=${OS_ENGINE_VERSION:-"OpenSearch_1.2"}
OS_INSTANCE_TYPE=${OS_INSTANCE_TYPE:-"r6g.large.search"}
OS_INSTANCE_COUNT=${OS_INSTANCE_COUNT:-2}
OS_EBS_VOLUME_TYPE=${OS_EBS_VOLUME_TYPE:-"gp3"}
OS_EBS_VOLUME_SIZE=${OS_EBS_VOLUME_SIZE:-100}
OS_EBS_IOPS=${OS_EBS_IOPS:-3500}
OS_EBS_THROUGHPUT=${OS_EBS_THROUGHPUT:-125}

aws opensearch create-domain \
    --domain-name ${OS_DOMAIN_NAME} \
    --engine-version ${OS_ENGINE_VERSION} \
    --cluster-config  InstanceType=${OS_INSTANCE_TYPE},InstanceCount=${OS_INSTANCE_COUNT} \
    --ebs-options EBSEnabled=true,VolumeType=${OS_EBS_VOLUME_TYPE},VolumeSize=${OS_EBS_VOLUME_SIZE},Iops=${OS_EBS_IOPS},Throughput=${OS_EBS_THROUGHPUT} \
    --access-policies '{"Version": "2012-10-17", "Statement": [{"Action": "es:*", "Principal":"*","Effect": "Allow", "Condition": {"IpAddress":{"aws:SourceIp":["192.0.2.0/32"]}}}]}'
