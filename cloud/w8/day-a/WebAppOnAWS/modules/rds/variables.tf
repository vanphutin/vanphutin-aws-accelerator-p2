variable "name_prefix" {
  description = "Name prefix for RDS resources."
  type        = string
}

variable "db_name" {
  description = "Initial database name."
  type        = string
}

variable "db_username" {
  description = "Master username."
  type        = string
}

variable "db_password" {
  description = "Master password."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
}

variable "db_engine_version" {
  description = "MySQL engine version."
  type        = string
}

variable "db_port" {
  description = "Database port."
  type        = number
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "db_security_group_ids" {
  description = "Security group IDs for RDS."
  type        = list(string)
}

variable "backup_retention_period" {
  description = "Backup retention in days."
  type        = number
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot on deletion."
  type        = bool
}
