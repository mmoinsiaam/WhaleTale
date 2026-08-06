variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "whale-pod"
}

variable "service_name" {
  type    = string
  default = "whale-service"
}

variable "task_family" {
  type    = string
  default = "rag-api-pod"
}

variable "ecr_repository_url" {
  description = "aws_ecr_repository.rag_api.repository_url from the root module"
  type        = string
}

variable "image_tag" {
  description = "Image tag to deploy, e.g. github.sha (comes in via TF_VAR_image_tag)"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Subnets for the ALB (need IGW route)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Subnets for the Fargate tasks (need NAT route for ECR/SSM pulls unless using VPC endpoints)"
  type        = list(string)
}

variable "container_port" {
  type    = number
  default = 8000
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "cpu" {
  type    = number
  default = 512
}

variable "memory" {
  type    = number
  default = 1024
}

variable "ssm_parameter_path_prefix" {
  description = "SSM path the task role may read, e.g. /your-app/* (matches the task-role example in the IAM doc)"
  type        = string
}

variable "log_retention_days" {
  type    = number
  default = 14
}
