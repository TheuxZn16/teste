# =============================================================================
# Módulo: ECR — Elastic Container Registry
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project_name}-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  lifecycle_policy {
    policy = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep last 10 images"
          selection = {
            tlsMaxImageAge = "30"
            tlsCountNumber = 10
            tlsCountUnit   = "image"
            tlsCountType   = "imageCountMoreThan"
          }
          action = {
            type = "expire"
          }
        }
      ]
    })
  }

  tags = {
    Name      = "${var.project_name}-frontend-ecr"
    Environment = var.environment
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  lifecycle_policy {
    policy = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep last 10 images"
          selection = {
            tlsMaxImageAge = "30"
            tlsCountNumber = 10
            tlsCountUnit   = "image"
            tlsCountType   = "imageCountMoreThan"
          }
          action = {
            type = "expire"
          }
        }
      ]
    })
  }

  tags = {
    Name      = "${var.project_name}-backend-ecr"
    Environment = var.environment
  }
}

output "frontend_repo_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "backend_repo_url" {
  value = aws_ecr_repository.backend.repository_url
}
