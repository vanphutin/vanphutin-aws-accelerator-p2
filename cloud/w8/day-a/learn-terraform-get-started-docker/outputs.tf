output "website_url" {
  description = "Địa chỉ URL để truy cập máy chủ web trên trình duyệt của bạn"
  value       = "http://localhost:${var.host_port}"
}

output "my_public_ip" {
  description = "IP công cộng của bạn được lấy qua Data Source"
  value       = data.http.my_ip.response_body
}