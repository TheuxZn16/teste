# =============================================================================
# Módulo: ECS — Cluster, Tasks e Services
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "cluster_name" {
  type = string
}

variable "frontend_image" {
  type = string
}

variable "backend_image" {
  type = string
}

variable "backend_secrets" {
  type = map(string)
}

variable "backend_environment" {
  type = map(string)
}

# ---------------------------------------------------------------------------
# ECS Cluster
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = var.cluster_name
  }
}

# ---------------------------------------------------------------------------
# IAM Roles
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project_name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]

  tags = {
    Name = "${var.project_name}-ecs-task-execution"
  }
}

resource "aws_iam_role" "ecs_backend_task" {
  name               = "${var.project_name}-backend-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = {
    Name = "${var.project_name}-backend-task"
  }
}

# Permissão para acessar SSM Parameters
data "aws_iam_policy_document" "ssm_access" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"]
  }
}

resource "aws_iam_role_policy" "backend_ssm" {
  name   = "${var.project_name}-backend-ssm-access"
  role   = aws_iam_role.ecs_backend_task.id
  policy = data.aws_iam_policy_document.ssm_access.json
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# CloudWatch Log Groups
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}-frontend"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-frontend-logs"
  }
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-backend-logs"
  }
}

# ---------------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------------

resource "aws_security_group" "frontend" {
  name_prefix = "${var.project_name}-${var.environment}-frontend-"
  description = "Security Group para Frontend ECS"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend-sg"
  }
}

resource "aws_security_group" "backend" {
  name_prefix = "${var.project_name}-${var.environment}-backend-"
  description = "Security Group para Backend ECS"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP API"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-backend-sg"
  }
}

# ---------------------------------------------------------------------------
# Task Definitions
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-frontend"
      image     = var.frontend_image
      essential = true
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name,
          "awslogs-region"        = data.aws_region.current.name,
          "awslogs-stream-prefix" = "frontend"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:80/index.html || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-frontend-task"
  }
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_backend_task.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-backend"
      image     = var.backend_image
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        for key, value in var.backend_environment :
        { name = key, value = value }
      ]
      secrets = [
        for key, value in var.backend_secrets :
        { name = key, valueFrom = value }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name,
          "awslogs-region"        = data.aws_region.current.name,
          "awslogs-stream-prefix" = "backend"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-backend-task"
  }
}

# ---------------------------------------------------------------------------
# ECS Services
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.frontend_tg_arn
    container_name   = "${var.project_name}-frontend"
    container_port   = 80
  }

  tags = {
    Name = "${var.project_name}-frontend-svc"
  }
}

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.backend_tg_arn
    container_name   = "${var.project_name}-backend"
    container_port   = 8080
  }

  tags = {
    Name = "${var.project_name}-backend-svc"
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

variable "frontend_tg_arn" {
  type = string
  default = ""
}

variable "backend_tg_arn" {
  type = string
  default = ""
}

output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "frontend_task_definition_arn" {
  value = aws_ecs_task_definition.frontend.arn
}

output "backend_task_definition_arn" {
  value = aws_ecs_task_definition.backend.arn
}

output "frontend_security_group_id" {
  value = aws_security_group.frontend.id
}

output "backend_security_group_id" {
  value = aws_security_group.backend.id
}
