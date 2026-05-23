output "resumes_bucket_name" {
  value = aws_s3_bucket.resumes.id
}

output "resumes_bucket_arn" {
  value = aws_s3_bucket.resumes.arn
}

output "acm_certificate_arn" {
  value = aws_acm_certificate_validation.main.certificate_arn
}

output "hosted_zone_id" {
  value = data.aws_route53_zone.main.zone_id
}