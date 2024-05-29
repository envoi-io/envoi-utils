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
  echo "Usage: $0 <bucket-name>"
  exit 1
}

BUCKET_NAME=${1:-$BUCKET_NAME}

if [ -z "${BUCKET_NAME}" ]; then
  usage
fi

ORIGIN_DOMAIN_NAME="${BUCKET_NAME}.s3.amazonaws.com"

aws cloudfront create-distribution --distribution-config file://<(cat << EOF
{
  "Comment": "${ORIGIN_DOMAIN_NAME}",
  "CacheBehaviors": {
    "Quantity": 0
  },
  "Logging": {
    "Bucket": "",
    "Prefix": "",
    "Enabled": false,
    "IncludeCookies": false
  },
  "Origins": {
    "Items": [
      {
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        },
        "Id": "S3-origin",
        "DomainName": "${ORIGIN_DOMAIN_NAME}"
      }
    ],
    "Quantity": 1
  },
  "DefaultRootObject": "index.html",
  "PriceClass": "PriceClass_All",
  "Enabled": false,
  "DefaultCacheBehavior": {
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    },
    "TargetOriginId": "S3-origin",
    "ViewerProtocolPolicy": "allow-all",
    "ForwardedValues": {
      "Headers": {
        "Quantity": 0
      },
      "Cookies": {
        "Forward": "none"
      },
      "QueryString": false
    },
    "SmoothStreaming": false,
    "AllowedMethods": {
      "Items": [
        "GET",
        "HEAD"
      ],
      "Quantity": 2
    },
    "MinTTL": 0
  },
  "CallerReference": "${ORIGIN_DOMAIN_NAME}-'`date +%s`'",
  "ViewerCertificate": {
    "CloudFrontDefaultCertificate": true
  },
  "CustomErrorResponses": {
    "Quantity": 0
  },
  "Restrictions": {
    "GeoRestriction": {
      "RestrictionType": "none",
      "Quantity": 0
    }
  },
  "Aliases": {
    "Quantity": 0
  },
  "CustomErrorResponses": {
    "Quantity": 2,
    "Items": [
      {
        "ErrorCode": 403,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      },
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  }
}
EOF
)
done