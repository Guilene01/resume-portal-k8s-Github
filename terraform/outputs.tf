output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value     = module.rds.db_endpoint
  sensitive = true
}

output "ecr_flask_url" {
  value = module.ecr.flask_repository_url
}

output "ecr_nginx_url" {
  value = module.ecr.nginx_repository_url
}

output "s3_resumes_bucket" {
  value = module.s3.resumes_bucket_name
}

output "acm_certificate_arn" {
  value = module.s3.acm_certificate_arn
}

output "hosted_zone_id" {
  value = module.s3.hosted_zone_id
}

output "github_actions_role_arn" {
  value = module.iam.github_actions_role_arn
}
output "sender_email" {
  description = "Verified SES sender email"
  value       = module.ses.sender_email
}