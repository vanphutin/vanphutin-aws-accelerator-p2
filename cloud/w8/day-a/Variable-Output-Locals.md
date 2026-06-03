# 📘 Hướng Dẫn Tự Học Terraform: Variables, Outputs, Locals & Cơ Chế Kiểm Tra Sớm (Early Checks)

Tài liệu này tổng hợp toàn bộ kiến thức nền tảng giúp tham số hóa mã nguồn Terraform để tăng tính linh hoạt và tái sử dụng, bao gồm: **Input Variables** (Đầu vào), **Outputs** (Đầu ra), **Locals** (Biến tính toán nội bộ), cùng cơ chế kiểm thử sớm cực kỳ quan trọng (**Validation, Precondition, Postcondition**).

---

## 🧩 1. Ba Trụ Cột Tham Số Hóa Trong Terraform

Để tránh việc viết cứng (hardcode) các giá trị trong file cấu hình `.hcl`, Terraform cung cấp 3 công cụ cơ bản:

| Công cụ | Bản chất | Ứng dụng thực tế |
| :--- | :--- | :--- |
| **`variable`** (Input) | Nhận giá trị truyền vào từ **bên ngoài** tại thời điểm chạy lệnh. | Thay đổi môi trường (`dev`/`prod`), kích thước VM, số lượng bản sao. |
| **`output`** (Output) | Công bố và trả kết quả tính toán hoặc trạng thái tài nguyên **ra ngoài**. | Xuất địa chỉ IP, chuỗi kết nối Database để kiểm tra hoặc dùng cho module khác. |
| **`locals`** (Internal) | Khai báo hằng số hoặc tính toán các biểu thức phức tạp **nội bộ**. | Tạo tiền tố tên chung, gộp bộ tag chung cho dự án để tránh lặp code. |

---

## 📥 2. Chi Tiết Cách Sử Dụng Variables, Outputs, Locals

### 🔹 2.1. Input Variables (Biến đầu vào)
Khai báo biến để linh hoạt hóa tham số cấu hình:
```hcl
variable "environment" {
  type        = string
  description = "Môi trường triển khai: dev | staging | prod"
  default     = "dev" # Nếu không có default, biến này sẽ bắt buộc phải truyền vào khi chạy
}
```

* **Ràng buộc kiểu (`type`):** Giúp kiểm soát kiểu dữ liệu nhập vào (như `string`, `number`, `bool`, `list(string)`, `map(string)`, `object({...})`).
* **Thứ tự ưu tiên truyền biến (Từ thấp đến cao):**
  1. Giá trị `default` khai báo trong block variable.
  2. Biến môi trường hệ thống (Ví dụ: `export TF_VAR_environment="staging"`).
  3. Khai báo trong file tự động nạp `terraform.tfvars` hoặc `*.auto.tfvars`.
  4. Cờ dòng lệnh CLI (Ví dụ: `terraform plan -var environment="prod"`) -> **Ưu tiên cao nhất**.

---

### 🔹 2.2. Output Values (Đầu ra dữ liệu)
Xuất thông tin cần thiết sau khi hạ tầng đã được tạo dựng thành công:
```hcl
output "bucket_name" {
  value       = aws_s3_bucket.app.id
  description = "Tên chính thức của S3 Bucket vừa tạo"
  sensitive   = true # Bật để ẩn giá trị này khỏi màn hình console (chống lộ mật khẩu/token)
}
```
* Output là giao diện kết nối quan trọng giúp các **Module** trao đổi thông tin với nhau, hoặc cho phép các dự án khác truy vấn trạng thái qua cơ chế **Remote State Data Source**.

---

### 🔹 2.3. Locals (Biến tính toán nội bộ)
Đặt tên cho các biểu thức hoặc giá trị tính toán dẫn xuất được sử dụng ở nhiều nơi:
```hcl
locals {
  name_prefix   = "${var.project}-${var.environment}"
  is_production = var.environment == "prod"
  
  # Bộ tag chung cho toàn bộ tài nguyên
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```
* **Cách sử dụng:** Truy cập qua tiền tố `local.` (Ví dụ: `local.name_prefix`, `local.common_tags`).
* **Khác biệt cốt lõi:** `variable` nhận giá trị thô trực tiếp từ bên ngoài truyền vào, còn `locals` tự tính toán, sinh ra các giá trị logic dựa trên các tham số nội bộ.
* ⚠️ **Lưu ý:** Đừng lạm dụng locals để khai báo quá nhiều biểu thức lồng nhau phức tạp. Nó sẽ làm code bị phân mảnh, che khuất nguồn gốc thực sự của dữ liệu và gây khó khăn khi debug.

---

## ⚡ 3. Cơ Chế Kiểm Tra Sớm (Early Checks) Chống Lỗi Hạ Tầng

Rất nhiều sự cố hạ tầng xảy ra do cấu hình đầu vào bị sai sót (ví dụ: gõ sai chữ `production` thành `pruduction`, hoặc bật nhầm cờ xóa cưỡng bức ở môi trường sản xuất). Terraform cung cấp 3 cấp độ kiểm tra để chặn đứng lỗi ngay từ đầu:

```text
    [ Biến nạp vào ]         [ Plan thành công ]           [ Apply bắt đầu ]          [ Apply thành công ]
    ────────────────         ───────────────────           ─────────────────          ────────────────────
      validation       ──►      precondition       ──►     [Tạo tài nguyên]    ──►       postcondition
     (Kiểm tra biến)        (Kiểm tra giả định)                                      (Kiểm tra kết quả)
```

### 🔹 3.1. Kiểm tra giá trị của Biến (`validation` block)
Kiểm tra tính hợp lệ của biến ngay khi nạp vào hệ thống. Lệnh sẽ bị chặn đứng lập tức ở bước `plan` mà không cần gọi bất kỳ API nào lên Cloud.

```hcl
variable "environment" {
  type    = string
  default = "dev"

  validation {
    # Điều kiện kiểm tra: giá trị phải nằm trong mảng dev, staging, prod
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Tham số environment bắt buộc phải là một trong các giá trị: dev, staging, prod."
  }
}
```
* **Kết quả khi gõ sai:**
  ```text
  Error: Invalid value for variable
  environment phải là một trong: dev, staging, prod.
  ```

---

### 🔹 3.2. Kiểm tra giả định trước khi chạy (`precondition`)
Dùng để kiểm tra mối quan hệ ràng buộc phức tạp giữa các tài nguyên trước khi tiến hành thực thi. Đặt trong khối `lifecycle` của resource.
* **Đặc điểm:** Chỉ được chạy sau khi đã dựng xong Plan nhưng **trước khi tạo tài nguyên**. Không thể tham chiếu đến thuộc tính tự thân (`self`) vì tài nguyên chưa được tạo.

```hcl
resource "aws_s3_bucket" "app" {
  bucket_prefix = "${local.name_prefix}-"
  force_destroy = var.force_destroy

  lifecycle {
    precondition {
      # Không cho phép bật force_destroy tại môi trường production
      condition     = !local.is_production || !var.force_destroy
      error_message = "Cảnh báo nghiêm trọng: Không được phép bật cờ force_destroy ở môi trường Production!"
    }
  }
}
```

---

### 🔹 3.3. Kiểm tra kết quả sau khi tạo (`postcondition`)
Dùng để xác nhận xem tài nguyên thực tế được tạo ra trên Cloud có đạt đúng các tiêu chuẩn và kỳ vọng đề ra hay không.
* **Đặc điểm:** Chạy **sau khi apply** tài nguyên thành công. Có thể tham chiếu thuộc tính tự thân bằng từ khóa `self` để kiểm tra.
* **Ví dụ:** Đảm bảo instance sau khi khởi tạo bắt buộc phải có thuộc tính địa chỉ IP công cộng (Public IP) hoặc nằm đúng trong dải VPC mong muốn.

---

### 🔹 3.4. Kiểm tra ngoài vòng đời (`check` block)
* Được giới thiệu từ Terraform 1.5, block `check` dùng để giám sát trạng thái hệ thống rộng hơn mà không làm hỏng tiến trình deploy thông thường.
* **Hành vi:** Khi điều kiện trong `check` thất bại, Terraform **chỉ in ra cảnh báo (warning)** chứ không chặn đứng hay rollback tiến trình apply. (Chi tiết sẽ học ở các bài lifecycle nâng cao).

---

## ❓ 4. Bộ Câu Hỏi Q&A Ôn Tập Học Nhanh (Flashcards Q&A)

### Q1: Khác biệt cốt lõi về thời điểm kích hoạt (timing) và mục tiêu kiểm tra giữa `validation`, `precondition`, và `postcondition` là gì?
<details>
<summary>💡 Xem câu trả lời</summary>

1. **`validation`:** Kích hoạt ngay lúc nạp biến đầu vào. Mục tiêu là kiểm tra tính hợp lệ của **giá trị biến thô** (ví dụ: định dạng email, khoảng số).
2. **`precondition`:** Kích hoạt sau khi plan xong nhưng **trước khi tạo tài nguyên**. Mục tiêu là kiểm tra mối quan hệ giữa các tài nguyên hoặc chính sách bảo mật (ví dụ: ở prod cấm xóa). Không dùng được `self`.
3. **`postcondition`:** Kích hoạt **sau khi apply thành công**. Mục tiêu là kiểm tra thuộc tính thực tế của tài nguyên vừa tạo trên Cloud có đúng thiết kế hay không (ví dụ: máy chủ đã được gán IP tĩnh chưa). Sử dụng được từ khóa `self`.
</details>

---

### Q2: Tại sao chúng ta không nên lạm dụng `locals` để khai báo quá nhiều biểu thức tính toán lồng nhau?
<details>
<summary>💡 Xem câu trả lời</summary>

Vì việc lạm dụng quá nhiều biểu thức lồng nhau trong `locals` sẽ biến mã nguồn thành một "hộp đen" cực kỳ khó đọc. Khi một kỹ sư khác đọc code, họ phải nhảy liên tục qua nhiều định nghĩa locals lồng chéo nhau để tìm ra giá trị thực sự đến từ đâu. Quy tắc tốt nhất là: Chỉ dùng `locals` cho các hằng số chung của dự án (như Tags, Project Name) hoặc các biểu thức lặp lại từ 3 lần trở lên trong code.
</details>

---

### Q3: Nếu bạn chạy lệnh apply và một điều kiện `postcondition` bị thất bại, trạng thái hạ tầng thực tế lúc đó sẽ như thế nào?
<details>
<summary>💡 Xem câu trả lời</summary>

Vì `postcondition` chỉ được chạy sau khi tài nguyên đã được tạo lập thành công ngoài thực tế, nên khi nó thất bại:
1. Tài nguyên thực tế **đã được tạo ra và đang chạy** trên Cloud.
2. Terraform sẽ lập tức dừng tiến trình apply, báo lỗi đỏ và ghi nhận tài nguyên đó vào file state.
3. Tuy nhiên, Terraform đánh dấu trạng thái deploy là thất bại để cảnh báo bạn rằng tài nguyên tạo ra không đạt chất lượng/tiêu chuẩn bảo mật cần thiết, buộc bạn phải cấu hình lại.
</details>

---

### Q4: Làm thế nào để truyền một biến chứa danh sách các địa chỉ IP dạng `list(string)` qua cờ dòng lệnh CLI `-var`?
<details>
<summary>💡 Xem câu trả lời</summary>

Bạn phải viết danh sách đó dưới dạng định dạng chuỗi JSON hoặc HCL array hợp lệ và bao ngoài bằng dấu nháy:
```bash
terraform plan -var 'ip_addresses=["192.168.1.1", "10.0.0.1"]'
```
*(Mẹo: Đối với các kiểu dữ liệu phức tạp như danh sách, bản đồ (map), hoặc object, việc tạo file `terraform.tfstate` hoặc `terraform.tfvars` để khai báo là giải pháp sạch sẽ và tránh lỗi gõ CLI nhất).*
</details>

---

### Q5: Tại sao block `precondition` không thể sử dụng từ khóa `self` để truy vấn các thuộc tính của chính tài nguyên chứa nó?
<details>
<summary>💡 Xem câu trả lời</summary>

Vì block `precondition` đại diện cho các điều kiện tiên quyết cần phải thỏa mãn **trước khi tài nguyên được tạo ra**. Tại thời điểm kiểm tra này, tài nguyên đó chưa hề tồn tại trên Cloud và cũng chưa có dữ liệu trong file state, do đó từ khóa `self` (đại diện cho thuộc tính tự thân của tài nguyên) hoàn toàn vô nghĩa và không có giá trị để truy vấn.
</details>

---