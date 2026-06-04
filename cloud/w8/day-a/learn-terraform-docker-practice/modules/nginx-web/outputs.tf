output "container_id" {
description = "ID của Docker container được tạo"
  value       = docker_container.nginx.id
}

output "website_url" {
  description = "Đường dẫn URL để truy cập vào container"
  value       = "http://localhost:${var.host_port}"
}