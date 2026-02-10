terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = format("%s-vpc-%s", var.environment, var.region)
  cidr = var.vpc_cidr

  azs = local.azs


  private_subnets = [
    for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, var.newbits, i)
  ]
  public_subnets = [
    for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, var.newbits, i + 100)
  ]

  enable_nat_gateway           = true
  single_nat_gateway           = true
  create_database_subnet_group = false


  tags = var.common_tags
}