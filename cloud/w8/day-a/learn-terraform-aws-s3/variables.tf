variable "aws_region" {
  type        = string
  description = "AWS Region triển khai hạ tầng"
  default     = "ap-southeast-1"
}

variable "environment" {
  type        = string
  description = "Môi trường triển khai (dev, staging, prod)"
  default     = "dev"
}

variable "project_name" {
  type        = string
  description = "Tên dự án sử dụng cho việc định danh"
  default     = "aws-s3-lab"
}

variable "bucket_prefix" {
  type        = string
  description = "Tiền tố duy nhất để đảm bảo tên S3 Bucket không bị trùng lặp toàn cầu"
  default     = "vanphutin"
}

# 🌟 SECRETS MANAGEMENT (Yêu cầu #6)
variable "s3_encryption_key" {
  type        = string
  description = "Khóa bí mật dùng để cấu hình mã hóa dữ liệu nhạy cảm trên S3 Bucket"
  sensitive   = true # Tự động ẩn giá trị khỏi log terminal khi plan/apply
}
