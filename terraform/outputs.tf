output "instance_id" {
  value = aws_instance.app.id
}

output "instance_public_ip" {
  value = aws_instance.app.public_ip
}

output "app_url" {
  value = "http://${aws_instance.app.public_ip}:${var.app_port}"
}

output "github_deploy_role_arn" {
  description = "Set this as the AWS_DEPLOY_ROLE_ARN GitHub secret"
  value       = aws_iam_role.github_deploy.arn
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.app.name
}
