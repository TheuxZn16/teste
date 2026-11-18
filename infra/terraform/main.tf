# =============================================================================
# Terraform — MotivaFit AWS Infrastructure
# =============================================================================
# Recursos criados:
#   - VPC com subnets públicas e privadas
#   - Amazon RDS PostgreSQL (Multi-AZ)
#   - ECS Cluster com Fargate
#   - Application Load Balancer (ALB)
#   - ECR Repositories
#   - CloudWatch Log Groups
#   - IAM Roles e Policies
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend S3 para estado remoto (descomente em produção)
  # backend "s3" {
  #   bucket         = "motivafit-terraform-state"
  #   key            = "infrastructure/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "MotivaFit"
      ManagedBy = "Terraform"
    }
  }
}

# =============================================================================
# Módulos
# =============================================================================

module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  availability_zones = var.availability_zones
}

module "rds" {
  source = "./modules/rds"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets

  db_identifier     = var.db_identifier
  db_engine_version = var.db_engine_version
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  db_allocated_storage = var.db_allocated_storage
  multi_az          = var.db_multi_az
  backup_retention  = var.db_backup_retention
  publicly_accessible = false
}

module "alb" {
  source = "./modules/alb"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets

  alb_name = var.alb_name
}

module "ecs" {
  source = "./modules/ecs"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  public_subnets  = module.vpc.public_subnets

  cluster_name = var.cluster_name

  frontend_image = var.frontend_image
  backend_image  = var.backend_image

  # Target Groups do ALB
  frontend_tg_arn = module.alb.frontend_tg_arn
  backend_tg_arn  = module.alb.backend_tg_arn

  # Secrets do SSM (configurados pelo CI/CD)
  backend_secrets = {
    DB_URL            = "/${var.project_name}/${var.environment}/DB_URL"
    DB_USER           = "/${var.project_name}/${var.environment}/DB_USER"
    DB_PASSWORD       = "/${var.project_name}/${var.environment}/DB_PASSWORD"
    JWT_SECRET        = "/${var.project_name}/${var.environment}/JWT_SECRET"
    JWT_ISSUER        = "/${var.project_name}/${var.environment}/JWT_ISSUER"
    CORS_ALLOWED_ORIGIN = "/${var.project_name}/${var.environment}/CORS_ALLOWED_ORIGIN"
  }

  backend_environment = {
    SPRING_PROFILES_ACTIVE = "prod"
    COOKIE_SECURE          = "true"
  }
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# =============================================================================
# Saídas
# =============================================================================

output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

output "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL"
  value       = module.rds.endpoint
  sensitive   = true
}

output "rds_address" {
  description = "Endereço do RDS"
  value       = module.rds.address
}

output "rds_port" {
  description = "Porta do RDS"
  value       = module.rds.port
}

output "ecs_cluster_arn" {
  description = "ARN do cluster ECS"
  value       = module.ecs.cluster_arn
}

output "alb_dns_name" {
  description = "DNS do Application Load Balancer"
  value       = module.alb.dns_name
}

output "ecr_frontend_repo_url" {
  description = "URL do repositório ECR do Frontend"
  value       = module.ecr.frontend_repo_url
}

output "ecr_backend_repo_url" {
  description = "URL do repositório ECR do Backend"
  value       = module.ecr.backend_repo_url
}
