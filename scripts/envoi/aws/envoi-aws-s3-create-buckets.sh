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
    echo "Usage: $0 <bucket-name-prefix>"
    echo "Creates the S3 buckets for the Envoi application."
    echo "bucket-name-prefix: The prefix to use for the bucket names."
}

ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX=${1:-$ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}

if [ -z "$ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX" ]; then
    usage
    exit 1
fi

export ENVOI_S3_SOURCE_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-source
export ENVOI_S3_SOURCE_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-archive
export ENVOI_S3_PROXIES_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-proxies
export ENVOI_S3_IMAGES_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-images
export ENVOI_S3_COMMON_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-common
export ENVOI_S3_SCREENING_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-screening-wui
export ENVOI_S3_SUBMISSION_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-submission-wui
export ENVOI_S3_ADMIN_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-admin-wui
export ENVOI_S3_MEETING_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-meetings-wui
export ENVOI_S3_SCHEDULER_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-scheduler-wui
export ENVOI_S3_CHANNEL_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-channel-wui
export ENVOI_S3_TRANSFER_SERVER_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-transfer-service-wui
export ENVOI_S3_MEDIAEDGE_BUCKET_NAME=${ENVOI_ENVOI_S3_BUCKET_NAME_PREFIX}-media-edge-wui

aws s3api create-bucket --bucket ${ENVOI_S3_SOURCE_BUCKET_NAME}
aws s3api create-bucket --bucket ${ENVOI_S3_PROXIES_BUCKET_NAME}
aws s3api create-bucket --bucket ${ENVOI_S3_IMAGES_BUCKET_NAME}
aws s3api create-bucket --bucket ${ENVOI_S3_COMMON_BUCKET_NAME}
aws s3api create-bucket --bucket ${ENVOI_S3_SCREENING_BUCKET_NAME}
aws s3api create-bucket --bucket ${ENVOI_S3_SUBMISSION_BUCKET_NAME}
aws s3api create-bucket --bucket ${ENVOI_S3_ADMIN_BUCKET_NAME}
aws s3api create-bucket --bucket ${ENVOI_S3_MEETING_BUCKET_NAME}
aws s3api create-bucket --bucket ${ENVOI_S3_SCHEDULER_BUCKET_NAME}
aws s3api create-bucket --bucket ${ENVOI_S3_CHANNEL_BUCKET_NAME}
aws s3api create-bucket --bucket ${ENVOI_S3_TRANSFER_SERVER_BUCKET_NAME}
aws s3api create-bucket --bucket ${ENVOI_S3_MEDIAEDGE_BUCKET_NAME}
