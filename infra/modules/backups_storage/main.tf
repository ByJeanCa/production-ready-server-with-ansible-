terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

resource "aws_s3_bucket" "db_backups" {
  bucket = var.bucket_name

  tags = var.common_tags
}

resource "aws_s3_bucket_lifecycle_configuration" "example" {
  bucket = aws_s3_bucket.db_backups.id

  rule {
    id = "expire-backups"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }
    expiration {
      days = 7
    }
  }
}

resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "s3_backups" {
  name = "ec2-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PutOnly"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.db_backups.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_backup_policy" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_backups.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-backup-profile"
  role = aws_iam_role.ec2_s3_role.name
}