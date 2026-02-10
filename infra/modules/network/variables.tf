variable "common_tags" {
  type = map(string)
}

variable "az_count" {
  type = number
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "newbits" {
  type = string
}