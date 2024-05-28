#!/usr/bin/env bash
# Create Elastic Search Domain

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

export ES_DOMAIN_NAME=${ES_DOMAIN_NAME:-envoi-dev}
export ES_VOLUME_SIZE=${ES_VOLUME_SIZE:-10}
export ES_VERSION=${ES_VERSION:-7.10}
export ES_ADMIN_IAM_ARN=arn:aws:iam::833740154547:role/envoi-services-test-role
export ES_INSTANCE_TYPE=${ES_INSTANCE_TYPE:-t3.medium.elasticsearch}
export ENVOI_AWS_REGION=${ENVOI_AWS_REGION:-us-east-1}
export ENVOI_AWS_ACCOUNT_ID=${ENVOI_AWS_ACCOUNT_ID:-833740154547}


aws es create-elasticsearch-domain \
--domain-name ${ES_DOMAIN_NAME} \
--elasticsearch-version ${ES_VERSION} \
--elasticsearch-cluster-config  InstanceType=${ES_INSTANCE_TYPE},InstanceCount=1 \
--ebs-options EBSEnabled=true,VolumeType=standard,VolumeSize=${ES_VOLUME_SIZE} \
--access-policies "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"${ES_ADMIN_IAM_ARN}\"},\"Action\":\"es:*\",\"Resource\":\"arn:aws:es:${ENVOI_AWS_REGION}:${ENVOI_AWS_ACCOUNT_ID}:domain\/envoi-dev\/*\"}]}"
 