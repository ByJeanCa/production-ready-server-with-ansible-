terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0.0"
    }
  }
}

provider "aws" {
  profile = "your-profile"
  region  = "us-east-1"
}

module "s3_bucket_backups" {
  source = "./modules/backups_storage"

  bucket_name = var.bucket_name
  common_tags = var.common_tags
}

module "vpc_module" {
  source = "./modules/network"

  common_tags = var.common_tags
  az_count = 2
  environment = var.environment
  region = var.region
  vpc_cidr = "10.0.0.0/16"
  newbits = 8
}

module "server_module" {
  source = "./modules/servers"

  environment = var.environment
  vpc_id = module.vpc_module.vpc_id
  common_tags = var.common_tags
  instance_type = var.instance_type
  instance_profile = module.s3_bucket_backups.ec2_instance_profile_name
  ami_id = var.ami_id
  subnet_id = module.vpc_module.public_subnets[0]
  key_name = var.key_name
}

module "monitoring_module" {
  source = "./modules/monitoring"

  instance_id = module.server_module.ec2_instance_id
  email = var.email
  ec2_role_name = module.s3_bucket_backups.ec2_role_name
}
