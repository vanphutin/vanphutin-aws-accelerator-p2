# Cấu hình backend lưu trữ state
terraform {
  # Khai báo backend là "local", nghĩa là file state sẽ được lưu trên máy cục bộ
  # Lưu ý: Trong môi trường production thực tế, bạn nên sử dụng "s3" hoặc "azurerm"
  backend "local" {
    path = "terraform.tfstate" # Tên file state sẽ được tạo trong thư mục hiện tại
  }
}