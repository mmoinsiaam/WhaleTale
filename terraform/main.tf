module "vpc" {  # set up vpc, subnets, and internet gateway
  source = "./modules/vpc"

  project_name        = var.project_name
  availability_zone   = "us-east-1a"
  availability_zone_2 = "us-east-1b"
}

module "ecs" {  # set up ECS cluster, service, task definition, and ALB
  source = "./modules/ecs"

  ecr_repository_url = aws_ecr_repository.rag_api.repository_url
  image_tag           = var.image_tag

  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids

  dev_access_cidrs           = var.dev_access_cidrs
  redis_rdb_url              = var.redis_rdb_url
  openai_api_key_ssm_arn     = aws_ssm_parameter.openai_api_key.arn 
  ssm_parameter_path_prefix  = "/rag-api/*"
}