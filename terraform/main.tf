data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# S3 Module
module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

# IAM Module (depends on EKS for OIDC)
module "iam" {
  source = "./modules/iam"

  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  account_id          = data.aws_caller_identity.current.account_id
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider       = module.eks.oidc_provider
  resumes_bucket_name = module.s3.resumes_bucket_name

  depends_on = [module.eks]
}
# IAM Base Module (EKS roles - must exist before EKS)
module "iam_base" {
  source = "./modules/iam_base"

  project_name = var.project_name
  environment  = var.environment
}

# EKS Module (depends on VPC and IAM roles)
module "eks" {
  source = "./modules/eks"

  project_name           = var.project_name
  environment            = var.environment
  eks_cluster_version    = var.eks_cluster_version
  eks_node_instance_type = var.eks_node_instance_type
  eks_node_min           = var.eks_node_min
  eks_node_max           = var.eks_node_max
  eks_node_desired       = var.eks_node_desired
  eks_cluster_role_arn   = module.iam_base.eks_cluster_role_arn
  eks_nodes_role_arn     = module.iam_base.eks_nodes_role_arn
  eks_nodes_sg_id        = module.vpc.eks_nodes_sg_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  private_subnet_ids     = module.vpc.private_subnet_ids
  vpc_id = module.vpc.vpc_id

  depends_on = [module.vpc, module.iam_base]
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  project_name       = var.project_name
  environment        = var.environment
  db_name            = var.db_name
  db_username        = var.db_username
  db_instance_class  = var.db_instance_class
  private_subnet_ids = module.vpc.private_subnet_ids
  rds_sg_id          = module.vpc.rds_sg_id

  depends_on = [module.vpc]
}
