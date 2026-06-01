variable "container_name" {
  type        = string
  description = "Tên của Docker container"
  default     = "my-local-webserver"
}

variable "nginx_image_tag" {
  type        = string
  description = "Phiên bản Nginx sử dụng"
  default     = "alpine"
}

variable "host_port" {
  type        = number
  description = "Cổng truy cập trên máy cá nhân (Host Port)"
  default     = 8080
}

variable "your_name" {
  type        = string
  description = "Tên của bạn để hiển thị trên Website"
  default     = "Học viên AWS Accelerator"
}