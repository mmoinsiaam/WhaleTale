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

variable "alb_origin_protocol_policy" {
  description = "Protocol CloudFront uses to talk to the ALB origin."
  type        = string
  default     = "http-only"
}

variable "api_path_pattern" {
  description = "Path pattern routed to the ALB origin instead of S3"
  type        = string
  default     = "/query"
}

variable "price_class" {
  description = "CloudFront price class: PriceClass_100 (NA+EU only, cheapest)"
  type        = string
  default     = "PriceClass_100"
}

variable "frontend_file_path" {
  description = "Local path to the built frontend file to upload as index.html"
  type        = string
  default     = "frontend.html"
}