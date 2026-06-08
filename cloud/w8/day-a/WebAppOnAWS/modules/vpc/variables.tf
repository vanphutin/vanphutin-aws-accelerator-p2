variable "name_prefix" {
  description = "Name prefix for VPC resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for subnets."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= length(var.public_subnet_cidrs) && length(var.availability_zones) >= length(var.private_subnet_cidrs)
    error_message = "availability_zones must contain at least as many items as the public and private subnet CIDR lists."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
}
