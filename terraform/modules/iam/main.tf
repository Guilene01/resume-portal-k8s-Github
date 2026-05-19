# Flask Pod Role (IRSA) - allows pods to access S3 and SES
resource "aws_iam_role" "flask_pod" {
  name = "${var.project_name}-flask-pod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider}:sub" = "system:serviceaccount:default:flask-sa"
          "${var.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-flask-pod-role"
    Environment = var.environment
  }
}

# Flask Pod Policy - S3, SES, Secrets Manager
resource "aws_iam_policy" "flask_pod" {
  name        = "${var.project_name}-flask-pod-policy"
  description = "Policy for Flask pods to access AWS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.resumes_bucket_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.project_name}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "flask_pod" {
  policy_arn = aws_iam_policy.flask_pod.arn
  role       = aws_iam_role.flask_pod.name
}

# GitHub OIDC Provider
# Try to create it - if it exists, we'll import it
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name        = "${var.project_name}-github-oidc"
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = false
  }
}

# GitHub Actions Role (OIDC)
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_username}/${var.github_repo}:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-github-actions-role"
    Environment = var.environment
  }
}

# GitHub Actions Role Policy
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::rp-terraform-state-gamela",
          "arn:aws:s3:::rp-terraform-state-gamela/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:*",
          "ec2:*",
          "eks:*",
          "rds:*",
          "s3:*",
          "cloudfront:*",
          "route53:*",
          "acm:*",
          "secretsmanager:*",
          "ecr:*"
        ]
        Resource = "*"
      }
    ]
  })
}