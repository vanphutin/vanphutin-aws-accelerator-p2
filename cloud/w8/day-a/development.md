# Quy trình & Các Lệnh Terraform Căn bản (Terraform Standard Workflow & Commands)

## 1. Chuẩn hóa Quy trình Triển khai

*   **Sử dụng cấu hình Terraform để tự động hóa:** Việc tạo và cấu hình tài nguyên của bạn thông qua mã giúp đảm bảo các cấu hình được lặp lại và nhất quán.
*   **Sử dụng các biến (Variables) để tùy chỉnh:** Dễ dàng tùy chỉnh cấu hình cho các môi trường khác nhau (như development, staging, production) mà không cần phải duy trì các file cấu hình hoàn toàn riêng biệt.

Để triển khai cơ sở hạ tầng với Terraform, bạn thực hiện theo quy trình 4 bước tiêu chuẩn:

1.  **Khởi tạo (`terraform init`):** Khởi tạo thư mục dự án của bạn với Terraform bằng cách chạy lệnh `terraform init`. Lệnh này tải xuống các plugin cần thiết cho provider được xác định trong cấu hình.
2.  **Áp dụng (`terraform apply`):** Tạo ra các tài nguyên được xác định trong cấu hình bằng cách chạy lệnh `terraform apply`. Terraform hiển thị kế hoạch thay đổi (execution plan) và yêu cầu bạn xác nhận trước khi thực hiện.
3.  **Xem đầu ra (`terraform output`):** Sau khi các tài nguyên đã được tạo thành công, bạn có thể xem các thông tin đầu ra bằng lệnh `terraform output`.
4.  **Hủy bỏ (`terraform destroy`):** Khi muốn loại bỏ và dọn dẹp các tài nguyên được quản lý bởi Terraform, hãy chạy lệnh `terraform destroy`.

### Bật tính năng tự động hoàn thành tab (Tab Completion)
Nếu bạn sử dụng Bash hoặc Zsh làm trình thông dịch dòng lệnh, bạn có thể bật tính năng tự động hoàn thành các lệnh Terraform. Để bật tính năng này, trước tiên hãy đảm bảo rằng một Tệp cấu hình đã tồn tại cho trình shell bạn đã chọn, sau đó chạy lệnh cài đặt thích hợp cho shell của bạn.

---

## 2. Chi tiết Lệnh: `terraform init`

Lệnh `terraform init` được sử dụng để khởi tạo thư mục làm việc Terraform. Nó xử lý mọi bước thiết lập cần thiết để sử dụng Terraform trong thư mục hiện tại.

### Mục đích của `terraform init`
*   Khởi tạo directory của bạn như một thư mục làm việc Terraform.
*   Tải xuống và cài đặt các plugin cần thiết để tương tác với các nhà cung cấp tài nguyên (Providers).
*   Thiết lập Backend để lưu trữ trạng thái (state).
*   Kích hoạt các tính năng nâng cao khác của Terraform (như module registry).

> [!NOTE]
> `terraform init` không tạo hay thay đổi bất kỳ tài nguyên thực tế nào trong cơ sở hạ tầng của bạn. Mục đích duy nhất của nó là chuẩn bị môi trường làm việc.

### Các hành động được thực thi
*   Tìm và tải xuống các plugin nhà cung cấp (provider plugins).
*   Thiết lập backend (mặc định là local backend hoặc backend đã cấu hình).
*   Tải xuống các module Terraform đã khai báo (nếu có).
*   Khởi tạo cấu hình cho các tính năng khác như remote state và hook scripts.

### Cú pháp & Tùy chọn phổ biến
```bash
terraform init [options]
```

*   **`-input=false`:** Vô hiệu hóa các lời nhắc nhập liệu tương tác.
*   **`-upgrade`:** Nâng cấp các plugin và module xuống phiên bản mới nhất tương thích.
*   **`-backend=false`:** Vô hiệu hóa thiết lập backend (chỉ sử dụng local backend).
*   **`-get=false`:** Vô hiệu hóa tải xuống module.
*   **`-lock=false`:** Bỏ qua khóa state nếu đã có khóa trước đó.
*   **`-lock-timeout=0s`:** Thời gian chờ khóa state.
*   **`-var 'key=value'`:** Thiết lập trực tiếp giá trị biến.
*   **`-var-file=filename`:** Load giá trị biến từ file.
*   **`-chdir=path`:** Thay đổi directory làm việc trước khi chạy lệnh.
*   **`-plugin-dir=path`:** Chỉ định thư mục chứa plugin cục bộ thay vì tải từ internet.
*   **`-reconfigure`:** Buộc Terraform phải định cấu hình lại backend từ đầu.
*   **`-migrate-state`:** Tự động di chuyển state sang backend mới khi cấu hình lại.
*   **`-no-color`:** Tắt màu trong output hiển thị.
*   **`-json`:** Output thông tin dưới dạng JSON.

### Các file cấu hình hợp lệ
Terraform init sẽ tìm kiếm các file cấu hình trong directory hiện tại:
*   Các file kết thúc bằng `.tf`
*   Các file kết thúc bằng `.tf.json`
*   Các file trong thư mục `modules/` được đặt tên đúng quy tắc.

Cấu hình Terraform có thể bao gồm: các block `provider`, `resource`, `data`, `variable`, `output` và `module`.

### Ví dụ Nâng cao
*   **Sử dụng biến và file biến:**
    ```bash
    terraform init -var "region=us-east-1" -var-file="terraform.tfvars"
    ```
*   **Buộc định cấu hình lại backend:**
    ```bash
    terraform init -reconfigure
    ```
*   **Di chuyển state sang backend mới:**
    ```bash
    terraform init -migrate-state
    ```
*   **Vô hiệu hóa lời nhắc tương tác:**
    ```bash
    terraform init -input=false
    ```
*   **Chỉ định thư mục plugin cục bộ:**
    ```bash
    terraform init -plugin-dir="/path/to/plugins"
    ```
    *Mặc định, Terraform sẽ tìm kiếm plugins trong thư mục ẩn `.terraform`. Bạn có thể dùng tùy chọn này để trỏ tới thư mục khác offline.*

---

## 3. Chi tiết Lệnh: `terraform validate`

Lệnh `terraform validate` được sử dụng để xác thực cấu hình Terraform của bạn. Nó kiểm tra tính hợp lệ về mặt cú pháp và ngữ nghĩa của tất cả các file cấu hình trong thư mục hiện tại.

### Mục đích của `terraform validate`
*   Xác thực cú pháp ngôn ngữ HCL.
*   Kiểm tra tính đúng đắn của các tham chiếu biến, thuộc tính tài nguyên và module.
*   Phát hiện cấu hình không hợp lệ trước khi triển khai thực tế.

> [!NOTE]
> Lệnh này không truy cập bất kỳ API nào của nhà cung cấp tài nguyên (AWS, Docker...), không ảnh hưởng đến bất kỳ tài nguyên thực tế nào, không thay đổi tài nguyên và không ghi vào file state.

### Khi nào nên sử dụng?
*   Ngay sau khi sửa đổi bất kỳ tệp cấu hình `.tf` nào.
*   Tích hợp trong hệ thống CI/CD để xác thực tự động trước khi triển khai (merge code).
*   Trước khi chạy lệnh `terraform plan`.
*   Khi thay đổi/nâng cấp cấu hình các biến hoặc module.
*   Để kiểm tra cấu hình ở chế độ ngoại tuyến (local offline mode).

### Cú pháp & Tùy chọn phổ biến
```bash
terraform validate [options]
```

*   **`-json`:** Output kết quả xác thực dưới dạng cấu trúc JSON (rất hữu ích cho tích hợp CI/CD parse lỗi).
*   **`-no-color`:** Tắt màu sắc trong output.
*   **`-var 'key=value'`:** Thiết lập giá trị biến để phục vụ việc xác thực.
*   **`-var-file=filename`:** Tải giá trị biến từ file để xác thực.
*   **`-chdir=path`:** Thay đổi directory làm việc trước khi chạy lệnh.

### Ví dụ Thực tế
*   **Xác thực cơ bản:**
    ```bash
    terraform validate
    ```
*   **Xác thực kèm biến tùy chỉnh:**
    ```bash
    terraform validate -var "region=us-east-1" -var-file="terraform.tfvars"
    ```
*   **Output dạng JSON phục vụ CI/CD:**
    ```bash
    terraform validate -json
    ```

---

## 4. Chi tiết Lệnh: `terraform plan`

Lệnh `terraform plan` tạo ra một kế hoạch thi hành (Execution Plan), giúp hiển thị chi tiết tất cả thay đổi sẽ được thực hiện để đưa hạ tầng thực tế về trạng thái khai báo trong code.

### Mục đích của `terraform plan`
*   Xem trước các thay đổi dự kiến trước khi áp dụng thực tế (giảm thiểu rủi ro).
*   Xác định rõ ràng tài nguyên nào sẽ được tạo mới, cập nhật hay xóa bỏ.
*   Kiểm tra tính tương thích giữa cấu hình mong muốn và trạng thái hiện tại.
*   Hỗ trợ đánh giá, phê duyệt thay đổi (code review) trong quy trình CI/CD.

### Khi nào nên sử dụng?
*   Trước mỗi lần chạy `terraform apply`.
*   Trong hệ thống CI/CD để tự động tạo kế hoạch phê duyệt.
*   Sau khi chỉnh sửa code cấu hình để kiểm tra tác động.
*   Khi cần xác định xem có xung đột (conflicts) hay thay đổi không mong muốn nào trên Cloud/Local hay không.

### Cú pháp & Tùy chọn phổ biến
```bash
terraform plan [options]
```

*   **`-out=filename`:** Lưu kế hoạch thi hành thành một tệp nhị phân để sử dụng chính xác cho lệnh `terraform apply` sau này.
*   **`-var 'key=value'` / `-var-file=filename`:** Cung cấp giá trị biến đầu vào.
*   **`-destroy`:** Tạo kế hoạch thi hành để hủy toàn bộ tài nguyên.
*   **`-refresh-only`:** Chỉ cập nhật trạng thái của file State khớp với thực tế mà không đề xuất bất kỳ thay đổi nào lên tài nguyên.
*   **`-target=resource`:** Chỉ tập trung lập kế hoạch cho một tài nguyên cụ thể (hạn chế dùng trong production).
*   **`-input=false`:** Không hỏi các biến chưa được gán giá trị mà báo lỗi trực tiếp.
*   **`-detailed-exitcode`:** Trả về các exit code chi tiết (0: không đổi, 2: có thay đổi, 1: có lỗi) rất hữu ích cho CI/CD pipeline script.
*   **`-parallelism=n`:** Số lượng worker chạy song song (mặc định là 10).

### Ký hiệu Trạng thái trong Output
*   `+` **(create):** Tài nguyên mới sẽ được tạo.
*   `~` **(update in-place):** Tài nguyên hiện tại sẽ được cập nhật thuộc tính tại chỗ.
*   `-/+` **(replace):** Tài nguyên cũ sẽ bị xóa hoàn toàn và tạo lại mới (do thay đổi các tham số không thể cập nhật trực tiếp).
*   `-` **(destroy):** Tài nguyên sẽ bị xóa bỏ hoàn toàn.

### Ví dụ Thực tế
*   **Chạy kế hoạch cơ bản:**
    ```bash
    terraform plan
    ```
*   **Lưu kế hoạch ra file:**
    ```bash
    terraform plan -out=tfplan.binary
    ```
*   **Chạy kế hoạch hủy toàn bộ:**
    ```bash
    terraform plan -destroy
    ```
*   **Chỉ xem thay đổi của một tài nguyên:**
    ```bash
    terraform plan -target=aws_instance.example
    ```

---

## 5. Chi tiết Lệnh: `terraform apply`

Lệnh `terraform apply` thực hiện các thay đổi được mô tả trong kế hoạch thi hành, làm cho trạng thái thực tế của cơ sở hạ tầng khớp hoàn toàn với cấu hình đã khai báo.

### Mục đích của `terraform apply`
*   Áp dụng kế hoạch thi hành đã tạo.
*   Thực hiện các thay đổi thực tế đối với cơ sở hạ tầng (tạo, cập nhật, xóa tài nguyên).
*   Tự động ghi nhận thông tin tài nguyên mới vào file trạng thái `terraform.tfstate` sau khi hoàn thành.

> [!WARNING]
> Nếu file state bị mất hoặc bị hỏng, `terraform apply` sẽ không thể đối chiếu dữ liệu hiện có và có thể cố gắng tạo lại tài nguyên từ đầu, gây lỗi trùng lặp hạ tầng nghiêm trọng.

### Cách thức hoạt động
1.  Đọc cấu hình từ các file `.tf`.
2.  Đọc file state hiện tại (`terraform.tfstate`).
3.  Tính toán kế hoạch thi hành (tương tự `terraform plan`).
4.  Hiển thị kế hoạch và yêu cầu xác nhận trực quan `yes/no` (trừ khi bật `-auto-approve`).
5.  Gọi API của Provider tương ứng để tạo/sửa/xóa tài nguyên thực tế.
6.  Cập nhật trạng thái mới nhất vào file state.

### Cú pháp & Tùy chọn phổ biến
```bash
terraform apply [options] [planfile]
```

*   **`planfile`:** Đường dẫn tới tệp kế hoạch nhị phân đã lưu trước đó bằng `terraform plan -out=...`. Nếu truyền vào, Terraform sẽ chạy ngay lập tức mà không cần hỏi xác nhận.
*   **`-auto-approve`:** Tự động phê duyệt và thực thi mà không yêu cầu người dùng nhập `yes` trên terminal (chỉ nên dùng trong CI/CD tự động).
*   **`-var 'key=value'` / `-var-file=filename`:** Khai báo biến.
*   **`-destroy`:** Triển khai kế hoạch hủy toàn bộ (tương tự lệnh `terraform destroy`).
*   **`-parallelism=n`:** Số lượng worker song song (mặc định: 10).
*   **`-target=resource`:** Chỉ áp dụng thay đổi cho một tài nguyên cụ thể.

### Ví dụ Thực tế
*   **Triển khai thông thường (có hỏi xác nhận):**
    ```bash
    terraform apply
    ```
*   **Triển khai tự động phê duyệt (CI/CD):**
    ```bash
    terraform apply -auto-approve
    ```
*   **Triển khai chính xác từ tệp kế hoạch đã lưu (Best Practice):**
    ```bash
    terraform apply "tfplan.binary"
    ```
*   **Chỉ cập nhật một tài nguyên đích:**
    ```bash
    terraform apply -target=docker_container.ai_app
    ```

---

## 6. Chi tiết Lệnh: `terraform destroy`

Lệnh `terraform destroy` được sử dụng để xóa sạch tất cả các tài nguyên do cấu hình Terraform hiện tại quản lý một cách an toàn và có trình tự.

### Mục đích của `terraform destroy`
*   Xóa toàn bộ hạ tầng đã tạo để đưa môi trường về trạng thái ban đầu.
*   Dọn dẹp môi trường thử nghiệm (development/testing) để tiết kiệm chi phí tài nguyên Cloud.
*   Cập nhật file state phản ánh trạng thái rỗng sau khi xóa.

> [!CAUTION]
> Lệnh `terraform destroy` sẽ xóa **TẤT CẢ** các tài nguyên được quản lý bởi thư mục cấu hình hiện tại. Hãy đảm bảo bạn đã sao lưu dữ liệu quan trọng trước khi thực thi! Lệnh này không thể hoàn tác sau khi đã chạy.

### Cơ chế Hoạt động
1.  Đọc cấu hình `.tf` và trạng thái hiện tại (`terraform.tfstate`).
2.  Tính toán biểu đồ phụ thuộc ngược (để biết tài nguyên nào cần xóa trước, tài nguyên nào xóa sau để tránh lỗi phụ thuộc).
3.  Hiển thị kế hoạch hủy và yêu cầu gõ `yes` để xác nhận.
4.  Gọi API Provider để tiến hành xóa tài nguyên thực tế.
5.  Ghi lại trạng thái rỗng vào file state.

### Cú pháp & Tùy chọn phổ biến
```bash
terraform destroy [options]
```

*   **`-auto-approve`:** Hủy toàn bộ tài nguyên lập tức không cần gõ `yes` xác nhận (Vô cùng nguy hiểm, cực kỳ hạn chế sử dụng!).
*   **`-target=resource`:** Chỉ xóa một tài nguyên cụ thể và các tài nguyên phụ thuộc vào nó.
*   **`-var 'key=value'` / `-var-file=filename`:** Gán biến đầu vào.

### Ví dụ Thực tế
*   **Hủy hạ tầng thông thường (an toàn):**
    ```bash
    terraform destroy
    ```
*   **Hủy tự động không cần hỏi:**
    ```bash
    terraform destroy -auto-approve
    ```
*   **Chỉ hủy một tài nguyên cụ thể:**
    ```bash
    terraform destroy -target=docker_container.adminer
    ```
