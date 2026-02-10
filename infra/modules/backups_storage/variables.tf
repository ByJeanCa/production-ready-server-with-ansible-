variable "bucket_name" {
  type = string
  default = "db-backups-jeanca-dev-20260204"
}

variable "common_tags" {
  type = map(string)
}