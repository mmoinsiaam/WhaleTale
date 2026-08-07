resource "aws_ecr_repository" "rag_api" {
  name                 = "rag-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
  force_delete = true
}

output "ecr_repository_url" { # Github Actions will use this later
  value = aws_ecr_repository.rag_api.repository_url
}