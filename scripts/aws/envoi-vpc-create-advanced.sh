#!/usr/bin/env bash

# subnet=$(echo "$vpc_subnets_json" | jq --argjson subnet_index "$subnet_index" '.Subnets[$subnet_index]')
# STEP_FUNCTION_JSON_OUT=$(JSON_IN=${STEP_FUNCTION_JSON} jq -crn "env.JSON_IN | fromjson | tojson")

# Envoi Distribution Cloud - AWS Virtual Private Networks:

# Defaults
export VPC_TAGS=Key=Name,Value=envoi-distribution-cloud
export VPC_CIDR_PREFIX=${VPC_CIDR_PREFIX:-10.10.1}
export VPC_CIDR=${VPC_CIDR_PREFIX}.0/24

function log {
    echo $1
}

function console {
    echo $1
}

# Define the list of commands
commands=("aws" "jq")

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

#
# Get the value of the environmental variable
VPC_TAGS_VALUE=$(env | grep VPC_TAGS | cut -d'=' -f2)

# Use jq to query the environmental variable
TAGS=$(jq -n --arg tags "$VPC_TAGS_VALUE" '$tags')

# Print the result
console "VPC Tags: $TAGS"

function create_vpc {
    declare -n VPC_REF=$1

    # Create the VPC
    CREATE_VPC_RESPONSE=$(aws ec2 create-vpc --cidr-block "$VPC_CIDR" --tags "$TAGS" --output JSON)
    VPC_REF=$CREATE_VPC_RESPONSE
}

function select_vpc {
    # Get the list of VPCs
    VPC_IDS=$(aws ec2 describe-vpcs --query 'Vpcs[].VpcId' --output text)

    # Convert the list into an array
    VPC_IDS_ARRAY=($VPC_IDS)

    # Display the VPCs and ask the user to select one
    console "Please select a VPC:"
    for i in "${!VPC_IDS_ARRAY[@]}"; do
        console "$i) ${VPC_IDS_ARRAY[$i]}"
    done

    read -p "Enter the number of the VPC you want to select: " SELECTION

    # Get the selected VPC
    SELECTED_VPC=${VPC_ARRAY[$SELECTION]}

    console "You selected VPC: $SELECTED_VPC"
}

function select_or_create_vpc {
    declare -n VPC_REF=$1
    
    # Get the list of VPCs
    VPCS=$(aws ec2 describe-vpcs --query 'Vpcs[].VpcId' --output text)

    # Convert the list into an array
    VPC_ARRAY=($VPCS)

    # Display the VPCs and ask the user to select one
    console "Please select a VPC:"
    for i in "${!VPC_ARRAY[@]}"; do
        console "$i) ${VPC_ARRAY[$i]}"
    done

    console "Or create a new VPC"

    read -p "Enter the number of the VPC you want to select or enter 'c' to create a new VPC: " SELECTION

    if [ "$SELECTION" == "c" ]; then
        create_vpc
    else
        # Get the selected VPC
        SELECTED_VPC=${VPC_ARRAY[$SELECTION]}
        console "You selected VPC: $SELECTED_VPC"
    fi

    VPC_REF=$SELECTED_VPC
}

function create_subnet {
    declare -n SUBNET_REF=$1
    VPC_ID=$2

    # Get the list of Subnets
    # Create a Subnet
    SUBNET=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block ${VPC_CIDR_PREFIX}.128/26 --output=json)
    SUBNET_REF=$SUBNET   
}


function select_or_create_subnet {
    declare -n SUBNET_REF=$1
    VPC_ID=$2

    # Get the list of Subnets
    SUBNETS=$(aws ec2 describe-subnets --query 'Subnets[].SubnetId' --output text)

    # Convert the list into an array
    SUBNET_ARRAY=($SUBNETS)

    # Display the Subnets and ask the user to select one
    console "Please select a Subnet:"
    for i in "${!SUBNET_ARRAY[@]}"; do
        console "$i) ${SUBNET_ARRAY[$i]}"
    done

    console "Or create a new Subnet"
    read -p "Enter the number of the Subnet you want to select or enter 'c'
    to create a new Subnet: " SELECTION
    if [ "$SELECTION" == "c" ]; then
        create_subnet SELECTED_SUBNET $VPC_ID
    else
    # Get the selected Subnet
    SELECTED_SUBNET=${SUBNET_ARRAY[$SELECTION]}
    console "You selected Subnet: $SELECTED_SUBNET"
    fi

    SUBNET_REF=$SELECTED_SUBNET
}

#1 Create a VPC
log "Creating VPC"
select_or_create_vpc VPC
VPC_ID=$(echo "$VPC" | jq -r '.VpcId')
log "VPC ID: ${VPC_ID}"

#aws ec2 create-vpc --cidr-block 10.0.1.0/24 --tag-specification ResourceType=vpc,Tags=[{Key=Name,Value=MyVpc}]

# Create Subnets - Public
log "Creating Public Subnet 1"
PUBLIC_SUBNET_1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block ${VPC_CIDR_PREFIX}.128/26 --output=json | jq -r .Subnet.SubnetId)
log "Public Subnet 1 ID: ${PUBLIC_SUBNET_1_ID}"

log "Creating Public Subnet 2"
PUBLIC_SUBNET_2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block ${VPC_CIDR_PREFIX}.192/26 --output=json | jq -r .Subnet.SubnetId)
log "Public Subnet 2 ID: ${PUBLIC_SUBNET_2_ID}"

#Create Subnets - Private
log "Creating Private Subnet 1"
PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block ${VPC_CIDR_PREFIX}.0/26 --output=json | jq -r .Subnet.SubnetId)
log "Private Subnet 1 ID: ${PRIVATE_SUBNET_1_ID}"

log "Creating Private Subnet 2"
PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block ${VPC_CIDR_PREFIX}.64/26 --output=json | jq -r .Subnet.SubnetId)
log "Private Subnet 2 ID: ${PRIVATE_SUBNET_2_ID}"

#Create Internet Gateway
log "Creating Internet Gateway"
IGW_ID=$(aws ec2 create-internet-gateway --output=json | jq -r .InternetGateway.InternetGatewayId)
log "Internet Gateway ID: ${IGW_ID}"

#Route Table
log "Creating Route Table"
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id ${VPC_ID} --output=json | jq -r .RouteTable.RouteTableId)
log "Route Table ID: ${ROUTE_TABLE_ID}"

#Associate Internet Gateway
log "Attaching Internet Gateway to VPC"
aws ec2 attach-internet-gateway --vpc-id ${VPC_ID} --internet-gateway-id ${IGW_ID}
log "Internet Gateway Attached to VPC"

# Associate Internet Gateway with the Newly Created Route Table
log "Creating Route Table"
CREATE_ROUTE_RESPONSE=$(aws ec2 create-route --route-table-id ${ROUTE_TABLE_ID} --destination-cidr-block 0.0.0.0/0 --gateway-id ${IGW_ID})
log "Route Table Created: ${CREATE_ROUTE_RESPONSE}"

#Associate Route Table
log "Associating Subnets to Route Table"
aws ec2 associate-route-table  --subnet-id ${PUBLIC_SUBNET_1_ID} --route-table-id ${ROUTE_TABLE_ID}
aws ec2 associate-route-table  --subnet-id ${PUBLIC_SUBNET_2_ID} --route-table-id ${ROUTE_TABLE_ID}
log "Subnets Associated to Route Table"

#Modify Subnet
log "Modifying Subnets to Auto Assign Public IP"
aws ec2 modify-subnet-attribute --subnet-id ${PUBLIC_SUBNET_1_ID} --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id ${PUBLIC_SUBNET_2_ID} --map-public-ip-on-launch
log "Subnets Modified"
