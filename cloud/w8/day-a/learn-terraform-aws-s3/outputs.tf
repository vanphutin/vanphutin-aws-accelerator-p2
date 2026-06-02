output "data_bucket_arn" {
  description = "ARN của Main Data S3 Bucket"
  value       = aws_s3_bucket.data_storage.arn
}

output "data_bucket_domain_name" {
  description = "Tên miền (Domain Name) của Main Data S3 Bucket"
  value       = aws_s3_bucket.data_storage.bucket_domain_name
}

output "log_bucket_arn" {
  description = "ARN của Log Storage S3 Bucket"
  value       = aws_s3_bucket.log_storage.arn
}

# 🌟 SENSITIVE OUTPUT (Yêu cầu #7)
output "s3_encryption_profile" {
  description = "Hồ sơ thông tin mã khóa mã hóa dữ liệu nhạy cảm"
  value = {
    provider       = "AWS-KMS-Customer-Key"
    encryption_key = var.s3_encryption_key
  }
  sensitive = true # Ẩn thông tin nhạy cảm ở màn hình console
}
