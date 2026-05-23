output "email_arn" {
  value = aws_ses_email_identity.sender.arn
}

output "sender_email" {
  value = var.sender_email
}