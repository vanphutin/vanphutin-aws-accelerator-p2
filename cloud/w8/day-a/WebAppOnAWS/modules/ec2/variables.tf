variable "name_prefix" {
  description = "Name prefix for EC2 resources."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name."
  type        = string
  default     = null
}

variable "public_subnet_id" {
  description = "Public subnet ID for the web server."
  type        = string
}

variable "security_group_ids" {
  description = "Security groups attached to the web server."
  type        = list(string)
}

variable "db_endpoint" {
  description = "RDS database endpoint."
  type        = string
}

variable "db_name" {
  description = "Database name."
  type        = string
}

variable "db_username" {
  description = "Database username."
  type        = string
}

variable "static_bucket_name" {
  description = "S3 static assets bucket name."
  type        = string
}
