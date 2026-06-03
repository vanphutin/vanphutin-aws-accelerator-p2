# 📘 Hướng Dẫn Tự Học Terraform: Lưu Trữ Trạng Thái Từ Xa (Remote State)

Tài liệu này tổng hợp toàn bộ kiến thức cốt lõi về **Lưu trữ trạng thái từ xa (Remote State)**, giúp bạn hiểu rõ cơ chế vận hành của Backend S3, giải quyết bài toán "con gà và quả trứng", và đặc biệt là cách sử dụng tính năng khóa trạng thái native hiện đại `use_lockfile = true` (không cần DynamoDB).

---

## 🧩 1. Ba "Điểm Chết" Của Local State & Giải Pháp Remote State

Khi lưu trữ file state trên máy cá nhân (`local`), bạn sẽ phải đối mặt với 3 rủi ro cực lớn:

| Tiêu chí | ❌ Local State (Trạng thái cục bộ) | 🟢 Remote State (Trạng thái từ xa) |
| :--- | :--- | :--- |
| **Chia sẻ nhóm** | Không chia sẻ được. Đồng nghiệp không có file state nên không thể cùng làm việc trên một hạ tầng. | Lưu tập trung trên Cloud (như S3). Bất kỳ ai có quyền truy cập đều đọc/ghi chung một bản đồ hạ tầng. |
| **Bảo mật** | Không an toàn. File state chứa mật khẩu, API token ở dạng văn bản thường (plaintext), nằm trên ổ cứng cá nhân và dễ bị vô tình commit lên Git. | Được lưu trữ an toàn, hỗ trợ **Mã hóa tĩnh (Encryption at Rest)** và phân quyền IAM chặt chẽ. |
| **Ghi đồng thời** | Không chống ghi đè chéo. Hai người chạy `apply` cùng lúc sẽ ghi đè đè lên nhau, làm hư hỏng dữ liệu (corrupt state). | Kích hoạt cơ chế **Khóa (Locking)** giúp chặn người thứ hai ghi đè khi người thứ nhất đang thao tác. |

---

## ⚙️ 2. Bài Toán "Con Gà Và Quả Trứng" Của Backend S3

### 🔹 2.1. Vấn đề nan giải
* Để Terraform cất file state lên một **S3 Bucket**, thì S3 Bucket đó phải **tồn tại trước**.
* Tuy nhiên, bạn lại muốn dùng chính Terraform để viết code tạo ra S3 Bucket đó. 
* Đây chính là bài toán **"Con gà có trước hay Quả trứng có trước?"**.

### 🔹 2.2. Giải pháp thực tế (Bootstrap Workflow)
Cộng đồng DevOps giải quyết vấn đề này bằng cách chia quy trình cấu hình thành **hai bước độc lập**:

```text
  [ Bước 1: Khởi tạo (Bootstrap) ]          [ Bước 2: Chuyển đổi (Migration) ]
  Chạy cấu hình nhỏ tạo S3 Bucket           Cấu hình Backend trỏ vào S3 vừa tạo
  Sử dụng State Local (Tạm thời)            Chạy 'terraform init' để đẩy State lên Cloud
```

1. **Bước 1 (Bootstrap):** Viết một file cấu hình nhỏ gọn và đơn giản, sử dụng **local state** để khai báo và tạo ra S3 Bucket (có bật Versioning, chặn Public Access, bật Encryption).
2. **Bước 2 (Migration):** Sau khi S3 Bucket đã được tạo thành công trên đám mây, bạn mở file cấu hình của mình ra, thêm block `backend "s3"` trỏ trực tiếp vào S3 Bucket vừa tạo. Chạy lệnh `terraform init` để đẩy (migrate) file state cục bộ lên đám mây. Từ đó trở đi, cấu hình này sẽ hoàn toàn chạy bằng Remote State.

---

## 🔒 3. Cấu Hình Backend S3 & Tính Năng Native Locking Hiện Đại

### 🔹 3.1. Block cấu hình S3 Backend cơ bản:
```hcl
terraform {
  backend "s3" {
    bucket         = "ten-bucket-state-cua-ban"
    key            = "app/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    use_lockfile   = true # Bật tính năng khóa native hiện đại!
  }
}
```

> [!NOTE]
> **Quy tắc giá trị tĩnh:** Block `backend` được Terraform đọc và xử lý cực kỳ sớm (ngay khi khởi chạy, trước khi biên dịch variables hay locals). Do đó, bạn **không được phép** sử dụng bất kỳ biến `var.` hay `local.` nào bên trong block này. Mọi giá trị khai báo đều bắt buộc phải là hằng số tĩnh (String Literal).

---

### 🔹 3.2. Cải tiến đột phá: `use_lockfile = true` (Native Locking)
> [!IMPORTANT]
> Đây là kiến thức cực kỳ mới và quan trọng giúp bạn tránh các tài liệu hướng dẫn cũ lỗi thời trên mạng.

* **Trước đây (Lỗi thời):** Để khóa state trên S3, người dùng bắt buộc phải tạo thêm một bảng cơ sở dữ liệu **Amazon DynamoDB** và khai báo thuộc tính `dynamodb_table` trong cấu hình.
* **Hiện tại (Hiện đại):** Tài liệu chính thức của HashiCorp đã ghi rõ: **Khóa dựa trên DynamoDB đã bị DEPRECATED (ngừng hỗ trợ) và sẽ bị loại bỏ hoàn toàn trong các phiên bản minor tiếp theo**. 
* **Giải pháp thay thế:** Sử dụng tham số `use_lockfile = true`. Tham số này kích hoạt cơ chế khóa native trực tiếp trên Amazon S3 mà không cần dựng thêm bảng DynamoDB nữa!

---

## ⚡ 4. Cơ Chế Khóa `use_lockfile` Hoạt Động Như Thế Nào?

Cơ chế khóa native này cực kỳ đơn giản và hiệu quả nhờ vào khả năng **Ghi có điều kiện (Conditional Writes)** trực tiếp ở tầng API của Amazon S3:

1. **Khi bắt đầu thao tác ghi (plan/apply/destroy):**
   * Terraform sẽ gửi một lệnh yêu cầu tạo một file khóa đặc biệt có tên là `<key>.tflock` (ví dụ: `app/terraform.tfstate.tflock`) trong S3 Bucket của bạn.
   * Lệnh ghi này đính kèm điều kiện API: **"Chỉ ghi thành công nếu file này chưa hề tồn tại"**.
2. **Nếu chưa có ai thao tác:**
   * File `.tflock` được tạo thành công. Terraform giữ khóa này trong suốt quá trình chạy lệnh để độc quyền chỉnh sửa.
   * Khi lệnh chạy xong xuôi (hoặc bị lỗi dừng lại), Terraform sẽ tự động gửi lệnh API để xóa file `.tflock` này đi để nhường quyền cho người tiếp theo.
3. **Nếu đang có người khác thao tác:**
   * Do file `.tflock` đã tồn tại, yêu cầu ghi có điều kiện của Terraform sẽ bị S3 từ chối và trả về lỗi **HTTP 412 PreconditionFailed**.
   * Terraform nhận được mã lỗi này sẽ biết ngay file state đang bị khóa và hiển thị cảnh báo chi tiết trên terminal cho bạn biết ai đang giữ khóa.

---

## ❓ 5. Bộ Câu Hỏi Q&A Ôn Tập Học Nhanh (Flashcards Q&A)

### Q1: Tại sao block `backend` trong Terraform bắt buộc phải sử dụng các chuỗi tĩnh (Hardcoded String) mà không cho phép dùng biến (var) hay local?
<details>
<summary>💡 Xem câu trả lời</summary>

Bởi vì block `backend` cấu hình nền tảng nơi cất giữ state cho toàn bộ dự án. Khi bạn gõ lệnh `terraform init`, Terraform phải đọc block này trước tiên để kết nối tới Cloud rồi mới có thể tải các API plugin (providers) và phân tích các file cấu hình còn lại. Ở giai đoạn cực sớm này, hệ thống phân tích biến (variable engine) chưa hề được khởi chạy, nên Terraform không có cách nào hiểu được các tham chiếu động `var.xxx` hay `local.xxx`.
*(Mẹo: Bạn có thể tách cấu hình backend ra file riêng bằng cách dùng cờ `-backend-config` khi init).*
</details>

---

### Q2: Nếu bạn vô tình làm hỏng hoặc xóa mất thư mục cấu hình local chứa mã nguồn bootstrap tạo S3 bucket ban đầu, hệ quả sẽ nghiêm trọng ra sao?
<details>
<summary>💡 Xem câu trả lời</summary>

**Hệ quả KHÔNG hề nghiêm trọng!** 
Bởi vì cấu hình bootstrap cực kỳ nhỏ gọn và đơn giản (thường chỉ chứa block định nghĩa S3 Bucket, Versioning và Access Block). Dù mất code local, bản thân S3 bucket thực tế vẫn đang chạy an toàn trên đám mây. Bạn hoàn toàn có thể dễ dàng viết lại vài dòng code cấu hình tương tự để quản lý lại hoặc đơn giản là giữ nguyên bucket đó hoạt động như một kho chứa từ xa cho các dự án khác mà không gặp bất kỳ gián đoạn nào.
</details>

---

### Q3: Tính năng `use_lockfile = true` mang lại lợi ích gì so với cách khóa state bằng DynamoDB truyền thống?
<details>
<summary>💡 Xem câu trả lời</summary>

1. **Đơn giản hóa tài nguyên:** Bạn không cần phải viết code tạo và quản lý một bảng cơ sở dữ liệu DynamoDB chỉ để phục vụ mục tiêu khóa state.
2. **Tiết kiệm chi phí:** Không phát sinh chi phí duy trì bảng dữ liệu cũng như dung lượng DynamoDB.
3. **Độ trễ thấp & Native:** Tận dụng trực tiếp tính năng Ghi có điều kiện (Conditional Write) bản xứ của S3 giúp giảm thiểu các kết nối phức tạp bên ngoài, giảm khả năng xảy ra lỗi phân quyền IAM chéo giữa 2 dịch vụ.
</details>

---

### Q4: Điều gì xảy ra khi bạn chạy `terraform apply` và nhận được lỗi "HTTP 412 PreconditionFailed"? Bạn cần xử lý thế nào?
<details>
<summary>💡 Xem câu trả lời</summary>

* **Nguyên nhân:** Lỗi này có nghĩa là đang có một tiến trình khác (hoặc một đồng nghiệp khác) đang chạy lệnh sửa đổi trên cùng hệ thống và đang giữ file khóa `.tflock`.
* **Cách xử lý:**
  1. Liên hệ với nhóm/đồng nghiệp để kiểm tra xem có ai đang deploy hay không và đợi họ hoàn thành.
  2. Nếu chắc chắn không có ai đang chạy (ví dụ do máy của họ bị crash giữa chừng làm kẹt khóa), bạn có thể kiểm tra file khóa `.tflock` trên S3 Bucket và xóa nó đi (hoặc dùng lệnh `terraform force-unlock` nếu backend hỗ trợ) để giải phóng quyền ghi.
</details>

---

### Q5: Tại sao việc bật tính năng Versioning cho S3 Bucket làm Backend lưu trữ State lại là một quy tắc bắt buộc (Best Practice)?
<details>
<summary>💡 Xem câu trả lời</summary>

Vì file state ghi nhận toàn bộ "sự sống" của hệ thống hạ tầng. Nếu trong quá trình deploy xảy ra sự cố mạng, xung đột dữ liệu hoặc bạn vô tình chạy lệnh xóa nhầm làm file state bị trống hoặc lỗi nặng, tính năng **Versioning** của S3 sẽ cho phép bạn khôi phục lại (Rollback) phiên bản file `.tfstate` chính xác trước đó chỉ trong vài giây, cứu nguy cho toàn bộ hệ thống hạ tầng doanh nghiệp.
</details>

---
