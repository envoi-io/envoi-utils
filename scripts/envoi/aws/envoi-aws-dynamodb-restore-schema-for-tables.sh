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
input_directory="."
dry_run="false"

#!/bin/bash


while [[ $# -gt 0 ]]
do
  case "$1" in
    --input-directory)
      input_directory=$2
      shift
      shift
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --table-name-prefix)
      table_name_prefix=$2
      shift
      shift
      ;;
    --verbose)
      verbose="true"
      shift
      ;;
    *)
      echo "Error: Invalid argument $1"
      exit 1
      ;;
  esac
done

command_out=(aws dynamodb create-table --no-cli-pager)

if [ "$dry_run" == "true" ]; then
  command_out+=("--dry-run")
fi

full_input_dir_path=$(realpath $input_directory)
input_files=$(ls "$full_input_dir_path"/*.json)

for input_file in $input_files; do
  input_file_json=$(cat $input_file)
  original_table_name=$(echo ${input_file_json} | jq -r '.TableName')
  new_table_name=${table_name_prefix}${original_table_name}
  json_out=$(echo "$input_file_json" | jq '.TableName = "'"$new_table_name"'"')

  echo "Creating table: $new_table_name"

  # Validation Step
  if ! echo "$json_out" | jq empty > /dev/null; then
      echo "Error: Invalid JSON output after jq modification:"
      echo "$json_out"
      exit 1
  fi

  # Parse the JSON string to a raw JSON object
  json_object=$(jq -n "$json_out")

  # Execute the create-table command
  ${command_out[@]} --cli-input-json "$json_object"
done