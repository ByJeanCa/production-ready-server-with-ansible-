output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_profile.name
  description = "Instance Profile name for ec2 instances"
}

output "ec2_role_name" {
  value = aws_iam_role.ec2_s3_role.name
}