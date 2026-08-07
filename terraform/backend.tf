terraform { #puts your tfstate in an s3 bucket, so that multiple people can work on the same terraform project
  backend "s3" {
    bucket       = "whaletale-tfstate"  #change to your own bucket name
    key          = "terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}