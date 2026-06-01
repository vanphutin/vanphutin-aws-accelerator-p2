# Hướng dẫn Chuyên sâu: Các Quy tắc Viết mã Terraform Chuẩn chỉnh & Chuyên nghiệp (Best Practices & Coding Standards)

Để xây dựng hạ tầng bằng mã (IaC) một cách an toàn, dễ bảo trì và có khả năng mở rộng tốt khi làm việc nhóm, việc tuân thủ các **Quy tắc viết mã (Write Rules)** là vô cùng quan trọng. Dưới đây là các tiêu chuẩn thiết kế mã nguồn Terraform được các kỹ sư DevOps hàng đầu thế giới áp dụng:

---

## 1. Quy tắc Đặt tên (Naming Conventions)
Đặt tên đúng chuẩn giúp mã nguồn dễ hiểu, dễ tra cứu và tránh nhầm lẫn giữa các tài nguyên.

*   **Sử dụng `snake_case`:** Tất cả tên tài nguyên, tên biến, đầu ra (outputs) và các thuộc tính phải viết thường và phân tách bằng dấu gạch dưới `_`.
    *   *Đúng:* `web_server_port`, `aws_instance`
    *   *Sai:* `webServerPort`, `web-server-port`
*   **Tránh lặp lại loại tài nguyên trong tên gọi:** Tên của tài nguyên không nên lặp lại loại tài nguyên đó vì Terraform đã tự động định danh bằng Block Type.
    *   *Đúng:* `resource "aws_instance" "web" {}`
    *   *Sai:* `resource "aws_instance" "web_instance" {}` hoặc `resource "aws_instance" "aws_web" {}`
*   **Tên biến boolean:** Nên bắt đầu bằng tiền tố `is_` hoặc `has_` để làm rõ mục đích.
    *   *Ví dụ:* `is_enabled`, `has_public_ip`.

---

## 2. Cấu trúc Thư mục & Phân tách File Tiêu chuẩn
Tránh việc gộp tất cả code vào một file `main.tf` duy nhất. Hãy phân tách chúng thành các tệp tin có trách nhiệm rõ ràng:

```text
my-project/
├── providers.tf      # Khai báo nhà cung cấp (AWS, Docker...) & yêu cầu phiên bản
├── variables.tf      # Khai báo các biến đầu vào (định nghĩa type và description)
├── terraform.tfvars  # Thiết lập giá trị thực tế của biến (Không commit file này nếu chứa secrets)
├── datasources.tf    # Khai báo các nguồn truy vấn dữ liệu động từ Cloud
├── main.tf           # Khai báo các tài nguyên hạ tầng chính (VPC, EC2, S3...)
├── outputs.tf        # Định nghĩa các thông số đầu ra cần hiển thị
└── backend.tf        # Cấu hình nơi lưu trữ file State (local hoặc S3/Terraform Cloud)
```

---

## 3. Quản lý Biến và Bảo mật Thông tin nhạy cảm (Secrets)
Rò rỉ thông tin đăng nhập (như API Key, Mật khẩu Database) là thảm họa bảo mật lớn nhất trong IaC.

*   **Luôn định nghĩa `type` và `description`:** Giúp người khác dễ hiểu biến này dùng để làm gì và nhận kiểu dữ liệu nào.
*   **Sử dụng thuộc tính `sensitive = true`:** Đối với các biến chứa mật khẩu, token, SSH keys... Hãy bật `sensitive = true` để Terraform tự động ẩn giá trị trong logs terminal.
    ```hcl
    variable "db_password" {
      type        = string
      description = "Mật khẩu quản trị database"
      sensitive   = true # Ẩn giá trị khỏi màn hình terminal
    }
    ```
*   **Bảo vệ file `terraform.tfvars`:**
    *   Thêm `terraform.tfvars` vào file `.gitignore` để tránh đẩy mật khẩu lên GitHub.
    *   Tạo file `terraform.tfvars.example` chứa các biến mẫu rỗng để hướng dẫn thành viên khác điền thông tin khi clone dự án về máy.

---

## 4. Sử dụng Khối Vòng đời tài nguyên (Lifecycle Blocks)
Các quy tắc `lifecycle` nằm bên trong khối `resource` giúp bạn kiểm soát cách Terraform tạo, sửa, xóa tài nguyên.

*   **Bảo vệ dữ liệu sống còn bằng `prevent_destroy = true`:**
    Áp dụng cho S3 bucket, Database Volume, DNS records... Để ngăn chặn việc vô tình xóa mất dữ liệu quan trọng khi chạy `terraform destroy`.
    ```hcl
    resource "docker_volume" "db_data" {
      name = "postgres_data"
      lifecycle {
        prevent_destroy = true # Chặn lệnh xóa tài nguyên này
      }
    }
    ```
*   **Tránh downtime bằng `create_before_destroy = true`:**
    Khi thay đổi thuộc tính của một máy chủ web buộc phải tạo mới, mặc định Terraform sẽ xóa máy chủ cũ trước rồi mới tạo máy chủ mới. Cấu hình này giúp tạo máy chủ mới thành công trước, chuyển luồng traffic sang rồi mới xóa máy chủ cũ (Zero-Downtime).
    ```hcl
    lifecycle {
      create_before_destroy = true
    }
    ```

---

## 5. Tối ưu hóa Dữ liệu động thông qua Data Sources
*   **Hạn chế Ghi cứng (Hardcode) IDs:** Các ID như AMI ID của máy ảo AWS, VPC ID, Subnet ID... thay đổi liên tục theo thời gian và giữa các tài khoản khác nhau.
*   **Giải pháp:** Hãy sử dụng `data` blocks để truy vấn động thông tin mới nhất trực tiếp từ môi trường Cloud.
    ```hcl
    # Tự động tìm kiếm AMI Ubuntu mới nhất từ AWS chính thức
    data "aws_ami" "latest_ubuntu" {
      most_recent = true
      owners      = ["099720109477"]
      filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
      }
    }
    ```

---

## 6. Quy trình Kiểm thử & Định dạng Chuẩn (Format & Validate)
Trước khi lưu file hoặc đẩy code (commit/push) lên Git, bạn luôn cần chạy 2 lệnh sau:

1.  **`terraform fmt` (Định dạng code):**
    Tự động căn lề, khoảng trắng, định dạng các dấu bằng (`=`) thẳng hàng theo đúng tiêu chuẩn thẩm mỹ của HashiCorp. Giúp code đồng nhất và cực đẹp mắt.
2.  **`terraform validate` (Xác thực cú pháp):**
    Kiểm tra xem code có bị lỗi cú pháp, sai kiểu dữ liệu hay thiếu thuộc tính bắt buộc hay không trước khi thực sự triển khai.

---

## 7. Quy tắc gán nhãn hạ tầng (Tagging Strategy)
Luôn gắn các nhãn `tags` vào mọi tài nguyên có hỗ trợ. Việc này giúp quản lý chi phí, phân loại hạ tầng giữa các môi trường cực kỳ dễ dàng.

```hcl
tags = {
  Name        = "nginx-web-server"
  Environment = "dev"          # dev, staging, prod
  Project     = "AI-Chatbot"
  Owner       = "Tin-DevOps"
  ManagedBy   = "Terraform"    # Đánh dấu tài nguyên được quản trị bằng IaC
}
```

Áp dụng các **Quy tắc viết mã** trên sẽ nâng tầm chất lượng code của bạn từ mức "chạy được" lên chuẩn "sản xuất doanh nghiệp" (Production-ready)!
