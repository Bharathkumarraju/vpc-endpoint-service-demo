# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Use the VPC module to create the Provider VPC and subnets
module "provider_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = var.provider_vpc_name
  cidr = var.provider_vpc_cidr

  azs = var.provider_az_names

  private_subnets = var.provider_private_subnets
  public_subnets  = var.provider_public_subnets

  enable_nat_gateway = false
  enable_vpn_gateway = false
}

# Create a security group for the web servers
resource "aws_security_group" "web_sg" {
  name   = var.web_sg_name
  vpc_id = module.provider_vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.web_sg_name
  }
}

# Find the custom AMI for our EC2 instances
data "aws_ami" "web_server_ami" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

# Launch the two EC2 instances in different private subnets
resource "aws_instance" "web_server" {
  count = 2

  ami           = data.aws_ami.web_server_ami.id
  instance_type = var.instance_type
  subnet_id     = element(module.provider_vpc.private_subnets, count.index)

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "web${count.index + 1}"
  }
}

# Create a Network Load Balancer (NLB)
resource "aws_lb" "nlb" {
  name               = var.nlb_name
  internal           = true
  load_balancer_type = "network"
  subnets            = module.provider_vpc.public_subnets
}

# Create a target group for the NLB
resource "aws_lb_target_group" "nlb_tg" {
  name        = var.nlb_tg_name
  port        = 80
  protocol    = "TCP"
  vpc_id      = module.provider_vpc.vpc_id

  target_type = "instance"
}

# Attach the EC2 instances to the target group
resource "aws_lb_target_group_attachment" "nlb_attachment" {
  count = 2
  target_group_arn = aws_lb_target_group.nlb_tg.arn
  target_id        = aws_instance.web_server[count.index].id
  port             = 80
}

# Create the NLB listener
resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg.arn
  }
}

# Create the VPC Endpoint Service
resource "aws_vpc_endpoint_service" "endpoint_service" {
  acceptance_required = true
  network_load_balancer_arns = [aws_lb.nlb.arn]
  private_dns_name = var.private_dns_name
}

# Add the consumer account as a principal
resource "aws_vpc_endpoint_service_allowed_principal" "consumer_principal" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.endpoint_service.id
  principal_arn           = "arn:aws:iam::${var.consumer_account_id}:root"
}

# Get the Route 53 hosted zone to create the TXT verification record
data "aws_route53_zone" "hosted_zone" {
  name = var.private_dns_name
}

# Create the TXT record for private DNS verification
resource "aws_route53_record" "dns_verification" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = aws_vpc_endpoint_service.endpoint_service.private_dns_name_configuration[0].name
  type    = "TXT"
  ttl     = 300
  records = [aws_vpc_endpoint_service.endpoint_service.private_dns_name_configuration[0].value]
}

# Output the service name for the consumer account
output "vpc_endpoint_service_name" {
  value = aws_vpc_endpoint_service.endpoint_service.service_name
}