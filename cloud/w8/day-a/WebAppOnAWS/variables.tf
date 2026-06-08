variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name used in resource names."
  type        = string
  default     = "webapp"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones used for public and private subnets."
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required for RDS subnet groups."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 1
    error_message = "At least one public subnet CIDR is required."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnet CIDRs are required for RDS subnet groups."
  }
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to the web instance."
  type        = list(string)
  default     = []
}

variable "web_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access the web server over HTTP."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "web_instance_type" {
  description = "EC2 instance type for the web server."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH access. Leave null to disable key-based SSH."
  type        = string
  default     = null
}

variable "mysql_port" {
  description = "MySQL port."
  type        = number
  default     = 3306
}

variable "db_name" {
  description = "Initial MySQL database name."
  type        = string
  default     = "webapp"
}

variable "db_username" {
  description = "Master username for RDS MySQL."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for RDS MySQL."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated RDS storage in GB."
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0"
}

variable "db_backup_retention_period" {
  description = "RDS backup retention in days."
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Whether deletion protection is enabled for RDS."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip final snapshot when deleting RDS."
  type        = bool
  default     = true
}

variable "static_assets_bucket_name" {
  description = "Globally unique S3 bucket name for static assets."
  type        = string
}

variable "static_assets_force_destroy" {
  description = "Whether Terraform can delete a non-empty static assets bucket."
  type        = bool
  default     = false
}
