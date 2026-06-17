# Ngân Hàng Câu Hỏi Ôn Tập (Q&A) Week 10: Security, Secrets Management & Operations

Ngân hàng câu hỏi này bao gồm các câu hỏi chất lượng cao từ Mentor, **tập trung duy nhất vào kiến thức Tuần 10 (Day A, Day B, Day C)**. Cấu trúc chia làm 3 cấp độ: Dễ, Trung bình, Khó. **Mỗi cấp độ bao gồm 17 câu hỏi chi tiết (tổng cộng 51 câu hỏi).**

---

## PHẦN 1: CẤP ĐỘ DỄ (17 Câu Hỏi & Trả Lời)

### Q1: Kubernetes RBAC viết tắt của từ gì và nhằm mục đích gì?
*   **Trả lời:** RBAC viết tắt của "Role-Based Access Control" (Kiểm soát truy cập dựa trên vai trò). Nó được sử dụng để phân quyền cho phép AI (User, Group, ServiceAccount) có quyền thực hiện hành động nào (Verbs: get, list, create, delete...) trên tài nguyên nào (Resources: Pod, Deployment, Secret...) trong cluster.

### Q2: Sự khác biệt cơ bản giữa `Role` và `ClusterRole` là gì?
*   **Trả lời:** `Role` giới hạn quyền truy cập chỉ trong phạm vi một **Namespace** cụ thể. `ClusterRole` phân quyền trên toàn bộ **Cluster** (hoặc cho các tài nguyên không thuộc namespace như Node, PersistentVolume).

### Q3: Tác dụng của Admission Controller trong Kubernetes là gì?
*   **Trả lời:** Là chốt chặn kiểm tra các API requests gửi lên API Server sau khi đã qua bước xác thực (Authentication & Authorization) nhưng trước khi lưu vào `etcd`. Nó gồm `Mutating` (để sửa đổi/bổ sung cấu hình) và `Validating` (để phê duyệt hoặc từ chối cấu hình dựa trên chính sách bảo mật).

### Q4: OPA Gatekeeper sử dụng ngôn ngữ nào để viết các chính sách bảo mật?
*   **Trả lời:** OPA Gatekeeper sử dụng ngôn ngữ **Rego** (một ngôn ngữ khai báo - declarative query language) để viết logic kiểm tra dữ liệu JSON/YAML của tài nguyên.

### Q5: Tại sao Base64 trong Kubernetes Secret không được coi là một cơ chế mã hóa bảo mật?
*   **Trả lời:** Vì Base64 chỉ là cơ chế mã hóa định dạng dữ liệu (Encoding) để truyền tải ký tự an toàn, không sử dụng khóa bảo mật (encryption key). Bất kỳ ai đọc được chuỗi Base64 đều có thể giải mã ra dữ liệu gốc một cách dễ dàng mà không cần mật khẩu.

### Q6: AWS Secrets Manager giải quyết vấn đề gì tốt hơn so với Kubernetes Secrets thông thường?
*   **Trả lời:** AWS Secrets Manager lưu trữ secret tập trung bên ngoài cluster, mã hóa bằng AWS KMS, hỗ trợ phân quyền truy cập IAM chặt chẽ và cung cấp tính năng **tự động xoay vòng mật khẩu** (secrets rotation) mà K8s Secrets thông thường không có sẵn.

### Q7: External Secrets Operator (ESO) dùng để làm gì?
*   **Trả lời:** ESO là một Kubernetes Operator dùng để tự động đồng bộ hóa (sync) các secrets từ các nguồn lưu trữ bên ngoài (như AWS Secrets Manager) về thành Kubernetes native Secrets trong cluster.

### Q8: Thuộc tính `refreshInterval` trong tài nguyên `ExternalSecret` có ý nghĩa gì?
*   **Trả lời:** Xác định tần suất thời gian (ví dụ: `1h`, `5m`) mà ESO Controller sẽ kiểm tra và kéo dữ liệu mới nhất từ AWS Secrets Manager về cluster để đảm bảo K8s Secret luôn đồng bộ với AWS.

### Q9: Sealed Secrets hoạt động dựa trên cơ chế mã hóa nào?
*   **Trả lời:** Hoạt động dựa trên **mã hóa bất đối xứng** (asymmetric encryption). Sử dụng Public Key (ở máy local của dev) để mã hóa secret thành `SealedSecret` và sử dụng Private Key (được lưu an toàn trong cluster bởi Sealed Secrets Controller) để giải mã ngược lại.

### Q10: Mục tiêu chính của việc tích hợp Trivy vào CI Pipeline (GitHub Actions / GitLab CI) là gì?
*   **Trả lời:** Là để tự động quét và phát hiện các lỗ hổng bảo mật (CVEs) trong các thư viện hệ điều hành hoặc mã nguồn ứng dụng trước khi container image được build và push lên Registry, giúp ngăn chặn việc đưa code lỗi lên môi trường chạy.

### Q11: Cosign dùng để làm gì trong bảo mật chuỗi cung ứng phần mềm?
*   **Trả lời:** Cosign dùng để ký số (sign) và xác thực (verify) container image, giúp đảm bảo image deploy lên cluster đúng là image chính thống được build từ pipeline tin cậy của doanh nghiệp chứ không phải image giả mạo của hacker.

### Q12: SLSA Framework (slsa.dev) định nghĩa mấy cấp độ bảo mật (Levels) cho sản phẩm phần mềm?
*   **Trả lời:** Định nghĩa 3 cấp độ bảo mật chính (Level 1: Quy trình tự động hóa; Level 2: Nền tảng build tin cậy + ký số provenance; Level 3: Môi trường build cô lập tuyệt đối, chống can thiệp).

### Q13: `ResourceQuota` trong Kubernetes dùng để quản trị tài nguyên ở cấp độ nào?
*   **Trả lời:** Dùng để giới hạn tổng tài nguyên tối đa (như tổng CPU, Memory, số lượng Pods, dung lượng Storage) được phép sử dụng trong phạm vi của **cả một Namespace**.

### Q14: Khi một Container không khai báo cấu hình CPU/Memory request/limit, `LimitRange` sẽ xử lý thế nào?
*   **Trả lời:** `LimitRange` sẽ tự động chèn (inject) các giá trị CPU/Memory request và limit mặc định (được định nghĩa trong trường `default` và `defaultRequest` của LimitRange manifest) vào container đó.

### Q15: Kịch bản "Pod-kill Chaos" trong Chaos Engineering giả lập sự cố gì?
*   **Trả lời:** Giả lập sự cố một hoặc nhiều Pod ứng dụng đột ngột bị sập hoặc bị giết chết (tương đương pod bị crash hoặc bị trục xuất khỏi node), nhằm kiểm tra xem Kubernetes và ứng dụng có tự khôi phục nhanh chóng hay không.

### Q16: AWS Cost Anomaly Detection sử dụng công nghệ gì để phát hiện chi tiêu bất thường?
*   **Trả lời:** Sử dụng **Machine Learning** để phân tích lịch sử hóa đơn AWS và tự động nhận diện các điểm tăng trưởng chi phí bất thường ngoài mô hình chi tiêu thông thường.

### Q17: Bản biên bản sự cố "Postmortem" trong SRE nên được viết theo tinh thần gì?
*   **Trả lời:** Viết theo tinh thần **Blameless (Không đổ lỗi cá nhân)**, tập trung vào việc tìm lỗi của quy trình/hệ thống và đưa ra các hành động khắc phục lâu dài.

---

## PHẦN 2: CẤP ĐỘ TRUNG BÌNH (17 Câu Hỏi & Trả Lời)

### Q18: Tại sao việc cấp quyền tạo Pod (`create` pods) cho một nhà phát triển mà không áp đặt Policy Engine lại là một lỗ hổng bảo mật nghiêm trọng dẫn đến Privilege Escalation (Leo thang đặc quyền)?
*   **Trả lời:** Vì nếu chỉ dùng RBAC thông thường cho phép tạo Pod, nhà phát triển (hoặc kẻ tấn công chiếm tài khoản) có thể tạo một Pod có cấu hình đặc biệt: mount root directory `/` của Worker Node vào Pod (`hostPath`), hoặc chạy container với quyền `privileged: true`. Từ Pod này, họ có thể thoát ra và chiếm quyền điều khiển hoàn toàn máy chủ Host Node (root access).

### Q19: Hãy phân biệt sự khác biệt về vai trò và cách triển khai giữa `ConstraintTemplate` và `Constraint` trong OPA Gatekeeper.
*   **Trả lời:**
    *   `ConstraintTemplate` định nghĩa **logic kiểm tra chung** (viết bằng code Rego) và khai báo schema cho các tham số đầu vào. Nó hoạt động như một "hàm" hoặc "class".
    *   `Constraint` là **thể hiện cụ thể (instance)** của template đó. Nó truyền các tham số thực tế (ví dụ: danh sách các label bắt buộc) và chỉ định đối tượng áp dụng (ví dụ: áp dụng cho Pod trong namespace `production`).

### Q20: Tại sao ValidatingAdmissionPolicy (VAP) lại có hiệu năng vượt trội hơn so với OPA Gatekeeper hay Kyverno?
*   **Trả lời:** Vì VAP được tích hợp trực tiếp "in-process" bên trong Kubernetes API Server và sử dụng ngôn ngữ CEL để đánh giá. Nó không cần thực hiện các cuộc gọi mạng HTTPS request ra ngoài đến các Webhook Pods (như Gatekeeper/Kyverno), giúp loại bỏ hoàn toàn độ trễ mạng (network latency) và rủi ro sập Webhook Service.

### Q21: Làm thế nào để loại trừ các Namespace hệ thống (ví dụ: `kube-system`) khỏi sự kiểm soát của một Kyverno Policy để tránh làm treo cluster khi có sự cố?
*   **Trả lời:** Trong cấu hình Kyverno `ClusterPolicy` spec, dưới mỗi rule, ta có thể khai báo trường `exclude`. Tại đây, ta sử dụng bộ lọc `resources.namespaces` để liệt kê các namespace muốn bỏ qua (ví dụ: `kube-system`, `kyverno`), hoặc lọc theo labels của namespace.

### Q22: External Secrets Operator (ESO) sử dụng cơ chế nào để kết nối an toàn với AWS Secrets Manager mà không cần lưu trữ AWS Access Key/Secret Key trong Cluster?
*   **Trả lời:** Sử dụng cơ chế **IRSA (IAM Roles for Service Accounts)**. Chúng ta tạo một ServiceAccount trong K8s gắn annotation chỉ định IAM Role ARN của AWS. EKS OIDC Provider sẽ xác thực ServiceAccount này và cấp AWS temporary credentials cho ESO Pod truy cập trực tiếp AWS Secrets Manager.

### Q23: Sự khác biệt lớn nhất về mặt vận hành GitOps giữa ESO và Sealed Secrets là gì?
*   **Trả lời:**
    *   Với **Sealed Secrets**: File secret đã mã hóa được lưu trực tiếp trên Git repo. Khi đổi mật khẩu, dev phải chạy CLI `kubeseal` mã hóa lại thủ công và push lên Git.
    *   Với **ESO**: Git chỉ chứa file cấu hình trỏ tới AWS Secrets Manager. Khi cần xoay vòng/đổi mật khẩu, ta chỉ việc đổi trên AWS Secrets Manager, ESO sẽ tự động kéo giá trị mới về cluster theo chu kỳ `refreshInterval` mà không cần sửa code/file trên Git.

### Q24: Trong quy trình CI/CD bảo mật, tại sao ta nên bật cờ `--ignore-unfixed` khi chạy quét lỗ hổng bằng Trivy?
*   **Trả lời:** Vì trong thực tế, có nhiều CVE được phát hiện nhưng nhà phát triển OS/thư viện gốc vẫn chưa ra mắt bản vá (patch). Nếu không dùng `--ignore-unfixed`, Trivy sẽ đánh sập (fail) pipeline CI liên tục cho các lỗi mà nhà phát triển không thể sửa được, gây tắc nghẽn quy trình CI/CD vô ích.

### Q25: Khái niệm "Keyless Signing" của Cosign hoạt động dựa trên cơ chế xác thực nào?
*   **Trả lời:** Hoạt động dựa trên **OIDC (OpenID Connect)**. Cosign lấy OIDC ID token từ môi trường CI tin cậy (như GitHub Actions), gửi tới Fulcio CA để lấy một chứng chỉ số tạm thời có hiệu lực 10 phút để ký, và ghi lại hành động ký vào sổ cái Rekor Transparency Log công khai, không cần lưu trữ bất kỳ private key vật lý nào.

### Q26: Làm thế nào để Kyverno kiểm tra xem một image container chạy trong cluster đã được ký số bằng Cosign hay chưa?
*   **Trả lời:** Kyverno cung cấp luật `verifyImages`. Trong luật này, ta khai báo đường dẫn registry image cần kiểm tra và cung cấp file Public Key của Cosign (hoặc cấu hình OIDC issuer/subject cho keyless). Kyverno Admission Webhook sẽ tự động truy vấn Docker Registry để tìm signature tương ứng và dùng key đó để xác thực.

### Q27: Nếu `ResourceQuota` của Namespace đã bị cạn kiệt, Karpenter có kích hoạt tạo Node mới khi có Deployment scale up không? Tại sao?
*   **Trả lời:** **Không.** Vì khi ResourceQuota bị cạn kiệt, API Server sẽ chặn ngay yêu cầu tạo thêm Pod từ cổng vào và trả về lỗi `403 Forbidden`. Yêu cầu bị hủy bỏ nên không có Pod nào rơi vào trạng thái `Pending` do thiếu tài nguyên phần cứng. Karpenter không phát hiện được Pod pending nào nên sẽ không scale node.

### Q28: Cấu hình `LimitRange` có thể tự động sửa đổi (mutate) tài nguyên Pod như thế nào?
*   **Trả lời:** Khi một Pod gửi lên API Server không khai báo CPU/Memory limits, `LimitRange` sẽ tự động sửa đổi spec của Pod đó bằng cách chèn các giá trị mặc định được định nghĩa trong các trường `default` (limits) và `defaultRequest` (requests) trước khi lưu vào etcd.

### Q29: Chaos Mesh mô phỏng lỗi "Network Latency Chaos" ở cấp độ container bằng cách sử dụng công cụ/cơ chế nào của Linux?
*   **Trả lời:** Chaos mesh sử dụng cơ chế **traffic control (tc)** và công cụ **netem** của Linux kernel bên trong network namespace riêng biệt của container để thêm độ trễ (delay), jitter hoặc làm mất gói tin (packet loss) đi ra từ card mạng của container đó.

### Q30: Sự khác biệt về mục đích cảnh báo giữa AWS Budgets Alert thông thường và AWS Cost Anomaly Detection?
*   **Trả lời:**
    *   `AWS Budgets Alert` cảnh báo dựa trên **hạn mức cố định** (ví dụ: báo khi chi phí vượt quá 1000 USD).
    *   `AWS Cost Anomaly Detection` cảnh báo dựa trên **tốc độ và hành vi chi tiêu bất thường** được nhận diện bởi Machine Learning (ví dụ: ngày thường tiêu 5 USD, nay đột ngột tiêu 50 USD/ngày ➔ báo động ngay lập tức dù tổng chi tiêu tháng vẫn dưới budget).

### Q31: Triết lý vận hành của Karpenter tối ưu chi phí (FinOps) tốt hơn Cluster Autoscaler (CA) truyền thống ở điểm nào?
*   **Trả lời:** Karpenter hoạt động theo mô hình **Right-sizing** (không dùng Node Groups cố định). Nó trực tiếp phân tích yêu cầu tài nguyên của Pod đang pending để chọn mua đúng loại instance type rẻ nhất đáp ứng đủ nhu cầu. Ngoài ra, Karpenter có tính năng **Consolidation** tự động dồn dịch Pods và tắt các Node EC2 trống để tiết kiệm chi phí.

### Q32: Exit Code `137` của một Container trong Kubernetes có ý nghĩa gì? Bạn cần kiểm tra metrics nào trên Grafana để chẩn đoán lỗi này?
*   **Trả lời:** Exit Code `137` có nghĩa là Container bị ép dừng bởi tín hiệu `SIGKILL`, thường do hệ thống kích hoạt **OOMKilled** (vượt quá giới hạn bộ nhớ Memory Limit cấu hình). Trên Grafana, ta cần kiểm tra biểu đồ bộ nhớ sử dụng của Pod (`container_memory_working_set_bytes`) để xem RAM có tăng đột biến chạm giới hạn limits trước khi sập hay không.

### Q33: SRE Runbook giải quyết bài toán gì cho kỹ sư trực ca (On-call engineer) trong lúc xử lý sự cố khẩn cấp?
*   **Trả lời:** Runbook cung cấp quy trình thao tác chuẩn từng bước (step-by-step) đã được kiểm chứng để xử lý một lỗi cụ thể (ví dụ: sập DB, nghẽn mạng). Nó giúp kỹ sư trực ca nhanh chóng cứu hệ thống (mitigate) mà không bị bối rối hoặc thao tác nhầm lẫn do áp lực thời gian của sự cố.

### Q34: Tại sao trong một biên bản sự cố Postmortem, chúng ta không được phép ghi tên cụ thể của lập trình viên làm lỗi?
*   **Trả lời:** Vì Postmortem tuân theo triết lý **Blameless (Không đổ lỗi)**. Đổ lỗi cho cá nhân làm giảm sự tin cậy trong đội ngũ, khiến nhân viên có xu hướng che giấu lỗi. Mục tiêu của Postmortem là tìm ra lỗ hổng của quy trình kiểm thử hoặc hệ thống đã cho phép lỗi đó xảy ra, từ đó thiết kế các rào chắn tự động để lỗi đó không thể lặp lại bởi bất kỳ ai.

---

## PHẦN 3: CẤP ĐỘ KHÓ (17 Câu Hỏi & Trả Lời)

### Q35: Hãy mô tả chi tiết quy trình bắt tay và cấp phát chứng chỉ tạm thời (ephemeral certificate) trong luồng Keyless Signing của Cosign. Vai trò của Fulcio CA và Rekor Ledger ở đây là gì?
*   **Trả lời:** Quy trình diễn ra cực kỳ bảo mật thông qua OIDC:
    1.  **OIDC Token:** CI Runner (ví dụ GitHub Actions) yêu cầu nhà cung cấp OIDC (GitHub) cấp một JWT token chứng minh định danh của runner đó.
    2.  **Fulcio CA:** Cosign sinh ngẫu nhiên một cặp khóa công khai/riêng tư tạm thời trong bộ nhớ của Runner (không ghi ra đĩa). Nó gửi OIDC token cùng public key tạm thời này lên Fulcio CA.
    3.  **Chứng chỉ tạm thời:** Fulcio CA xác thực OIDC token hợp lệ, sau đó cấp một chứng chỉ số X.509 tạm thời có thời hạn chỉ **10 phút** trỏ tới định danh của runner và chứa public key tạm thời đó.
    4.  **Rekor Ledger:** Cosign đẩy thông tin chứng chỉ tạm thời và chữ ký của image lên sổ cái minh bạch Rekor. Rekor lưu trữ vĩnh viễn và trả về bằng chứng thời gian (Signed Entry Timestamp - SET).
    5.  **Publish:** Chữ ký và chứng chỉ tạm thời được đẩy lên Docker Registry. Private key tạm thời lập tức bị xóa khỏi bộ nhớ của runner. Khi verify, hệ thống dùng Rekor SET để chứng minh chữ ký được tạo ra trong đúng khoảng thời gian 10 phút chứng chỉ còn hạn.

### Q36: Tình huống thực tế: Webhook Service của Kyverno bị sập hoàn toàn (do Node chứa nó bị quá tải CPU). Lúc này, nếu CI/CD pipeline cố gắng deploy một bản vá khẩn cấp cho ứng dụng Production, chuyện gì sẽ xảy ra? Thiết kế kiến trúc thế nào để giảm thiểu rủi ro này?
*   **Trả lời:**
    *   **Hiện tượng:** Nếu cấu hình Kyverno Webhook `failurePolicy` là `Fail` (Fail-Closed), API Server sẽ từ chối tất cả các yêu cầu tạo/cập nhật Pod, làm đóng băng toàn bộ hệ thống deploy. Nếu là `Ignore` (Fail-Open), API Server cho phép deploy qua mà không quét bảo mật.
    *   **Thiết kế giảm thiểu rủi ro (Production-ready):**
        1.  **Chạy HA:** Chạy Kyverno webhook tối thiểu 3 replicas, phân bổ trên các worker node khác nhau qua `podAntiAffinity`.
        2.  **Bypass System Namespaces:** Loại trừ namespace `kube-system` và `kyverno` khỏi phạm vi webhook quét để các pod hệ thống tự khôi phục được.
        3.  **Tách biệt Node Group:** Đưa Kyverno Pods chạy trên System Node Group riêng biệt để tránh bị ảnh hưởng bởi quá tải CPU từ các ứng dụng của người dùng.
        4.  **Dùng VAP:** Chuyển các luật kiểm tra cấu hình cơ bản sang sử dụng **ValidatingAdmissionPolicy** vì VAP chạy in-process trực tiếp trong API Server, không sợ sập webhook.

### Q37: Phân tích cơ chế giới hạn "Execution Budget" của ngôn ngữ CEL trong ValidatingAdmissionPolicy. Làm thế nào để API Server tự bảo vệ mình trước các biểu thức CEL quá phức tạp?
*   **Trả lời:**
    *   Ngôn ngữ CEL được thiết kế phi Turing-hoàn chỉnh, không có đệ quy hoặc vòng lặp vô hạn.
    *   Kubernetes API Server gán cho mỗi API request một **ngân sách chi phí thực thi (Execution Cost Budget)** nhất định (ví dụ: 10,000 units).
    *   Khi biên dịch VAP, API Server tính toán trước chi phí tĩnh (Static Cost) của biểu thức CEL.
    *   Khi chạy thực tế, nếu biểu thức duyệt qua mảng dữ liệu quá lớn (ví dụ: lọc hàng trăm container env vars) và vượt quá hạn mức ngân sách units cho phép, API Server sẽ dừng thực thi biểu thức ngay lập tức, trả về lỗi từ chối request để bảo vệ CPU của Control Plane khỏi bị treo.

### Q38: Khi cấu hình Secrets Rotation tự động trên AWS Secrets Manager kết hợp với ESO, làm thế nào để đảm bảo quá trình xoay vòng mật khẩu database không gây lỗi xác thực (Authentication/Connection Error) cho các Pod ứng dụng đang chạy?
*   **Trả lời:** Thiết kế xoay vòng không downtime:
    1.  **Mật khẩu kép (Double-password window):** Cấu hình Database engine chấp nhận đồng thời cả mật khẩu cũ và mật khẩu mới trong thời gian xoay vòng (AWS Secrets Manager RDS rotation hỗ trợ việc này qua Lambda).
    2.  **Rolling Restart:** Khi ESO phát hiện mật khẩu mới trên AWS Secrets Manager, nó sẽ cập nhật K8s Secret. Chúng ta sử dụng công cụ như **Reloader** để tự động restart cuốn chiếu (Rolling Update) các Pod ứng dụng.
    3.  Các Pod mới dựng lên sẽ dùng mật khẩu mới kết nối vào DB, các Pod cũ vẫn duy trì kết nối bằng mật khẩu cũ. Khi toàn bộ Pod mới đã hoạt động ổn định, AWS Secrets Manager mới chính thức thu hồi mật khẩu cũ.

### Q40: Tại sao khi sử dụng Karpenter kết hợp với `ResourceQuota` trong môi trường Kubernetes Enterprise, chúng ta có thể gặp tình trạng "Autoscaling Deadlock" (Khóa chết tự động co giãn)? Cách khắc phục?
*   **Trả lời:**
    *   **Nguyên nhân Deadlock:** Khi một Namespace đạt giới hạn tối đa của `ResourceQuota` (ví dụ: đạt 20 Core CPU). Lập trình viên cố gắng scale thêm Pod (cần thêm 4 CPU). API Server đối chiếu quota thấy vượt quá ➔ Từ chối tạo Pod và trả về lỗi `403 Forbidden`. Vì request bị từ chối lập tức, không có Pod nào được sinh ra ở trạng thái `Pending` do thiếu tài nguyên phần cứng. Karpenter chỉ trigger tạo Node EC2 mới khi có Pod `Pending`. Do đó, Karpenter không bao giờ scale thêm Node, hệ thống bị nghẽn (deadlock) dù hạ tầng đám mây vẫn còn dư thừa tài nguyên vật lý.
    *   **Khắc phục:** Phải cấu hình hệ thống giám sát cảnh báo (Prometheus Alerts) khi `ResourceQuota` đạt 80% công suất để SRE chủ động nâng quota, hoặc xây dựng các Controller tự động điều chỉnh quota dựa trên nhu cầu sử dụng thực tế.

### Q41: Hãy giải thích cách sử dụng tính năng `verifyImages` của Kyverno kết hợp với Rekor Transparency Log để xác thực chữ ký ảnh Keyless của Cosign ở cổng Admission Control.
*   **Trả lời:**
    Trong cấu hình `verifyImages` của Kyverno, chúng ta khai báo trường `authority` trỏ tới cấu hình keyless:
    1.  Cấu hình trường `keyless.url` trỏ tới Rekor URL công khai (hoặc nội bộ).
    2.  Cấu hình `keyless.identities` chỉ định rõ `issuer` (ví dụ: `https://token.actions.githubusercontent.com`) và `subject` (đường dẫn workflow Git chạy build chính thức của công ty).
    3.  Khi Pod deploy, Kyverno chặn lại, gọi lên Registry lấy chứng chỉ số tạm thời của image, đối chiếu với Rekor để lấy bằng chứng cryptographic chứng minh chữ ký được ghi nhận hợp lệ trên sổ cái, và so khớp định danh của người ký (issuer/subject) xem có đúng pipeline của công ty hay không. Nếu trùng khớp, nó mới cho phép chạy Pod.

### Q51: Hãy viết một biểu thức CEL trong ValidatingAdmissionPolicy để bắt buộc các Pod trong namespace `production` chỉ được phép sử dụng images lấy từ registry nội bộ có tên là `my-registry.io/company/`, đồng thời cấm sử dụng tag `latest`.
*   **Trả lời:**
    Trong VAP manifest, ta định nghĩa phần `validations` như sau:
    ```yaml
    spec:
      validations:
        - expression: >-
            object.spec.containers.all(c, 
              c.image.startsWith('my-registry.io/company/') && 
              !c.image.endsWith(':latest') && 
              c.image.contains(':')
            )
          message: "All container images must come from 'my-registry.io/company/' and must not use the 'latest' tag."
    ```
    *(Biểu thức này duyệt qua tất cả các container, kiểm tra chuỗi dẫn đường dẫn image bắt đầu bằng registry tin cậy, không kết thúc bằng `:latest`, và bắt buộc phải khai báo tag cụ thể thông qua việc kiểm tra ký tự `:`).*
