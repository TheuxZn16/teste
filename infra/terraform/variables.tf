# =============================================================================
# Variáveis do Terraform
# =============================================================================

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "motivafit"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# VPC
variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "CIDRs das subnets públicas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "CIDRs das subnets privadas"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "Zonas de disponibilidade"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# RDS
variable "db_identifier" {
  description = "Identificador da instância RDS"
  type        = string
  default     = "motivafit-db"
}

variable "db_engine_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "16.2"
}

variable "db_instance_class" {
  description = "Tipo de instância RDS"
  type        = string
  default     = "db.t3.medium"
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "motivafit"
}

variable "db_username" {
  description = "Usuário master do banco"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Senha master do banco"
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "Armazenamento alocado (GB)"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Habilitar Multi-AZ"
  type        = bool
  default     = true
}

variable "db_backup_retention" {
  description = "Retenção de backups (dias)"
  type        = number
  default     = 7
}

# ECS
variable "cluster_name" {
  description = "Nome do cluster ECS"
  type        = string
  default     = "motivafit-cluster"
}

variable "frontend_image" {
  description = "Imagem Docker do Frontend"
  type        = string
  default     = "motivafit-frontend:latest"
}

variable "backend_image" {
  description = "Imagem Docker do Backend"
  type        = string
  default     = "motivafit-backend:latest"
}

# ALB
variable "alb_name" {
  description = "Nome do Application Load Balancer"
  type        = string
  default     = "motivafit-alb"
}
