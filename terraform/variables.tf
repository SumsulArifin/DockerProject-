variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name, e.g. staging or production"
  type        = string
  default     = "staging"
}

variable "project_name" {
  type    = string
  default = "devops-task"
}

variable "instance_type" {
  description = "EC2 instance type. Keep within AWS Free Tier for staging."
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "allowed_ssh_cidr" {
  description = "Left unused when ssh_enabled is false (deploys go through SSM instead)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_enabled" {
  description = "Open port 22 in the security group. Off by default: deploys use SSM Session Manager."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "github_oidc_repo" {
  description = "GitHub repo allowed to assume the deploy role via OIDC, e.g. my-org/my-repo"
  type        = string
}
