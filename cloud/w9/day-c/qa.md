# Bộ Câu Hỏi Vấn Đáp (Q&A) - Day C: Progressive Delivery và Canary

Tài liệu này tổng hợp bộ câu hỏi từ dễ đến khó phục vụ cho việc vấn đáp và đánh giá kiến thức của học viên về chủ đề **Progressive Delivery, Canary Deployment, Blue/Green, Argo Rollouts và Flagger**.

---

## 1. Mức độ: DỄ (15 câu)

### Câu 1: Progressive Delivery là gì? Mục tiêu chính của nó so với mô hình deploy truyền thống (Big Bang deploy) là gì?
*   **Gợi ý trả lời:**
    *   **Progressive Delivery (Triển khai lũy tiến):** Là phương pháp đưa phiên bản ứng dụng mới ra môi trường production theo từng bước có kiểm soát, kết hợp chia luồng traffic, giám sát tự động và đưa ra quyết định tiếp tục (promote) hoặc hủy bỏ (abort).
    *   **Mục tiêu chính:** Hạn chế tối đa bán kính ảnh hưởng (blast radius) khi có lỗi xảy ra ở phiên bản mới. Phát hiện lỗi sớm trên một nhóm nhỏ người dùng trước khi phổ biến ra toàn bộ hệ thống.

### Câu 2: Blast Radius (bán kính ảnh hưởng) là gì? Hãy cho ví dụ cách tính blast radius khi chuyển 5% traffic sang canary version.
*   **Gợi ý trả lời:**
    *   **Blast Radius:** Là mức độ ảnh hưởng tối đa của một sự cố (lỗi, sập hệ thống) đối với người dùng hoặc hệ thống.
    *   **Ví dụ:** Nếu hệ thống đang xử lý tổng cộng 1,000 requests/giây (RPS). Khi chuyển 5% traffic sang canary version bị lỗi, blast radius tối đa được giới hạn ở mức **50 requests/giây bị ảnh hưởng**, thay vì toàn bộ 1,000 requests/giây như deploy 100% truyền thống.

### Câu 3: So sánh sự khác biệt cơ bản giữa chiến lược deploy Blue/Green và Canary.
*   **Gợi ý trả lời:**
    *   **Blue/Green:** Duy trì hai môi trường độc lập hoàn chỉnh có quy mô tương đương (Blue - chạy bản cũ, Green - chạy bản mới). Switch 100% traffic lập tức từ Blue sang Green sau khi Green đã được kiểm thử ổn định.
    *   **Canary:** Triển khai một phiên bản mới chạy song song với phiên bản cũ trong cùng một môi trường. Chuyển một phần nhỏ traffic (ví dụ 2%, 5%, 10%) sang bản mới, quan sát metrics rồi tăng dần tỷ lệ này lên 100%.

### Câu 4: Argo Rollouts là gì? Tại sao `Deployment` mặc định của Kubernetes lại không phù hợp cho việc chạy tự động các bước deploy phức tạp như Canary kèm theo phân tích metrics?
*   **Gợi ý trả lời:**
    *   **Argo Rollouts** là một Kubernetes-native controller cung cấp Custom Resource Definition (CRD) tên là `Rollout` thay thế cho `Deployment` để hỗ trợ các chiến lược release nâng cao.
    *   **Tại sao Deployment không phù hợp:** `Deployment` chỉ hỗ trợ chiến lược `RollingUpdate` (thế chỗ dần pod cũ bằng pod mới) hoặc `Recreate` một cách thô sơ. Nó hoàn toàn không có khả năng tự động chia tỷ lệ traffic theo phần trăm chính xác (weight-based routing), không thể tự động tạm dừng (pause) theo các bước phức tạp và không thể kết nối với Prometheus để phân tích chất lượng ứng dụng trước khi quyết định đi tiếp.

### Câu 5: Kể tên 3 bước hành động chính (steps) trong spec của một Argo Rollout Canary và giải thích ngắn gọn nhiệm vụ của từng bước.
*   **Gợi ý trả lời:**
    *   3 bước chính gồm:
        1.  **`setWeight`:** Quy định tỷ lệ phần trăm traffic (hoặc tỷ lệ replicas) được chuyển hướng sang phiên bản canary.
        2.  **`pause`:** Tạm dừng tiến trình rollout. Có thể tạm dừng có thời hạn (ví dụ `duration: 10m`) hoặc dừng vô hạn để chờ phê duyệt thủ công (`pause: {}`).
        3.  **`analysis`:** Kích hoạt một cuộc phân tích metrics tự động (`AnalysisTemplate`) để đánh giá sức khỏe của phiên bản mới.

### Câu 6: Phân biệt `AnalysisTemplate` và `AnalysisRun` trong Argo Rollouts.
*   **Gợi ý trả lời:**
    *   **`AnalysisTemplate` (Mẫu phân tích):** Là khai báo định nghĩa chung, chứa cấu hình về loại metric cần đo, query PromQL, tần suất đo, và các điều kiện thành công/thất bại (như một Class/Template).
    *   **`AnalysisRun` (Lượt chạy phân tích):** Là một thể hiện thực tế (instance) được Argo Rollouts tạo ra khi chạy một bước rollout cụ thể dựa trên `AnalysisTemplate`. Nó lưu trữ kết quả của các lần đo thực tế (success, failure, inconclusive).

### Câu 7: Giải thích sự khác biệt giữa Background Analysis và Inline Analysis trong Argo Rollouts.
*   **Gợi ý trả lời:**
    *   **Background Analysis:** Chạy song song độc lập trong suốt quá trình rollout (từ step đầu tiên đến step cuối cùng). Nếu bất kỳ lúc nào metrics vi phạm, rollout sẽ bị abort ngay lập tức.
    *   **Inline Analysis:** Được khai báo như một bước (step) cụ thể trong danh sách `steps`. Tiến trình rollout sẽ bị dừng lại tại step này và chỉ được đi tiếp sang step sau khi lượt phân tích (`AnalysisRun`) hoàn thành và trả về kết quả thành công (`Successful`).

### Câu 8: Kể tên ít nhất 4 metrics provider được hỗ trợ bởi Argo Rollouts để thực hiện phân tích chất lượng bản release.
*   **Gợi ý trả lời:**
    *   Các provider phổ biến: `prometheus` (truy vấn Prometheus), `web` (gọi API HTTP), `job` (chạy một Kubernetes Job kiểm thử), `datadog`, `newrelic`, `wavefront`, `influxdb`.

### Câu 9: Trong `AnalysisTemplate`, tham số `initialDelay` và `interval` dùng để làm gì?
*   **Gợi ý trả lời:**
    *   **`initialDelay`:** Thời gian trì hoãn trước khi thực hiện lần đo đầu tiên (ví dụ `initialDelay: 2m`). Mục đích để chờ ứng dụng canary tích lũy đủ traffic và sinh metrics ổn định, tránh đo quá sớm khi chưa có dữ liệu.
    *   **`interval`:** Khoảng thời gian giãn cách giữa các lần đo tiếp theo (ví dụ `interval: 1m` - cứ mỗi 1 phút lại chạy query kiểm tra một lần).

### Câu 10: Tham số `failureLimit` trong `AnalysisTemplate` có ý nghĩa gì? Điều gì xảy ra khi số lần đo thất bại vượt quá giới hạn này?
*   **Gợi ý trả lời:**
    *   **`failureLimit`:** Số lần đo được phép trả về kết quả thất bại tối đa trước khi lượt phân tích bị coi là hỏng hoàn toàn (mặc định là 0, tức là hỏng ngay lần đo lỗi đầu tiên).
    *   **Khi vượt quá:** `AnalysisRun` sẽ chuyển trạng thái sang `Failed`. Argo Rollouts Controller lập tức chuyển trạng thái Rollout sang `Aborted`, tự động rút toàn bộ traffic khỏi canary và khôi phục 100% traffic về bản stable.

### Câu 11: Nêu ít nhất 4 công nghệ traffic management (traffic routing) phổ biến có thể tích hợp với Argo Rollouts để phân chia % traffic chính xác.
*   **Gợi ý trả lời:**
    *   Các công nghệ phổ biến:
        1.  **NGINX Ingress Controller** (sử dụng annotation weight).
        2.  **Istio Service Mesh** (sử dụng VirtualService weighted routes).
        3.  **Linkerd** (sử dụng ServiceMeshInterface - SMI).
        4.  **AWS ALB Ingress Controller** (sử dụng Target Group weights).

### Câu 12: Lệnh CLI nào của Argo Rollouts dùng để dừng ngay lập tức một tiến trình rollout và trả toàn bộ traffic về phiên bản stable?
*   **Gợi ý trả lời:**
    *   Sử dụng lệnh CLI:
        ```bash
        kubectl argo rollouts abort <rollout-name> -n <namespace>
        ```

### Câu 13: Khi một Rollout bị abort, Argo Rollouts Controller sẽ thực hiện những hành động gì trên các ReplicaSet và traffic routing để khôi phục trạng thái an toàn?
*   **Gợi ý trả lời:**
    *   Controller thực hiện:
        1.  Cập nhật cấu hình traffic routing (Ingress/VirtualService) để trả 100% traffic về cho **Stable ReplicaSet**.
        2.  Scale down số lượng replicas của **Canary ReplicaSet** về 0 pod (hoặc giữ ở mức tối thiểu để debug tùy cấu hình).
        3.  Đặt trạng thái của Rollout thành `Degraded` và `Aborted` để báo hiệu sự cố cho người vận hành.

### Câu 14: Phân biệt hai chiến lược rollout Canary: dùng Replica Ratio (xấp xỉ bằng số lượng pod) và dùng Traffic Routing (sử dụng Ingress/Service Mesh).
*   **Gợi ý trả lời:**
    *   **Dùng Replica Ratio (Không có traffic router):** Ví dụ để có 10% traffic, Rollout tự động scale 1 pod canary và 9 pod stable.
        *   *Nhược điểm:* Độ chia traffic không chính xác, phụ thuộc số lượng pod tối thiểu lớn, tốn tài nguyên hạ tầng.
    *   **Dùng Traffic Routing:** Số lượng pod canary và stable có thể cấu hình độc lập (ví dụ chỉ cần 1 pod canary). Việc chia 10% traffic được thực hiện chính xác ở tầng proxy (Ingress/Envoy) dựa trên cấu hình phần trăm routing.
        *   *Ưu điểm:* Tiết kiệm tài nguyên, độ chính xác cực cao, hỗ trợ phân chia lưu lượng lớn.

### Câu 15: Flagger là gì? Điểm khác biệt lớn nhất về mặt thiết kế tài nguyên (CRD) của Flagger so với Argo Rollouts là gì?
*   **Gợi ý trả lời:**
    *   **Flagger** là một công cụ Progressive Delivery thuộc dự án FluxCD (CNCF).
    *   **Điểm khác biệt thiết kế:** 
        *   Argo Rollouts yêu cầu thay thế hoàn toàn `Deployment` bằng một CRD mới là `Rollout`.
        *   Flagger sử dụng CRD có tên `Canary` để **bọc xung quanh (wrap) Deployment sẵn có**. Flagger tự động quản lý việc nhân bản Deployment thành các bản stable/canary và quản lý Ingress thay cho người dùng.

---

## 2. Mức độ: TRUNG BÌNH (10 câu)

### Câu 16: Tại sao việc sử dụng metrics "Error Budget Burn Rate" (từ Ngày B) lại được khuyến nghị làm tín hiệu phân tích trong `AnalysisTemplate` của Canary thay vì sử dụng trực tiếp "Raw Error Rate"?
*   **Gợi ý trả lời:**
    *   **Raw Error Rate (Tỷ lệ lỗi thô):** Ví dụ 1% lỗi. Con số này không có ngữ cảnh. 1% có thể chấp nhận được nếu SLO là 95%, nhưng là thảm họa nếu SLO là 99.99%.
    *   **Error Budget Burn Rate (Tốc độ đốt ngân sách lỗi):** Đã được chuẩn hóa dựa trên SLO mục tiêu của service. Burn rate > 14 nghĩa là bản canary đang tiêu tốn ngân sách lỗi nhanh gấp 14 lần cho phép. Việc dùng burn rate giúp thống nhất một `AnalysisTemplate` chung cho nhiều services có các SLO khác nhau mà không cần viết lại ngưỡng chấp nhận lỗi cho từng service.

### Câu 17: Giải thích tại sao khi thiết kế `AnalysisTemplate` truy vấn Prometheus, việc đặt `initialDelay` quá ngắn (ví dụ: nhỏ hơn 2 lần scrape interval của Prometheus) có thể dẫn đến việc AnalysisRun bị fail hoặc inconclusive sai lệch.
*   **Gợi ý trả lời:**
    *   Nếu Prometheus được cấu hình quét metrics (`scrape_interval`) mỗi 30 giây. Khi pod canary vừa khởi chạy, nó chưa xử lý đủ request và Prometheus chưa kịp thực hiện lượt scrape nào để lưu trữ dữ liệu.
    *   Nếu đặt `initialDelay` quá ngắn (ví dụ 10 giây), `AnalysisRun` sẽ truy vấn Prometheus ngay lập tức. Kết quả trả về sẽ là rỗng (no data) hoặc số liệu không đầy đủ, dẫn đến việc tính toán PromQL bị sai lệch (ví dụ chia cho 0), làm cho lượt phân tích bị đánh dấu hỏng (`Failed` hoặc `Inconclusive`) một cách oan uổng. Do đó, khuyến nghị đặt `initialDelay` tối thiểu từ 2 phút trở lên để đảm bảo có đủ ít nhất 2-3 chu kỳ scrape ổn định.

### Câu 18: Trình bày cách ArgoCD và Argo Rollouts phối hợp hoạt động với nhau. Tại sao cần cấu hình Custom Health Check cho Rollout CRD trong ArgoCD?
*   **Gợi ý trả lời:**
    *   **Cách phối hợp:** ArgoCD quản lý file Git khai báo và apply `Rollout` CRD vào cluster. Khi có phiên bản mới, ArgoCD nhận thấy mong muốn thay đổi và update spec của Rollout. Lúc này, Argo Rollouts Controller trong cluster sẽ tiếp quản để thực hiện chia traffic từng bước.
    *   **Tại sao cần Custom Health Check:** Mặc định, ArgoCD không biết cấu trúc bên trong của `Rollout` CRD. Khi Rollout đang tạm dừng ở bước Canary (chờ phân tích hoặc chờ duyệt), ArgoCD có thể coi tài nguyên này là chưa hoàn thành đồng bộ (OutOfSync/Progressing) và liên tục báo trạng thái màu vàng/đỏ trên UI. Cấu hình Custom Health Check bằng Lua script giúp ArgoCD hiểu rằng *"Rollout đang ở trạng thái Paused/Canary là hoàn toàn bình thường (Healthy)"*, giúp biểu đồ ArgoCD hiển thị đúng thực tế.

### Câu 19: Viết một file YAML định nghĩa một `AnalysisTemplate` đơn giản truy vấn Prometheus để kiểm tra tỷ lệ lỗi (error rate) của `api-service` trong 5 phút gần nhất, yêu cầu lỗi phải dưới 1%, thực hiện đo 3 lần, mỗi lần cách nhau 2 phút.
*   **Gợi ý trả lời:**
    *   **File YAML cấu hình:**
        ```yaml
        apiVersion: argoproj.io/v1alpha1
        kind: AnalysisTemplate
        metadata:
          name: api-service-error-rate-check
          namespace: platform
        spec:
          metrics:
          - name: error-rate
            interval: 2m
            count: 3
            initialDelay: 1m
            successCondition: result[0] < 0.01
            provider:
              prometheus:
                address: http://prometheus:9090
                query: |
                  sum(rate(http_requests_total{service="api-service", status_code=~"5.."}[5m]))
                  /
                  sum(rate(http_requests_total{service="api-service"}[5m]))
        ```

### Câu 20: Giải thích cơ chế hoạt động của NGINX Ingress controller khi tích hợp với Argo Rollouts. Nó sử dụng annotation nào để điều phối traffic và làm thế nào Argo Rollouts tự động cập nhật annotation đó?
*   **Gợi ý trả lời:**
    *   **Cơ chế:** Cần có 2 Ingress resources trong cluster: một Ingress chính (Stable Ingress) và một Ingress phụ (Canary Ingress) trỏ tới service stable và service canary tương ứng.
    *   **Annotation sử dụng:** NGINX Ingress sử dụng annotation `nginx.ingress.kubernetes.io/canary: "true"` và `nginx.ingress.kubernetes.io/canary-weight: "X"` (với X là phần trăm traffic cần chuyển).
    *   **Cách cập nhật:** Trong spec `trafficRouting.nginx` của Rollout, ta khai báo tên của Stable Ingress. Khi tiến trình rollout chạy qua các bước `setWeight: X`, Argo Rollouts Controller sẽ tự động tìm kiếm, tính toán và sửa đổi trực tiếp giá trị của annotation `canary-weight` trên Canary Ingress resource trong Kubernetes API, ép NGINX proxy chuyển hướng đúng tỷ lệ traffic mong muốn mà không cần người dùng can thiệp thủ công.

### Câu 21: Trong spec của Argo Rollouts, làm thế nào để cấu hình bước pause vô thời hạn (chờ phê duyệt thủ công từ con người) và bước pause có thời gian xác định (ví dụ: 10 phút)? Viết đoạn YAML cấu hình mẫu cho hai bước này.
*   **Gợi ý trả lời:**
    *   **Cấu hình:**
        *   Bước pause vô thời hạn: Không khai báo trường `duration`.
        *   Bước pause có thời hạn: Khai báo trường `duration` kèm đơn vị thời gian (s, m, h).
    *   **YAML cấu hình mẫu:**
        ```yaml
        spec:
          strategy:
            canary:
              steps:
              - setWeight: 10
              - pause: {} # Dừng vô thời hạn, chờ lệnh promote thủ công
              - setWeight: 50
              - pause:
                  duration: 10m # Tự động đi tiếp sau 10 phút
        ```

### Câu 22: Phân biệt các trạng thái vòng đời của một Rollout: `Progressing`, `Paused`, `Degraded`, `Aborted`. Khi nào Rollout rơi vào trạng thái `Degraded`?
*   **Gợi ý trả lời:**
    *   **`Progressing`:** Rollout đang thực hiện cập nhật pod, tạo ReplicaSet mới hoặc đang shift traffic.
    *   **`Paused`:** Rollout đang tạm dừng tại một bước cụ thể (chờ thời gian trôi qua hoặc chờ approve).
    *   **`Aborted`:** Rollout đã bị hủy bỏ tiến trình cập nhật do có lệnh abort thủ công hoặc do AnalysisRun bị lỗi. Traffic đã được trả về stable.
    *   **`Degraded`:** Xảy ra khi Rollout gặp lỗi nghiêm trọng không thể tự phục hồi, ví dụ: pod canary liên tục bị lỗi cấu hình/CrashLoopBackOff không thể ready, vượt quá thời gian timeout của `progressDeadlineSeconds`.

### Câu 23: Làm thế nào để cấu hình các label khác nhau cho các Pod thuộc ReplicaSet stable và canary (`canaryMetadata` và `stableMetadata`) trong Rollout CRD? Việc này giúp ích gì cho Prometheus scraper và Grafana dashboard?
*   **Gợi ý trả lời:**
    *   **Cách cấu hình trong Rollout spec:**
        ```yaml
        spec:
          strategy:
            canary:
              canaryMetadata:
                labels:
                  role: canary
              stableMetadata:
                labels:
                  role: stable
        ```
    *   **Lợi ích:** Khi các pod được gắn nhãn phân biệt (`role: canary` hoặc `role: stable`), Prometheus scraper sẽ tự động gán nhãn này vào các metrics thu thập từ pod. Trên Grafana dashboard, ta có thể viết PromQL lọc theo label `role="canary"` để theo dõi riêng biệt latency và error rate của riêng nhóm pod thử nghiệm, giúp đánh giá chính xác chất lượng code mới mà không bị lẫn lộn dữ liệu với phiên bản cũ đang chạy ổn định.

### Câu 24: So sánh chi tiết ưu và nhược điểm của việc sử dụng Argo Rollouts so với Flagger trong thực tế vận hành của một đội ngũ Platform SRE.
*   **Gợi ý trả lời:**
    *   **Argo Rollouts:**
        *   *Ưu điểm:* Cung cấp CLI plugin rất mạnh (`kubectl argo rollouts`), giao diện dashboard UI trực quan để theo dõi trực tiếp các step; tích hợp sâu sắc và mượt mà trong hệ sinh thái Argo (ArgoCD).
        *   *Nhược điểm:* Phải thay đổi toàn bộ file manifest từ `Deployment` sang `Rollout`, yêu cầu đội ngũ dev phải học định nghĩa CRD mới.
    *   **Flagger:**
        *   *Ưu điểm:* Không xâm lấn code/manifest cũ, giữ nguyên `Deployment` tiêu chuẩn; tự động tạo các service ảo và quản lý cấu hình Ingress phức tạp; hỗ trợ tốt cho GitOps thuần túy của FluxCD.
        *   *Nhược điểm:* Thiếu giao diện UI trực quan chuyên dụng như Argo, theo dõi trạng thái chủ yếu qua Kubernetes Events hoặc log của controller, khó can thiệp dừng/tiếp tục thủ công hơn.

### Câu 25: Nếu một AnalysisRun của bạn trả về trạng thái `Inconclusive`, điều đó có nghĩa là gì? Hãy chỉ ra các nguyên nhân phổ biến trong thực tế dẫn đến trạng thái này và cách khắc phục.
*   **Gợi ý trả lời:**
    *   **Ý nghĩa:** `Inconclusive` (Không thể kết luận) nghĩa là phép đo không trả về kết quả Đạt (Success) hay Hỏng (Failure), thường do không lấy được dữ liệu hoặc biểu thức logic đánh giá bị lỗi. Trạng thái này không làm abort rollout ngay nhưng sẽ chặn rollout không cho đi tiếp nếu không cấu hình bỏ qua.
    *   **Nguyên nhân phổ biến và cách khắc phục:**
        1.  *Lỗi kết nối mạng:* Prometheus server bị quá tải hoặc sập tạm thời làm Argo Rollouts không gọi được API. *Khắc phục:* Đảm bảo tính HA cho Prometheus và tăng thông số timeout trong provider.
        2.  *Query PromQL trả về rỗng (No Data):* Do ghi sai tên metric hoặc pod chưa phát sinh traffic nào. *Khắc phục:* Sử dụng hàm `vector(0)` hoặc cấu hình mặc định trong PromQL để trả về giá trị mặc định khi rỗng.
        3.  *Lỗi cú pháp logic:* Biểu thức `successCondition` tham chiếu sai định dạng kết quả. *Khắc phục:* Sử dụng `promtool` chạy thử query trước và kiểm tra kỹ syntax.

---

## 3. Mức độ: THỰC TẾ / TÌNH HUỐNG (5 câu)

### Câu 26: *[Tình huống Cấu hình Rollout & Ingress]* Hãy viết một file YAML `Rollout` hoàn chỉnh tích hợp với NGINX Ingress cho dịch vụ `api-service`. Cấu hình bao gồm: chia traffic theo các bước 10%, 30%, 50%; tại bước 10% có chạy một background analysis kiểm tra burn rate; tại bước 30% có bước pause 10 phút; tại bước 50% có chạy inline analysis kiểm tra latency p99.
*   **Gợi ý trả lời:**
    *   **File YAML cấu hình:**
        ```yaml
        apiVersion: argoproj.io/v1alpha1
        kind: Rollout
        metadata:
          name: api-service
          namespace: platform
        spec:
          replicas: 4
          strategy:
            canary:
              analysis:
                templates:
                - templateName: api-service-burn-rate-check # Chạy background suốt quá trình
              trafficRouting:
                nginx:
                  stableIngress: api-service-ingress
              steps:
              - setWeight: 10
              - pause: { duration: 5m }
              - setWeight: 30
              - pause:
                  duration: 10m # Bước pause 10 phút
              - setWeight: 50
              - analysis:
                  templates:
                  - templateName: api-service-latency-p99-check # Inline analysis tại bước 50%
              - setWeight: 100
          template:
            # (Phần cấu hình pod spec của Deployment cũ giữ nguyên...)
        ```

### Câu 27: *[Tình huống Canary Rollback tự động]* Trong lúc deploy phiên bản v2.0.0 của `api-service` bằng Canary Rollout với background analysis, Prometheus ghi nhận `service:availability_burn_rate:1h` tăng vọt lên 18 (do code v2.0.0 bị lỗi kết nối DB). Hãy mô tả chi tiết chuỗi sự kiện diễn ra tự động từ lúc Prometheus sinh metric, AnalysisRun phát hiện lỗi, cho đến khi hệ thống tự động rollback hoàn toàn và trạng thái cuối cùng của Rollout.
*   **Gợi ý trả lời:**
    *   Chuỗi sự kiện diễn ra như sau:
        1.  **Phát sinh metric lỗi:** Pod v2.0.0 (canary) bị lỗi kết nối DB, trả về lỗi HTTP 500 cho khách hàng. Prometheus scrape metric và tính toán lại recording rule làm chỉ số `service:availability_burn_rate:1h` tăng vọt lên 18 (vượt ngưỡng an toàn là 14).
        2.  **Đo lường thất bại:** `AnalysisRun` đang chạy ngầm thực hiện truy vấn Prometheus định kỳ (ví dụ mỗi 1 phút). Nó nhận giá trị 18, so sánh với `successCondition` và đánh giá lượt đo này là **Fail**.
        3.  **Hủy bỏ Rollout:** Do vượt quá `failureLimit` (bằng 0), `AnalysisRun` lập tức chuyển trạng thái sang `Failed`. Argo Rollouts Controller bắt được sự kiện này, lập tức hủy bỏ tiến trình cập nhật.
        4.  **Điều hướng an toàn:** Controller sửa đổi ngay lập tức Canary Ingress, đưa `canary-weight` về `0` để ngắt toàn bộ traffic thực tế khỏi các pod v2.0.0 lỗi, trả 100% traffic về cho các pod stable v1.0.0.
        5.  **Thu hồi tài nguyên:** Controller scale down số lượng replica của ReplicaSet canary (v2.0.0) về 0.
        6.  **Trạng thái cuối cùng:** Rollout được đánh dấu trạng thái cuối cùng là `Degraded` và `Aborted`. Hệ thống an toàn, người dùng không còn gặp lỗi.

### Câu 28: *[Tình huống Xung đột Sync Policy giữa ArgoCD và Argo Rollouts]* Một kỹ sư cấu hình ArgoCD quản lý một ứng dụng dùng `Rollout` CRD. Tuy nhiên, khi chỉnh sửa tag image trên Git, ArgoCD lập tức báo lỗi sync và liên tục cố gắng đè lại (overwrite) số lượng replica của stable ReplicaSet, phá hỏng tiến trình Canary đang chia traffic của Rollouts Controller. Hãy phân tích nguyên nhân (do cấu hình auto-sync, prune hoặc thiếu ignoreDifferences) và đưa ra giải pháp khắc phục triệt để.
*   **Gợi ý trả lời:**
    *   **Nguyên nhân:** Khi Rollouts Controller thực hiện chia traffic Canary, nó sẽ tự động thay đổi thuộc tính `spec.replicas` hoặc cấu hình selector của các service/ReplicaSet trong cluster để chia luồng. ArgoCD đọc cluster thấy có sự khác biệt (drift) so với file YAML gốc trên Git và cố gắng ghi đè lại (sync/self-heal) để đưa cluster về đúng Git. Điều này tạo ra xung đột tranh giành quyền kiểm soát tài nguyên giữa ArgoCD và Argo Rollouts.
    *   **Giải pháp khắc phục:**
        1.  Cấu hình `ignoreDifferences` trong file khai báo ArgoCD `Application` để bảo ArgoCD bỏ qua việc so sánh trường `replicas` của Rollout:
            ```yaml
            spec:
              ignoreDifferences:
              - group: argoproj.io
                kind: Rollout
                jsonPointers:
                - /spec/replicas
            ```
        2.  Sử dụng các controller routing chính thức (như NGINX, Istio) để chia traffic thay vì dựa vào việc scale số lượng pod.

### Câu 29: *[Tình huống A/B Testing nâng cao]* Doanh nghiệp muốn chạy thử nghiệm một tính năng mới (chỉ dành cho các request có HTTP Header `X-Beta-User: true`) trên phiên bản canary, còn các request thông thường của khách hàng đại trà vẫn đi vào phiên bản stable. Hãy mô tả giải pháp thiết kế sử dụng Istio VirtualService kết hợp với Argo Rollouts để hiện thực hóa yêu cầu này.
*   **Gợi ý trả lời:**
    *   **Giải pháp thiết kế:**
        1.  Cấu hình Argo Rollouts tích hợp với **Istio traffic routing**. Khai báo tên `VirtualService` trong spec của Rollout.
        2.  Trong file cấu hình Istio `VirtualService`, định nghĩa 2 HTTP routes:
            *   *Route 1 (Beta route):* Kiểm tra điều kiện header `headers: { "X-Beta-User": { "exact": "true" } }`. Trỏ traffic của route này về destination rule target là `api-service-canary`.
            *   *Route 2 (Default route):* Không check header, trỏ toàn bộ traffic về `api-service-stable`.
        3.  Khi Rollout deploy bản mới, các bước `steps` của Rollout sẽ điều phối trọng số traffic của riêng Route 1 (hoặc ta có thể cấu hình bước đầu tiên nhảy thẳng `setHeaderRoute` thay vì `setWeight`). Các request có header beta sẽ được định tuyến chính xác sang pod canary để chạy thử nghiệm A/B mà không ảnh hưởng đến bất kỳ người dùng phổ thông nào.

### Câu 30: *[Tình huống Smoke Test bằng Kubernetes Job]* Trước khi cho phép bất kỳ lượng traffic thực tế nào đi vào Pod canary mới, bạn muốn chạy một loạt các test kiểm thử tự động (smoke tests/integration tests) bằng một Kubernetes Job độc lập. Nếu Job này thành công (exit code 0), traffic mới bắt đầu được shift sang. Hãy thiết kế cấu hình `AnalysisTemplate` sử dụng metric provider `web` hoặc `job` để kích hoạt và kiểm tra kết quả của Kubernetes Job này trong bước đầu tiên của Rollout.
*   **Gợi ý trả lời:**
    *   **Thiết kế cấu hình:** Sử dụng provider `job` trong `AnalysisTemplate` để khởi chạy một Kubernetes Job chạy tích hợp test.
    *   **YAML AnalysisTemplate cấu hình:**
        ```yaml
        apiVersion: argoproj.io/v1alpha1
        kind: AnalysisTemplate
        metadata:
          name: canary-smoke-test
          namespace: platform
        spec:
          metrics:
          - name: run-smoke-test
            provider:
              job:
                spec:
                  template:
                    spec:
                      containers:
                      - name: test-runner
                        image: ghcr.io/example/smoke-tests:v2.0.0
                        command: ["npm", "run", "test:canary"]
                      restartPolicy: Never
        ```
    *   Trong `Rollout` spec, tại bước đầu tiên trước khi chạy `setWeight`, khai báo chạy inline analysis trỏ về template này:
        ```yaml
        steps:
        - analysis:
            templates:
            - templateName: canary-smoke-test # Chạy Job test trước
        - setWeight: 10 # Chỉ đạt 10% traffic sau khi test pass
        ```
    *   *Cơ chế:* Khi bắt đầu rollout, Argo Rollouts tạo ra một `AnalysisRun` chạy Job test này. Nếu Job trả về exit code 0 (thành công), bước test pass và rollout đi tiếp sang bước shift 10% traffic. Nếu Job lỗi (exit code khác 0), rollout lập tức abort, đảm bảo pod lỗi bị cô lập hoàn toàn trước khi tiếp cận người dùng.
