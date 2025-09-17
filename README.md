# vpc-endpoint-service-demo
This repository contains the Terraform code to set up a cross-account AWS PrivateLink connection, as detailed in the Medium article below.
This is only for POC purpose - not for enterprise deployment :) use it at your own risk!

## Project Overview
This project demonstrates how to securely share an application from a **Provider VPC** to a **Consumer VPC** using AWS VPC Endpoint Service and VPC Interface Endpoints, bypassing the public internet, VPC peering, and Transit Gateway.

## How to use
The Terraform code is organized into two separate directories:
* `1.provider_aws_account/` - Contains the code to set up the VPC Endpoint Service.
* `2.consumer_aws_account/` - Contains the code to set up the VPC Interface Endpoint.

Follow the instructions in the `main.tf` and `terraform.tfvars` files within each directory to deploy the infrastructure.

## Learn More
For a detailed step-by-step guide and architecture overview, check out the full article on Medium:

[**AWS — Securely Share Apps to clients with PrivateLink via Endpoint Service**](https://medium.com/@bhrth.dsra1/aws-securely-share-app-to-clients-with-privatelink-via-endpoint-service-6215d9965c03)