variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "redis_rdb_url" {
  type = string
  sensitive = true
}

variable "dev_access_cidrs" {
  type = list(string)
}