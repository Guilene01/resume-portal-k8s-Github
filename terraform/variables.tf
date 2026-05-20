variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for naming resources"
  type        = string
  default     = "resume-portal"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Your domain name"
  type        = string
  default     = "gamela.shop"
}

# VPC
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# EKS
variable "eks_cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_min" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "eks_node_max" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}

variable "eks_node_desired" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

# RDS
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "portal"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "portaladmin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

# SES
variable "sender_email" {
  description = "Verified SES sender email"
  type        = string
  default     = "guileneerna@gmail.com"
}


