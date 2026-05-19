output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "ecr_flask_url" {
  description = "ECR URL for Flask app"
  value       = module.ecr.flask_repository_url
}

output "ecr_nginx_url" {
  description = "ECR URL for Nginx frontend"
  value       = module.ecr.nginx_repository_url
}

output "s3_frontend_bucket" {
  description = "Frontend S3 bucket name"
  value       = module.s3.frontend_bucket_name
}

output "s3_resumes_bucket" {
  description = "Resumes S3 bucket name"
  value       = module.s3.resumes_bucket_name
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain"
  value       = module.s3.cloudfront_domain
}
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC"
  value       = module.iam.github_actions_role_arn
}