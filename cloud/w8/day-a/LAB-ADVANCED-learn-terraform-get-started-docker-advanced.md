# Bài tập Thực hành Terraform Nâng cao & Chuyên sâu (Day A)
## Chủ đề: Thiết lập Hệ thống Multi-Tier AI Chatbot Đạt chuẩn Best Practice & Coding Standards

Bài lab này là sự kết hợp hoàn hảo giữa **Kiến trúc Multi-Tier tích hợp AI Chatbot cục bộ** và bộ quy tắc viết code chuẩn chỉnh **[writing-rules.md](./writing-rules.md)**. 

Thông qua bài học này, từng dòng code bạn viết ra sẽ được phân tích, định nghĩa và giải thích lý do **tại sao nó lại là Best Practice** trong thực tế doanh nghiệp.

---

## 🎯 7 Quy tắc từ `writing-rules.md` được áp dụng và giải thích trong bài lab:
1.  **Quy tắc đặt tên (`snake_case` & tránh lặp loại tài nguyên)**: Áp dụng trên tất cả tài nguyên, biến và outputs.
2.  **Cấu trúc phân tách file tiêu chuẩn**: Tách hạ tầng thành 6 file chức năng riêng biệt để dễ quản lý.
3.  **Bảo mật dữ liệu nhạy cảm (Secrets Management)**: Sử dụng thuộc tính `sensitive = true` cho mật khẩu DB và Groq API Key.
4.  **Bảo vệ dữ liệu & Zero-Downtime (Lifecycle blocks)**: Sử dụng `prevent_destroy` bảo vệ dữ liệu hội thoại và `create_before_destroy` cho ứng dụng AI.
5.  **Truy vấn động**: Không hardcode thông tin kết nối mà sử dụng biến và tham chiếu logic.
6.  **Xác thực và Định dạng tự động**: Thực thi `terraform fmt` và `terraform validate` trước khi chạy.
7.  **Chiến lược Gán nhãn (Tagging Strategy)**: Gắn đầy đủ các tag phục vụ quản trị, phân loại hạ tầng.

---

## 🛠️ Cấu trúc thư mục dự án tiêu chuẩn (Rule #2)
Bạn hãy khởi tạo một thư mục trống mới (ví dụ: `cloud/w8/day-a/learn-terraform-get-started-docker-advanced/`) và tạo đầy đủ 6 tệp tin riêng biệt dưới đây.

> [!NOTE]  
> **Giải thích quy tắc #2:** Việc tách nhỏ file giúp mã nguồn rõ ràng, dễ bảo trì, tránh xung đột git khi làm việc nhóm lớn, và giúp kỹ sư DevOps dễ dàng định vị lỗi khi hệ thống gặp sự cố.

---

## 📂 Chi tiết Mã nguồn & Định nghĩa Best Practice từng File

### 1. File `providers.tf` (Khai báo Nhà cung cấp)

```hcl
terraform {
  required_version = ">= 1.2.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.1"
    }
  }
}

provider "docker" {}
provider "local" {}
```

> [!TIP]  
> **Giải thích chuẩn Best Practice:**
> *   **Ràng buộc phiên bản (`required_version` & `version`):** Luôn khóa phiên bản của Terraform Core và các Providers (dùng toán tử gán phiên bản an toàn `~>`). Điều này ngăn chặn việc hệ thống tự động tải về các bản cập nhật mới trong tương lai có chứa thay đổi lớn gây lỗi cú pháp (breaking changes).

---

### 2. File `variables.tf` (Khai báo Biến đầu vào - Rule #3)

```hcl
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
```

> [!IMPORTANT]  
> **Giải thích chuẩn Best Practice (Rule #3):**
> *   **Mô tả rõ ràng (`description`):** Mọi biến bắt buộc phải có mô tả rõ ràng để các kỹ sư khác biết biến này dùng vào việc gì.
> *   **Xác định kiểu dữ liệu (`type`):** Giúp Terraform bắt lỗi sớm ngay ở bước biên dịch cú pháp nếu người dùng nhập sai kiểu (ví dụ: nhập chuỗi chữ vào biến `port` kiểu `number`).
> *   **Bảo mật dữ liệu nhạy cảm (`sensitive = true`):** Mật khẩu DB và API Key của Groq bắt buộc phải có thuộc tính này. Terraform sẽ mã hóa đầu ra, thay thế bằng dấu `(sensitive value)` trên màn hình console khi bạn chạy lệnh plan/apply để chống rò rỉ thông tin.

---

### 3. File `terraform.tfvars` (Gán giá trị Biến thực tế)

```hcl
groq_api_key = "gsk_your_groq_api_key_placeholder"
db_password  = "PostgresAdminPass!123"
db_user      = "db_admin"
db_name      = "chatbot_production"
ai_app_port  = 5000
adminer_port = 8888
```

> [!CAUTION]  
> **Giải thích chuẩn Best Practice (Rule #3):**
> *   **Không commit file này lên Git:** Tệp này chứa API Key thực tế và mật khẩu database của bạn. Trong môi trường thực tế, bạn **bắt buộc phải ghi file này vào `.gitignore`**.
> *   **File thay thế an toàn:** Thay vào đó, hãy tạo một file mẫu mang tên `terraform.tfvars.example` chứa các biến nhưng để trống giá trị (ví dụ: `groq_api_key = ""`) và đẩy lên Git để làm tài liệu hướng dẫn cho người khác.

---

### 4. File `main.tf` (Tài nguyên lõi - Rule #1, #4, #7)

```hcl
# A. MẠNG NỘI BỘ (Private Network)
resource "docker_network" "private_net" {
  name = "ai-private-network"
}

# B. Ổ ĐĨA DỮ LIỆU BỀN VỮNG (Persistent Volume)
resource "docker_volume" "db_data" {
  name = "postgres_ai_db_data"

  # 🌟 LIFECYCLE RULE 1: prevent_destroy (Rule #4)
  # Ngăn chặn việc lỡ tay chạy lệnh destroy xóa sạch lịch sử chat quý giá của hệ thống
  lifecycle {
    prevent_destroy = true
  }
}

# C. CONTAINER DATABASE (PostgreSQL)
resource "docker_image" "postgres_img" {
  name         = "postgres:15-alpine"
  keep_locally = true
}

resource "docker_container" "db" {
  name  = "postgres-db-server"
  image = docker_image.postgres_img.image_id

  networks_advanced {
    name    = docker_network.private_net.name
    aliases = ["db-host"] # Tên miền nội bộ an toàn
  }

  env = [
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_DB=${var.db_name}"
  ]

  volumes {
    volume_name    = docker_volume.db_data.name
    container_path = "/var/lib/postgresql/data"
  }

  # 🌟 GIẢ LẬP DOCKER COMPOSE PROJECT ĐỂ NHÓM TRONG DOCKER DESKTOP
  labels {
    label = "com.docker.compose.project"
    value = "terraform-advanced-ai-lab"
  }
  labels {
    label = "com.docker.compose.service"
    value = "db"
  }
}

# D. TỰ ĐỘNG TẠO FILE APP PYTHON CHẠY AI CHATBOT
resource "local_file" "app_py" {
  filename = "${path.module}/app.py"
  content  = <<-EOF
            import os
            import time
            import requests
            import psycopg2
            from flask import Flask, request, jsonify, render_template_string

            app = Flask(__name__)

            # Đọc cấu hình từ biến môi trường
            DB_HOST = os.environ.get("DB_HOST", "db-host")
            DB_USER = os.environ.get("DB_USER", "postgres")
            DB_PASS = os.environ.get("DB_PASS", "postgres")
            DB_NAME = os.environ.get("DB_NAME", "my_app_db")
            GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")

            def init_db():
                conn = None
                for i in range(15): # Tránh lỗi container app lên trước DB gây mất kết nối
                    try:
                        conn = psycopg2.connect(
                            host=DB_HOST,
                            user=DB_USER,
                            password=DB_PASS,
                            database=DB_NAME
                        )
                        break
                    except Exception as e:
                        print("PostgreSQL chưa sẵn sàng, đang thử lại...")
                        time.sleep(3)
                
                if not conn:
                    print("LỖI KẾT NỐI DATABASE!")
                    return
                
                cur = conn.cursor()
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS chat_history (
                        id SERIAL PRIMARY KEY,
                        prompt TEXT NOT NULL,
                        response TEXT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    );
                """)
                conn.commit()
                cur.close()
                conn.close()

            HTML_TEMPLATE = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Llama3 AI Chatbot & Terraform Best Practice</title>
                <style>
                    body {
                        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                        background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 100%);
                        color: #f8fafc;
                        min-height: 100vh;
                        margin: 0;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        padding: 20px;
                        box-sizing: border-box;
                    }
                    .container {
                        width: 100%;
                        max-width: 800px;
                        background: rgba(255, 255, 255, 0.03);
                        backdrop-filter: blur(20px);
                        border-radius: 24px;
                        border: 1px solid rgba(255, 255, 255, 0.08);
                        box-shadow: 0 20px 50px rgba(0,0,0,0.5);
                        display: flex;
                        flex-direction: column;
                        height: 85vh;
                        overflow: hidden;
                    }
                    .header {
                        padding: 20px;
                        background: rgba(255,255,255,0.02);
                        border-bottom: 1px solid rgba(255,255,255,0.08);
                        text-align: center;
                    }
                    .header h1 {
                        margin: 0;
                        font-size: 1.8rem;
                        background: linear-gradient(90deg, #38bdf8, #818cf8);
                        -webkit-background-clip: text;
                        -webkit-text-fill-color: transparent;
                    }
                    .chat-area {
                        flex: 1;
                        padding: 20px;
                        overflow-y: auto;
                        display: flex;
                        flex-direction: column;
                        gap: 15px;
                    }
                    .message {
                        max-width: 80%;
                        padding: 14px 18px;
                        border-radius: 16px;
                        line-height: 1.5;
                        font-size: 0.95rem;
                        white-space: pre-line;
                    }
                    .user-msg {
                        align-self: flex-end;
                        background: #4f46e5;
                        color: white;
                        border-bottom-right-radius: 4px;
                    }
                    .ai-msg {
                        align-self: flex-start;
                        background: rgba(255, 255, 255, 0.06);
                        border: 1px solid rgba(255, 255, 255, 0.05);
                        color: #e2e8f0;
                        border-bottom-left-radius: 4px;
                    }
                    .input-area {
                        padding: 20px;
                        background: rgba(255,255,255,0.01);
                        border-top: 1px solid rgba(255,255,255,0.08);
                        display: flex;
                        gap: 10px;
                    }
                    input {
                        flex: 1;
                        background: rgba(0,0,0,0.2);
                        border: 1px solid rgba(255,255,255,0.1);
                        padding: 14px 20px;
                        border-radius: 12px;
                        color: white;
                        font-size: 1rem;
                        outline: none;
                    }
                    button {
                        background: linear-gradient(90deg, #4f46e5, #6366f1);
                        color: white;
                        border: none;
                        padding: 0 25px;
                        border-radius: 12px;
                        font-weight: 600;
                        cursor: pointer;
                    }
                    .system {
                        font-size: 0.8rem;
                        color: #64748b;
                        margin-top: 5px;
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>Groq Llama3 - Multi-Tier AI System</h1>
                        <div class="system">Hạ tầng chuẩn chỉnh và an toàn được quản trị hoàn toàn bằng code Terraform</div>
                    </div>
                    <div class="chat-area" id="chatArea">
                        <div class="message ai-msg">Chào bạn! Tôi là Llama3 Chatbot. Tất cả những câu bạn hỏi tôi sẽ được lưu trữ an toàn trong Database PostgreSQL! Hãy nhập câu hỏi đầu tiên.</div>
                    </div>
                    <div class="input-area">
                        <input type="text" id="promptInput" placeholder="Hỏi tôi bất kỳ điều gì..." onkeydown="if(event.key === 'Enter') sendMessage()">
                        <button onclick="sendMessage()">Gửi</button>
                    </div>
                </div>

                <script>
                    async function sendMessage() {
                        const input = document.getElementById('promptInput');
                        const prompt = input.value.trim();
                        if (!prompt) return;

                        input.value = '';
                        appendMessage(prompt, 'user-msg');

                        const loadingId = appendMessage('AI đang suy nghĩ...', 'ai-msg');

                        try {
                            const response = await fetch('/chat', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({ prompt: prompt })
                            });
                            const data = await response.json();
                            
                            document.getElementById(loadingId).remove();
                            
                            if (data.error) {
                                appendMessage('Lỗi: ' + data.error, 'ai-msg');
                            } else {
                                appendMessage(data.response, 'ai-msg');
                            }
                        } catch (err) {
                            document.getElementById(loadingId).remove();
                            appendMessage('Không thể kết nối đến Web server', 'ai-msg');
                        }
                    }

                    function appendMessage(text, className) {
                        const chatArea = document.getElementById('chatArea');
                        const msgDiv = document.createElement('div');
                        msgDiv.className = 'message ' + className;
                        msgDiv.innerText = text;
                        
                        const id = 'msg_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
                        msgDiv.id = id;
                        
                        chatArea.appendChild(msgDiv);
                        chatArea.scrollTop = chatArea.scrollHeight;
                        return id;
                    }
                </script>
            </body>
            </html>
            """

            @app.route("/")
            def home():
                return render_template_string(HTML_TEMPLATE)

            @app.route("/chat", methods=["POST"])
            def chat():
                data = request.json
                prompt = data.get("prompt", "")
                
                if not prompt:
                    return jsonify({"error": "Empty prompt"}), 400
                    
                try:
                    url = "https://api.groq.com/openai/v1/chat/completions"
                    headers = {
                        "Authorization": f"Bearer {GROQ_API_KEY}",
                        "Content-Type": "application/json"
                    }
                    payload = {
                        "model": "llama-3.1-8b-instant",
                        "messages": [{"role": "user", "content": prompt}],
                        "temperature": 0.7
                    }
                    
                    response = requests.post(url, json=payload, headers=headers, timeout=20)
                    response_data = response.json()
                    
                    if response.status_code != 200:
                        error_msg = response_data.get("error", {}).get("message", "Lỗi Groq API")
                        return jsonify({"error": error_msg}), response.status_code
                        
                    ai_response = response_data["choices"][0]["message"]["content"]
                    
                    # Kết nối DB và lưu trữ cuộc trò chuyện
                    conn = psycopg2.connect(
                        host=DB_HOST,
                        user=DB_USER,
                        password=DB_PASS,
                        database=DB_NAME
                    )
                    cur = conn.cursor()
                    cur.execute(
                        "INSERT INTO chat_history (prompt, response) VALUES (%s, %s)",
                        (prompt, ai_response)
                    )
                    conn.commit()
                    cur.close()
                    conn.close()
                    
                    return jsonify({"response": ai_response})
                    
                except Exception as e:
                    return jsonify({"error": str(e)}), 500

            if __name__ == "__main__":
                init_db()
                app.run(host="0.0.0.0", port=5000)
            EOF
}

# E. CONTAINER AI APP (Flask Web Server)
resource "docker_image" "python_img" {
  name         = "python:3.10-slim"
  keep_locally = true
}

resource "docker_container" "ai_app" {
  name  = "ai-chatbot-web"
  image = docker_image.python_img.image_id

  networks_advanced {
    name = docker_network.private_net.name
  }

  ports {
    internal = 5000
    external = var.ai_app_port
  }

  env = [
    "DB_HOST=db-host",
    "DB_USER=${var.db_user}",
    "DB_PASS=${var.db_password}",
    "DB_NAME=${var.db_name}",
    "GROQ_API_KEY=${var.groq_api_key}"
  ]

  volumes {
    host_path      = abspath(local_file.app_py.filename)
    container_path = "/app/app.py"
  }

  # Lệnh khởi chạy bootstrap ứng dụng
  command = [
    "sh",
    "-c",
    "pip install Flask requests psycopg2-binary && python /app/app.py"
  ]

  # 🌟 GIẢ LẬP DOCKER COMPOSE PROJECT ĐỂ NHÓM TRONG DOCKER DESKTOP
  labels {
    label = "com.docker.compose.project"
    value = "terraform-advanced-ai-lab"
  }
  labels {
    label = "com.docker.compose.service"
    value = "ai-app"
  }

  # 🌟 LƯU Ý LIFECYCLE TRÊN LOCAL DOCKER:
  # Tránh dùng create_before_destroy trên local Docker vì tên container cố định ("ai-chatbot-web") sẽ gây lỗi xung đột tên khi tạo mới trước khi xóa cũ.
  # Do đó, trên local ta sẽ để chế độ mặc định (xóa container cũ trước rồi tạo container mới).

  depends_on = [
    local_file.app_py,
    docker_container.db
  ]
}

# F. CONTAINER WEB UI QUẢN TRỊ DATABASE (Adminer)
resource "docker_image" "adminer_img" {
  name         = "adminer:latest"
  keep_locally = true
}

resource "docker_container" "adminer" {
  name  = "adminer-web-client"
  image = docker_image.adminer_img.image_id

  networks_advanced {
    name = docker_network.private_net.name
  }

  ports {
    internal = 8080
    external = var.adminer_port
  }

  # 🌟 GIẢ LẬP DOCKER COMPOSE PROJECT ĐỂ NHÓM TRONG DOCKER DESKTOP
  labels {
    label = "com.docker.compose.project"
    value = "terraform-advanced-ai-lab"
  }
  labels {
    label = "com.docker.compose.service"
    value = "adminer"
  }

  # 🌟 CHIẾN LƯỢC GÁN NHÃN (Rule #7)
  # Phân loại và quản trị tài nguyên chuyên nghiệp
  labels {
    label = "environment"
    value = "production"
  }
  labels {
    label = "managed_by"
    value = "terraform"
  }
  labels {
    label = "project"
    value = "AI-Chatbot"
  }
}
```

> [!NOTE]  
> **Giải thích chuẩn Best Practice áp dụng trong `main.tf`:**
> *   **Quy tắc đặt tên (Rule #1):** Đặt tên nhãn tài nguyên logic cực ngắn gọn (`db`, `ai_app`, `adminer`) và sử dụng cấu trúc `snake_case` cho nhãn (`private_net`, `db_data`, `postgres_img`). Không đặt trùng lặp loại tài nguyên (ví dụ: dùng `db_data` thay vì `db_data_volume`).
> *   **An toàn dữ liệu (Rule #4 - `prevent_destroy`):** Volume lưu trữ data PostgreSQL được cấu hình `prevent_destroy = true`. Nếu bất kỳ ai chạy lệnh `terraform destroy` hệ thống sẽ từ chối thực thi và chặn đứng hành động xóa để tránh thất thoát dữ liệu khách hàng.
> *   **Zero-Downtime & Local Docker Lifecycle (Rule #4):** Trong môi trường cloud thực tế (như AWS EC2/ASG), ta thường dùng `create_before_destroy = true` để chạy máy ảo mới ổn định rồi mới xóa máy ảo cũ (tránh downtime). Tuy nhiên, trên môi trường Docker cục bộ, vì tên container (`ai-chatbot-web`) và cổng bị cố định, việc cố gắng tạo mới trước khi xóa cũ sẽ gây ra lỗi xung đột tên và cổng của daemon Docker (Conflict). Do đó, trên local ta phải dùng quy trình mặc định (xóa container cũ trước, rồi tạo container mới).
> *   **Chiến lược gán nhãn (Rule #7):** Mọi tài nguyên hỗ trợ gán nhãn đều được gán `labels` để phục vụ phân loại môi trường (`production`) và ghi chú công cụ quản lý (`managed_by = terraform`).

---

### 5. File `outputs.tf` (Giá trị đầu ra)

```hcl
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
```

> [!TIP]  
> **Giải thích chuẩn Best Practice:**
> *   **Bảo mật thông tin nhạy cảm ở đầu ra:** Biến `db_connection_info` trả về thông tin đăng nhập database. Khi được gán `sensitive = true`, Terraform sẽ không in trực tiếp các thông tin này ra màn hình CLI khi apply xong để tránh rò rỉ trong log CI/CD.

---

### 6. File `backend.tf` (Cấu hình Backend)

```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

> [!NOTE]  
> **Giải thích chuẩn Best Practice:**
> *   Mặc dù chúng ta lưu trữ file state dạng `local` để chạy offline trên máy tính, nhưng việc tạo riêng một file `backend.tf` giúp chúng ta dễ dàng nâng cấp dự án lên **Remote Backend (AWS S3)** trong tương lai chỉ bằng cách thay đổi cấu hình trong tệp tin này mà không ảnh hưởng tới code logic ở các tệp tin khác.

---

## 🚀 QUY TRÌNH THỰC THI CHUẨN BEST PRACTICE (Rule #6)

Khi đã viết xong toàn bộ code, bạn hãy thực hiện theo đúng chu trình kiểm thử và vận hành chuẩn mực của một kỹ sư DevOps chuyên nghiệp dưới đây:

### Bước 1: Tự động Định dạng Code (Rule #6)
Trước khi chạy dự án, hãy để Terraform tự động chuẩn hóa và định dạng lại khoảng trắng, dấu `=` cho thẳng hàng tắp lự bằng lệnh:
```bash
terraform fmt
```
*Bạn sẽ thấy tệp tin được định dạng lại cực kỳ ngăn nắp và đẹp mắt theo chuẩn thẩm mỹ HashiCorp.*

### Bước 2: Xác thực kiểm tra cú pháp (Rule #6)
Chạy lệnh kiểm tra tính logic và lỗi chính tả của toàn bộ thư mục:
```bash
terraform validate
```
*Kết quả trả về `Success! The configuration is valid.` thì code của bạn đã hoàn toàn sẵn sàng.*

### Bước 3: Khởi tạo và Tải Provider
```bash
terraform init -upgrade
```

### Bước 4: Lập kế hoạch & Áp dụng Triển khai
1. Xem kế hoạch:
   ```bash
   terraform plan
   ```
2. Thực thi triển khai thực tế lên Docker:
   ```bash
   terraform apply
   ```
   *(Nhập `yes`)*

---

## 🛡️ PHẦN THỰC HÀNH Lifecycle & State CLI (An toàn & Quản lý)

Sau khi apply thành công và kiểm tra Chat bot tại `http://localhost:5000` cũng như Adminer tại `http://localhost:8888`, bạn hãy thực hành các bài kiểm tra thực tế:

### Bài test 1: Kiểm chứng cơ chế an toàn (`prevent_destroy`)
Thử chạy lệnh xóa sạch hạ tầng:
```bash
terraform destroy
```
* **Kết quả thực tế:** Lệnh bị Terraform **từ chối ngay lập tức** vì volume chứa database PostgreSQL của bạn đã được bảo vệ tối cao bằng `prevent_destroy = true`! Bạn đã cứu hệ thống khỏi một pha xóa nhầm dữ liệu lịch sử chat của người dùng!
* **Cách mở khóa để dọn dẹp:** Để hủy hạ tầng phục vụ bài học tiếp theo, bạn chỉ cần sửa `prevent_destroy = false` trong khối `lifecycle` của tài nguyên `docker_volume.db_data` ở file `main.tf`, chạy lại `terraform apply` để ghi nhận cài đặt, rồi mới chạy lệnh hủy.

### Bài test 2: Quản lý File State bằng CLI
1. Xem danh sách các tài nguyên mà Terraform đang lưu giữ trong bộ não State:
   ```bash
   terraform state list
   ```
2. Tháo gỡ container Adminer ra khỏi sự quản lý của Terraform mà không làm tắt dịch vụ thực tế của nó trên Docker:
   ```bash
   terraform state rm docker_container.adminer
   ```
3. Nhập lại container Adminer đang chạy tự do đó quay về dưới trướng quản lý của Terraform bằng lệnh `import`:
   ```bash
   terraform import docker_container.adminer adminer-web-client
   ```

Chúc bạn hoàn thành xuất sắc bài lab đỉnh cao đầy tính thực tiễn và đạt chuẩn **Best Practice** này!
