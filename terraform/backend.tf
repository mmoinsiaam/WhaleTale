terraform {
  backend "s3" {
    bucket       = "your-tf-state-bucket"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}