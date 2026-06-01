# Bài tập Thực hành Terraform Cục bộ bằng Docker (Không cần tài khoản AWS)
## Đề bài: Khởi chạy Máy chủ Web Nginx Cục bộ & Tạo Trang Web Cá nhân hóa bằng Terraform

Bài thực hành này được thiết kế để chạy **hoàn toàn trên máy tính cá nhân của bạn (100% miễn phí, không cần đăng ký tài khoản đám mây hay thẻ tín dụng)** nhưng vẫn áp dụng đầy đủ tất cả các khái niệm cốt lõi của Terraform:
1. **Providers**: Cấu hình Docker Provider và Local/HTTP Provider.
2. **Variables (Biến đầu vào)**: Khai báo cổng port, tên container trong `variables.tf` và gán giá trị trong `terraform.tfvars`.
3. **Data Sources**: Sử dụng `http` Data Source để truy vấn địa chỉ IP công cộng hiện tại của bạn từ một dịch vụ API ngoài.
4. **Resources (Tài nguyên)**: 
   - `local_file`: Tự động tạo tệp `index.html` với nội dung cá nhân hóa.
   - `docker_image`: Tải ảnh (image) Nginx từ Docker Hub.
   - `docker_container`: Khởi chạy container Nginx, ánh xạ cổng và nạp file `index.html` đã tạo.
5. **Outputs (Giá trị đầu ra)**: Xuất ra địa chỉ URL cục bộ để bạn truy cập và địa chỉ IP công cộng lấy từ Data Source.
6. **Backend**: Cấu hình Local Backend để lưu trữ file `terraform.tfstate`.

---

## 🛠️ Yêu cầu chuẩn bị trước
Máy tính của bạn cần cài đặt **Docker Desktop** (Đang chạy). Nếu chưa có, bạn có thể tải nhanh tại [Docker Desktop](https://www.docker.com/products/docker-desktop/).

---

## Cấu trúc Thư mục Dự án
Bạn sẽ tạo các file này trong thư mục `cloud/w8/day-a/learn-terraform-get-started-aws/`:
```text
learn-terraform-get-started-aws/
├── providers.tf      # Khai báo các providers (Docker, Local, HTTP)
├── variables.tf      # Khai báo các biến đầu vào (cổng port, tên container...)
├── terraform.tfvars  # Gán giá trị thực tế cho các biến
├── datasources.tf    # Dùng HTTP Data Source để lấy thông tin từ Internet
├── main.tf           # Tạo file HTML cục bộ và khởi chạy Container Nginx
├── outputs.tf        # Xuất đường dẫn URL truy cập website
└── backend.tf        # Lưu trữ trạng thái cục bộ
```

---

## Hướng dẫn từng bước thực hiện

### Bước 1: Khởi tạo Cấu hình Providers (`providers.tf`)
Tạo file `providers.tf` để khai báo các Provider sẽ sử dụng:
*   `docker`: Để tạo container.
*   `local`: Để tạo và quản lý tệp trên máy tính.
*   `http`: Để truy vấn thông tin từ một API ngoài qua giao thức HTTP.

```hcl
terraform {
  required_version = ">= 1.2.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.1"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4.0"
    }
  }
}

# Cấu hình mặc định cho Docker cục bộ
provider "docker" {}
provider "local" {}
provider "http" {}
```

---

### Bước 2: Khai báo và Thiết lập Biến (`variables.tf` & `terraform.tfvars`)

#### 1. Tạo file `variables.tf` (Khai báo biến):
```hcl
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
```

#### 2. Tạo file `terraform.tfvars` (Gán giá trị thực tế):
```hcl
container_name  = "nginx-terraform-lab"
nginx_image_tag = "alpine"
host_port       = 8080             # Bạn có thể đổi sang 8081, 8082... nếu 8080 bị trùng
your_name       = "Văn Phú Tín"    # Hãy nhập tên của bạn ở đây!
```

---

### Bước 3: Sử dụng Data Sources (`datasources.tf`)
Để hiểu cách **Data Source** hoạt động (truy vấn thông tin có sẵn bên ngoài thay vì tạo mới), chúng ta sẽ gửi một HTTP request đến API `https://api.ipify.org` để lấy địa chỉ IP công cộng hiện tại của mạng nhà bạn.

Tạo file `datasources.tf`:
```hcl
# Sử dụng HTTP Data Source để gọi API lấy IP công cộng
data "http" "my_ip" {
  url = "https://api.ipify.org"
}
```

---

### Bước 4: Định nghĩa Tài nguyên (`main.tf`)
Tại đây, chúng ta liên kết các tài nguyên với nhau:
1.  Dùng `local_file` tạo ra file `index.html` ngay trong thư mục code. Nội dung file HTML sẽ sử dụng biến `your_name`.
2.  Dùng `docker_image` tải ảnh Nginx bản nhẹ (`alpine`).
3.  Dùng `docker_container` khởi chạy container, gắn cổng `host_port` và ánh xạ (mount) file `index.html` cục bộ vào bên trong thư mục hiển thị web của Nginx (`/usr/share/nginx/html/index.html`).

Tạo file `main.tf`:
```hcl
# 1. Tạo tệp index.html cục bộ chứa nội dung cá nhân hóa từ biến
resource "local_file" "welcome_page" {
  filename = "${path.module}/index.html"
  content  = <<-EOF
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Học Terraform Cục bộ</title>
                <style>
                    body {
                        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                        background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
                        color: white;
                        text-align: center;
                        padding: 100px;
                        height: 100vh;
                        margin: 0;
                        box-sizing: border-box;
                    }
                    .card {
                        background: rgba(255, 255, 255, 0.1);
                        backdrop-filter: blur(10px);
                        border-radius: 15px;
                        padding: 40px;
                        display: inline-block;
                        box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
                        border: 1px solid rgba(255, 255, 255, 0.2);
                    }
                    h1 { margin-top: 0; }
                    p { font-size: 1.2em; color: #e0e0e0; }
                    .badge {
                        background: #4caf50;
                        padding: 5px 15px;
                        border-radius: 20px;
                        font-size: 0.9em;
                        font-weight: bold;
                    }
                </style>
            </head>
            <body>
                <div class="card">
                    <h1>Chào mừng ${var.your_name} đến với thế giới Terraform!</h1>
                    <p>Ứng dụng này đang chạy trên <strong>Docker Container</strong> được quản lý hoàn toàn bằng code Terraform.</p>
                    <p>Địa chỉ IP công cộng của bạn (Lấy từ HTTP Data Source):</p>
                    <span class="badge">${data.http.my_ip.response_body}</span>
                </div>
            </body>
            </html>
            EOF
}

# 2. Tải Nginx Docker Image từ Docker Hub
resource "docker_image" "nginx" {
  name         = "nginx:${var.nginx_image_tag}"
  keep_locally = false
}

# 3. Khởi chạy Docker Container và mount file index.html vào trong container
resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = var.container_name

  # Ánh xạ cổng (Ví dụ: 8080 trên máy thật -> 80 của container)
  ports {
    internal = 80
    external = var.host_port
  }

  # Nạp trang index.html đã tạo ở bước 1 vào container Nginx để hiển thị
  volumes {
    host_path      = abspath(local_file.welcome_page.filename)
    container_path = "/usr/share/nginx/html/index.html"
    read_only      = true
  }

  # Đảm bảo file index.html phải được tạo trước khi khởi chạy container
  depends_on = [local_file.welcome_page]
}
```

---

### Bước 5: Định nghĩa các Outputs (`outputs.tf`)
Thiết lập hiển thị đường dẫn URL để bạn click truy cập trực tiếp từ Terminal sau khi hoàn thành.

Tạo file `outputs.tf`:
```hcl
output "website_url" {
  description = "Địa chỉ URL để truy cập máy chủ web trên trình duyệt của bạn"
  value       = "http://localhost:${var.host_port}"
}

output "my_public_ip" {
  description = "IP công cộng của bạn được lấy qua Data Source"
  value       = data.http.my_ip.response_body
}
```

---

### Bước 6: Cấu hình Backend (`backend.tf`)
Vì chúng ta chạy local, file state sẽ được lưu trữ an toàn ngay trong thư mục này.

Tạo file `backend.tf`:
```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

---

## 🚀 Hướng dẫn các lệnh thực thi bài Lab

Bạn hãy mở Terminal hoặc PowerShell tại thư mục `learn-terraform-get-started-aws/` và chạy lần lượt các lệnh sau:

1. **Khởi tạo và tải xuống các Providers:**
   ```bash
   terraform init
   ```
   *(Terraform sẽ tải Docker, Local và HTTP Providers về máy của bạn)*

2. **Kiểm tra cú pháp code có hợp lệ không:**
   ```bash
   terraform validate
   ```

3. **Xem kế hoạch thay đổi (Plan):**
   ```bash
   terraform plan
   ```
   *Bạn sẽ thấy kế hoạch tạo 3 tài nguyên (1 file cục bộ, 1 docker image, 1 docker container).*

4. **Triển khai chạy Container:**
   ```bash
   terraform apply
   ```
   *(Nhập `yes` để đồng ý chạy)*

5. **Kiểm tra kết quả:**
   * Ngay sau khi chạy xong, Terraform sẽ xuất ra đường link `website_url` dạng `http://localhost:8080`.
   * Hãy mở trình duyệt và truy cập: **`http://localhost:8080`**.
   * Bạn sẽ thấy giao diện trang web hiển thị lời chào theo tên của bạn (`your_name`) và địa chỉ IP công cộng của bạn hiển thị đẹp mắt!

6. **Hủy bỏ hạ tầng (Dọn dẹp):**
   Khi thực hành xong và muốn tắt container, hãy chạy:
   ```bash
   terraform destroy
   ```
   *(Nhập `yes` để xác nhận xóa sạch container và file HTML đã tạo)*

Chúc bạn thực hành vui vẻ và nắm trọn vẹn các khái niệm Terraform cơ bản! Nếu gặp bất kỳ lỗi nào khi cài đặt hay chạy lệnh, hãy báo cho tôi biết nhé!
