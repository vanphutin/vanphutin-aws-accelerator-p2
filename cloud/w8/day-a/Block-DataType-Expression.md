# 📘 Hướng Dẫn Tự Học Terraform: Block, Data Type & Expression

Tài liệu này được biên soạn và tối ưu hóa cấu trúc giúp bạn dễ dàng nắm bắt các khái niệm cốt lõi của **HCL (HashiCorp Configuration Language)** bao gồm: Block (khối), Argument (đối số), Data Type (kiểu dữ liệu), Expression (biểu thức) và Block đặc biệt `terraform {}`.

---

## 🧩 1. Ba Thành Phần Cơ Bản Của Cú Pháp HCL

Ngôn ngữ cấu hình HCL được xây dựng dựa trên hai khối cơ bản chính:

### 🔹 1.1. Argument (Đối số)
* **Khái niệm:** Dùng để gán một giá trị cho một tên định danh cụ thể.
* **Cú pháp:** `<Tên Identifier> = <Biểu thức / Giá trị>`
* **Ví dụ:**
  ```hcl
  region = "ap-southeast-1"
  ```
  * Vế trái (`region`) là **Identifier** (định danh).
  * Vế phải (`"ap-southeast-1"`) là **Biểu thức/Giá trị**.

---

### 🔹 1.2. Block (Khối cấu hình)
* **Khái niệm:** Block đóng vai trò là một container (vùng chứa) các cấu hình khác bên trong cặp ngoặc nhọn `{}`.
* **Cấu trúc của một Block:**
  1. **Block Type:** Loại block (ví dụ: `resource`, `variable`, `output`, `provider`, `terraform`, `locals`).
  2. **Block Labels:** Nhãn xác định block (có thể không có nhãn hoặc có nhiều nhãn tùy thuộc vào loại block).
  3. **Block Body:** Thân block nằm trong cặp ngoặc nhọn `{ }`, chứa các arguments và các block lồng nhau.

#### 📊 Sơ đồ cấu trúc Block trong Terraform:

```text
resource  "aws_s3_bucket"  "first"  {
   │           │              │      └── 3. Body (Thân block chứa các arguments)
   │           │              └───────── 2. Label 2: Tên local tự đặt (ví dụ: "first")
   │           └──────────────────────── 2. Label 1: Kiểu resource của Provider (ví dụ: "aws_s3_bucket")
   └──────────────────────────────────── 1. Block Type (ví dụ: "resource")

    bucket_prefix = "tf-series-bai2-" 
    # └ identifier ┘ └─ biểu thức ─┘ -> Đây là một Argument!

    tags = {                
      Project = "terraform-series"
    }
}
```

---

## 📊 2. Các Kiểu Dữ Liệu Trong Terraform (Data Types)

Terraform hỗ trợ hệ thống kiểu dữ liệu rất chặt chẽ, được chia thành các nhóm chính:

### 🔴 2.1. Kiểu dữ liệu nguyên thủy (Primitive Types)
| Kiểu dữ liệu | Mô tả | Ví dụ |
| :--- | :--- | :--- |
| **`string`** | Chuỗi ký tự Unicode | `"ap-southeast-1"`, `"tf-series"` |
| **`number`** | Số nguyên hoặc số thực | `1`, `-3`, `0.5`, `8080` |
| **`bool`** | Giá trị logic (Đúng/Sai) | `true`, `false` |

### 🟡 2.2. Kiểu dữ liệu tập hợp (Collection Types)
> [!NOTE]
> Collection types chứa các phần tử có **cùng một kiểu dữ liệu** bên trong.

* **`list(...)`**: Danh sách các giá trị có thứ tự (chỉ mục/index bắt đầu từ 0).
  ```hcl
  list_example = ["a", "b", "c"]
  ```
* **`set(...)`**: Tập hợp các giá trị không trùng lặp và không có thứ tự cụ thể.
  ```hcl
  set_example = ["a", "b", "c"] # Tự động loại bỏ các phần tử trùng lặp
  ```
* **`map(...)`**: Tập hợp các cặp key-value có cùng kiểu dữ liệu cho phần value.
  ```hcl
  map_example = { 
    "key1" = "value1"
    "key2" = "value2" 
  }
  ```

### 🟢 2.3. Kiểu dữ liệu cấu trúc (Structural Types)
> [!TIP]
> Khác với Collection, các kiểu dữ liệu cấu trúc có thể chứa các phần tử với **nhiều kiểu dữ liệu khác nhau** và có cấu trúc/schema định sẵn.

* **`object(...)`**: Một schema cấu trúc gồm các thuộc tính có kiểu dữ liệu cụ thể.
  ```hcl
  object_example = {
    name    = "terraform"  # Kiểu string
    port    = 8080         # Kiểu number
    enabled = true         # Kiểu bool
  }
  ```
* **`tuple(...)`**: Một danh sách có độ dài cố định và mỗi phần tử có thể có kiểu dữ liệu khác nhau.
  ```hcl
  tuple_example = ["terraform", 8080, true]
  ```

### ⚪ 2.4. Kiểu đặc biệt & Locals
* **`null`**: Đại diện cho giá trị rỗng hoặc không tồn tại. Nếu bạn gán một argument bằng `null`, Terraform sẽ bỏ qua argument đó như thể nó chưa từng được cấu hình.
* **`locals` (Biến cục bộ)**: *Lưu ý: Đây không phải là một kiểu dữ liệu mà là một block đặc biệt* dùng để định nghĩa các biến cục bộ lặp đi lặp lại trong mã cấu hình nhằm tránh lặp code.

---

## ⚡ 3. Biểu Thức & Hàm (Expressions & Functions)

### 🔹 3.1. Expression (Biểu thức)
Argument hiếm khi chỉ nhận các giá trị tĩnh cố định. Biểu thức (Expression) cho phép chúng ta tính toán, xử lý và nối chuỗi động từ các nguồn dữ liệu khác nhau.

* **Nối chuỗi bằng nội suy (String Interpolation):** Sử dụng cú pháp `${...}`
* **Ví dụ nối chuỗi và dùng hàm:**
  ```hcl
  resource "aws_s3_bucket" "first" {
    # Nối chuỗi bằng phép toán cộng chuỗi kết hợp với hàm lower
    bucket = "tf-series-bai2-${lower(random_string.name.result)}"
    
    tags = {
      # Nội suy trực tiếp kết quả vào chuỗi tag Name
      Name = "tf-series-bai2-${random_string.name.result}"
    }
  }
  ```

### 🔹 3.2. Built-in Functions (Hàm dựng sẵn)
Hàm là phần làm HCL trở nên cực kỳ mạnh mẽ. Terraform cung cấp hàng trăm hàm dựng sẵn và **không cho phép người dùng tự định nghĩa hàm mới**. Một số nhóm hàm phổ biến:
* **Hàm xử lý chuỗi:** `lower()`, `upper()`, `join()`, `replace()`, `trim()`
* **Hàm số học:** `abs()`, `max()`, `min()`, `ceil()`, `floor()`
* **Hàm collection:** `length()`, `keys()`, `values()`, `lookup()`, `concat()`
* **Hàm mã hóa & Network:** `base64encode()`, `md5()`, `cidrsubnet()`

> [!TIP]
> Bạn có thể chạy lệnh `terraform console` trong terminal để kiểm tra nhanh kết quả hoạt động của các biểu thức và hàm này tại chỗ mà không cần tạo resource thực tế.

---

## ⚙️ 4. Block Đặc Biệt: `terraform {}`

Block `terraform {}` không mô tả hạ tầng. Nó được dùng để khai báo các thiết lập hệ thống về cách chính Terraform vận hành cấu hình này.
* **Đặc điểm quan trọng:** Nó chỉ nhận **giá trị tĩnh** (static values). Bạn **không** được phép sử dụng variables, locals hoặc các tham chiếu động ở đây.

### 📌 Sáu thành phần chính cấu tạo nên block `terraform {}`:

1. **`required_version`**: Chỉ định phiên bản CLI của Terraform được phép chạy mã nguồn này.
   ```hcl
   required_version = ">= 1.5.0"
   ```
2. **`required_providers`**: Định nghĩa nguồn và phiên bản của tất cả provider plugins cần thiết để tạo và quản lý tài nguyên.
   ```hcl
   required_providers {
     aws = {
       source  = "hashicorp/aws"
       version = "~> 6.0"
     }
   }
   ```
3. **`backend`**: Cấu hình nơi cất giữ tập tin trạng thái (`terraform.tfstate`). Mặc định lưu ở thư mục `local`. Bạn có thể chuyển sang lưu ở AWS S3, GCS, Consul,...
4. **`cloud`**: Thiết lập để sử dụng dịch vụ đám mây **HCP Terraform (HashiCorp Cloud Platform)** quản lý thay thế cho backend truyền thống.
5. **`experiments`**: Dùng để kích hoạt các tính năng thử nghiệm đang phát triển của HCL.
6. **`provider_meta`**: Chứa thông tin bổ sung cho provider, rất hiếm khi cần sử dụng trực tiếp.

---

## ❓ 5. Bộ Câu Hỏi Q&A Ôn Tập Học Nhanh (Flashcards Q&A)

Dưới đây là các câu hỏi ôn tập được biên soạn trực quan giúp bạn nắm vững kiến thức HCL cốt lõi:

### Q1: Điểm khác biệt lớn nhất giữa Block và Argument trong cú pháp HCL là gì?
<details>
<summary>💡 Xem câu trả lời</summary>

* **Argument:** Là một cặp định danh-giá trị (`name = value`). Nó dùng để gán giá trị trực tiếp cho một thuộc tính cụ thể của tài nguyên.
* **Block:** Là một khối lớn chứa thông tin cấu hình, được định nghĩa bởi một loại block (`type`), theo sau bởi không hoặc nhiều nhãn (`labels`) và kết thúc bằng một thân block nằm trong cặp ngoặc nhọn `{}`. Block có thể chứa nhiều Argument hoặc các block lồng nhau khác.
</details>

---

### Q2: Sự khác biệt giữa kiểu dữ liệu `list` (Collection) và kiểu `tuple` (Structural) là gì?
<details>
<summary>💡 Xem câu trả lời</summary>

* **`list` (Collection type):**
  * Tất cả các phần tử bắt buộc phải có **cùng một kiểu dữ liệu** (ví dụ: tất cả đều là string `["a", "b", "c"]`).
  * Độ dài có thể thay đổi động linh hoạt.
* **`tuple` (Structural type):**
  * Có thể chứa các phần tử có **nhiều kiểu dữ liệu khác nhau** ở các vị trí khác nhau (ví dụ: `["aws", 80, true]`).
  * Có độ dài cố định dựa theo schema được định nghĩa sẵn cho từng phần tử.
</details>

---

### Q3: Tại sao chúng ta không thể sử dụng biến `var` hay `local` bên trong block `terraform {}`?
<details>
<summary>💡 Xem câu trả lời</summary>

Bởi vì block `terraform {}` chịu trách nhiệm cấu hình nền tảng khởi chạy cho chính Terraform (tải provider plugins, cài đặt CLI version, định vị backend chứa state file). Quá trình phân tích block này diễn ra **trước khi Terraform tải các biến hoặc bắt đầu giải mã cấu hình tài nguyên**. Do đó, block này bắt buộc chỉ chấp nhận **giá trị tĩnh (static values)** có sẵn lúc đọc file cấu hình ban đầu.
</details>

---

### Q4: Giá trị `null` hoạt động như thế nào trong Terraform và nó giúp gì khi viết code?
<details>
<summary>💡 Xem câu trả lời</summary>

Khi một argument được gán giá trị `null`, Terraform sẽ hành xử như thể bạn **chưa từng khai báo** argument đó trong file cấu hình. Điều này cực kỳ hữu ích khi bạn viết các module dùng chung: bạn gán giá trị mặc định cho một biến tùy chọn là `null`. Nếu người dùng không nhập biến đó, thuộc tính tương ứng sẽ tự động bị bỏ qua thay vì báo lỗi hoặc áp dụng một giá trị mặc định không mong muốn.
</details>

---

### Q5: Làm thế nào để thử nghiệm nhanh kết quả của một biểu thức hoặc kiểm tra hoạt động của hàm HCL (ví dụ: `lower("HEllo")`) mà không cần chạy lệnh `terraform apply`?
<details>
<summary>💡 Xem câu trả lời</summary>

Bạn chỉ cần chạy lệnh `terraform console` trong terminal tại thư mục dự án Terraform. Lệnh này mở ra giao diện dòng lệnh tương tác REPL. Tại đây, bạn có thể gõ trực tiếp bất kỳ biểu thức HCL hay hàm nào và nhấn **Enter** để xem kết quả trả về ngay tại chỗ mà không cần tạo bất kỳ tài nguyên nào trên đám mây.
</details>

---
