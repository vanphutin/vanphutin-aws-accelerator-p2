# 📘 Hướng Dẫn Tự Học Terraform: Đồ Thị Phụ Thuộc (Dependency Graph)

Tài liệu này tổng hợp toàn bộ kiến thức cốt lõi về **Đồ thị phụ thuộc (Dependency Graph)** trong Terraform, giúp bạn hiểu rõ cách thức hoạt động bên dưới của HCL: Thứ tự tạo/xóa tài nguyên, cơ chế chạy song song, phụ thuộc ngầm (implicit) và rõ ràng (explicit), cũng như cờ cứu hộ `-target`.

---

## 🧩 1. Đồ Thị Phụ Thuộc (Dependency Graph) Là Gì?

### 🔹 1.1. Nguyên lý cốt lõi
* 📌 **Quan niệm sai lầm:** Nhiều người nghĩ rằng Terraform sẽ tạo tài nguyên theo thứ tự từ trên xuống dưới như cách chúng được viết trong file `.hcl`. 
* 🛠️ **Thực tế:** Thứ tự khai báo các dòng hay các file cấu hình **hoàn toàn không quyết định** thứ tự thực thi. 
* 📊 **Giải pháp:** Terraform biên dịch toàn bộ code cấu hình của bạn thành một mô hình toán học gọi là **Đồ thị có hướng không chu trình (DAG - Directed Acyclic Graph)**:
  * **Đỉnh (Node):** Đại diện cho từng tài nguyên (resource, module, provider).
  * **Cạnh (Edge):** Đại diện cho mối quan hệ phụ thuộc giữa các tài nguyên (Cái nào cần tạo trước, cái nào cần tạo sau).

---

## 📊 2. Xem Đồ Thị Tận Mắt Bằng Lệnh `terraform graph`

Bạn có thể xuất cấu trúc đồ thị hiện tại của dự án dưới định dạng đồ họa **DOT** bằng lệnh:

```bash
terraform graph
```

### 🔹 2.1. Cấu trúc xuất mẫu (Định dạng DOT):
```ruby
digraph G {
  rankdir = "RL";
  node [shape = rect, fontname = "sans-serif"];
  "aws_s3_bucket.data" [label="aws_s3_bucket.data"];
  "aws_s3_bucket_versioning.data" [label="aws_s3_bucket_versioning.data"];
  "aws_s3_bucket_versioning.data" -> "aws_s3_bucket.data";
}
```

* **Ý nghĩa dòng cuối:** Cạnh `"aws_s3_bucket_versioning.data" -> "aws_s3_bucket.data"` chỉ ra rằng: Khối `versioning` hướng mũi tên trỏ vào `bucket`, đồng nghĩa với việc **khối versioning phụ thuộc trực tiếp vào bucket**.
* **Cách chuyển đổi thành hình ảnh trực quan:** Định dạng DOT có thể được vẽ ra hình ảnh PNG/SVG bằng công cụ Graphviz. Lệnh xuất nhanh:
  ```bash
  terraform graph | dot -Tpng > graph.png
  ```
  *(Mẹo này cực kỳ hữu ích để chụp ảnh tài liệu báo cáo hoặc phân tích hệ thống lớn).*

---

## 🔄 3. Cơ Chế Sắp Xếp Topo & Chạy Song Song

### 🔹 3.1. Sắp xếp Topo (Topological Sort)
Có đồ thị trong tay, Terraform thực hiện thuật toán sắp xếp Topo để ra thứ tự thao tác chuẩn xác:
* Tài nguyên nào không phụ thuộc vào bất kỳ ai -> **Tạo trước**.
* Tài nguyên nào phụ thuộc vào tài nguyên khác -> **Xếp hàng chờ** tài nguyên kia tạo xong hoàn toàn.

### 🔹 3.2. Chạy Song Song (Parallel Execution)
* Nếu hai hoặc nhiều tài nguyên **không có cạnh kết nối nào với nhau** (hoàn toàn độc lập), Terraform sẽ tiến hành **tạo chúng song song** cùng một lúc để tối ưu thời gian.
* Mặc định, Terraform hỗ trợ thực thi song song lên tới **10 thao tác cùng lúc** (có thể cấu hình lại bằng cờ `-parallelism=N`). Đây là lý do vì sao Terraform deploy hạ tầng quy mô lớn cực nhanh.

### 🔹 3.3. Tại sao cơ chế xóa (Destroy) lại đảo ngược thứ tự?

```text
       [ Khởi Tạo (Apply) ]                     [ Hủy Bỏ (Destroy) ]
       (Thuận theo mũi tên)                    (Ngược chiều mũi tên)
     ────────────────────────                 ────────────────────────
      1. Tài nguyên cha (A)                    1. Tài nguyên con (B)
               │ (Xong trước)                           │ (Phải gỡ trước)
               ▼                                        ▼
      2. Tài nguyên con (B)                    2. Tài nguyên cha (A)
```

* **Nguyên tắc tự nhiên:** Nếu B cần A để hoạt động, khi tạo ta cần **A trước, B sau**. Khi xóa, ta bắt buộc phải **gỡ B trước, A sau**. Nếu xóa A trước, tài nguyên B sẽ bị lỗi "mất gốc" hoặc Cloud Provider sẽ chặn không cho phép xóa (ví dụ: Không thể xóa Subnet nếu bên trong vẫn còn máy chủ VM đang chạy).

---

## ⚡ 4. Phụ Thuộc Ngầm (Implicit) vs Phụ Thuộc Rõ Ràng (Explicit)

Có hai cách để thiết lập mối liên kết phụ thuộc giữa các tài nguyên trong Terraform:

### 🔹 4.1. Phụ thuộc ngầm (Implicit Dependency)
* **Khái niệm:** Xảy ra tự nhiên khi bạn tham chiếu (reference) trực tiếp một thuộc tính của tài nguyên này vào đối số của tài nguyên khác.
* **Ví dụ:**
  ```hcl
  resource "aws_security_group" "web_sg" {
    name = "web-sg"
  }

  resource "aws_instance" "web_server" {
    ami           = "ami-xyz"
    instance_type = "t3.micro"
    # Tham chiếu ID của Security Group vào Instance
    vpc_security_group_ids = [aws_security_group.web_sg.id] 
  }
  ```
  * Ở đây, `aws_instance.web_server` tự động phụ thuộc ngầm vào `aws_security_group.web_sg`. Terraform tự biết phải tạo Security Group trước rồi mới tạo Web Server. Bạn không cần làm gì thêm.

### 🔹 4.2. Phụ thuộc rõ ràng (Explicit Dependency) bằng `depends_on`
* **Khái niệm:** Dùng để xử lý các **phụ thuộc ẩn** ở tầng ứng dụng hoặc hệ thống mà bản thân cú pháp HCL không thể tự nhìn thấy hay suy luận ra được.
* **Cú pháp:** Khai báo trực tiếp tham số `depends_on = [<RESOURCE>]` bên trong block.
* **Ví dụ thực tế:** Một máy chủ cần ghi log hoặc truy cập Database bằng một phân quyền đặc biệt (IAM Role Policy), tuy nhiên khai báo máy chủ lại không hề gọi thuộc tính nào của IAM Policy đó. Quan hệ này nằm ở tầng vận hành của ứng dụng.
  ```hcl
  resource "aws_iam_role_policy" "s3_access" {
    name = "s3-access-policy"
    role = aws_iam_role.web_role.id
    # ... policy rules ...
  }

  resource "aws_instance" "web" {
    ami           = "ami-123456"
    instance_type = "t2.micro"

    # Chỉ định thủ công: Phải tạo xong policy trước khi tạo EC2
    depends_on = [
      aws_iam_role_policy.s3_access
    ]
  }
  ```

> [!WARNING]
> Chỉ sử dụng `depends_on` khi thực sự không thể tạo phụ thuộc ngầm. Lạm dụng `depends_on` quá nhiều sẽ làm đồ thị phụ thuộc trở nên phức tạp, mất đi khả năng chạy song song và làm chậm quá trình deploy hạ tầng.

---

## 🚪 5. Cờ `-target`: Lối Thoát Hiểm, Không Phải Công Cụ Hàng Ngày

Khi gặp một tài nguyên bị lỗi nặng hoặc bạn đang cần debug nhanh một góc nhỏ của hệ thống, cờ `-target` cho phép giới hạn phạm vi tác động vào đúng tài nguyên đó:

```bash
terraform apply -target=aws_s3_bucket.data
```

* **Cách hoạt động:** Terraform sẽ chỉ quét và chạy một nhánh nhỏ của đồ thị dẫn đến tài nguyên được nhắm mục tiêu (tạo nó và các tài nguyên trực tiếp mà nó cần), bỏ qua hoàn toàn phần còn lại.
* **Hậu quả của việc lạm dụng `-target`:**
  * Gây lệch cấu hình và trạng thái giữa mã nguồn `.hcl` và file `.tfstate` một cách có chủ ý.
  * Bản thân Terraform sẽ hiển thị cảnh báo rất lớn khuyến cáo không nên sử dụng.
  * Nếu bạn thấy mình liên tục gõ `-target` chỉ để apply cho nhanh, đó là dấu hiệu cảnh báo cấu hình hạ tầng của bạn đang quá lớn và cồng kềnh. 

> [!TIP]
> Thay vì lạm dụng `-target`, hãy thiết kế tách cấu hình hạ tầng thành nhiều Workspace hoặc nhiều State nhỏ độc lập để quản lý và vận hành hiệu quả hơn.

---

## ❓ 6. Bộ Câu Hỏi Q&A Ôn Tập Học Nhanh (Flashcards Q&A)

### Q1: Đồ thị phụ thuộc của Terraform được gọi là DAG (Directed Acyclic Graph) - "Không chu trình" nghĩa là gì và tại sao nó lại tối quan trọng?
<details>
<summary>💡 Xem câu trả lời</summary>

* **"Không chu trình" (Acyclic):** Nghĩa là trong đồ thị không có bất kỳ vòng lặp vô hạn nào (không có tình trạng A phụ thuộc B, B phụ thuộc C, và C lại quay ngược lại phụ thuộc A).
* **Tầm quan trọng:** Nếu xuất hiện chu trình lặp (Cyclic Dependency), Terraform sẽ rơi vào vòng lặp vô tận và không bao giờ xác định được tài nguyên nào cần tạo trước. Lúc này, Terraform sẽ lập tức dừng lại và báo lỗi: *"Error: Cycle detected..."* buộc bạn phải gỡ bỏ vòng lặp tham chiếu chéo đó.
</details>

---

### Q2: Tại sao việc khai báo tài nguyên theo thứ tự viết trước/viết sau trong file `.hcl` không hề ảnh hưởng đến thứ tự tạo trên Cloud?
<details>
<summary>💡 Xem câu trả lời</summary>

Vì Terraform hoạt động theo nguyên lý **khai báo (declarative)** chứ không phải **tuần tự (procedural)**. Khi bạn chạy lệnh, Terraform sẽ đọc toàn bộ các file cấu hình cùng lúc, phân tích mối quan hệ tham chiếu giữa các block để xây dựng nên **Đồ thị phụ thuộc**. Thứ tự thực thi hoàn toàn do thuật toán sắp xếp Topo trên đồ thị quyết định, chứ không phụ thuộc vào dòng dòng code nằm ở vị trí nào trong file.
</details>

---

### Q3: Nếu có 5 tài nguyên hoàn toàn độc lập (không tham chiếu lẫn nhau), Terraform sẽ xử lý tạo chúng như thế nào?
<details>
<summary>💡 Xem câu trả lời</summary>

Do không có sự phụ thuộc hay liên kết chéo, 5 tài nguyên này được xem là các nhánh song song độc lập trên đồ thị. Terraform sẽ kích hoạt cơ chế thực thi đa luồng (multi-threading) để gọi API tạo **cả 5 tài nguyên cùng một lúc (song song)** nhằm giảm thiểu thời gian chờ đợi (tối đa mặc định lên tới 10 luồng).
</details>

---

### Q4: Cho ví dụ cụ thể về việc lạm dụng `depends_on` quá đà sẽ gây hại như thế nào đối với hiệu năng của hệ thống Terraform?
<details>
<summary>💡 Xem câu trả lời</summary>

Giả sử bạn có 10 Virtual Machines hoạt động độc lập và có thể tạo song song cùng lúc chỉ mất 2 phút. Nếu bạn lười và khai báo thủ công `depends_on` nối đuôi nhau liên tiếp (VM2 phụ thuộc VM1, VM3 phụ thuộc VM2, v.v.), Terraform sẽ bị ép buộc phải chạy tuần tự từng máy chủ một. Tổng thời gian deploy sẽ bị kéo dài lên tới 20 phút (gấp 10 lần) do bạn đã phá hủy hoàn toàn khả năng chạy song song tự nhiên của đồ thị.
</details>

---

### Q5: Tại sao cờ `-target` được ví như "Lối thoát hiểm" (lối đi đặc biệt khi gặp hỏa hoạn) thay vì là lối đi hàng ngày?
<details>
<summary>💡 Xem câu trả lời</summary>

Vì cờ `-target` chỉ được thiết kế cho các tình huống khẩn cấp, cô lập tài nguyên lỗi để khắc phục sự cố cục bộ. Việc lạm dụng nó hàng ngày sẽ phá vỡ tính đồng bộ của hệ thống: bạn tạo tài nguyên này nhưng bỏ quên cập nhật các tài nguyên liên quan, dẫn đến sự bất đồng nhất sâu sắc giữa code `.hcl` và file `.tfstate`, rất dễ gây ra các lỗi không đồng bộ nghiêm trọng về sau.
</details>

---