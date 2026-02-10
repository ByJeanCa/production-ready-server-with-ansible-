terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

resource "aws_security_group" "allow_ssh_https" {
  name        = "allow_ssh_https"
  description = "Allow ssh and https inbound traffic and all outbound traffic"
  vpc_id      = var.vpc_id

  tags = merge(
    {Name = "allow_tls"},
    var.common_tags)
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.allow_ssh_https.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_ingress_rule" "ssh_2222" {
  security_group_id = aws_security_group.allow_ssh_https.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 2222
  ip_protocol = "tcp"
  to_port     = 2222
}

resource "aws_vpc_security_group_ingress_rule" "ssh_default" {
  security_group_id = aws_security_group.allow_ssh_https.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_ingress_rule" "http_default" {
  security_group_id = aws_security_group.allow_ssh_https.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.allow_ssh_https.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = "single-instance"

  instance_type               = var.instance_type
  key_name                    = var.key_name
  monitoring                  = false
  subnet_id                   = var.subnet_id
  ami                         = var.ami_id
  associate_public_ip_address = true
  create_security_group       = false
  vpc_security_group_ids      = [aws_security_group.allow_ssh_https.id]
  iam_instance_profile        = var.instance_profile

  metadata_options = {
  http_endpoint = "enabled"
  http_tokens   = "required"
  } 

  tags = var.common_tags
}