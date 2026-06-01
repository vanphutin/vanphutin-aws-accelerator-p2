output "ai_chatbot_url" {
  description = "Địa chỉ truy cập giao diện trò chuyện Web UI AI Chatbot"
  value       = "http://localhost:${var.ai_app_port}"
}

output "database_admin_url" {
  description = "Địa chỉ truy cập giao diện quản trị Database Adminer"
  value       = "http://localhost:${var.adminer_port}"
}

output "db_connection_info" {
  description = "Thông tin kết nối Database trong mạng ảo nội bộ"
  value = {
    host     = "db-host"
    port     = 5432
    database = var.db_name
    username = var.db_user
  }
  sensitive = true # 🌟 Quy tắc bảo mật nhạy cảm khi output
}