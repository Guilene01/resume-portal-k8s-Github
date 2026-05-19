output "flask_repository_url" {
  value = aws_ecr_repository.flask.repository_url
}

output "nginx_repository_url" {
  value = aws_ecr_repository.nginx.repository_url
}

output "flask_repository_name" {
  value = aws_ecr_repository.flask.name
}

output "nginx_repository_name" {
  value = aws_ecr_repository.nginx.name
}

output "registry_id" {
  value = aws_ecr_repository.flask.registry_id
}