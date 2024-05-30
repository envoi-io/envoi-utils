#!/bin/bash

function usage {
  cat <<EOF
  This script will backup the schema for all DynamoDB tables for the current AWS account in the current region.
  Usage: $0 [options] 

  Options:
  -h, --help            Display this help and exit
  -v, --verbose         Print verbose output
  -o, --output-dir      Output directory for schema files. Default: .
  -n, --no-file-output  Suppress output to files. Default: false
EOF
}

verbose=""
output_dir="."
output_to_files="true"

while [[ $# -gt 0 ]]
do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--verbose)
      verbose="true"
      shift
      ;;
    -o|--output-dir)
      output_dir="$2"
      shift 2
      ;;
    -n|--no-file-output)
      output_to_files="false"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
    esac
done

full_output_dir_path=$(realpath $output_dir)
cd $output_dir

echo "Getting list of tables"
tables=$(aws dynamodb list-tables --query 'TableNames' --output text)
for table in $tables; do
    echo "Getting schema for table: $table"
    schema=$(aws dynamodb describe-table --table-name "$table" | jq '.Table | {TableName, KeySchema, AttributeDefinitions} + (try {LocalSecondaryIndexes: [ .LocalSecondaryIndexes[] | {IndexName, KeySchema, Projection} ]} // {}) + (try {GlobalSecondaryIndexes: [ .GlobalSecondaryIndexes[] | {IndexName, KeySchema, Projection} ]} // {}) + {BillingMode: "PAY_PER_REQUEST"}')
    [ "$verbose" == "true"  ] && echo $schema
    if [[ "$output_to_files" == "true" ]]; then
      full_file_path="$full_output_dir_path/$table.json"
      echo "Saving schema to ${full_file_path}" 
      echo $schema > $table.json   
    fi
    echo ""
done