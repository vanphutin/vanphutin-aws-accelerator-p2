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