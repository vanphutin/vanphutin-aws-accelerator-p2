# 📘 Hướng Dẫn Tự Học Terraform: Cơ Chế State (Trạng Thái)

Tập tin này tổng hợp toàn bộ kiến thức cốt lõi về **State (Trạng thái)** trong Terraform, giúp bạn hiểu rõ nguyên lý hoạt động, cơ chế so sánh ba chiều, khóa trạng thái (locking), backend và các lưu ý bảo mật đặc biệt quan trọng.

---

## 🧩 1. Tại Sao Terraform Cần State?

### 🔹 1.1. Khái niệm cốt lõi
Để quản lý hạ tầng một cách khai báo (declarative), Terraform bắt buộc phải có một nơi để lưu giữ "bản đồ hiện trạng" của hệ thống. File **`terraform.tfstate`** chính là bản đồ này.

* 🏠 **Hình dung thực tế (Ẩn dụ):**
  * **File `.hcl` (main.tf):** Là **Bản vẽ thiết kế** của kiến trúc sư (Mô tả những gì bạn *muốn* xây dựng).
  * **File `.tfstate`:** Là **Bản đồ hoàn công** ghi nhận hiện trạng công trình sau khi thi công xong (Mô tả những gì thực tế *đã* được tạo ra).
  * **Hạ tầng thực tế (AWS, Azure, GCP, v.v.):** Là **Ngôi nhà thực tế** ngoài đời thực.
  * Nếu sau này bạn muốn xây thêm tầng hoặc sửa nhà, kiến trúc sư sẽ mang bản vẽ mới so sánh với bản đồ hoàn công (`.tfstate`) để biết chính xác cần thay đổi chỗ nào.

### 🔹 1.2. Các nhiệm vụ chính của State:
1. **Lưu trữ thuộc tính tài nguyên:** Biết chính xác thuộc tính nào đã được gán (ví dụ: IP Address, DNS, Resource ID mà cloud provider cấp).
2. **Metadata về sự phụ thuộc (Dependencies):** 
   * State ghi nhớ mối quan hệ phụ thuộc giữa các resource. 
   * Điều này cực kỳ quan trọng khi **xóa** tài nguyên: Khi bạn gỡ bỏ một resource khỏi cấu hình `.hcl`, nó không còn tồn tại trong mã nguồn để Terraform suy luận ra thứ tự xóa nữa. Nhờ có file state, Terraform sẽ biết cần xóa tài nguyên nào trước, tránh lỗi phá vỡ liên kết (ví dụ: Xóa Virtual Machine trước khi xóa Subnet chứa nó).

---

## 📂 2. Tập Tin State Lưu Trữ Những Gì?

Terraform **không** copy toàn bộ file cấu hình của bạn vào state, nó chỉ lưu trữ những dữ liệu tối giản cần thiết để quản lý:
* **Resource Mapping:** Ánh xạ các resource khai báo trong code với các Resource ID thực tế trên Cloud Provider.
* **Metadata phụ thuộc:** Thứ tự tạo và mối quan hệ cha-con, phụ thuộc chéo giữa các resource.
* **Metadata của Terraform Workflow:** Ghi nhận cấu trúc sơ đồ các module (module tree) và phiên bản của các Provider sử dụng (`required_providers`).

---

## 🔄 3. Cơ Chế Refresh: So Sánh 3 Chiều (3-Way Comparison)

Mỗi lần bạn chạy lệnh `terraform plan` hoặc `terraform apply`, trước khi tính toán sự thay đổi (diff), Terraform thực hiện một tiến trình gọi là **Refresh**. 

### 📊 Mô hình so sánh 3 chiều:

```text
   [ main.tf (HCL) ] ───► (Bạn muốn gì?) ────► Env = "dev"
          │
          │ (So sánh tạo ra Diff)
          ▼
   [ terraform.tfstate ] ◄─ [ Cập nhật bằng Refresh ] ─- [ Hạ tầng thực tế (Cloud) ]
   (Lần cuối đã biết)                                     (Đang có gì ngoài đời thực)
   Env = "dev"                                            Env = "dev"
```

1. **Bước 1 (Refresh):** Terraform liên hệ với các Cloud/Infrastructure Provider (như AWS, Azure, GCP, v.v.) thông qua API để hỏi tình trạng thực tế của tất cả các tài nguyên hiện tại, sau đó cập nhật thông tin mới nhất vào bộ nhớ (và file state).
2. **Bước 2 (So sánh - Diff):** So sánh thiết kế trong file cấu hình `.hcl` của bạn với hiện trạng thực tế vừa cập nhật để đưa ra phương án hành động thích hợp nhất (tạo mới, sửa đổi, hoặc hủy bỏ).
3. **Kết quả:** Nếu cả 3 khớp nhau hoàn toàn, diff rỗng và Terraform báo: `"No changes. Your infrastructure matches the configuration."`

---

## ⚡ 4. Xử Lý Lệch Lạc Hạ Tầng (Configuration Drift)

**Configuration Drift** xảy ra khi ai đó tự ý đăng nhập vào giao diện quản lý của Provider (ví dụ: AWS Console, Azure Portal, GCP Console, v.v.) để sửa đổi tài nguyên, khiến cho hạ tầng thực tế khác với những gì được khai báo trong file cấu hình `.hcl`. Khi phát hiện sự lệch lạc này qua so sánh 3 chiều, bạn có 2 lựa chọn xử lý:

| Phương án | Mục tiêu | Cách thực hiện |
| :--- | :--- | :--- |
| **1. Thích ứng với thực tế** | Giữ lại các thay đổi thủ công trên hạ tầng thực tế và cập nhật ngược lại vào file code. | 1. Chạy `terraform refresh` (hoặc `plan`) để cập nhật state khớp với hạ tầng thực tế.<br>2. Sửa lại code `.hcl` thủ công cho giống với giá trị thực tế đó để code và state đồng nhất. |
| **2. Kéo thực tế về cấu hình** | Ép hạ tầng thực tế phải quay trở lại đúng như những gì đã khai báo trong code `.hcl`. | Chạy `terraform apply`. Terraform sẽ nhận thấy thực tế bị thay đổi và tự động ghi đè, cấu hình lại hệ thống thực tế để đưa nó về đúng với file `.hcl`. |

### 🔹 4.1. Hướng Dẫn Từng Bước Xử Lý Khi Có Diff (Khác Biệt) Thực Tế

Khi bạn chạy lệnh `terraform plan` và nhận được thông báo có sự khác biệt (diff), hãy xác định mục tiêu của bạn để chọn 1 trong 3 hướng xử lý chi tiết dưới đây:

#### 📌 Hướng 1: Bạn vừa chủ động sửa code `.hcl` và muốn hạ tầng thực tế thay đổi theo code
*(Trường hợp viết thêm tài nguyên mới hoặc cập nhật thông số tài nguyên hiện có).*
* **Mục tiêu:** Ép hệ thống thực tế phải tuân thủ và đồng bộ theo đúng bản vẽ thiết kế mới trong code.
* **Cách thực hiện:**
  1. Xem kỹ danh sách các thay đổi trong terminal (`+` là thêm mới, `~` là sửa đổi thuộc tính, `-` là xóa đi).
  2. Nếu cấu hình thay đổi đã hoàn toàn chính xác, hãy chạy lệnh:
     ```bash
     terraform apply
     ```
  3. Nhập `yes` để xác nhận. Terraform sẽ gọi API lên Provider để cập nhật hạ tầng thực tế cho giống hệt với code của bạn.

#### 📌 Hướng 2: Ai đó đã sửa thủ công tài nguyên trên Cloud (Drift) và bạn muốn GIỮ LẠI thay đổi đó
*(Ví dụ: Tăng Ram/CPU của máy chủ trực tiếp trên Web Console và bạn thấy cấu hình này tốt, muốn cập nhật ngược lại vào mã nguồn).*
* **Mục tiêu:** Cập nhật lại file code `.hcl` để khớp với thực tế đang chạy mà không làm gián đoạn hạ tầng.
* **Cách thực hiện:**
  1. Chạy lệnh `terraform plan` để xem các thuộc tính bị lệch (ví dụ: Ram bị thay đổi từ `8GB` lên `16GB`).
  2. Mở file `.hcl` của bạn ra và **sửa code thủ công** để thay đổi thuộc tính đó cho giống hệt thực tế (đổi `ram = 8` thành `ram = 16`).
  3. Chạy lại lệnh `terraform plan`.
  4. Lúc này, Terraform so sánh thấy code của bạn đã khớp hoàn toàn với thực tế, diff sẽ biến mất (trở về 0) và báo: `"No changes"`. Cấu hình mới đã được lưu vết an toàn trong code!

#### 📌 Hướng 3: Ai đó sửa phá hoại hoặc sửa nhầm trên Cloud và bạn muốn HỦY BỎ để khôi phục lại trạng thái cũ
*(Ví dụ: Kẻ xấu tự ý xóa một rule quan trọng của firewall trên giao diện quản trị Web).*
* **Mục tiêu:** Khôi phục hạ tầng thực tế quay về đúng trạng thái an toàn ban đầu được định nghĩa trong code.
* **Cách thực hiện:**
  1. Bạn không cần sửa đổi bất kỳ dòng code `.hcl` nào.
  2. Chạy trực tiếp lệnh:
     ```bash
     terraform apply
     ```
  3. Terraform sẽ nhận diện sự thiếu hụt/lệch lạc trên Cloud và tự động cấu hình lại (hoặc tạo mới lại) tài nguyên bị mất để đưa nó về đúng nguyên trạng ban đầu của file code.

---

## 🔒 5. Cơ Chế Khóa State (State Locking)

> [!IMPORTANT]
> Khi nhiều người hoặc nhiều hệ thống CI/CD cùng làm việc trên một dự án hạ tầng, việc đồng thời thay đổi state cực kỳ nguy hiểm và dễ dẫn đến hư hỏng dữ liệu (corrupt state).

* **Khái niệm:** Khi bạn chạy các lệnh có khả năng thay đổi state (`plan`, `apply`, `destroy`, `refresh`), Terraform sẽ kích hoạt cơ chế **Lock (Khóa)** file state.
* **Cách hoạt động:**
  1. Tiến trình bắt đầu -> Gửi yêu cầu lấy Lock.
  2. Lấy Lock thành công -> Tiến hành đọc/ghi dữ liệu. Lúc này các tiến trình khác sẽ bị chặn và báo lỗi nếu cố tình can thiệp.
  3. Tiến trình hoàn thành (hoặc bị lỗi) -> Tự động giải phóng Lock (Unlock).
* **Sự cố Stale Lock:** Nếu máy tính của bạn bị mất mạng đột ngột hoặc Terraform crash giữa chừng, Lock có thể không được giải phóng kịp và bị "kẹt" (Stale Lock). Bạn sẽ phải tự tay mở khóa bằng cách sử dụng lệnh:
  ```bash
  terraform force-unlock <LOCK_ID>
  ```
  *(Lưu ý: Chỉ làm điều này khi chắc chắn không có ai khác đang thực thi lệnh).*

---

## 🌐 6. Nơi Lưu Trữ Trạng Thái (State Backend)

**Backend** định nghĩa nơi Terraform sẽ lưu trữ file `.tfstate` và cơ chế tạo file khóa `.tflock`.

### 🔹 6.1. Local Backend
* **Mặc định:** File state lưu ngay tại máy tính của bạn (`terraform.tfstate`).
* **Hạn chế:** Không thể làm việc nhóm, nguy cơ mất dữ liệu khi hỏng ổ cứng, không có cơ chế khóa state tự động khi làm việc chung.

### 🔹 6.2. Remote Backend (Bắt buộc cho dự án thực tế)
Lưu trữ state ở một hệ thống lưu trữ tập trung, an toàn, hỗ trợ mã hóa và cơ chế Locking.

| Loại Backend | Nơi lưu trữ State | Cơ chế Khóa (Locking) |
| :--- | :--- | :--- |
| **AWS S3** | Amazon S3 Bucket (mã hóa tĩnh) | **DynamoDB Table** (bắt buộc) |
| **Azure Blob** | Azure Storage Account | Blob Lease (tự động) |
| **Google Cloud (GCS)** | Google Cloud Storage Bucket | Lock Object (tự động) |
| **HCP Terraform** | Đám mây HCP Terraform của HashiCorp | Tích hợp sẵn trong workspace |

---

## ⚠️ 7. Cảnh Báo Bảo Mật: State Là Plaintext!

> [!CAUTION]
> Tập tin state của Terraform lưu trữ dữ liệu dưới dạng **văn bản thuần túy (plaintext)**. Mọi thông tin nhạy cảm bao gồm mật khẩu cơ sở dữ liệu, SSH keys, Token API/Access Keys của các Provider đều hiển thị rõ ràng nếu chúng được khai báo trong code hoặc sinh ra tự động.

### 🛡️ Quy tắc bảo mật sống còn:
1. ❌ **Không bao giờ** commit các file `terraform.tfstate` hoặc `terraform.tfstate.backup` lên GitHub/GitLab.
2. 📝 Hãy cấu hình file `.gitignore` để tự động loại bỏ các file state khỏi Git.
3. 🔒 Sử dụng Remote Backend an toàn có bật tính năng **mã hóa ở trạng thái nghỉ (Encryption at Rest)** và phân quyền truy cập chặt chẽ.

---

## ❓ 8. Bộ Câu Hỏi Q&A Ôn Tập Học Nhanh (Flashcards Q&A)

### Q1: Tại sao nói "Metadata về sự phụ thuộc" (Dependency Metadata) trong file state là quan trọng nhất khi chạy lệnh `terraform destroy`?
<details>
<summary>💡 Xem câu trả lời</summary>

Khi bạn xóa một tài nguyên ra khỏi file code `.hcl`, Terraform không còn bất kỳ dấu vết nào trong mã nguồn để biết tài nguyên đó từng liên kết với cái gì. Nhờ có **Dependency Metadata** trong file state, Terraform ghi nhớ toàn bộ phả hệ và mối quan hệ trước đó của tài nguyên (ví dụ: VM nằm trong Subnet nào). Từ đó, khi thực hiện lệnh hủy (`destroy`), Terraform sẽ tự tính toán được sơ đồ hủy ngược chính xác: xóa VM trước, sau đó mới xóa Subnet an toàn mà không gây lỗi xung đột phụ thuộc.
</details>

---

### Q2: Chuyện gì xảy ra nếu bạn chạy `terraform apply` sau khi một tài nguyên trên hạ tầng thực tế đã bị ai đó lỡ tay xóa mất trên giao diện điều khiển (Console)?
<details>
<summary>💡 Xem câu trả lời</summary>

1. Khi bạn khởi chạy, quá trình **Refresh** tự động diễn ra. Terraform gọi API lên hệ thống Provider và phát hiện tài nguyên đó đã không còn tồn tại.
2. Terraform cập nhật trạng thái trong bộ nhớ là tài nguyên đó đã bị xóa (không còn tồn tại thực tế).
3. Terraform thực hiện so sánh với file cấu hình `.hcl` (nơi vẫn khai báo muốn có tài nguyên này).
4. Kết quả plan/apply sẽ là **Tạo mới lại** (Create) tài nguyên đó để đưa hạ tầng thực tế về đúng trạng thái khai báo trong code.
</details>

---

### Q3: Tại sao khi sử dụng Remote Backend là AWS S3, chúng ta lại phải cấu hình thêm một bảng Amazon DynamoDB?
<details>
<summary>💡 Xem câu trả lời</summary>

Bản thân dịch vụ Amazon S3 là một dịch vụ lưu trữ đối tượng (Object Storage), nó **không** hỗ trợ cơ chế khóa ghi (writing lock) nguyên khối. Nếu 2 kỹ sư cùng `apply` một lúc, S3 sẽ chấp nhận cả hai và ghi đè đè lên nhau gây hư hỏng file state. Do đó, Terraform cần sử dụng dịch vụ **DynamoDB** (cơ sở dữ liệu NoSQL tốc độ cao) làm công cụ quản lý khóa (State Locking). Khi một người chạy lệnh, Terraform sẽ ghi một khóa tạm thời vào DynamoDB; lệnh chạy xong sẽ xóa khóa đó đi.
</details>

---

### Q4: Điều gì xảy ra nếu bạn vô tình commit file `terraform.tfstate` chứa mật khẩu Database (kiểu plaintext) lên một kho lưu trữ Git công khai (Public Repo)? Bạn cần làm gì ngay lập tức?
<details>
<summary>💡 Xem câu trả lời</summary>

Mật khẩu của bạn đã bị lộ hoàn toàn vì file state lưu plaintext và Git lưu lại toàn bộ lịch sử commit.
**Các bước cần xử lý khẩn cấp:**
1. **Thu hồi và đổi mới (Rotate)** lập tức tất cả thông tin nhạy cảm đó (đổi mật khẩu database, thu hồi Access Keys/Token API cũ, tạo key mới).
2. Xóa triệt để file state khỏi lịch sử Git bằng công cụ chuyên dụng (như `git-filter-repo` hoặc BFG Repo-Cleaner) để tránh kẻ xấu lục lại lịch sử commit cũ.
3. Chuyển cấu hình lưu trữ file state sang **Remote Backend** bảo mật và thêm `.tfstate` vào file `.gitignore` ngay lập tức.
</details>

---

### Q5: "Drift" trong Terraform là gì? Nêu sự khác nhau giữa lệnh `terraform plan` và `terraform refresh` khi đối phó với Drift.
<details>
<summary>💡 Xem câu trả lời</summary>

* **Drift (Lệch cấu hình):** Là sự sai khác giữa cấu hình hạ tầng khai báo trong code và trạng thái hạ tầng đang chạy thực tế.
* **`terraform refresh`:** Chỉ thực hiện việc truy vấn thực tế hạ tầng để cập nhật lại file state cho chính xác với thực tế. Nó **không** làm thay đổi hạ tầng thực tế và cũng **không** thay đổi file code `.hcl`.
* **`terraform plan`:** Sẽ thực hiện cả bước refresh ngầm, sau đó đưa ra **phương án hành động** (diff) để làm thế nào đưa hạ tầng thực tế về giống hệt với code `.hcl` (sẽ tạo lại, sửa đổi hoặc xóa tài nguyên bị drift).
</details>

---