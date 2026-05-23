terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# Resumes Bucket (private - stores uploaded PDFs)
resource "aws_s3_bucket" "resumes" {
  bucket        = "${var.project_name}-resumes-${var.environment}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-resumes"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "resumes" {
  bucket = aws_s3_bucket.resumes.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "resumes" {
  bucket = aws_s3_bucket.resumes.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "resumes" {
  bucket                  = aws_s3_bucket.resumes.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACM Certificate for ALB HTTPS
resource "aws_acm_certificate" "main" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-cert"
    Environment = var.environment
  }
}

# ACM Certificate validation
resource "aws_acm_certificate_validation" "main" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.main.arn

  timeouts {
    create = "10m"
  }
}

# Route 53 DNS validation records for ACM
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}