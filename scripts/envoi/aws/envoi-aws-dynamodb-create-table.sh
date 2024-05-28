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

#   create-table
# --attribute-definitions <value>
# --table-name <value>
# --key-schema <value>
# [--local-secondary-indexes <value>]
# [--global-secondary-indexes <value>]
# [--billing-mode <value>]
# [--provisioned-throughput <value>]
# [--stream-specification <value>]
# [--sse-specification <value>]
# [--tags <value>]
# [--table-class <value>]
# [--deletion-protection-enabled | --no-deletion-protection-enabled]
# [--cli-input-json | --cli-input-yaml]
# [--generate-cli-skeleton <value>]

#parse command line arguments
# while [[ $# -gt 0 ]]
# do
#   key="$1"

#   case $key in
#     --attribute-definitions)
#     attribute_definitions="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     --table-name)
#     table_name="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     --key-schema)
#     key_schema="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     --local-secondary-indexes)
#     local_secondary_indexes="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     --global-secondary-indexes)
#     global_secondary_indexes="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     --billing-mode)
#     billing_mode="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     --provisioned-throughput)
#     provisioned_throughput="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     --stream-specification)
#     stream_specification="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     --sse-specification)
#     sse_specification="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     --tags)
#     tags="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     --table-class)
#     table_class="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     --deletion-protection-enabled|--no-deletion-protection-enabled)
#     deletion_protection_enabled="$key"
#     shift # past argument
#     ;;
#     --cli-input-json|--cli-input-yaml)
#     cli_input="$key"
#     shift # past argument
#     ;;
#     --generate-cli-skeleton)
#     generate_cli_skeleton="$2"
#     shift # past argument
#     shift # past value
#     ;;
#     help)
#     aws dynamodb create-table help
#     exit 0
#     ;;
#     *)    # unknown option
#     shift # past argument
#     ;;
#   esac
# done

# #execute command

# aws_command=[ "aws", "dynamodb", "create-table" ]

# if [ -n "$attribute_definitions" ]; then
#   aws_command+=("--attribute-definitions $attribute_definitions")
# fi

# if [ -n "$table_name" ]; then
#   aws_command+=("--table-name $table_name")
# fi

# if [ -n "$key_schema" ]; then
#   aws_command+=("--key-schema $key_schema")
# fi

# if [ -n "$local_secondary_indexes" ]; then
#   aws_command+=("--local-secondary-indexes $local_secondary_indexes")
# fi

# if [ -n "$global_secondary_indexes" ]; then
#   aws_command+=("--global-secondary-indexes $global_secondary_indexes")
# fi

# if [ -n "$billing_mode" ]; then
#   aws_command+=("--billing-mode $billing_mode")
# fi

# if [ -n "$provisioned_throughput" ]; then
#   aws_command+=("--provisioned-throughput $provisioned_throughput")
# fi

# if [ -n "$stream_specification" ]; then
#   aws_command+=("--stream-specification $stream_specification")
# fi

# if [ -n "$sse_specification" ]; then
#   aws_command+=("--sse-specification $sse_specification")
# fi

# if [ -n "$tags" ]; then
#   aws_command+=("--tags $tags")
# fi

# if [ -n "$table_class" ]; then
#   aws_command+=("--table-class $table_class")
# fi

# if [ -n "$deletion_protection_enabled" ]; then
#   aws_command+=("--deletion-protection-enabled")
# fi

# if [ -n "$cli_input" ]; then
#   aws_command+=("--cli-input-json $cli_input")
# fi

# if [ -n "$generate_cli_skeleton" ]; then
#   aws_command+=("--generate-cli-skeleton $generate_cli_skeleton")
# fi

# # Turn the array into a command and execute it
# aws_command="${aws_command[@]}"

# # echo "Executing: $aws_command"
# eval $aws_command

aws dynamodb create-table $*
