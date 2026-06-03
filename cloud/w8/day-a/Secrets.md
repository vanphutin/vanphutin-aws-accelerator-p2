# 📘 Hướng Dẫn Tự Học Terraform: Quản Lý Bí Mật & Dữ Liệu Nhạy Cảm (Secrets Management)

Một trong những thách thức lớn nhất khi làm việc với Terraform (và Infrastructure as Code nói chung) là bảo vệ các dữ liệu nhạy cảm (như mật khẩu Database, API Keys, Private Keys, SSH Credentials). Tài liệu này tổng hợp toàn bộ các phương pháp bảo mật từ cơ bản (`sensitive` variables) đến nâng cao ứng dụng các tính năng hiện đại nhất gần đây (`ephemeral` resources, `write-only` arguments).

---

## 🧩 1. Vấn Đề Cốt Lõi: Tại Sao Secrets Dễ Bị Lộ Trong Terraform?

Khi làm việc với các giá trị bí mật trong Terraform, chúng có nguy cơ bị rò rỉ ở hai nơi chính:
1. **Console Output:** Khi bạn chạy `terraform plan` hoặc `terraform apply`, Terraform sẽ in ra tất cả các giá trị thuộc tính tài nguyên lên màn hình terminal. Bất kỳ ai nhìn vào màn hình hoặc xem logs của hệ thống CI/CD đều có thể đọc được.
2. **File State (`terraform.tfstate`):** Đây là nơi nguy hiểm nhất. Terraform bắt buộc phải lưu giữ hiện trạng thực tế của tài nguyên để quản lý, do đó nó sẽ ghi toàn bộ giá trị (kể cả mật khẩu hay key) dưới dạng **văn bản thuần túy (plaintext)** vào file state.

---

## 🛡️ 2. Tuyến Phòng Thủ Đầu Tiên: `sensitive = true`

### 🔹 2.1. Khái niệm và Cách sử dụng
Để ngăn chặn các giá trị nhạy cảm bị in ra màn hình terminal trong quá trình chạy lệnh, Terraform hỗ trợ tham số `sensitive = true` cho cả **Variables** và **Outputs**.

* **Khai báo Variable nhạy cảm:**
  ```hcl
  variable "db_password" {
    type      = string
    sensitive = true # Đánh dấu nhạy cảm!
    default   = "SuperSecretPassword123"
  }
  ```

* **Khai báo Output nhạy cảm:**
  ```hcl
  output "database_connection" {
    value     = aws_db_instance.db.password
    sensitive = true # Bắt buộc phải đánh dấu nếu tham chiếu đến một giá trị nhạy cảm
  }
  ```

### 🔹 2.2. Kết quả hiển thị trên Terminal:
Khi bạn chạy lệnh `plan` hoặc `apply`, thay vì in ra mật khẩu thật, Terraform sẽ che giấu và chỉ hiển thị:
```text
  db_password = (sensitive value)
```

> [!CAUTION]
> **CẢNH BÁO QUAN TRỌNG:** Thuộc tính `sensitive = true` **chỉ có tác dụng che giấu hiển thị trên Terminal**. Giá trị thật của mật khẩu **vẫn được ghi công khai dưới dạng plaintext** bên trong file `terraform.tfstate`. Do đó, đây không phải là giải pháp bảo mật triệt để cho file state!

---

## ⚡ 3. Giải Pháp Nâng Cao Hiện Đại: Ephemeral Resources (Tài Nguyên Tạm Thời)

> [!IMPORTANT]
> Đây là tính năng đột phá được giới thiệu trong các phiên bản Terraform gần đây (từ Terraform 1.10+), giải quyết triệt để vấn đề rò rỉ secret trong file state.

### 🔹 3.1. Ephemeral Resources là gì?
* **Tài nguyên thông thường (Resource/Data Source):** Luôn ghi dữ liệu quét được vào file state trên đĩa cứng để phục vụ cho các lần chạy sau.
* **Tài nguyên tạm thời (Ephemeral Resource):** Chỉ được tải vào **bộ nhớ RAM** của máy tính trong lúc lệnh `apply` đang chạy để truyền mật khẩu cho tài nguyên khác. Ngay khi lệnh kết thúc, dữ liệu này sẽ **bị xóa sạch khỏi bộ nhớ và hoàn toàn không bao giờ ghi xuống file state trên đĩa**.

```text
               ┌──────────────────────────────┐
               │    HCP Vault / Secret Manager│
               └──────────────┬───────────────┘
                              │
                              │  (Chỉ tải vào RAM lúc Apply)
                              ▼
  [ RAM máy chạy ] ────► Ephemeral Resource ────► [ Khởi tạo tài nguyên ]
                              │
                              │  (Kết thúc apply: Xóa sạch khỏi RAM)
                              ▼
                   ❌ KHÔNG GHI VÀO STATE FILE!
```

### 🔹 3.2. Ví dụ cấu hình Ephemeral với Vault:
Khai báo block `ephemeral` thay vì `data` thông thường để lấy mật khẩu tạm thời từ HashiCorp Vault:
```hcl
# Sử dụng ephemeral để lấy secret động từ Vault
ephemeral "vault_generic_secret" "db_creds" {
  path = "secret/data/db"
}

resource "aws_db_instance" "database" {
  allocated_storage = 20
  engine            = "mysql"
  username          = "admin"
  
  # Truyền mật khẩu từ tài nguyên tạm thời vào
  password          = ephemeral.vault_generic_secret.db_creds.data["password"]
}
```
* **Kết quả vượt trội:** Mật khẩu database được truyền trực tiếp từ Vault vào AWS thành công, nhưng trong file `terraform.tfstate` của bạn, thuộc tính mật khẩu hoàn toàn trống hoặc không lưu vết giá trị nhạy cảm này!

---

## 🔄 4. Tham Số Ghi Một Chiều (Write-Only Arguments)

Một số Cloud Provider hiện đại hỗ trợ cơ chế đối số ghi một chiều (Write-Only) cho các thuộc tính nhạy cảm:
* **Khái niệm:** Cho phép bạn truyền mật khẩu hoặc key lên Cloud API để thiết lập hệ thống, nhưng khi Terraform quét ngược lại trạng thái (Read/Refresh) từ Cloud, Cloud API sẽ không trả lại giá trị đó nữa (hoặc trả về dạng mã hóa một chiều).
* **Kết quả:** Terraform sẽ không theo dõi sự sai khác (drift) của giá trị này và cũng không lưu giá trị plaintext của nó vào state sau khi khởi tạo thành công.

---

## 🛡️ 5. Các Quy Tắc Vàng (Best Practices) Để Quản Lý Secrets

Để đảm bảo hệ thống hạ tầng an toàn tuyệt đối, hãy tuân thủ 5 quy tắc vàng sau:

1. ❌ **Tuyệt đối không hardcode bí mật:** Không bao giờ gõ trực tiếp mật khẩu, private key hay access key vào trong các file code `.tf`.
2. 📝 **Sử dụng file `.tfvars` được bảo vệ hoặc Biến Môi Trường:**
   * Lưu các giá trị nhạy cảm vào file `secret.tfvars` và thêm file này vào `.gitignore`.
   * Hoặc truyền qua biến môi trường của hệ thống với tiền tố `TF_VAR_`:
     ```bash
     export TF_VAR_db_password="MySuperSecurePassword"
     ```
3. 🔒 **Sử dụng Secret Manager ngoài:** Kết hợp Terraform với các dịch vụ quản lý khóa chuyên nghiệp như **AWS Secrets Manager**, **HashiCorp Vault**, **Azure Key Vault**, **GCP Secret Manager** để lấy mật khẩu động tại thời điểm chạy.
4. 💾 **Bảo mật Remote State:** Remote Backend chứa state (như S3) phải bật mã hóa tĩnh bắt buộc bằng khóa quản lý (KMS) và phân quyền chặt chẽ thông qua IAM để chỉ các tài khoản CI/CD hoặc DevOps có thẩm quyền mới được phép đọc.
5. 🧹 **Không commit file backup:** Tránh commit file `terraform.tfstate.backup` vì nó cũng chứa dữ liệu plaintext tương tự file state chính.

---

## ❓ 6. Bộ Câu Hỏi Q&A Ôn Tập Học Nhanh (Flashcards Q&A)

### Q1: Tại sao nói thuộc tính `sensitive = true` chỉ là "mặt nạ che mắt" trên terminal chứ không phải giải pháp bảo mật file state?
<details>
<summary>💡 Xem câu trả lời</summary>

Bởi vì `sensitive = true` chỉ can thiệp vào bộ lọc hiển thị (output formatter) của Terraform CLI để ẩn giá trị nhạy cảm, thay thế bằng chuỗi `(sensitive value)` trên màn hình terminal nhằm tránh bị quay màn hình hoặc lộ log CI/CD. Còn ở bên dưới, hệ thống lõi của Terraform vẫn bắt buộc phải ghi nhận chính xác giá trị nhạy cảm đó ở dạng văn bản thuần túy (plaintext) vào file `terraform.tfstate` để so sánh trạng thái ở lần chạy sau.
</details>

---

### Q2: Sự khác biệt cốt lõi giữa `data` source thông thường và `ephemeral` resource mới trong Terraform là gì?
<details>
<summary>💡 Xem câu trả lời</summary>

* **`data` source:** Lấy thông tin từ hệ thống ngoài, sau đó **ghi lại và lưu giữ vĩnh viễn** toàn bộ dữ liệu đó vào file `terraform.tfstate` trên đĩa cứng.
* **`ephemeral` resource:** Lấy thông tin nhạy cảm từ hệ thống ngoài (như Vault), chỉ lưu tạm thời trên **bộ nhớ RAM** để truyền sang tài nguyên khác trong suốt quá trình apply. Lệnh chạy xong, RAM được giải phóng và dữ liệu nhạy cảm **biến mất hoàn toàn**, không ghi một byte nào xuống file state trên đĩa.
</details>

---

### Q3: Làm thế nào để truyền Access Key và Secret Key của AWS vào Terraform một cách an toàn nhất mà không sợ bị lộ vào code hay state?
<details>
<summary>💡 Xem câu trả lời</summary>

Cách tốt nhất là **không khai báo chúng trong code** và cũng không truyền qua variables. Thay vào đó, hãy sử dụng các cơ chế xác thực môi trường của Cloud Provider:
1. Chạy lệnh cấu hình trên máy cá nhân: `aws configure` (lưu credential vào thư mục bảo mật `~/.aws/credentials`).
2. Hoặc sử dụng các biến môi trường chuẩn của AWS: `AWS_ACCESS_KEY_ID` và `AWS_SECRET_ACCESS_KEY`.
3. Khi deploy trên EC2 hoặc CI/CD (như GitHub Actions), hãy sử dụng **IAM Roles** hoặc **OIDC (OpenID Connect)** để cấp quyền động ngắn hạn (Temporary Credentials) mà không cần dùng đến Access Key tĩnh.
</details>

---

### Q4: Nếu bạn bắt buộc phải dùng file `.tfvars` để chứa các mật khẩu test cục bộ, làm cách nào để đảm bảo an toàn không bị lộ lên GitHub?
<details>
<summary>💡 Xem câu trả lời</summary>

1. Đặt tên file cấu hình chứa mật khẩu nhạy cảm kết thúc bằng đuôi `.tfvars` đặc biệt (ví dụ: `secrets.auto.tfvars` hoặc `local.tfvars`).
2. Ngay lập tức mở file `.gitignore` ở thư mục gốc của dự án và thêm dòng:
   ```text
   *.tfvars
   *.tfvars.json
   !variables.tfvars # Ngoại trừ các file tham số mẫu không nhạy cảm nếu có
   ```
3. Luôn chạy lệnh `git status` trước khi commit để chắc chắn file chứa mật khẩu không nằm trong danh sách chuẩn bị đẩy lên Git.
</details>

---

### Q5: Khi sử dụng Ephemeral Resources để lấy secret từ Vault, chuyện gì xảy ra nếu hệ thống Vault bị mất kết nối ngay trước khi bạn chạy lệnh `terraform destroy` hạ tầng?
<details>
<summary>💡 Xem câu trả lời</summary>

Do thông tin secret (credentials) không hề được lưu lại trong file state trên đĩa cứng, nên mỗi lần chạy bất kỳ lệnh nào (`plan`, `apply`, `destroy`), Terraform đều bắt buộc phải kết nối trực tiếp đến Vault để lấy lại key tạm thời vào RAM. Nếu Vault bị mất kết nối, Terraform sẽ không thể truy vấn được key, lệnh `destroy` sẽ lập tức báo lỗi dừng lại và không thể tiến hành xóa tài nguyên. Đây là sự đánh đổi về tính sẵn sàng (Availability) để đổi lấy sự bảo mật tuyệt đối (Security).
</details>

---
