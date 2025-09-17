# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Use the VPC module to create the Consumer VPC and subnets
module "consumer_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = var.consumer_vpc_name
  cidr = var.consumer_vpc_cidr

  azs = var.consumer_az_names

  private_subnets = var.consumer_private_subnets
  public_subnets  = var.consumer_public_subnets

  enable_nat_gateway = false
  enable_vpn_gateway = false
}

# Create a security group for the client instance and endpoint
resource "aws_security_group" "client_sg" {
  name   = var.client_sg_name
  vpc_id = module.consumer_vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.consumer_vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the VPC Interface Endpoint
resource "aws_vpc_endpoint" "interface_endpoint" {
  vpc_id              = module.consumer_vpc.vpc_id
  service_name        = var.provider_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.consumer_vpc.public_subnets[0], module.consumer_vpc.public_subnets[1]]
  security_group_ids  = [aws_security_group.client_sg.id]
  private_dns_enabled = true
}

# Find the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

# Launch the test EC2 instance
resource "aws_instance" "test_client" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = module.consumer_vpc.public_subnets[0]
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.client_sg.id]

  tags = {
    Name = "test-client"
  }
}
