# A. MẠNG NỘI BỘ (Private Network)
resource "docker_network" "private_net" {
  name = "ai-private-network"
}

# B. Ổ ĐĨA DỮ LIỆU BỀN VỮNG (Persistent Volume)
resource "docker_volume" "db_data" {
  name = "postgres_ai_db_data"

  # 🌟 LIFECYCLE RULE 1: prevent_destroy (Rule #4)
  # Tạm thời đặt thành false để bạn có thể dọn dẹp hạ tầng (chạy terraform destroy)
  lifecycle {
    prevent_destroy = false
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
    "GROQ_API_KEY=${var.groq_api_key}",
    "APP_HASH=${md5(local_file.app_py.content)}"
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