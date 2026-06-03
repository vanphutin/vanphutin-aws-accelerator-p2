# 📘 Hướng Dẫn Tự Học Terraform: Meta-arguments

Trong Terraform, **Meta-arguments** là các đối số đặc biệt do chính ngôn ngữ HCL định nghĩa. Chúng không thuộc về bất kỳ Provider cụ thể nào (như AWS hay Docker), mà có thể được sử dụng trong mọi khối `resource` hoặc `module` để thay đổi cách thức Terraform quản lý và triển khai tài nguyên.

---

## 📊 1. Tổng quan về 5 Meta-arguments trong Terraform

Terraform hỗ trợ 5 Meta-arguments chính:

| Meta-argument | Phạm vi áp dụng | Mục đích sử dụng |
| :--- | :--- | :--- |
| **`depends_on`** | `resource`, `module` | Khai báo phụ thuộc rõ ràng (Explicit Dependency) khi Terraform không tự nhận diện được. |
| **`count`** | `resource`, `module` | Tạo ra nhiều bản sao tài nguyên dựa trên một số nguyên (index-based). |
| **`for_each`** | `resource`, `module` | Tạo ra nhiều bản sao tài nguyên dựa trên một danh sách (set) hoặc bản đồ (map) (key-based). |
| **`provider`** | `resource`, `module` | Chỉ định cấu hình Provider cụ thể (thường dùng khi cấu hình multi-region/multi-account thông qua `alias`). |
| **`lifecycle`** | `resource` | Định nghĩa các quy tắc kiểm soát vòng đời của tài nguyên (tạo trước xóa sau, chống xóa, bỏ qua thay đổi). |

---

## 🔗 2. Phụ Thuộc Rõ Ràng (`depends_on`)

Thông thường, Terraform tự động xây dựng đồ thị phụ thuộc (Dependency Graph) dựa trên các tham chiếu chéo giữa các tài nguyên (Implicit Dependency). Tuy nhiên, có những trường hợp ứng dụng của bạn cần tài nguyên A được tạo trước tài nguyên B nhưng không có tham chiếu trực tiếp trong mã.

### 📌 Ví dụ thực tế:
Tạo một EC2 Instance phụ thuộc vào việc cấu hình IAM Role Policy hoàn tất, nhằm đảm bảo Instance có đủ quyền ngay khi khởi chạy.

```hcl
resource "aws_iam_role" "example" {
  name = "example-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.example.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  # 🌟 Bắt buộc phải gắn Policy trước khi tạo EC2 Instance
  depends_on = [
    aws_iam_role_policy_attachment.example
  ]
}
```

> [!WARNING]
> **Không lạm dụng `depends_on`:** Chỉ sử dụng khi thực sự cần thiết. Lạm dụng `depends_on` sẽ làm mất đi khả năng chạy song song (parallelism) của Terraform, kéo dài thời gian deploy hạ tầng.

---

## 🔢 3. Tạo Nhiều Bản Sao Theo Chỉ Số (`count`)

Đối số `count` cho phép bạn tạo ra một số lượng cụ thể các tài nguyên giống nhau bằng cách truyền vào một số nguyên.

### 📌 Ví dụ thực tế:
Tạo 3 EC2 Instance giống nhau và đánh số thứ tự:

```hcl
resource "aws_instance" "server" {
  count         = 3
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    # Sử dụng count.index (bắt đầu từ 0 đến count-1) để phân biệt tên máy chủ
    Name = "Web-Server-${count.index + 1}"
  }
}
```

### ⚠️ Hạn chế nghiêm trọng của `count`:
Các tài nguyên tạo bởi `count` được quản lý dưới dạng danh sách (List) được định chỉ số: `aws_instance.server[0]`, `aws_instance.server[1]`, `aws_instance.server[2]`.

*   **Vấn đề:** Nếu bạn có một danh sách tên người dùng `["Alice", "Bob", "Charlie"]` và dùng `count` để tạo IAM User. Khi bạn xóa `"Bob"` khỏi danh sách, danh sách sẽ thu gọn lại và `"Charlie"` (đứng vị trí số 2) sẽ bị dịch lên vị trí số 1.
*   **Hậu quả:** Terraform sẽ xóa tài nguyên của Charlie và cập nhật/tạo lại tài nguyên thứ 2 để đổi tên từ Bob thành Charlie. Điều này gây phá hủy hạ tầng không mong muốn.

---

## 🔀 4. Tạo Nhiều Bản Sao Theo Khóa (`for_each`)

Để khắc phục nhược điểm dịch chuyển index của `count`, `for_each` được khuyến khích sử dụng khi tạo danh sách tài nguyên động. `for_each` nhận vào một tập hợp không trùng lặp (`set`) hoặc một bản đồ (`map`).

### 📌 Ví dụ với `set(string)`:
Tạo các IAM User độc lập từ một tập hợp tên:

```hcl
resource "aws_iam_user" "users" {
  for_each = toset(["alice", "bob", "charlie"])
  name     = each.value # equal to each.key
}
```

### 📌 Ví dụ với `map(object)`:
Tạo nhiều Subnet khác nhau trong VPC với cấu hình chi tiết:

```hcl
variable "subnet_config" {
  type = map(object({
    cidr_block = string
    is_public  = bool
  }))
  default = {
    subnet_a = { cidr_block = "10.0.1.0/24", is_public = true }
    subnet_b = { cidr_block = "10.0.2.0/24", is_public = false }
  }
}

resource "aws_subnet" "subnets" {
  for_each   = var.subnet_config
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value.cidr_block

  tags = {
    Name = "Subnet-${each.key}"
    Type = each.value.is_public ? "Public" : "Private"
  }
}
```

### 💡 Ưu điểm vượt trội:
Mỗi tài nguyên được định danh bằng một chuỗi khóa (Key): `aws_subnet.subnets["subnet_a"]`. Khi bạn thêm hoặc bớt các phần tử trong map, các tài nguyên khác hoàn toàn không bị ảnh hưởng hay bị tạo lại.

---

## 🌐 5. Chỉ Định Nhà Cung Cấp Tùy Chọn (`provider`)

Khi bạn cần triển khai tài nguyên trên nhiều vùng địa lý (Multi-region) hoặc nhiều tài khoản Cloud khác nhau trong cùng một dự án, bạn sẽ dùng `provider`.

### 📌 Ví dụ thực tế:
Tạo tài nguyên ở vùng `ap-southeast-1` (mặc định) và vùng `us-east-1` (sử dụng alias):

```hcl
# Provider mặc định
provider "aws" {
  region = "ap-southeast-1"
}

# Provider phụ với alias
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

# Tạo EC2 ở Singapore (sử dụng provider mặc định)
resource "aws_instance" "singapore_server" {
  ami           = "ami-singapore-id"
  instance_type = "t2.micro"
}

# Tạo EC2 ở Mỹ (chỉ định provider phụ qua alias)
resource "aws_instance" "us_server" {
  provider      = aws.us_east # Chỉ định provider
  ami           = "ami-us-id"
  instance_type = "t2.micro"
}
```

---

## 🔄 6. Kiểm Soát Vòng Đời Tài Nguyên (`lifecycle`)

Khối `lifecycle` nằm bên trong khối `resource` để cấu hình cách Terraform tương tác với các nhà cung cấp dịch vụ khi tạo, sửa, hoặc xóa tài nguyên.

```hcl
resource "aws_instance" "web" {
  # ... cấu hình thông thường ...

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
    ignore_changes        = [tags]
  }
}
```

### 🔹 6.1. `create_before_destroy` (Mặc định: `false`)
*   **Hành vi mặc định:** Khi một thuộc tính thay đổi yêu cầu tạo lại tài nguyên (như đổi AMI máy ảo), Terraform sẽ xóa (destroy) tài nguyên cũ trước, sau đó mới tạo (create) tài nguyên mới. Điều này gây ra downtime.
*   **Khi bật `true`:** Terraform sẽ tạo tài nguyên mới chạy thành công trước, sau đó mới tiến hành xóa tài nguyên cũ.
*   *Ứng dụng:* Đảm bảo tính liên tục của dịch vụ (Zero-Downtime deployment).

### 🔹 6.2. `prevent_destroy` (Mặc định: `false`)
*   **Khi bật `true`:** Terraform sẽ từ chối bất kỳ kế hoạch nào cố gắng hủy tài nguyên này (bao gồm cả lệnh `terraform destroy`).
*   *Ứng dụng:* Bảo vệ các tài nguyên quan trọng chứa dữ liệu như Production Database, S3 Bucket lưu trữ Log tài chính, CloudFront, v.v.

### 🔹 6.3. `ignore_changes` (Nhận vào danh sách thuộc tính)
*   **Hành vi:** Bỏ qua sự khác biệt của các thuộc tính được liệt kê khi so sánh giữa mã code và thực tế ngoài Cloud.
*   *Ứng dụng:* Khi hạ tầng thực tế bị thay đổi bởi một dịch vụ bên thứ ba (như AWS Auto Scaling tự động đổi size EC2, hoặc chính sách tag tự động của doanh nghiệp) và bạn không muốn Terraform ghi đè các thay đổi đó về trạng thái cũ.
    ```hcl
    lifecycle {
      ignore_changes = [
        tags,
        instance_type, # Bỏ qua nếu Auto Scaling Group tự động thay đổi
      ]
    }
    ```

### 🔹 6.4. `replace_triggered_by` (Nhận vào danh sách tham chiếu tài nguyên)
*   **Khi bật:** Buộc tài nguyên này phải được tạo mới lại nếu bất kỳ tài nguyên nào được tham chiếu trong danh sách bị thay đổi hoặc tạo mới.
*   *Ứng dụng:* Tạo lại VM khi cấu hình mạng (VPC/Subnet/Security Group) bị thay đổi nhằm đảm bảo các thông số mạng được nạp mới chính xác.

---

## ❓ 7. Bộ Câu Hỏi Q&A Ôn Tập Học Nhanh (Flashcards Q&A)

### Q1: Tại sao nên sử dụng `for_each` thay vì `count` khi tạo danh sách tài nguyên động từ một mảng?
<details>
<summary>💡 Xem câu trả lời</summary>

Vì `count` quản lý tài nguyên dựa trên chỉ số (index) của mảng (`[0], [1], [2]`). Nếu một phần tử ở giữa danh sách bị xóa, tất cả các phần tử đứng sau sẽ bị dịch chuyển index, dẫn đến việc Terraform cố gắng xóa và tạo lại toàn bộ các tài nguyên bị dịch chuyển đó. Trong khi đó, `for_each` quản lý tài nguyên dựa trên khóa định danh (string key). Việc thêm/xóa phần tử chỉ tác động trực tiếp lên tài nguyên tương ứng mà không làm ảnh hưởng đến các tài nguyên khác.
</details>

---

### Q2: Nếu bạn cấu hình `prevent_destroy = true` cho một database, và sau đó chạy lệnh `terraform destroy`, điều gì sẽ xảy ra?
<details>
<summary>💡 Xem câu trả lời</summary>

Terraform sẽ lập tức dừng tiến trình ngay lập tức và trả về một thông báo lỗi màu đỏ chỉ rõ tài nguyên đó không thể bị hủy. Không có bất kỳ tài nguyên nào trong dự án bị xóa tại thời điểm đó. Để thực sự xóa, bạn phải vào code sửa đổi giá trị `prevent_destroy = false` trước, sau đó mới chạy lại lệnh destroy.
</details>

---

### Q3: Có thể truyền biến (variables) hoặc biến cục bộ (locals) vào thuộc tính `prevent_destroy` hoặc `create_before_destroy` trong khối `lifecycle` được không?
<details>
<summary>💡 Xem câu trả lời</summary>

**Không.** Giống như khối `terraform {}`, khối `lifecycle` là cấu hình đặc biệt của nhân Terraform Core. Nó được đánh giá và phân tích ngữ pháp rất sớm trước khi Terraform tính toán các biểu thức hoặc nạp giá trị của biến. Do đó, các thuộc tính bên trong `lifecycle` chỉ chấp nhận các giá trị logic tĩnh (`true` hoặc `false`) được viết cứng trong code.
</details>

---

### Q4: Mục đích thực tế của việc sử dụng `ignore_changes` là gì? Cho ví dụ minh họa.
<details>
<summary>💡 Xem câu trả lời</summary>

Mục đích của `ignore_changes` là bỏ qua những thay đổi ngoài ý muốn do hệ thống bên ngoài tự động thay đổi ngoài tầm kiểm soát của Terraform (Drift).
*Ví dụ:* Bạn tạo một AWS ECS Service và đặt cấu hình số lượng bản sao là `desired_count = 2`. Tuy nhiên, bạn cũng bật tính năng AWS Application Auto Scaling để tự động tăng số lượng bản sao lên 5 khi tải cao. Nếu không dùng `ignore_changes = [desired_count]`, mỗi lần bạn chạy `terraform apply`, Terraform sẽ cố gắng hạ số lượng bản sao từ 5 về lại 2, gây gián đoạn tải hệ thống.
</details>

---

### Q5: Khi cấu hình `alias` cho một Provider để làm việc multi-region, làm thế nào để tham chiếu provider đó vào một resource?
<details>
<summary>💡 Xem câu trả lời</summary>

Bạn sử dụng cú pháp: `<PROVIDER_NAME>.<ALIAS_NAME>`.
*Ví dụ:* Nếu bạn khai báo provider aws với alias là `us_east`:
```hcl
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}
```
Thì trong khối resource, bạn chỉ định thông qua tham số `provider`:
```hcl
resource "aws_instance" "web" {
  provider = aws.us_east
  # ...
}
```
</details>

---
