variable "site_name" {
  type = string
  description = "Tên định danh duy nhất của website (chữ thường, viết liền)"
}

variable "host_port" {
  type = number
  description = "Cổng port ánh xạ ngoài máy host"

  validation {
    condition     = var.host_port >= 1024 && var.host_port <=65535
    error_message = "host_port phải nằm trong khoảng từ 1024 đến 65535."
  }
}

variable "html_template_path" {
  type = string
 description = "Đường dẫn tuyệt đối hoặc tương đối tới tệp index.html.tpl" 
}

variable "admin_name" {
  type = string
  description = "Tên quản trị viên hiển thị trên trang web"
  default     = "Admin"
}

variable "site_title" {
  type = string
  description = "Tiêu đề HTML của website"
}

variable "bg_color" {
  type = string
  description = "Màu nền CSS của trang web"
  default     = "#1e293b"
}

variable "welcome_message" {
  type = string
  description = "Lời chào hiển thị ở tiêu đề trang chính"
}