output "flask_pod_role_arn" {
  value = aws_iam_role.flask_pod.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}