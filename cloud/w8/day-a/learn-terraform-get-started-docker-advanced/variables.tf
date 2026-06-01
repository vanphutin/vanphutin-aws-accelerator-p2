variable "groq_api_key" {
  type        = string
  description = "API Key của Groq Cloud để sử dụng mô hình Llama3"
  sensitive   = true # 🌟 Quy tắc bảo mật nhạy cảm
}

variable "db_password" {
  type        = string
  description = "Mật khẩu quản trị PostgreSQL"
  sensitive   = true # 🌟 Quy tắc bảo mật nhạy cảm
}

variable "db_user" {
  type        = string
  description = "Tên tài khoản quản trị PostgreSQL"
  default     = "postgres"
}

variable "db_name" {
  type        = string
  description = "Tên cơ sở dữ liệu lưu trữ lịch sử chat"
  default     = "ai_chat_db"
}

variable "ai_app_port" {
  type        = number
  description = "Cổng truy cập ứng dụng AI ngoài máy thật"
  default     = 5000
}

variable "adminer_port" {
  type        = number
  description = "Cổng truy cập giao diện quản trị database Adminer ngoài máy thật"
  default     = 8888
}