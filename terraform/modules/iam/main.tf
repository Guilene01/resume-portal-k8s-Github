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

# Read manually created OIDC provider
# Created once manually - not managed by Terraform
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Read manually created GitHub Actions role
# Created once manually - not managed by Terraform
data "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"
}