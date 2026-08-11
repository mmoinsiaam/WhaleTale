output "alb_dns_name" {
  value = module.ecs.alb_dns_name
}

output "s3_bucket_name" {
  description = "Name of the frontend S3 bucket"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID, needed for cache invalidations"
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_domain_name" {
  description = "Default *.cloudfront.net domain the site is served from"
  value       = aws_cloudfront_distribution.this.domain_name
}
