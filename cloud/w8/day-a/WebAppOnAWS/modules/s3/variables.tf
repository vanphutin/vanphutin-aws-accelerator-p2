variable "bucket_name" {
  description = "S3 bucket name."
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for tags."
  type        = string
}

variable "force_destroy" {
  description = "Whether Terraform can delete a non-empty bucket."
  type        = bool
  default     = false
}
