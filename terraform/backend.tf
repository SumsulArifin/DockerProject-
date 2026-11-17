# Fill in the bucket/table created by terraform/bootstrap, then run:
#   terraform init -backend-config=environments/staging.backend.hcl
# (or pass -backend-config values directly on the CLI / via CI secrets).
terraform {
  backend "s3" {
    # bucket         = "devops-task-tfstate-<your-suffix>"
    # key            = "devops-task/<env>/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "devops-task-tfstate-<your-suffix>-locks"
    # encrypt        = true
  }
}
