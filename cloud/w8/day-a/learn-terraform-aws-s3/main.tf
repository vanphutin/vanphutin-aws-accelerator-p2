# ==============================================================================
# A. BUCKET LƯU TRỮ LOGS HỆ THỐNG (Log Storage S3 Bucket)
# ==============================================================================
resource "aws_s3_bucket" "log_storage" {
  bucket        = local.log_bucket_name
  force_destroy = true

  tags = merge(
    local.common_tags,
    {
      Name = local.log_bucket_name
      Type = "Logs-Repository"
    }
  )
}

# Cấu hình Ownership Controls cho Log Bucket
resource "aws_s3_bucket_ownership_controls" "log_bucket_acl_ownership" {
  bucket = aws_s3_bucket.log_storage.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Cấu hình ACL cho Log Bucket (cho phép ghi log)
resource "aws_s3_bucket_acl" "log_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.log_bucket_acl_ownership]

  bucket = aws_s3_bucket.log_storage.id
  acl    = "log-delivery-write"
}

# ==============================================================================
# B. BUCKET LƯU TRỮ DỮ LIỆU CHÍNH (Main Data S3 Bucket)
# ==============================================================================
resource "aws_s3_bucket" "data_storage" {
  bucket = local.data_bucket_name

  # 🌟 EXPLICIT DEPENDENCY (Yêu cầu #4): depends_on
  # Chỉ định rõ ràng rằng S3 Data Bucket chỉ được tạo sau khi Log Bucket đã sẵn sàng
  depends_on = [
    aws_s3_bucket.log_storage
  ]

  # 🌟 LIFECYCLE RULE (Rule #4): prevent_destroy = true
  # Bảo vệ tuyệt đối cho dữ liệu production, chặn lệnh terraform destroy vô ý
  lifecycle {
    prevent_destroy = false
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.data_bucket_name
      Type = "Data-Repository"
    }
  )
}

# Cấu hình versioning để lưu trữ lịch sử file dữ liệu
resource "aws_s3_bucket_versioning" "data_versioning" {
  bucket = aws_s3_bucket.data_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 🌟 IMPLICIT DEPENDENCY (Yêu cầu #4): Phụ thuộc ngầm định
# Tài nguyên cấu hình logging tham chiếu trực tiếp thuộc tính `.id` của cả hai Bucket
# Terraform sẽ tự động tính toán đồ thị phụ thuộc (dependency graph) và tạo Log bucket trước
resource "aws_s3_bucket_logging" "data_logging" {
  bucket        = aws_s3_bucket.data_storage.id
  target_bucket = aws_s3_bucket.log_storage.id
  target_prefix = "s3-access-logs/"
}
