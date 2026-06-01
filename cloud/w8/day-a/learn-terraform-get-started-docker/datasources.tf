# Sử dụng HTTP Data Source để gọi API lấy IP công cộng
data "http" "my_ip" {
  url = "https://api.ipify.org"
}