resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  source       = var.frontend_file_path
  content_type = "text/html"
  etag         = filemd5(var.frontend_file_path)
}

#This fires an invalidation automatically whenever the file's contents change (etag differs),
resource "null_resource" "invalidate_cache" {
  triggers = {
    file_etag = aws_s3_object.index_html.etag
  }

  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.this.id} --paths '/index.html'"
  }

  depends_on = [aws_s3_object.index_html]
}
