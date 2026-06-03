# 📘 Hướng Dẫn Tự Học Terraform: Các Thao Tác Quản Trị State (State Operations)

Khi làm việc với hạ tầng thực tế, bạn sẽ gặp những tình huống phức tạp mà chỉ chạy lệnh `apply` thông thường không thể giải quyết được. Tài liệu này hướng dẫn chi tiết **3 thao tác quản trị State cốt lõi**: Đưa hạ tầng có sẵn vào quản lý (`import`), đổi tên/di chuyển tài nguyên (`state mv`), và ngừng quản lý tài nguyên (`state rm`).

---

## 🧩 1. Ba Kịch Bản Quản Trị State Thực Tế

| Kịch bản | Nhu cầu thực tế | Thao tác giải quyết |
| :--- | :--- | :--- |
| **1. Hạ tầng có sẵn** | Bạn có một tài nguyên (ví dụ: S3 Bucket, VM) được tạo bằng tay từ trước, giờ muốn đưa vào cho Terraform quản lý mà **không muốn xóa đi tạo lại**. | **`import` block** (Config-driven import) |
| **2. Đổi tên tài nguyên** | Bạn muốn đổi tên định danh của tài nguyên trong file code `.hcl` nhưng **không muốn Terraform xóa tài nguyên cũ và tạo tài nguyên mới** (gây mất dữ liệu). | **`terraform state mv`** |
| **3. Ngừng quản lý** | Bạn muốn Terraform "quên" tài nguyên này đi, không quản lý nó nữa nhưng **giữ nguyên tài nguyên hoạt động** trên Cloud (ví dụ để chuyển sang file state khác). | **`terraform state rm`** |

---

## 📥 2. Đưa Hạ Tầng Có Sẵn Vào Quản Lý (Terraform Import)

Rất hiếm khi bạn bắt đầu một dự án với một hạ tầng trống trơn. Thông thường, hệ thống đã có sẵn các tài nguyên được tạo thủ công từ trước. Terraform sẽ không biết đến sự tồn tại của chúng vì chúng chưa được ghi nhận trong file state.

### 🔹 2.1. Tiến hóa của cơ chế Import
* **Trước Terraform 1.5 (Lệnh CLI thủ công):** Người dùng phải chạy lệnh `terraform import <địa_chỉ_đích> <id_thực_tế>`. Điểm cực kỳ bất tiện là bạn phải tự tay viết trước block khai báo resource trong file code `.hcl` sao cho khớp chính xác từng thuộc tính với thực tế. Nếu viết sai lệch dù chỉ 1 dòng, lệnh apply tiếp theo sẽ báo lỗi hoặc đòi chỉnh sửa cloud.
* **Từ Terraform 1.5+ (Config-driven Import):** Khai báo ý định import trực tiếp bằng một block `import` ngay trong code. Terraform sẽ tự phân tích và tự động viết hộ code cấu hình cho bạn!

### 🔹 2.2. Cách sử dụng Block `import` và Tự sinh cấu hình:

#### **Bước 1:** Khai báo block `import` trong file code `.tf` của bạn:
```hcl
import {
  to = aws_s3_bucket.adopted
  id = "ten-bucket-co-san-tren-aws" # ID thực tế của tài nguyên trên Cloud
}
```
*(Để ý: Lúc này bạn chưa hề viết block `resource "aws_s3_bucket" "adopted"` nào cả).*

#### **Bước 2:** Chạy lệnh tự động sinh code cấu hình:
Sử dụng cờ `-generate-config-out` kèm đường dẫn file muốn xuất code nháp:
```bash
terraform plan -generate-config-out=generated.tf
```

* **Kết quả:** Terraform sẽ tự động gọi API lên Cloud để quét tài nguyên có ID tương ứng, tự viết ra block cấu hình chi tiết của tài nguyên đó và lưu vào file `generated.tf`. 
* **Bước 3:** Bạn chỉ cần kiểm tra lại file `generated.tf`, chỉnh sửa nếu muốn, sau đó chạy `terraform apply` để hoàn tất việc đưa tài nguyên vào quản lý của State.

---

## 🔄 3. Đổi Tên / Di Chuyển Tài Nguyên (`state mv`)

### 🔹 3.1. Rủi ro khi đổi tên trực tiếp trong code
Giả sử trong code của bạn đang quản lý một Database hoặc Storage Bucket có tên local là `adopted`:
```hcl
resource "aws_s3_bucket" "adopted" { ... }
```
Nếu bạn đổi tên định danh trong code thành `data`:
```hcl
resource "aws_s3_bucket" "data" { ... }
```
Khi bạn chạy `terraform plan`, Terraform sẽ đối chiếu với file state và hiểu nhầm rằng: **"Tài nguyên `adopted` đã bị xóa bỏ, và có một tài nguyên `data` mới được thêm vào"**. Hệ quả: Terraform sẽ tiến hành **xóa sạch** bucket chứa dữ liệu cũ để tạo một bucket trống trơn mới. Đây là một **thảm họa mất mát dữ liệu**!

### 🔹 3.2. Giải pháp an toàn bằng `state mv`
Lệnh `state mv` giúp bạn đổi tên ánh xạ (địa chỉ) của tài nguyên ngay trong file state để khớp với tên mới trong code mà không làm ảnh hưởng đến tài nguyên thực tế ngoài đời thực.

* **Cú pháp:**
  ```bash
  terraform state mv <Địa_chỉ_cũ_trong_state> <Địa_chỉ_mới_trong_code>
  ```
* **Ví dụ thực tế:**
  ```bash
  terraform state mv aws_s3_bucket.adopted aws_s3_bucket.data
  ```
* **Kết quả:** File state được cập nhật tên mới. Khi bạn đổi tên tương ứng trong file code `.hcl` và chạy lại `terraform plan`, Terraform sẽ báo `"No changes"` vì cả code và state đã khớp nhau hoàn hảo mà không cần đụng chạm gì đến hạ tầng thật!

---

## 🗑️ 4. Ngừng Quản Lý Tài Nguyên (`state rm`)

Có những trường hợp bạn muốn Terraform ngừng quản lý, không theo dõi một tài nguyên nữa (ví dụ: Bạn muốn tách tài nguyên đó sang một cấu hình Terraform khác độc lập để quản lý), nhưng bắt buộc **phải giữ tài nguyên đó tiếp tục hoạt động bình thường** trên Cloud.

* **Vấn đề nếu xóa code trực tiếp:** Nếu bạn xóa block code của tài nguyên đó trong file `.hcl` rồi chạy `apply`, Terraform sẽ lập tức gọi API lên Cloud để **xóa sổ** tài nguyên đó.
* **Giải pháp an toàn:** Sử dụng lệnh `state rm` để xóa tài nguyên đó ra khỏi "bản đồ" file state trước.
* **Cú pháp:**
  ```bash
  terraform state rm <Địa_chỉ_tài_nguyên_trong_state>
  ```
* **Ví dụ:**
  ```bash
  terraform state rm aws_s3_bucket.data
  ```
* **Hành vi sau khi chạy:** Terraform sẽ "quên" hoàn toàn tài nguyên này. Bây giờ, bạn có thể an toàn xóa block code của tài nguyên đó trong file `.hcl` đi mà không sợ bị xóa tài nguyên thật khi chạy `apply`.

> [!WARNING]
> Sử dụng `state rm` rất dễ để lại các "tài nguyên mồ côi" (Orphaned Resources) chạy lãng phí trên Cloud mà không ai quản lý. Hãy chắc chắn rằng bạn có kế hoạch quản lý tài nguyên này ở một nơi khác sau khi chạy lệnh.

---

## ❓ 5. Bộ Câu Hỏi Q&A Ôn Tập Học Nhanh (Flashcards Q&A)

### Q1: Tại sao chúng ta bắt buộc phải khóa state (State Locking) và sao lưu state trước khi thực hiện các lệnh như `state mv` hay `state rm`?
<details>
<summary>💡 Xem câu trả lời</summary>

Bởi vì các lệnh `state mv` và `state rm` là các thao tác ghi trực tiếp và thay đổi cấu trúc của file `terraform.tfstate`. Nếu có một tiến trình khác cũng đang cố gắng chỉnh sửa state cùng lúc, file state sẽ bị lỗi cấu trúc dữ liệu (Corrupt State) làm Terraform không thể đọc được nữa. Việc sao lưu (Backup) giúp bạn luôn có một đường lui an toàn để khôi phục lại nguyên trạng bản đồ hạ tầng nếu lỡ tay gõ sai lệnh di chuyển hoặc xóa nhầm tài nguyên quan trọng.
</details>

---

### Q2: Khác biệt lớn nhất giữa việc xóa block tài nguyên trong code `.hcl` và việc chạy lệnh `terraform state rm` là gì?
<details>
<summary>💡 Xem câu trả lời</summary>

* **Xóa block code `.hcl` rồi chạy apply:** Terraform đối chiếu thấy tài nguyên có trong state nhưng không có trong code -> Terraform hiểu là bạn muốn xóa bỏ nó, và sẽ gọi API lên Cloud để **xóa sạch tài nguyên thực tế**.
* **Chạy lệnh `terraform state rm`:** Terraform chỉ xóa dữ liệu của tài nguyên đó ra khỏi file state. Tài nguyên thực tế trên Cloud **vẫn hoạt động bình thường** không hề bị ảnh hưởng, chỉ là Terraform từ nay sẽ không quản lý hay theo dõi nó nữa.
</details>

---

### Q3: Nếu bạn chạy lệnh `terraform state mv` để đổi tên tài nguyên trong state nhưng quên không sửa tên tương ứng trong file code `.hcl`, chuyện gì sẽ xảy ra ở lệnh apply tiếp theo?
<details>
<summary>💡 Xem câu trả lời</summary>

Terraform sẽ đối chiếu code và state và thấy:
1. Trong code `.hcl` vẫn còn khai báo tài nguyên với tên cũ -> Terraform nghĩ bạn muốn tạo mới một tài nguyên với tên cũ đó.
2. Trong state có tài nguyên mang tên mới nhưng trong code `.hcl` lại không khai báo -> Terraform nghĩ bạn muốn xóa bỏ tài nguyên mang tên mới này đi.
Hệ quả: Terraform sẽ cố gắng xóa tài nguyên mang tên mới và tạo lại một tài nguyên mang tên cũ, gây ra xung đột hoặc lỗi hệ thống nghiêm trọng. Do đó, **luôn đồng bộ cả code `.hcl` và lệnh state mv**.
</details>

---

### Q4: Lệnh `terraform plan -generate-config-out=generated.tf` giúp ích gì cho các kỹ sư DevOps khi tiếp quản một dự án hạ tầng cũ được dựng thủ công?
<details>
<summary>💡 Xem câu trả lời</summary>

Nó giúp tiết kiệm hàng ngày, hàng tuần làm việc. Thay vì phải ngồi dò tìm từng cấu hình trên Web Console của Cloud Provider rồi tự tay gõ lại hàng trăm dòng code `.hcl` phức tạp một cách mò mẫm, tính năng tự sinh cấu hình này sẽ tự động kết nối qua API, đọc chính xác cấu hình thực tế và viết hộ bạn một file code nháp `.tf` chuẩn chỉ đến từng thuộc tính chỉ trong vài giây.
</details>

---

### Q5: Có bao giờ bạn cần chạy lệnh `import` cho một tài nguyên nhưng không có ID thực tế của tài nguyên đó không?
<details>
<summary>💡 Xem câu trả lời</summary>

**Không bao giờ.**
Mục tiêu của lệnh `import` là liên kết một định danh trong code với một thực thể thực tế trên Cloud. Nếu không có ID thực tế (ví dụ: tên Bucket S3, ID của VPC, ID của VM), Terraform sẽ không thể biết phải gọi API đến tài nguyên nào để tải cấu hình và ánh xạ vào state. ID thực tế chính là "chìa khóa" bắt buộc phải khai báo trong tham số `id` của block `import`.
</details>

---