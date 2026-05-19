output "resumes_bucket_name" {
  value = aws_s3_bucket.resumes.id
}

output "resumes_bucket_arn" {
  value = aws_s3_bucket.resumes.arn
}

output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  value = aws_s3_bucket.frontend.arn
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}