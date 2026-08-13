# --- Origin Access Control: lets CloudFront read the private S3 bucket ---
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Managed policies:
# CachingOptimized: long-lived caching for static assets in S3.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# CachingDisabled: chat responses are per-request.
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# AllViewer: forwards all headers, cookies, and query strings (required for POST)
data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = "${var.project_name} frontend + chat API"
  default_root_object = "index.html"
  price_class         = var.price_class

  origin { # first origin is the S3 bucket
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin { # second origin is the ALB
    domain_name = module.ecs.alb_dns_name
    origin_id    = "alb-chat-api"

    custom_origin_config {
      http_port                = 80
      https_port                = 443
      origin_protocol_policy    = var.alb_origin_protocol_policy  # http-only by default
      origin_ssl_protocols       = ["TLSv1.2"]
      origin_keepalive_timeout  = 5
      origin_read_timeout       = 30
    }
  }

  default_cache_behavior {  # serve the static from S3
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods         = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # /query behavior: forward straight through to the ALB
  ordered_cache_behavior {
    path_pattern             = var.api_path_pattern
    target_origin_id          = "alb-chat-api"
    viewer_protocol_policy    = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods              = ["GET", "HEAD"]
    compress                    = true
    cache_policy_id             = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id    = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # No custom domain
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
