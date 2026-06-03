# Định nghĩa Terraform & Khái niệm Cơ bản (Terraform Core Concepts)

## 1. Giới thiệu về Infrastructure as Code (IaC) & Terraform

**Infrastructure as Code (IaC)** cho phép bạn quản lý cơ sở hạ tầng với các file cấu hình hơn là thông qua giao diện người dùng đồ họa. IaC cho phép bạn xây dựng, thay đổi và quản lý cơ sở hạ tầng của mình một cách an toàn, nhất quán và có thể lặp lại bằng cách xác định cấu hình tài nguyên mà bạn có thể phiên bản, sử dụng lại và chia sẻ.

**Terraform** là công cụ Infrastructure as Code (IaC) của HashiCorp. Nó cho phép bạn xác định tài nguyên và cơ sở hạ tầng trong các tệp cấu hình khai báo, có thể đọc được của con người và quản lý vòng đời cơ sở hạ tầng của bạn. Sử dụng Terraform có một số lợi thế so với việc quản lý thủ công cơ sở hạ tầng của bạn:

*   Terraform có thể quản lý cơ sở hạ tầng trên nhiều nền tảng đám mây.
*   Ngôn ngữ cấu hình mà con người có thể đọc được giúp bạn viết mã cơ sở hạ tầng nhanh chóng.
*   Trạng thái của Terraform cho phép bạn theo dõi các thay đổi tài nguyên trong suốt quá trình triển khai của mình.
*   Bạn có thể cam kết cấu hình của mình với kiểm soát phiên bản để cộng tác an toàn trên cơ sở hạ tầng.

---

## 2. Lợi ích của IaC và Terraform

Quản lý cơ sở hạ tầng như code cho phép bạn xây dựng, thay đổi và quản lý cơ sở hạ tầng của mình một cách an toàn, nhất quán và có thể lặp lại bằng cách xác định cấu hình tài nguyên mà bạn có thể phiên bản, sử dụng lại và chia sẻ.

*   **Tự động hóa (Automation):** Giảm thiểu thao tác thủ công, tăng tốc độ triển khai.
*   **Lặp lại (Repeatability):** Tạo ra các môi trường giống hệt nhau một cách dễ dàng.
*   **Đáng tin cậy (Reliability):** Tránh lỗi cấu hình do con người.
*   **Dễ cộng tác (Collaboration):** Làm việc nhóm hiệu quả hơn thông qua việc chia sẻ code.
*   **Có thể kiểm soát phiên bản (Version Control):** Theo dõi lịch sử thay đổi hạ tầng bằng Git.
*   **Linh hoạt (Flexibility):** Hỗ trợ đa đám mây (Multi-Cloud) và hybrid cloud.
*   **Hiệu quả về chi phí (Cost Efficiency):** Tối ưu tài nguyên và thời gian vận hành.

---

## 3. Khái niệm Cốt lõi của Terraform (Terraform Core Concepts)

Terraform Core bao gồm bộ xử lý trung tâm cho Terraform. Nó xác định các công cụ CLI và các thành phần cần thiết để các plugin hoạt động. Các plugin sau là một phần của Terraform core:

*   **Plugin nhà cung cấp (provider plugins)**
*   **Plugin resource**
*   **Plugin data source**
*   **Plugin provisioner**
*   **Plugin builder**

### Provider (Nhà cung cấp)
**Providers** là các plugin do HashiCorp duy trì và là các plugin do cộng đồng cung cấp (đã được kiểm tra và chấp thuận). Providers cho phép Terraform tương tác với tài nguyên của nhà cung cấp, chẳng hạn như AWS, Azure, Google Cloud, Kubernetes, DataDog, GitHub, v.v.

Khi bạn xác định tài nguyên hoặc cấu hình provider trong file `.tf`, Terraform sẽ tải xuống provider đó bằng trình quản lý plugin tích hợp sẵn. Khi bạn chạy các lệnh Terraform, Terraform sẽ giao tiếp với các nhà cung cấp để thực hiện các tác vụ cần thiết.

### Data Sources (Nguồn dữ liệu)
**Data sources** cho phép Terraform truy xuất dữ liệu từ các tài nguyên có sẵn. Không giống như tài nguyên (resources), data sources không tạo ra tài nguyên mới. Thay vào đó, chúng được sử dụng để lấy thông tin về các tài nguyên hiện có và sử dụng thông tin đó trong cấu hình Terraform của bạn. 

*Ví dụ:* Bạn có thể sử dụng data source để lấy ID của AMI hiện có, hoặc địa chỉ IP công cộng của một instance đang chạy.

### Module (Mô-đun)
**Modules** là các thành phần có thể tái sử dụng cho phép bạn tổ chức mã Terraform thành các đơn vị logic. Chúng hữu ích để đóng gói cấu hình tài nguyên thành các đơn vị có thể tái sử dụng và có thể chia sẻ. Bằng cách sử dụng modules, bạn có thể giảm sự trùng lặp mã, tăng khả năng bảo trì và dễ dàng quản lý cấu hình phức tạp.

### Resource (Tài nguyên)
**Resources** là các khối Terraform xây dựng và quản lý cơ sở hạ tầng của bạn. Tài nguyên đại diện cho các tài nguyên hoặc dịch vụ thực tế, chẳng hạn như EC2, S3 buckets, hoặc tài khoản người dùng. Mỗi tài nguyên được định nghĩa bằng một block resource, chứa thông tin về loại tài nguyên và các tham số liên quan.

### Backend
**Backend** là nơi Terraform lưu trữ trạng thái (state) của bạn. Khi bạn chạy lệnh Terraform, nó ghi lại thông tin về tài nguyên hiện tại mà Terraform đang quản lý vào file trạng thái. Khi bạn chạy lại Terraform, nó sẽ đọc trạng thái từ backend để xác định những thay đổi cần thực hiện. 

Hầu hết các dự án sử dụng remote backend để lưu trữ trạng thái, thay vì local backend. Các backend phổ biến bao gồm Terraform Cloud, Terraform Enterprise, Amazon S3, Azure Blob Storage và Google Cloud Storage.

### Variable và Output
*   **Variables (Biến đầu vào):** Là cách để bạn nhập giá trị vào cấu hình Terraform của mình từ bên ngoài. Chúng giúp bạn làm cho mã Terraform linh hoạt hơn bằng cách cho phép bạn tùy chỉnh cấu hình mà không cần sửa đổi file `.tf`.
*   **Outputs (Giá trị đầu ra):** Được sử dụng để xuất thông tin từ cấu hình Terraform của bạn, chẳng hạn như địa chỉ IP của một instance hoặc một URL. Điều này cho phép các cấu hình Terraform khác hoặc các hệ thống bên ngoài sử dụng thông tin này. Bạn có thể xác định các giá trị output trong cấu hình của mình bằng block `output` và truy xuất chúng bằng lệnh `terraform output`.

---

## 4. Terraform Hoạt động Như thế nào?

Terraform hoạt động dựa trên mô hình **Khai báo (Declarative)** và kiến trúc **Plugin-based** để quản lý hạ tầng dưới dạng mã (IaC). Thay vì viết các câu lệnh chỉ dẫn từng bước cách tạo tài nguyên (Imperative), bạn chỉ cần mô tả trạng thái cuối cùng mong muốn (Desired State) của hạ tầng trong các tệp cấu hình `.tf`, và Terraform sẽ tự động tính toán các bước để đạt được trạng thái đó.

Dưới đây là chi tiết về kiến trúc và quy trình hoạt động của Terraform:

### 1. Kiến trúc cốt lõi của Terraform

Hệ thống của Terraform gồm 2 thành phần chính hoạt động phối hợp:
*   **Terraform Core (Bộ xử lý trung tâm):** 
    *   Là một ứng dụng viết bằng ngôn ngữ Go, chạy dưới dạng dòng lệnh (CLI).
    *   Nhiệm vụ: Đọc các file cấu hình `.tf`, phân tích cú pháp, xây dựng **Biểu đồ phụ thuộc tài nguyên (Dependency Graph)** để biết tài nguyên nào cần tạo trước, tài nguyên nào cần tạo sau.
    *   Nó so sánh mã nguồn (Trạng thái mong muốn) với file trạng thái `terraform.tfstate` (Trạng thái hiện tại) để tính toán ra những hành động cần làm.
*   **Providers (Các Plugin nhà cung cấp):**
    *   Terraform Core không trực tiếp giao tiếp với các dịch vụ đám mây (như AWS, Azure, Docker...). Thay vào đó, nó giao tiếp với các **Providers** thông qua cơ chế gọi hàm từ xa (giao thức gRPC).
    *   Nhiệm vụ: Dịch các yêu cầu khai báo chuẩn từ Terraform Core thành các lệnh gọi API cụ thể của từng dịch vụ (ví dụ: dịch yêu cầu tạo máy ảo thành API `CreateInstance` của AWS hoặc `docker run` của Docker).

```text
+-----------------------+
|  Mã cấu hình (.tf)    |
+-----------+-----------+
            |
            v
+-----------+-----------+
|    Terraform Core     | <=====> [ File Trạng thái (terraform.tfstate) ]
+-----------+-----------+
            |
            | (gRPC Call)
            v
+-----------+-----------+
|    AWS/Docker Provider|
+-----------+-----------+
            |
            | (API Request)
            v
+-----------+-----------+
|  Hạ tầng thực tế      |
+-----------------------+
```

---

### 2. Quy trình làm việc tiêu chuẩn (Standard Workflow)

Quy trình làm việc của Terraform bao gồm 3 bước chính (thường gọi là **Write -> Plan -> Apply**):

#### 🚀 Bước 1: Khởi tạo (`terraform init`)
*   Khi bạn chạy lệnh này, Terraform sẽ phân tích mã nguồn để xem bạn khai báo những Provider nào (ví dụ: AWS, Docker, Local).
*   Nó tự động tải các plugin Provider tương ứng từ Terraform Registry về máy và lưu vào thư mục ẩn `.terraform/`.
*   Khởi tạo backend lưu trữ file state.

#### 📝 Bước 2: Lập kế hoạch (`terraform plan`)
*   Terraform Core đối chiếu mã cấu hình của bạn (Trạng thái mong muốn) với tệp tin `terraform.tfstate` (Trạng thái thực tế hiện tại).
*   Nó gửi các truy vấn (Read) thông qua Provider để xác thực xem hạ tầng thực tế có bị thay đổi thủ công gì hay không (cơ chế Drift Detection).
*   Nó đưa ra một **Kế hoạch hành động (Execution Plan)** hiển thị rõ ràng những gì sẽ thay đổi:
    *   `+ create`: Tạo mới tài nguyên.
    *   `~ update in-place`: Cập nhật tài nguyên hiện có.
    *   `-/+ replace`: Xóa tài nguyên cũ và tạo tài nguyên mới thay thế (do thay đổi các thuộc tính bắt buộc phải tạo lại).
    *   `- destroy`: Xóa bỏ tài nguyên.

#### ⚙️ Bước 3: Áp dụng triển khai (`terraform apply`)
*   Khi bạn đồng ý với kế hoạch và nhập `yes`, Terraform Core bắt đầu thực thi kế hoạch.
*   Nó gọi các lệnh API thông qua các Provider để tạo/sửa/xóa tài nguyên thực tế trên Cloud hoặc môi trường local.
*   **Cập nhật State:** Ngay sau khi mỗi tài nguyên được tạo hoặc thay đổi thành công, Terraform lập tức cập nhật thông tin chi tiết của nó (như ID, IP, ARN...) vào file `terraform.tfstate` để quản lý cho các lần chạy tiếp theo.

---

### 3. Tầm quan trọng tối thượng của File State (`terraform.tfstate`)

File State hoạt động như một **bản đồ ánh xạ** giữa mã nguồn khai báo của bạn và các tài nguyên thực tế ngoài môi trường.
*   Nếu không có file State, Terraform sẽ mất đi "ký ức". Nó sẽ không biết tài nguyên nào đã được tạo và sẽ cố gắng tạo lại từ đầu, gây ra lỗi trùng lặp hạ tầng.
*   Nó lưu trữ siêu dữ liệu (metadata) và lịch sử phụ thuộc giúp Terraform phá hủy tài nguyên theo đúng trình tự ngược lại một cách an toàn khi bạn chạy lệnh `terraform destroy`.

---

## 5. Tài liệu Ngôn ngữ Terraform (Terraform Language Documentation)

**Terraform Language Documentation** là tài liệu tham khảo chính thức của HashiCorp về ngôn ngữ HCL (HashiCorp Configuration Language) và các cú pháp được sử dụng trong Terraform. Nó cung cấp thông tin chi tiết về cấu trúc, cú pháp, các loại giá trị (types), biến (variables), hàm (functions), câu lệnh (statements) và các khối cấu hình (blocks) có thể sử dụng trong các tệp `.tf`. Đây là nguồn tài nguyên quan trọng để học và tra cứu cách viết, hiểu và duy trì mã Terraform hiệu quả.

Cấu trúc của Terraform Language Documentation thường bao gồm:

1.  **Cú pháp cơ bản:** Giải thích cách Terraform phân tích cú pháp mã, bao gồm các quy tắc về dấu ngoặc, khoảng trắng, ký tự comment, v.v.
2.  **Types (Các loại giá trị):** Mô tả các kiểu dữ liệu cơ bản như `string`, `number`, `bool`, `list`, `map`, `set`, cũng như `object` và `tuple`, và cách chúng hoạt động trong Terraform.
3.  **Expressions (Biểu thức):** Giải thích cách sử dụng các biểu thức để tính toán giá trị, bao gồm toán tử số học, toán tử so sánh, logic, interpolations `${...}`, và các biểu thức gọi hàm.
4.  **Functions (Hàm):** Liệt kê tất cả các hàm tích hợp sẵn trong Terraform (ví dụ: `concat`, `lookup`, `file`, `cidrsubnet`, v.v.) cùng với mô tả tham số và giá trị trả về.
5.  **Blocks (Khối):** Giải thích cấu trúc của các khối Terraform quan trọng như:
    *   `terraform`: Định nghĩa cấu hình Terraform core (providers, versions).
    *   `variable`: Khai báo và cấu hình biến đầu vào.
    *   `output`: Định nghĩa giá trị đầu ra của cấu hình.
    *   `resource`: Khai báo các tài nguyên sẽ quản lý.
    *   `data`: Khai báo các nguồn dữ liệu để truy xuất thông tin.
    *   `module`: Định nghĩa và sử dụng các module.
    *   `lifecycle`: Cấu hình các hành vi trong vòng đời của tài nguyên.
    *   `provisioner`: Cấu hình provisioners để thực thi hành động trong quá trình provisioning.
6.  **Provider-specific Attributes (Thuộc tính đặc thù của Provider):** Mô tả chi tiết các thuộc tính và tham số riêng của từng tài nguyên, thường được tổ chức theo Provider (ví dụ: AWS Provider, Docker Provider, v.v.).
7.  **Configuration Language Features:** Thông tin về các tính năng nâng cao như `dynamic` blocks, `for_each`, `count`, `splat` expressions, v.v.
8.  **Error Messages:** Hướng dẫn cách hiểu và xử lý các thông báo lỗi thường gặp trong quá trình chạy Terraform.

Tài liệu này giúp người dùng:
*   Viết mã Terraform chính xác và hiệu quả.
*   Sử dụng các tính năng của ngôn ngữ HCL một cách thành thạo.
*   Tìm hiểu chi tiết về các tài nguyên và data source của từng Provider.
*   Khắc phục sự cố và lỗi cấu hình.

> [!TIP]
> Để truy cập, bạn có thể tìm kiếm "Terraform Language Documentation" trên trang web chính thức của HashiCorp hoặc HashiCorp Terraform Registry.

---

## 6. Các đối số đặc biệt (Meta-arguments)

Ngoài các thuộc tính riêng của từng tài nguyên, Terraform cung cấp một số đối số đặc biệt gọi là **Meta-arguments** có thể được sử dụng trong mọi khối `resource` hoặc `module` để thay đổi hành vi triển khai:

*   **`depends_on`**: Khai báo phụ thuộc rõ ràng (Explicit Dependency) giữa các tài nguyên.
*   **`count`**: Tạo nhiều bản sao tài nguyên theo số lượng chỉ định (index-based).
*   **`for_each`**: Tạo nhiều bản sao tài nguyên dựa trên một `set` hoặc `map` (key-based).
*   **`provider`**: Lựa chọn cấu hình Provider không mặc định (thông qua `alias`).
*   **`lifecycle`**: Tùy chỉnh vòng đời của tài nguyên (ví dụ: `create_before_destroy`, `prevent_destroy`, `ignore_changes`).

> [!TIP]
> Để tìm hiểu chi tiết cách hoạt động, ví dụ thực tế và các lưu ý quan trọng của các đối số này, hãy tham khảo tài liệu hướng dẫn chuyên sâu: [Meta-Arguments.md](./Meta-Arguments.md).

