variable "name_prefix" {
  description = "Name prefix for security groups."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "allowed_ssh" {
  description = "CIDR blocks allowed to access SSH."
  type        = list(string)
}

variable "web_ingress" {
  description = "CIDR blocks allowed to access HTTP."
  type        = list(string)
}

variable "mysql_port" {
  description = "MySQL port."
  type        = number
}
