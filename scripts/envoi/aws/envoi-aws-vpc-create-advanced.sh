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

log() {
    echo $1
}

#Envoi Distribution Cloud - AWS Virtual Private Networks:
export VPC_TAGS=Key=Name,Value=envoi-distribution-cloud
export VPC_CIDR_PREFIX=10.10.1
export VPC_CIDR=${VPC_CIDR_PREFIX}.0/24

#1 Create a VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --output=json | jq -r .Vpc.VpcId)
echo $VPC_ID

#aws ec2 create-vpc --cidr-block 10.0.1.0/24 --tag-specification ResourceType=vpc,Tags=[{Key=Name,Value=MyVpc}]

# Create Subnets - Public
PUBLIC_SUBNET_1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block ${VPC_CIDR_PREFIX}.128/26 --output=json | jq -r .Subnet.SubnetId)
log $PUBLIC_SUBNET_1_ID

PUBLIC_SUBNET_2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block ${VPC_CIDR_PREFIX}.192/26 --output=json | jq -r .Subnet.SubnetId)
log $PUBLIC_SUBNET_2_ID

#Create Subnets - Private
PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block ${VPC_CIDR_PREFIX}.0/26 --output=json | jq -r .Subnet.SubnetId)
log "Private Subnet 1 ID: ${PRIVATE_SUBNET_1_ID}"

PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block ${VPC_CIDR_PREFIX}.64/26 --output=json | jq -r .Subnet.SubnetId)

#Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --output=json | jq -r .InternetGateway.InternetGatewayId)

#Route Table
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id ${VPC_ID} --output=json | jq -r .RouteTable.RouteTableId)


#Associate Internet Gateway
aws ec2 attach-internet-gateway --vpc-id ${VPC_ID} --internet-gateway-id ${IGW_ID}

# Associate Internet Gateway with the Newly Created Route Table
CREATE_ROUTE_RESPONSE=$(aws ec2 create-route --route-table-id ${ROUTE_TABLE_ID} --destination-cidr-block 0.0.0.0/0 --gateway-id ${IGW_ID})

#Associate Route Table
aws ec2 associate-route-table  --subnet-id ${PUBLIC_SUBNET_1_ID} --route-table-id ${ROUTE_TABLE_ID}
aws ec2 associate-route-table  --subnet-id ${PUBLIC_SUBNET_2_ID} --route-table-id ${ROUTE_TABLE_ID}

#Modify Subnet
aws ec2 modify-subnet-attribute --subnet-id ${PUBLIC_SUBNET_1_ID} --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id ${PUBLIC_SUBNET_2_ID} --map-public-ip-on-launch