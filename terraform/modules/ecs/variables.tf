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
  description = "Subnets for the Fargate tasks"
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

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "dev_access_cidrs" {
  type    = list(string)
  default = []
}

variable "redis_rdb_url" {
  description = "URL to the redis dump.rdb file to load on startup"
  type        = string
}

variable "redis_image" {
  description = "Redis image for the sidecar container"
  type        = string
  default     = "redis/redis-stack:latest"
}

variable "redis_init_image" {
  description = "Small curl-capable image used only to download the .rdb before redis starts"
  type        = string
  default     = "curlimages/curl:8.10.1"
}

variable "openai_api_key_ssm_arn" {
  description = "ARN of the SSM parameter holding the OpenAI API key, injected into rag-api as OPENAI_API_KEY via ECS secrets"
  type        = string
}