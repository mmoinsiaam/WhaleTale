data "aws_caller_identity" "current" {} # response format is { account_id, arn, user_id}

resource "aws_cloudwatch_log_group" "rag_api" {
  name              = "/ecs/${var.task_family}"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
}

resource "aws_iam_role_policy" "ecs_task_execution_ssm_read" {
  name = "ssm-secret-read-${var.task_family}"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters"]
      Resource = var.openai_api_key_ssm_arn
    }]
  })
}

# IAM: task execution role (pulls image from ECR, ships logs to CloudWatch)
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

# Task def: Basically the docker compose of ECS
resource "aws_ecs_task_definition" "this" {
  family                   = var.task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # makes sure each task gets its own ENI for its own sg and private ip
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  # Ephemeral, task-local volume shared between redis-init and redis.
  volume {
    name = "redis-data"
  }

  container_definitions = jsonencode([
    {
      name      = "rag-api"
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      # rag-api talks to redis over localhost since both containers share the same task-local network namespace (awsvpc mode)
      environment = [
        {
          name  = "REDIS_URL"
          value = "redis://localhost:6379"
        }
      ]
      secrets = [
        {
          name      = "OPENAI_API_KEY"
          valueFrom = var.openai_api_key_ssm_arn
        }
      ]
      dependsOn = [
        {
          containerName = "redis"
          condition     = "HEALTHY"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rag_api.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "rag-api"
        }
      }
    },
    {
      # Runs once, downloads the .rdb snapshot into the shared volume,
      name      = "redis-init"
      image     = var.redis_init_image
      essential = false

      user = "0"  #gives root access for init to properly write to the shared volume
      command = [
        "-fsSL",
        "-o", "/data/dump.rdb",
        var.redis_rdb_url #download .rdb snapshot from this url into shared volume (redis-data)
      ]
      mountPoints = [
        {
          sourceVolume  = "redis-data"
          containerPath = "/data"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rag_api.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "redis-init"
        }
      }
    },
    {
      name      = "redis"
      image     = var.redis_image
      essential = true
      # Wait for the download to fully finish before starting redis.
      dependsOn = [
        {
          containerName = "redis-init"
          condition     = "COMPLETE"
        }
      ]
      # --dir/--dbfilename point redis at the file redis-init just wrote
      command = [
        "redis-stack-server",
        "--dir",
        "/data",
        "--dbfilename",
        "dump.rdb",
        "--appendonly",
        "no",
        "--protected-mode",
        "no"
      ]
      mountPoints = [
        {
          sourceVolume  = "redis-data"
          containerPath = "/data"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "redis-cli ping || exit 1"]
        interval    = 15
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rag_api.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "redis"
        }
      }
    }
  ])
}

# ECS service
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
  force_new_deployment = true

  depends_on = [aws_lb_listener.http]
}
