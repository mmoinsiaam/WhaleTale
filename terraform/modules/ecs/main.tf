data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# CloudWatch log group
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "rag_api" {
  name              = "/ecs/${var.task_family}"
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------------------
# ECS cluster
# ---------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
}

# ---------------------------------------------------------------------------
# IAM: task execution role (pulls image from ECR, ships logs to CloudWatch)
# Name matches the *ecsTaskExecutionRole* pattern in the GH Actions IAM policy.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-${var.task_family}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------------------------------------------------------------------------
# IAM: task role (assumed by the running container at runtime)
# Name matches the *ecsTaskRole* pattern in the GH Actions IAM policy.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole-${var.task_family}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_ssm_read" {
  name = "ssm-read-${var.task_family}"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_path_prefix}"
    }]
  })
}

# ---------------------------------------------------------------------------
# Task definition — this is what consumes the image from the ECR push step
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  family                   = var.task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "rag-api"
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rag_api.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "rag-api"
        }
      }
    }
  ])
}

# ---------------------------------------------------------------------------
# ECS service
# ---------------------------------------------------------------------------
resource "aws_ecs_service" "this" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "rag-api"
    container_port   = var.container_port
  }

  # Forces a new deployment whenever the task def changes (new image tag)
  # so `terraform apply` on every push actually rolls the service.
  force_new_deployment = true

  depends_on = [aws_lb_listener.http]
}
