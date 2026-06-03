# 🛠️ Day A - Khám phá Sức mạnh của Terraform (Infrastructure as Code)

Chào mừng bạn đến với ngày học đầu tiên của Tuần 8 thuộc **Phase 2 — AWS Accelerator Internship Program**. Hôm nay, chúng ta sẽ tập trung toàn bộ thời gian để làm quen, nghiên cứu và làm chủ công cụ quản trị hạ tầng dưới dạng mã **Terraform (IaC)** hàng đầu thế giới từ cơ bản đến nâng cao.

---

## 🎯 Mục tiêu Ngày học
*   Nắm vững khái niệm **Infrastructure as Code (IaC)** và lợi ích vượt trội của nó trong DevOps doanh nghiệp.
*   Hiểu rõ kiến trúc core của **Terraform**, vai trò của **Providers**, **Data Sources**, **Resources**, **Backend**, **State**, **Variables & Outputs**.
*   Vận hành trơn tru chu trình làm việc tiêu chuẩn **Write -> Plan -> Apply -> Destroy** của Terraform.
*   Triển khai thực tế các hệ thống từ cơ bản đến nâng cao hoàn toàn cục bộ trên Docker Desktop.
*   Áp dụng và thấm nhuần **7 Quy tắc viết mã chuẩn chỉnh (Coding Standards & Best Practices)** của HashiCorp.

---

## 📂 Bản đồ Học tập & Tài liệu Hướng dẫn (Study Guide Index)

Dưới đây là sơ đồ danh mục các tài liệu và bài lab được thiết kế bài bản để dẫn dắt bạn đi từ lý thuyết đến thực chiến. Hãy học theo đúng lộ trình này:

| Thứ tự | Chủ đề / Tài liệu | File tài liệu | Nội dung tóm tắt |
| :---: | :--- | :--- | :--- |
| **0** | **Thông báo Phase 2** | [W8_phase2_announcement_cloud.md](./W8_phase2_announcement_cloud.md) | Lịch trình học tập chi tiết của Tuần 8, các tài liệu tham khảo và cách phân bổ thời gian. |
| **1** | **Khái niệm & Định nghĩa** | [define.md](./define.md) | Định nghĩa IaC, Terraform core, Providers, Modules, Resources, Backend, State và cách thức hoạt động. |
| **2** | **Quy trình & Lệnh cơ bản** | [development.md](./development.md) | Chi tiết về quy trình 4 bước tiêu chuẩn (`init`, `validate`, `plan`, `apply`, `destroy`) và các tùy chọn CLI phổ biến. |
| **3** | **Tiêu chuẩn viết mã (Best Practices)** | [writing-rules.md](./writing-rules.md) | Quy tắc đặt tên `snake_case`, cấu trúc thư mục tiêu chuẩn, bảo mật Secrets (`sensitive`), và tối ưu `lifecycle` blocks. |
| **4** | **Các đối số Meta-arguments** | [Meta-Arguments.md](./Meta-Arguments.md) | Hướng dẫn chi tiết về 5 đối số đặc biệt của HCL: `depends_on`, `count`, `for_each`, `provider`, và `lifecycle`. |
| **5** | **Bài thực hành Cơ bản (Basic Lab)** | [LAB_BASIC-learn-terraform-get-started-docker.md](./LAB_BASIC-learn-terraform-get-started-docker.md) | **[100% Cục bộ]** Tự động tạo file HTML cá nhân hóa, tải Nginx image, chạy container Nginx và mount website lên local. |
| **6** | **Bài thực hành Nâng cao (Advanced Lab)** | [LAB-ADVANCED-learn-terraform-get-started-docker-advanced.md](./LAB-ADVANCED-learn-terraform-get-started-docker-advanced.md) | Thiết lập hệ thống Multi-Tier AI Chatbot tích hợp Groq Llama3 + PostgreSQL DB + Adminer Web UI đạt chuẩn DevOps thực tế. |

---

## ⚙️ Yêu cầu Chuẩn bị Môi trường (Prerequisites)

Để thực hành trơn tru 2 bài lab (Basic & Advanced), máy tính cá nhân của bạn cần được cài đặt sẵn:
1.  **Docker Desktop** (Đang hoạt động): Dùng để chạy ảo hóa container Nginx, PostgreSQL, Flask App AI Chatbot và Adminer.
    *   [Tải Docker Desktop tại đây](https://www.docker.com/products/docker-desktop/).
2.  **Terraform CLI** (Khuyến nghị phiên bản `>= 1.2.0`): Bộ giải mã code IaC của HashiCorp.
    *   [Tải Terraform tại đây](https://developer.hashicorp.com/terraform/install).

---

## 🛡️ Khuyến nghị Học tập Hiệu quả

> [!IMPORTANT]
> **Quy tắc Vàng cho Kỹ sư DevOps:**
> *   **Tuyệt đối không hardcode thông tin nhạy cảm:** Không bao giờ lưu trực tiếp API Keys, Passwords vào file `.tf` hay commit file `.tfvars` lên GitHub. Luôn bật `sensitive = true` cho các biến nhạy cảm.
> *   **Format và Validate trước khi chạy:** Luôn tập thói quen chạy `terraform fmt` (tự động căn chỉnh code cực đẹp mắt) và `terraform validate` (kiểm tra lỗi cú pháp) trước khi chạy lệnh plan/apply.
> *   **Đọc kỹ Kế hoạch (Plan):** Hãy luôn kiểm tra kỹ lưỡng output của lệnh `terraform plan` để hiểu chính xác tài nguyên nào sẽ bị tạo mới, thay đổi hay bị xóa (`create`, `update`, `replace`, `destroy`) để tránh thảm họa vận hành.

Chúc toàn thể các bạn học viên có một ngày tự học và thực hành Terraform thật thú vị, gặt hái nhiều kiến thức chất lượng để sẵn sàng cho phần học Kubernetes (K8s) vào ngày mai!
