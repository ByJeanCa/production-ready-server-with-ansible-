variable "bucket_name" {
  type = string
  default = "db-backups-jeanca-dev-20260204"
}

variable "common_tags" {
  type = map(string)
  default = {
    Project   = "Production-ready-server"
    Owner     = "Jean"
    Managedby = "Terraform"
    environment = "dev"
  }
  description = "Base tags to merge into all resources"
}

variable "environment" {
  type = string
  default = "dev"
}

variable "region" {
  type = string
  default = "us-east-1"
}

variable "instance_type" {
  type = string
  default = "t3.micro"
}

variable "ami_id" {
  type = string
  default = "ami-0b6c6ebed2801a5cb"
}

variable "key_name" {
  type = string
  default = "test"
}

variable "email" {
  type = string
  default = ""
}