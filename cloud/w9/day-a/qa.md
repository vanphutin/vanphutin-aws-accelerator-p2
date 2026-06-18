# Bộ Câu Hỏi Vấn Đáp (Q&A) - Day A: GitOps và CI/CD

Tài liệu này tổng hợp bộ câu hỏi từ dễ đến khó phục vụ cho việc vấn đáp và đánh giá kiến thức của học viên về chủ đề **GitOps, CI/CD, GitHub Actions, ArgoCD, Flux và Chiến lược Rollback**.

---

## 1. Mức độ: DỄ (15 câu)

### Câu 1: Định nghĩa ngắn gọn GitOps là gì? Nguồn sự thật (source of truth) trong GitOps là gì?
*   **Gợi ý trả lời:**
    *   **GitOps** là phương pháp vận hành hệ thống trong đó toàn bộ trạng thái mong muốn (desired state) của hạ tầng và ứng dụng được mô tả dưới dạng các file cấu hình khai báo (declarative) lưu trong Git.
    *   **Nguồn sự thật:** Git repository chính là nguồn sự thật duy nhất và tối cao. Mọi thay đổi trên cluster phải xuất phát từ việc thay đổi file cấu hình trong Git.

### Câu 2: Kể tên 4 nguyên tắc cốt lõi của OpenGitOps.
*   **Gợi ý trả lời:**
    *   4 nguyên tắc OpenGitOps bao gồm:
        1.  **Declarative (Khai báo):** Trạng thái mong muốn được mô tả bằng dữ liệu (YAML/JSON), không phải bằng câu lệnh thao tác từng bước.
        2.  **Versioned and Immutable (Có phiên bản và bất biến):** Trạng thái được lưu trữ trong hệ thống có lịch sử phiên bản (Git commit) bất biến.
        3.  **Pulled Automatically (Tự động kéo):** Tác nhân (agent) trong cluster tự động phát hiện và kéo trạng thái mong muốn từ Git về.
        4.  **Continuously Reconciled (Liên tục đối chiếu):** Hệ thống liên tục so sánh trạng thái mong muốn (Git) và thực tế (Cluster) để tự động sửa sai lệch (drift).

### Câu 3: So sánh ngắn gọn mô hình Push-based CD và Pull-based GitOps.
*   **Gợi ý trả lời:**
    *   **Push-based CD:** Pipeline CI/CD (như GitHub Actions runner) nắm giữ credentials của cluster và chủ động đẩy (push) các thay đổi vào cluster bằng cách chạy các lệnh như `kubectl apply`.
    *   **Pull-based GitOps:** Một controller chạy bên trong cluster (như ArgoCD) định kỳ kéo (pull) cấu hình từ Git về và tự áp dụng vào chính nó. Pipeline CI không cần quyền truy cập trực tiếp vào cluster.

### Câu 4: Trình bày lợi ích lớn nhất của mô hình Pull-based GitOps so với Push-based CD về mặt quản lý thông tin xác thực (credentials).
*   **Gợi ý trả lời:**
    *   Mô hình Pull giúp thắt chặt bảo mật vì **không cần lưu trữ credential có quyền hạn cao của cluster (như kubeconfig)** trên các hệ thống CI bên ngoài (như GitHub, GitLab).
    *   Ngay cả khi hệ thống CI bị hack, kẻ tấn công cũng không thể trực tiếp chiếm quyền điều khiển Kubernetes cluster do cluster chỉ mở cổng kéo dữ liệu từ Git về mà không nhận lệnh đẩy trực tiếp từ CI.

### Câu 5: Hãy kể tên 5 thành phần chính trong kiến trúc của ArgoCD và vai trò tóm tắt của chúng.
*   **Gợi ý trả lời:**
    *   5 thành phần chính:
        1.  **API Server:** Nhận yêu cầu từ UI, CLI, Webhook và xác thực người dùng.
        2.  **Repo Server:** Nhân bản (clone) Git repository và biên dịch/render các file manifest (YAML, Helm, Kustomize).
        3.  **Application Controller:** Bộ não chính, liên tục giám sát cluster và so sánh live state với desired state để thực hiện đối chiếu (reconciliation).
        4.  **Redis:** Cache các manifest đã được render để giảm tải cho Repo Server và đẩy nhanh tốc độ hiển thị UI.
        5.  **Dex:** Identity provider tích hợp sẵn để hỗ trợ đăng nhập một lần (SSO) qua GitHub, LDAP, OIDC...

### Câu 6: Custom Resource Definition (CRD) trung tâm của ArgoCD dùng để mô tả một ứng dụng là gì? Nêu 3 thông tin chính được khai báo trong CRD này.
*   **Gợi ý trả lời:**
    *   CRD trung tâm là **`Application`** (nhóm api `argoproj.io/v1alpha1`).
    *   3 thông tin chính khai báo trong `spec` gồm:
        *   `source`: Trỏ tới Git repository, nhánh (revision), và thư mục (path) chứa manifest.
        *   `destination`: Trỏ tới Kubernetes API Server và namespace đích cần deploy ứng dụng.
        *   `syncPolicy`: Cấu hình cách thức đồng bộ (Manual hoặc Automated với các tùy chọn như `prune`, `selfHeal`).

### Câu 7: Giải thích sự khác biệt giữa trạng thái Sync (Sync Status) và trạng thái Health (Health Status) của một ArgoCD Application.
*   **Gợi ý trả lời:**
    *   **Sync Status (Synced / OutOfSync):** Trả lời câu hỏi *"YAML khai báo trong Git có khớp chính xác với tài nguyên đang chạy trong cluster hay không?"*.
    *   **Health Status (Healthy / Progressing / Degraded...):** Trả lời câu hỏi *"Workload chạy trong cluster có hoạt động bình thường không?"* (ví dụ: các Pod có Ready không, Service có Endpoint không). Một ứng dụng có thể đã *Synced* (YAML khớp hoàn toàn) nhưng vẫn bị *Degraded* (Pod bị CrashLoopBackOff).

### Câu 8: Sync Wave trong ArgoCD dùng để làm gì? Cách khai báo Sync Wave cho một Kubernetes resource.
*   **Gợi ý trả lời:**
    *   **Sync Wave** dùng để sắp xếp thứ tự ưu tiên áp dụng các tài nguyên khi ArgoCD thực hiện đồng bộ. Tài nguyên có số wave nhỏ hơn sẽ được deploy trước và phải ở trạng thái Healthy thì ArgoCD mới tiến hành deploy các tài nguyên thuộc wave lớn hơn.
    *   **Cách khai báo:** Sử dụng annotation `argocd.argoproj.io/sync-wave` trong metadata của tài nguyên, ví dụ:
        ```yaml
        metadata:
          annotations:
            argocd.argoproj.io/sync-wave: "1"
        ```

### Câu 9: Có những loại Sync Hook phổ biến nào trong ArgoCD? Nêu ví dụ ứng dụng của PreSync Hook.
*   **Gợi ý trả lời:**
    *   Các Sync Hooks phổ biến: `PreSync` (chạy trước sync), `Sync` (chạy song song), `PostSync` (chạy sau khi sync thành công), `SyncFail` (chạy khi sync lỗi).
    *   **Ví dụ ứng dụng PreSync:** Thường dùng để chạy một Kubernetes Job thực hiện schema migration cho database trước khi các container của ứng dụng phiên bản mới khởi chạy.

### Câu 10: Tại sao nên tách biệt Application config repository và Infrastructure config repository trong thực tế?
*   **Gợi ý trả lời:**
    *   Giúp phân định rõ ràng quyền hạn (RBAC): Đội ngũ phát triển app chỉ có quyền thay đổi app repo (sửa tag image, env...), trong khi đội ngũ Platform/DevOps nắm quyền infra repo (sửa ingress, network policy, storage class).
    *   Giảm nhiễu và hạn chế blast radius: Các commit deploy app diễn ra liên tục với tần suất cao không làm ảnh hưởng đến cấu hình cốt lõi của cluster hạ tầng.

### Câu 11: Trong GitHub Actions, phân biệt `job` và `step`.
*   **Gợi ý trả lời:**
    *   **Job:** Là một nhóm các step thực thi trên cùng một máy ảo (runner). Mặc định các job chạy song song với nhau trừ khi có khai báo phụ thuộc (`needs`).
    *   **Step:** Là một tác vụ nhỏ chạy tuần tự bên trong một job (có thể là một lệnh shell hoặc một GitHub Action đóng gói sẵn). Các step dùng chung hệ thống file trên runner của job đó.

### Câu 12: OIDC (OpenID Connect) trong CI/CD (như kết nối GitHub Actions với AWS) giải quyết vấn đề bảo mật nào so với việc dùng AWS Access Key/Secret Key truyền thống?
*   **Gợi ý trả lời:**
    *   OIDC loại bỏ hoàn toàn việc lưu trữ các credentials dài hạn (như AWS Access Key ID và Secret Access Key) dưới dạng GitHub Secrets.
    *   Thay vào đó, GitHub Actions runner sẽ tự động trao đổi với AWS Security Token Service (STS) để nhận về một credential tạm thời chỉ có hiệu lực ngắn hạn (vài phút đến 1 tiếng) để thực hiện deploy.

### Câu 13: `GITHUB_TOKEN` trong GitHub Actions là gì? Điểm khác biệt quan trọng của nó so với Personal Access Token (PAT) là gì?
*   **Gợi ý trả lời:**
    *   `GITHUB_TOKEN` là một security token tạm thời được GitHub tự động tạo ra cho mỗi workflow run để tương tác với API của repository đó.
    *   **Điểm khác biệt:** `GITHUB_TOKEN` tự động hết hạn ngay khi workflow kết thúc và chỉ có quyền hạn giới hạn trong phạm vi repo chạy job. PAT là token dài hạn, thuộc sở hữu của một tài khoản cá nhân cụ thể và có thể có quyền hạn rộng trên nhiều repo.

### Câu 14: Trong Flux, CRD `GitRepository` và `Kustomization` đóng vai trò gì?
*   **Gợi ý trả lời:**
    *   `GitRepository`: Khai báo nguồn dữ liệu (URL git repo, credential kết nối, tần suất kéo thông tin - interval).
    *   `Kustomization`: Định nghĩa cách thức render (dùng Kustomize/YAML thuần), thư mục đích cần apply, namespace áp dụng và thực hiện đồng bộ tài nguyên vào Kubernetes.

### Câu 15: So sánh ngắn gọn ArgoCD và Flux về mặt giao diện người dùng (UI) và tính dễ tiếp cận cho người mới bắt đầu.
*   **Gợi ý trả lời:**
    *   **ArgoCD:** Cung cấp một giao diện Web UI built-in trực quan, hiển thị cây tài nguyên sinh động, giúp người mới dễ theo dõi trạng thái đồng bộ, xem log và debug nhanh chóng.
    *   **Flux:** Hoạt động dạng "Kubernetes-native", không có giao diện UI chính thức đi kèm (chủ yếu dùng CLI và các công cụ bổ trợ). Flux có độ dốc học tập cao hơn nhưng nhẹ và tích hợp sâu vào hệ sinh thái Custom Resource của Kubernetes.

---

## 2. Mức độ: TRUNG BÌNH (10 câu)

### Câu 16: Phân tích sự khác biệt giữa hai chiến lược quản lý môi trường: Folder-per-environment và Branch-per-environment. Khi nào nên dùng loại nào?
*   **Gợi ý trả lời:**
    *   **Folder-per-environment:** Tất cả các môi trường (dev, staging, prod) nằm trên cùng một nhánh Git (thường là `main`) nhưng ở các thư mục khác nhau. Thay đổi môi trường được thực hiện qua Pull Request chuyển đổi thư mục. 
        *   *Ưu điểm:* Tránh divergence (lệch cấu trúc nhánh), dễ so sánh (diff) trực tiếp giữa các môi trường, promotion rõ ràng. Khuyên dùng cho phần lớn hệ thống hiện đại.
    *   **Branch-per-environment:** Mỗi môi trường tương ứng với một nhánh Git (`dev`, `staging`, `production`). 
        *   *Ưu điểm:* Cô lập mạnh mẽ về mặt phân quyền nhánh Git. 
        *   *Nhược điểm:* Dễ bị lệch lịch sử commit (divergence), xảy ra conflict phức tạp khi merge code từ nhánh thấp lên nhánh cao. Thường dùng cho các hệ thống legacy.

### Câu 17: Mô tả chi tiết luồng hoạt động của mô hình "plan-on-PR, apply-on-merge" dùng Helm và GitHub Actions. Tại sao lệnh `helm diff` lại quan trọng trong luồng này?
*   **Gợi ý trả lời:**
    *   **Luồng hoạt động:**
        1.  **Plan-on-PR:** Khi lập trình viên mở Pull Request (PR) vào nhánh `main`, pipeline CI tự động chạy các bước kiểm tra cú pháp (`yamllint`, `kubeval`), biên dịch chart (`helm lint`) và chạy lệnh `helm diff upgrade --install` để so sánh sự khác biệt cấu hình. Kết quả diff được comment trực tiếp vào PR để reviewers đánh giá rủi ro.
        2.  **Apply-on-merge:** Sau khi PR được merge vào nhánh `main`, pipeline CD chạy lệnh `helm upgrade --install` thật sự lên cluster để áp dụng thay đổi.
    *   **Tầm quan trọng của `helm diff`:** Nó giúp reviewer thấy trước một cách tường minh những thay đổi sẽ xảy ra trên cluster (thêm/sửa/xóa resource nào, biến nào thay đổi) trước khi chấp nhận merge PR, giảm thiểu lỗi deploy ngoài ý muốn.

### Câu 18: Trình bày cơ chế hoạt động của OIDC khi GitHub Actions runner thực hiện assume một AWS IAM Role để deploy tài nguyên.
*   **Gợi ý trả lời:**
    *   Cơ chế gồm các bước:
        1.  GitHub Actions runner yêu cầu một OIDC ID token từ GitHub OIDC provider. Token này chứa thông tin xác thực (claims) dạng JSON được ký số bởi GitHub (gồm repository, branch, environment...).
        2.  Runner gửi OIDC token này tới AWS Security Token Service (STS) thông qua lệnh assume role.
        3.  AWS STS kiểm tra chữ ký số của GitHub OIDC provider và đối chiếu các thông tin claims xem có khớp với cấu hình Trust Policy của IAM Role trên AWS hay không.
        4.  Nếu khớp, AWS STS cấp lại một tập AWS Access Key/Secret Key/Session Token tạm thời có thời hạn ngắn để runner sử dụng deploy tài nguyên vào AWS.

### Câu 19: Giải thích sự khác biệt giữa Reusable Workflow và Composite Action trong GitHub Actions. Khi nào nên sử dụng mỗi loại?
*   **Gợi ý trả lời:**
    *   **Reusable Workflow:** Là một file workflow hoàn chỉnh được định nghĩa ở một nơi khác, được gọi lại bằng trigger `workflow_call`. Nó có thể chứa nhiều `jobs` khác nhau chạy trên các runner khác nhau, khai báo permissions và environments riêng.
        *   *Nên dùng:* Khi muốn đóng gói một quy trình CI/CD hoàn chỉnh (ví dụ: luồng Build -> Test -> Scan -> Deploy) cho nhiều service sử dụng chung.
    *   **Composite Action:** Là một action đóng gói một danh sách các `steps` tuần tự chạy trên cùng một job và một runner. Không thể chứa nhiều job hay chỉ định runtime environment.
        *   *Nên dùng:* Khi muốn gộp các bước lệnh lặp đi lặp lại (ví dụ: cài đặt một bộ CLI, config credential) thành một bước duy nhất để làm sạch file workflow.

### Câu 20: Hãy đề xuất một chiến lược đặt tên Cache Key tối ưu trong GitHub Actions cho một dự án Node.js/npm. Tại sao cần đưa hệ điều hành (OS) và hash của file lock vào key?
*   **Gợi ý trả lời:**
    *   **Đề xuất key:** `cache-key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}` kèm theo restore-keys: `${{ runner.os }}-node-`.
    *   **Tại sao cần OS:** Vì một số dependency khi cài đặt có biên dịch native code (C++ binding) phụ thuộc vào hệ điều hành của runner (Linux, macOS, Windows).
    *   **Tại sao cần hash lockfile:** File `package-lock.json` ghi nhận chính xác phiên bản của mọi dependency. Khi file này thay đổi (thêm/bớt thư viện), hash của nó thay đổi, buộc GitHub Actions phải bỏ cache cũ và cài mới hoàn toàn để đảm bảo tính chính xác, tránh xung đột phiên bản.

### Câu 21: Trình bày mô hình App-of-Apps trong ArgoCD. Nó giải quyết bài toán gì khi quản lý hàng chục ứng dụng trên nhiều cluster?
*   **Gợi ý trả lời:**
    *   **Mô hình App-of-Apps:** Là mô hình cấu trúc phân cấp, trong đó bạn tạo ra một ArgoCD Application "gốc" (Root App). Root App này quản lý một thư mục chứa manifest khai báo của các ArgoCD Application "con" (Child Apps), và mỗi Child App mới thực sự quản lý các tài nguyên Kubernetes (Deployment, Service...) của từng ứng dụng cụ thể.
    *   **Bài toán giải quyết:** Giải quyết vấn đề bootstrap cluster và quản lý tập trung. Thay vì lập trình viên/DevOps phải vào giao diện Web UI hoặc chạy CLI thủ công để tạo từng ứng dụng (50-100 ứng dụng), họ chỉ cần cài ArgoCD và apply duy nhất một file Root App. ArgoCD sẽ tự động quét và tạo toàn bộ các ứng dụng con một cách nhất quán và tự động.

### Câu 22: Nếu một Custom Resource (CRD) của bên thứ ba không có health check tích hợp trong ArgoCD, làm thế nào để định nghĩa health check cho nó? Viết ví dụ một đoạn mã Lua đơn giản.
*   **Gợi ý trả lời:**
    *   Có thể cấu hình Custom Health Check trong ConfigMap `argocd-cm` dưới key `resource.customizations.health.<group>_<kind>`. Phần logic check được viết bằng ngôn ngữ **Lua**.
    *   **Ví dụ đoạn mã Lua check trạng thái CRD:**
        ```lua
        hs = {}
        if obj.status ~= nil and obj.status.ready == true then
          hs.status = "Healthy"
          hs.message = "Resource is ready and functional"
        else
          hs.status = "Progressing"
          hs.message = "Waiting for ready status..."
        end
        return hs
        ```

### Câu 23: Vai trò của `AppProject` trong ArgoCD là gì? Nó giúp thắt chặt bảo mật đa khách thuê (multi-tenancy) như thế nào?
*   **Gợi ý trả lời:**
    *   `AppProject` (Project) cung cấp một ranh giới logic bảo mật để quản lý nhóm các ArgoCD Application.
    *   **Thắt chặt bảo mật:** Nó thiết lập các guardrail bằng cách giới hạn:
        *   **Source Repositories:** Chỉ cho phép ứng dụng thuộc project này kéo code từ các Git repositories được chỉ định cụ thể.
        *   **Destinations:** Chỉ cho phép ứng dụng deploy lên đúng các cluster và namespaces được phép.
        *   **Cluster Resources:** Quy định project đó có được tạo tài nguyên cấp cluster (như Namespace, ClusterRole) hay chỉ được tạo namespace-scoped resources.
        *   **Roles:** Phân quyền chi tiết (RBAC) cho người dùng/nhóm người dùng được thao tác trên các ứng dụng của project đó.

### Câu 24: So sánh chi tiết 3 chiến lược rollback khi xảy ra sự cố trên production: `git revert`, `kubectl rollout undo` và ArgoCD rollback qua UI/CLI.
*   **Gợi ý trả lời:**
    *   **`git revert`:** Tạo một commit mới đảo ngược commit lỗi trên Git.
        *   *Ưu điểm:* Giữ Git luôn là nguồn sự thật, an toàn nhất, có lịch sử audit rõ ràng trong Git.
        *   *Nhược điểm:* Tốc độ trung bình (tốn thời gian push commit, chạy CI kiểm tra).
    *   **`kubectl rollout undo`:** Gọi trực tiếp Kubernetes API để đưa Deployment về ReplicaSet revision trước.
        *   *Ưu điểm:* Cực kỳ nhanh trong tình huống khẩn cấp.
        *   *Nhược điểm:* Đi vòng qua GitOps gây ra trạng thái Drift (lệch cấu hình với Git). Nếu ArgoCD bật tự động đối chiếu, nó sẽ ghi đè lại phiên bản lỗi của Git ngay sau đó.
    *   **ArgoCD Rollback (qua UI/CLI):** Yêu cầu ArgoCD deploy lại một revision cũ trong lịch sử đồng bộ của nó và tạm thời tắt tính năng Auto-Sync.
        *   *Ưu điểm:* Nhanh, đi qua cơ chế kiểm soát của ArgoCD, lưu được log rollback.
        *   *Nhược điểm:* Vẫn gây ra drift tạm thời với Git. Cần phải cập nhật Git sau khi hệ thống ổn định để bật lại Auto-Sync.

### Câu 25: Tại sao việc lạm dụng lệnh `kubectl rollout undo` trong hệ thống đang chạy GitOps (ví dụ có ArgoCD đang bật Automated Sync + SelfHeal) lại có thể gây ra hiện tượng xung đột/chập chữa (reconciliation loop)?
*   **Gợi ý trả lời:**
    *   Khi bạn chạy `kubectl rollout undo`, Kubernetes API server cập nhật cấu hình live state của Deployment về ReplicaSet cũ (ví dụ: image tag v1.0.0).
    *   ArgoCD liên tục đối chiếu cluster và phát hiện ra live state (v1.0.0) bị lệch (drift) so với desired state trong Git (v2.0.0).
    *   Do bật `SelfHeal` và `Automated Sync`, ArgoCD sẽ lập tức áp dụng lại manifest trong Git (v2.0.0) đè lên cluster.
    *   Kết quả là cluster bị giằng co liên tục giữa lệnh rollback thủ công và lệnh sync tự động của ArgoCD, tạo ra vòng lặp vô tận khiến ứng dụng chập chờn và không thể ổn định.

---

## 3. Mức độ: THỰC TẾ / TÌNH HUỐNG (5 câu)

### Câu 26: *[Tình huống Security]* GitHub Actions của dự án bị lộ Personal Access Token (PAT) có quyền ghi vào infra repo. Kẻ tấn công đã sửa đổi một manifest để chèn một container độc hại. Hãy phân tích cách giảm thiểu rủi ro này bằng cách chuyển dịch sang OIDC và cấu hình `AppProject` trong ArgoCD để hạn chế blast radius.
*   **Gợi ý trả lời:**
    *   **Bước 1: Chuyển dịch sang OIDC:** Thu hồi ngay lập tức PAT bị lộ. Cấu hình OIDC kết nối giữa GitHub Actions và Cloud Provider. Thiết lập Trust Policy trên IAM Role của Cloud Provider giới hạn chỉ cho phép thực thi từ repository cụ thể, nhánh cụ thể (`main`), loại bỏ hoàn toàn credential dài hạn trong GitHub secrets.
    *   **Bước 2: Hardening ArgoCD AppProject:**
        *   Cấu hình `AppProject` giới hạn thuộc tính `sourceRepos` chỉ chứa các URL git repo chính thức của công ty.
        *   Hạn chế `destinations` chỉ cho phép deploy vào namespace cụ thể của team, tuyệt đối không dùng wildcard `*`.
        *   Cấm tạo cluster-scoped resources bằng cách không cấu hình `clusterResourceWhitelist`.
        *   Bật tính năng chữ ký số (commit signature verification) để ArgoCD chỉ đồng bộ các commits được ký bởi khóa GPG hợp lệ của các thành viên được ủy quyền.

### Câu 27: *[Tình huống Rollback]* Một bản deploy mới của `api-service` bị lỗi crash loop ngay khi khởi chạy. Hệ thống sử dụng ArgoCD để quản lý. Tuy nhiên, lúc này Git server (GitHub) đang bị sập không thể push commit revert. Hãy đưa ra các bước xử lý khẩn cấp để đưa ứng dụng về version cũ hoạt động bình thường, và nêu rõ tác dụng phụ của từng bước.
*   **Gợi ý trả lời:**
    *   **Phương án 1: Dùng tính năng Rollback của ArgoCD (Khuyên dùng)**
        *   *Các bước:* Truy cập ArgoCD UI (hoặc CLI), chọn Application `api-service`, chọn revision trước đó chạy ổn định trong lịch sử và nhấn **Rollback**. ArgoCD sẽ tự động tắt tính năng Auto-Sync và apply lại revision cũ.
        *   *Tác dụng phụ:* Tạo ra drift với Git. Sau khi GitHub hoạt động trở lại, bắt buộc phải push commit revert cấu hình trên Git và bật lại Auto-Sync cho Application.
    *   **Phương án 2: Rollback thủ công bằng `kubectl` kết hợp tắt/tạm dừng ArgoCD sync**
        *   *Các bước:* Chạy lệnh `argocd app set api-service --sync-policy manual` để tắt tự động sync. Sau đó chạy `kubectl rollout undo deployment/api-service -n platform` để ép Kubernetes rollback nhanh.
        *   *Tác dụng phụ:* Ứng dụng khôi phục nhanh nhưng mất đi sự giám sát tự động của GitOps. Rất dễ bị quên bật lại sync sau khi xử lý xong sự cố.

### Câu 28: *[Tình huống Lập lịch Deploy]* Bạn cần triển khai một database migration Job chạy trước khi cập nhật Deployment mới của ứng dụng chính. Hãy viết một file YAML ArgoCD Application (hoặc manifest chi tiết của Job và Deployment) sử dụng Sync Waves và Sync Hooks để đảm bảo Job chạy và hoàn thành thành công trước khi pod của ứng dụng mới được tạo.
*   **Gợi ý trả lời:**
    *   **Giải pháp:** Sử dụng PreSync Hook trên Migration Job và chỉ định chính sách xóa Job sau khi hoàn thành.
    *   **File YAML cấu hình Job:**
        ```yaml
        apiVersion: batch/v1
        kind: Job
        metadata:
          name: db-migration-job
          namespace: platform
          annotations:
            argocd.argoproj.io/hook: PreSync
            argocd.argoproj.io/hook-delete-policy: HookSucceeded
        spec:
          template:
            spec:
              containers:
              - name: migration
                image: ghcr.io/example/db-migration:v2.0.0
                command: ["npm", "run", "db:migrate"]
              restartPolicy: Never
        ```
    *   **Giải thích:** Annotation `argocd.argoproj.io/hook: PreSync` báo cho ArgoCD biết phải chạy Job này trước khi tiến hành deploy tài nguyên chính (Deployment ứng dụng). `hook-delete-policy: HookSucceeded` sẽ tự động dọn dẹp Pod của Job sau khi nó chạy thành công để tránh rác tài nguyên.

### Câu 29: *[Tình huống Caching & Docker]* Pipeline CI của bạn build Docker image mất hơn 10 phút vì không tận dụng được cache của các layer cũ. Hãy mô tả cách tích hợp GitHub Actions cache với Docker Buildx (sử dụng cache-from và cache-to với gha hoặc registry exporter) để tăng tốc độ build.
*   **Gợi ý trả lời:**
    *   Sử dụng action `docker/setup-buildx-action` kết hợp với `docker/build-push-action` trong workflow GitHub Actions.
    *   Cấu hình tham số `cache-from` và `cache-to` trỏ về cache của GitHub Actions (`gha` backend) để các layer đã build được lưu trữ trực tiếp trên hạ tầng cache của GitHub.
    *   **Cấu hình mẫu trong step build:**
        ```yaml
        - name: Build and push
          uses: docker/build-push-action@v5
          with:
            context: .
            push: true
            tags: ghcr.io/example/api-service:v2.0.0
            cache-from: type=gha
            cache-to: type=gha,mode=max
        ```
    *   *Giải thích:* `type=gha` kích hoạt GitHub Actions cache backend. `mode=max` lưu trữ tất cả các layer cache (kể cả các build layer trung gian của multi-stage builds), giúp tối ưu hóa tối đa thời gian build cho các lần chạy sau.

### Câu 30: *[Tình huống Flux Multi-tenancy]* Công ty có 3 đội phát triển độc lập sử dụng chung một Kubernetes cluster. Bạn được giao nhiệm vụ thiết kế cấu hình Flux để đảm bảo đội A không thể vô tình sửa đổi hoặc xóa tài nguyên của đội B thông qua GitOps. Hãy mô tả giải pháp sử dụng ServiceAccount impersonation trong Flux `Kustomization` để giải quyết bài toán này.
*   **Gợi ý trả lời:**
    *   **Giải pháp:** Sử dụng tính năng **ServiceAccount Impersonation** của Flux `Kustomization`.
    *   **Các bước thiết kế:**
        1.  Trong mỗi namespace của từng đội (ví dụ: namespace `team-a`, `team-b`), tạo một Kubernetes `ServiceAccount` (ví dụ: `flux-reconciler`) và cấp quyền RBAC (Role/RoleBinding) giới hạn chỉ được thao tác các tài nguyên bên trong namespace đó.
        2.  Trong file cấu hình Flux `Kustomization` của từng đội, sử dụng thuộc tính `spec.serviceAccountName` trỏ tới ServiceAccount tương ứng của đội đó:
            ```yaml
            apiVersion: kustomize.toolkit.fluxcd.io/v1
            kind: Kustomization
            metadata:
              name: team-a-workloads
              namespace: flux-system
            spec:
              interval: 10m
              path: ./apps/team-a
              sourceRef:
                kind: GitRepository
                name: team-a-repo
              serviceAccountName: team-a/flux-reconciler # Thực hiện giả danh SA này khi apply
            ```
        3.  Khi Flux thực hiện apply tài nguyên từ Git repository của team A, nó sẽ giả danh (impersonate) tài khoản `team-a/flux-reconciler`. Nếu trong Git của team A có chứa manifest cố tình can thiệp vào namespace của team B, Kubernetes API Server sẽ chặn yêu cầu ngay lập tức do ServiceAccount của team A không có quyền trên namespace của team B.
