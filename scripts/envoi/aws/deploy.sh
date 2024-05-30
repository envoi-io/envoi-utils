#!/usr/bin/env bash

# Get location of the script file
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source Config
source "${SCRIPT_DIR}/config.sh"

# Create Secrets

# Create IAM Roles

# Create DynamoDB Tables

# Create VPC
"${SCRIPT_DIR}/envoi-aws-vpc-create.sh"

# Create DocumentDB Cluster
"${SCRIPT_DIR}/envoi-aws-docdb-create-cluster.sh"

# Create DocumentDB Instance
"${SCRIPT_DIR}/envoi-aws-docdb-create-instance.sh"

# Create OpenSearch Domain
"${SCRIPT_DIR}/envoi-aws-opensearch-create-domain.sh"
