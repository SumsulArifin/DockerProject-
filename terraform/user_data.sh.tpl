#!/usr/bin/env bash
set -euo pipefail

# Bootstrap: install Docker and the CloudWatch awslogs log driver dependency.
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

mkdir -p /opt/app

# SSM agent ships pre-installed on Amazon Linux 2023; nothing else to do here.
# The actual application container is started by the CI/CD deploy workflow
# (scripts/remote_deploy.sh) over SSM RunCommand, not by this bootstrap script,
# so first deploys and later rollouts go through the same code path.

echo "app_port=${app_port}" > /opt/app/bootstrap.env
