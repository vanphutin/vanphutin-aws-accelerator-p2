locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = "vanphutin-devops"
    ManagedBy   = "Terraform"
  }

  bucket_base_name = "${var.bucket_prefix}-${var.project_name}-${var.environment}"

  data_bucket_name = "${local.bucket_base_name}-data"
  log_bucket_name  = "${local.bucket_base_name}-logs"
}
