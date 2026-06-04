variable "admin_name" {
  type        = string
  description = "Tên mặc định hiển thị của quản trị viên"
  default     = "Học viên AWS Accelerator"
}

variable "websites" {
  type = map(object({
    port            = number
    site_title      = string
    bg_color        = string
    welcome_message = string
  }))
  description = "Cấu hình danh sách các website cần khởi tạo động"
}