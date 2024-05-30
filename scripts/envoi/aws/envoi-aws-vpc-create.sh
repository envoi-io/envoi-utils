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

# Defaults
export ENVOI_VPC_NAME=${ENVOI_VPC_NAME:-envoi-distribution-cloud}
export ENVOI_VPC_TAGS="Key=Name,Value=${ENVOI_VPC_NAME}"
export ENVOI_VPC_CIDR_PREFIX=${ENVOI_VPC_CIDR_PREFIX:-10.10.1}
export ENVOI_VPC_CIDR="${ENVOI_VPC_CIDR_PREFIX}.0/24"

function log {
  echo $1
}

# Create Subnets - Public
log "Creating VPC"
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --tag-specification ResourceType=vpc,Tags=[{$VPC_TAGS}] --output=json | jq -r .Vpc.VpcId)
log "VPC ID: ${VPC_ID}"

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