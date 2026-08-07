variable "openai_api_key" {
  type      = string
  sensitive = true
}

resource "aws_ssm_parameter" "openai_api_key" { #uploads the OpenAI API key to AWS SSM Parameter Store
  name  = "/rag-api/openai-api-key"
  type  = "SecureString"
  value = var.openai_api_key
}