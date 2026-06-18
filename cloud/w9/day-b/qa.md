# Bộ Câu Hỏi Vấn Đáp (Q&A) - Day B: Observability, SLO/SLI và OpenTelemetry

Tài liệu này tổng hợp bộ câu hỏi từ dễ đến khó phục vụ cho việc vấn đáp và đánh giá kiến thức của học viên về chủ đề **Observability, Monitoring, OpenTelemetry, Prometheus, Loki, Grafana, SLO/SLI và SRE**.

---

## 1. Mức độ: DỄ (15 câu)

### Câu 1: Phân biệt sự khác biệt cơ bản giữa Monitoring và Observability.
*   **Gợi ý trả lời:**
    *   **Monitoring (Giám sát):** Trả lời các câu hỏi biết trước (known-unknowns). Ví dụ: kiểm tra CPU có vượt 80% không, error rate có tăng không. Nó dựa trên dashboard và alert cố định để thông báo khi có lỗi xảy ra.
    *   **Observability (Khả năng quan sát):** Cho phép điều tra, trả lời các câu hỏi chưa biết trước (unknown-unknowns) khi xảy ra sự cố lạ mà không cần deploy thêm code. Nó dựa trên việc thu thập dữ liệu phong phú để lập và kiểm chứng các giả thuyết.

### Câu 2: Kể tên 3 trụ cột của Observability và nêu vai trò ngắn gọn của từng trụ cột.
*   **Gợi ý trả lời:**
    *   3 trụ cột gồm:
        1.  **Metrics (Chỉ số):** Số liệu đo lường dạng chuỗi thời gian (time-series), dùng để phát hiện bất thường nhanh chóng và tạo cảnh báo (ví dụ: CPU%, memory, RPS).
        2.  **Logs (Nhật ký):** Các sự kiện có mốc thời gian chi tiết, cho biết chính xác điều gì đã xảy ra tại một thời điểm cụ thể.
        3.  **Traces (Vết yêu cầu):** Bản ghi hành trình của một request đi qua các microservices, giúp xác định nút thắt cổ chai và dịch vụ gây trễ hoặc lỗi.

### Câu 3: Cardinality trong hệ thống metrics là gì? Tại sao high cardinality lại là một vấn đề nghiêm trọng đối với Prometheus?
*   **Gợi ý trả lời:**
    *   **Cardinality** là số lượng tổ hợp nhãn (label values) độc nhất tạo ra các time-series khác nhau trong cơ sở dữ liệu.
    *   **Tại sao nghiêm trọng:** Prometheus lưu mỗi tổ hợp nhãn thành một time-series riêng biệt trong RAM và đĩa. Nếu cardinality quá cao (hàng triệu time-series), Prometheus sẽ bị cạn kiệt RAM (OOM), ghi log WAL quá tải, làm chậm các truy vấn PromQL và có thể gây sập hệ thống.

### Câu 4: Đưa ra 3 ví dụ về nhãn (label) tốt (low cardinality) và 3 ví dụ về nhãn nguy hiểm (high cardinality) khi thiết kế metrics cho một HTTP service.
*   **Gợi ý trả lời:**
    *   **Nhãn tốt (Low cardinality - số lượng giá trị hữu hạn và nhỏ):** `service`, `namespace`, `method` (GET, POST), `status_code` (200, 500).
    *   **Nhãn nguy hiểm (High cardinality - số lượng giá trị vô hạn hoặc cực lớn):** `user_id`, `email`, `request_id`, `session_id`, raw URL chứa ID (ví dụ: `/api/users/12345`).

### Câu 5: OpenTelemetry (OTel) là gì? Nó giải quyết vấn đề gì liên quan đến sự phụ thuộc nhà cung cấp (vendor lock-in)?
*   **Gợi ý trả lời:**
    *   **OpenTelemetry** là một framework mã nguồn mở tiêu chuẩn hóa, cung cấp bộ SDK, API và công cụ (như Collector) để thu thập, xử lý và xuất telemetry data (metrics, logs, traces).
    *   **Giải quyết vendor lock-in:** OTel đóng vai trò như một lớp trung gian chuẩn hóa. Code ứng dụng chỉ cần tích hợp OTel SDK. Phía sau, bạn có thể dễ dàng chuyển đổi nhà cung cấp lưu trữ (từ Datadog sang Prometheus/Tempo, Dynatrace...) chỉ bằng cách sửa cấu hình của OTel Collector mà không cần sửa đổi bất kỳ dòng code nào trong ứng dụng.

### Câu 6: Kể tên 4 thành phần cấu hình chính của OTel Collector pipeline và nhiệm vụ của từng thành phần.
*   **Gợi ý trả lời:**
    *   4 thành phần cấu hình chính:
        1.  **Receivers:** Điểm nhận dữ liệu vào Collector (ví dụ: `otlp` gRPC/HTTP, `prometheus`, `filelog`).
        2.  **Processors:** Xử lý, lọc, gộp hoặc làm giàu dữ liệu trước khi gửi đi (ví dụ: `batch`, `memory_limiter`, `k8sattributes`).
        3.  **Exporters:** Nơi gửi dữ liệu đã xử lý đến các hệ thống lưu trữ/phân tích (ví dụ: `prometheusremotewrite`, `otlp/tempo`, `loki`).
        4.  **Connectors:** Thành phần kết nối trung gian giúp chuyển đổi dữ liệu từ pipeline này sang pipeline khác (ví dụ: chuyển đổi traces thành metrics).

### Câu 7: Phân biệt Auto-instrumentation và Manual instrumentation khi triển khai OpenTelemetry trong ứng dụng.
*   **Gợi ý trả lời:**
    *   **Auto-instrumentation (Đo lường tự động):** Sử dụng các agent hoặc thư viện tiền tải (preload) của OTel để tự động bắt các metrics/traces của các framework HTTP (Express, Spring...), thư viện database, message queue mà không cần viết code.
    *   **Manual instrumentation (Đo lường thủ công):** Nhà phát triển tự viết code sử dụng OTel SDK để tạo ra các custom span, đo lường các logic nghiệp vụ đặc thù (ví dụ: đo thời gian xử lý thuật toán thanh toán).

### Câu 8: Context Propagation trong distributed tracing là gì? Tại sao nó lại cần thiết?
*   **Gợi ý trả lời:**
    *   **Context Propagation** là cơ chế truyền thông tin ngữ cảnh của trace (như `trace_id` và `span_id`) xuyên suốt hành trình của request qua nhiều microservices khác nhau thông qua HTTP/gRPC headers.
    *   **Tại sao cần thiết:** Nếu không truyền context, mỗi service nhận request sẽ tự tạo ra một `trace_id` mới. Hệ thống sẽ có các trace rời rạc và không thể liên kết chúng lại thành một hành trình request hoàn chỉnh (End-to-End Trace).

### Câu 9: Trình bày cấu trúc của header `traceparent` theo chuẩn W3C TraceContext.
*   **Gợi ý trả lời:**
    *   Header `traceparent` có định dạng phân tách bằng dấu gạch ngang gồm 4 phần:
        `version` - `trace_id` - `parent_span_id` - `trace_flags`
    *   Ví dụ: `00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01`
        *   `00`: Phiên bản định dạng (version).
        *   `4bf92f3577b34da6a3ce929d0e0e4736`: ID duy nhất của toàn bộ trace (16 bytes).
        *   `00f067aa0ba902b7`: ID của span cha trực tiếp gửi request (8 bytes).
        *   `01`: Trace flags, chỉ định trace này có được lấy mẫu (sample) hay không.

### Câu 10: Phân biệt Head-based sampling và Tail-based sampling trong distributed tracing.
*   **Gợi ý trả lời:**
    *   **Head-based sampling:** Quyết định lấy mẫu (giữ lại hay bỏ trace) được đưa ra ngay khi request vừa bắt đầu (tại gateway hoặc service đầu tiên). Đơn giản, hiệu năng cao nhưng dễ làm mất các trace lỗi xuất hiện ở cuối hành trình.
    *   **Tail-based sampling:** Quyết định lấy mẫu được đưa ra sau khi toàn bộ hành trình của request đã hoàn thành. Cho phép lọc thông minh (ví dụ: giữ lại 100% trace bị lỗi hoặc chạy chậm, loại bỏ trace thành công), nhưng tốn tài nguyên do Collector phải lưu trữ tạm thời toàn bộ span trong RAM để phân tích trước khi đưa ra quyết định.

### Câu 11: Kể tên 4 loại metric cơ bản trong Prometheus và mô tả ngắn gọn một trường hợp sử dụng cho mỗi loại.
*   **Gợi ý trả lời:**
    *   4 loại metric cơ bản:
        1.  **Counter:** Chỉ số chỉ tăng (hoặc reset về 0). Dùng để đếm tổng số request, tổng số lỗi.
        2.  **Gauge:** Chỉ số có thể lên và xuống. Dùng để đo CPU hiện tại, dung lượng RAM, số lượng queue.
        3.  **Histogram:** Đo lường phân phối tần suất (ví dụ: latency). Dùng để tính toán percentile (p95, p99) thời gian phản hồi.
        4.  **Summary:** Tương tự histogram nhưng tính toán percentile ngay tại phía client ứng dụng (app). Ít dùng hơn histogram vì không thể gộp (aggregate) kết quả từ nhiều container lại một cách chính xác.

### Câu 12: Trong PromQL, sự khác biệt giữa hàm `rate()` và `irate()` là gì? Khi nào nên dùng hàm nào?
*   **Gợi ý trả lời:**
    *   **`rate()`:** Tính toán tốc độ tăng trung bình trên giây của counter trong suốt cửa sổ thời gian (ví dụ `[5m]`). Phù hợp để làm cấu hình Alert vì nó mượt mà và phản ánh xu hướng ổn định.
    *   **`irate()`:** Tính toán tốc độ tăng tức thời dựa trên 2 điểm dữ liệu gần nhất trong cửa sổ thời gian. Rất nhạy với các biến động nhanh, phù hợp cho dashboard debug ngắn hạn.

### Câu 13: Định nghĩa các khái niệm: SLI, SLO, SLA và mối quan hệ giữa chúng.
*   **Gợi ý trả lời:**
    *   **SLI (Service Level Indicator):** Chỉ số đo lường thực tế, ví dụ: *"Tỷ lệ request thành công thực tế đạt 99.95%"*.
    *   **SLO (Service Level Objective):** Mục tiêu nội bộ hướng tới, ví dụ: *"Tỷ lệ request thành công phải đạt >= 99.9% trong 30 ngày"*.
    *   **SLA (Service Level Agreement):** Cam kết pháp lý/thương mại với khách hàng kèm theo điều khoản phạt, ví dụ: *"Tỷ lệ thành công phải đạt >= 99.5%, nếu không sẽ đền bù 10% chi phí"*.
    *   **Mối quan hệ:** SLI dùng để đo lường xem hệ thống có đạt SLO hay không; và SLO luôn được thiết lập khắt khe hơn SLA (`SLI > SLO > SLA`) để tạo vùng đệm an toàn.

### Câu 14: Error Budget là gì? Nếu một dịch vụ có SLO availability là 99.9% trong 30 ngày, hãy giải thích ý nghĩa của chỉ số này đối với đội ngũ phát triển sản phẩm.
*   **Gợi ý trả lời:**
    *   **Error Budget** là ngân sách lỗi được phép xảy ra, bằng `1 - SLO`. Với SLO 99.9%, Error Budget là 0.1%.
    *   **Ý nghĩa:** Nó đại diện cho ranh giới giữa sự đổi mới và tính ổn định. Khi hệ thống còn nhiều ngân sách lỗi, đội phát triển được phép release tính năng mới nhanh hơn, chấp nhận rủi ro. Khi ngân sách lỗi bị cạn kiệt (hoặc về gần 0), đội phát triển phải dừng release và tập trung sửa lỗi, tối ưu hóa hệ thống để hồi phục ngân sách.

### Câu 15: LogQL trong Grafana Loki dùng để làm gì? Viết một câu lệnh LogQL đơn giản để lọc các log chứa từ khóa "error" của service "api-service".
*   **Gợi ý trả lời:**
    *   **LogQL** là ngôn ngữ truy vấn của Grafana Loki, có cú pháp tương tự PromQL nhưng dùng để truy vấn logs dựa trên nhãn (labels) và bộ lọc nội dung text.
    *   **Câu lệnh LogQL:**
        ```logql
        {service_name="api-service", namespace="platform"} |= "error"
        ```

---

## 2. Mức độ: TRUNG BÌNH (10 câu)

### Câu 16: Viết một câu truy vấn PromQL để tính toán latency p99 (percentile 99) trong cửa sổ 5 phút từ một metric histogram có tên `http_request_duration_seconds_bucket` cho service `api-service`, nhóm theo label `le`. Giải thích ý nghĩa của các thành phần trong câu truy vấn đó.
*   **Gợi ý trả lời:**
    *   **Câu truy vấn PromQL:**
        ```promql
        histogram_quantile(
          0.99,
          sum by (le) (
            rate(http_request_duration_seconds_bucket{service="api-service"}[5m])
          )
        )
        ```
    *   **Giải thích các thành phần:**
        *   `rate(...[5m])`: Tính toán tốc độ tăng trung bình mỗi giây của từng bucket (`le`) trong 5 phút qua.
        *   `sum by (le) (...)`: Cộng gộp (aggregate) giá trị tốc độ của các bucket có cùng nhãn `le` trên toàn bộ các instances của `api-service`.
        *   `histogram_quantile(0.99, ...)`: Tính toán phân vị thứ 99, ước lượng xem 99% số request có thời gian xử lý nhỏ hơn bao nhiêu giây.

### Câu 17: Trình bày sự khác biệt giữa Prometheus Local TSDB (kèm WAL) và cơ chế Remote Write. Khi nào nên cấu hình Remote Write trong thực tế?
*   **Gợi ý trả lời:**
    *   **Prometheus Local TSDB:** Lưu trữ dữ liệu metrics cục bộ trên đĩa của Prometheus server, sử dụng WAL (Write-Ahead Log) để chống mất dữ liệu khi crash. Tốc độ rất nhanh nhưng dung lượng lưu trữ giới hạn (thường chỉ giữ dữ liệu từ vài ngày đến 15 ngày).
    *   **Remote Write:** Cơ chế Prometheus tự động stream các metrics thu thập được sang một hệ thống lưu trữ bên ngoài (như Thanos, Cortex, Grafana Mimir, AWS Managed Prometheus).
    *   **Khi nào cấu hình:** Khi cần lưu trữ metrics dài hạn (nhiều tháng, nhiều năm) để phân tích xu hướng, hoặc khi cần xây dựng hệ thống giám sát có tính sẵn sàng cao (High Availability), gom dữ liệu từ nhiều Prometheus cluster về một nơi quản lý tập trung.

### Câu 18: Burn Rate là gì? Viết công thức tính Burn Rate dựa trên observed error ratio và SLO target. Giải thích ý nghĩa của Burn Rate = 14 so với Burn Rate = 1.
*   **Gợi ý trả lời:**
    *   **Burn Rate** là tốc độ tiêu thụ ngân sách lỗi (Error Budget).
    *   **Công thức:**
        $$\text{Burn Rate} = \frac{\text{Observed Error Ratio}}{\text{Allowed Error Ratio (1 - SLO)}}$$
    *   **Ý nghĩa:**
        *   `Burn Rate = 1`: Bạn đang tiêu thụ ngân sách lỗi ở tốc độ vừa khít để hết sạch sau đúng chu kỳ SLO (ví dụ: hết sạch 0.1% lỗi sau đúng 30 ngày).
        *   `Burn Rate = 14`: Tốc độ tiêu thụ nhanh gấp 14 lần tốc độ cho phép. Nghĩa là bạn sẽ tiêu hết sạch 100% ngân sách lỗi chỉ trong vòng khoảng 51 giờ (2.1 ngày) nếu lỗi tiếp tục duy trì ở mức này.

### Câu 19: Giải thích cơ chế cảnh báo Multi-window multi-burn-rate theo khuyến nghị của Google SRE. Tại sao nó lại giải quyết được nhược điểm của việc cấu hình alert dựa trên cửa sổ thời gian đơn lẻ (single-window alert)?
*   **Gợi ý trả lời:**
    *   **Cơ chế:** Kết hợp đồng thời 2 cửa sổ thời gian khác nhau để đưa ra quyết định cảnh báo:
        *   *Cửa sổ ngắn (Fast burn):* Ví dụ cửa sổ 1 giờ, ngưỡng burn rate > 14, thời gian chờ (pending) 5 phút. Dùng để phát hiện các sự cố nghiêm trọng (ví dụ sập hoàn toàn hệ thống) để gọi điện on-call ngay lập tức.
        *   *Cửa sổ dài (Slow burn):* Ví dụ cửa sổ 6 giờ, ngưỡng burn rate > 6, thời gian chờ 30 phút. Dùng để phát hiện các lỗi nhỏ, rò rỉ âm thầm nhưng kéo dài.
    *   **Giải quyết nhược điểm:**
        *   Nếu chỉ dùng cửa sổ ngắn: Dễ bị cảnh báo giả (nhiễu) khi có spike tăng đột biến trong vài phút rồi tự hết.
        *   Nếu chỉ dùng cửa sổ dài: Thời gian kích hoạt cảnh báo quá chậm khi có sự cố nghiêm trọng, hoặc sau khi sự cố đã được sửa, alert vẫn tiếp tục bị kẹt (firing) do dữ liệu lỗi cũ vẫn nằm trong cửa sổ dài.

### Câu 20: So sánh hai phương pháp thiết kế dashboard phổ biến: USE method (thường dùng cho hạ tầng) và RED method (thường dùng cho web/API services). Hãy liệt kê các chỉ số tương ứng của từng phương pháp.
*   **Gợi ý trả lời:**
    *   **USE Method (Dành cho tài nguyên phần cứng/hạ tầng như Node, Disk, RAM):**
        *   **U**tilization: Phần trăm tài nguyên đang được sử dụng (ví dụ: CPU load 70%).
        *   **S**aturation: Độ nghẽn/hàng đợi của tài nguyên (ví dụ: CPU run queue length, disk IO queue).
        *   **E**rrors: Số lượng lỗi xảy ra trên tài nguyên (ví dụ: network interface drops).
    *   **RED Method (Dành cho dịch vụ ứng dụng/request-driven services):**
        *   **R**ate: Số lượng request/giây đi vào hệ thống (Throughput).
        *   **E**rrors: Số lượng request bị lỗi hoặc tỷ lệ lỗi (Error Rate).
        *   **D**uration: Thời gian xử lý request (Latency).

### Câu 21: Phân biệt kiến trúc và mô hình index của Grafana Loki so với Elasticsearch/EFK stack. Tại sao Loki lại có chi phí vận hành rẻ hơn nhiều?
*   **Gợi ý trả lời:**
    *   **Elasticsearch:** Thực hiện đánh chỉ mục toàn văn (full-text index) trên toàn bộ nội dung của log. Tìm kiếm rất nhanh và mạnh mẽ nhưng tốn cực kỳ nhiều RAM và dung lượng đĩa để lưu trữ file index.
    *   **Grafana Loki:** Chỉ thực hiện đánh chỉ mục trên các nhãn (labels) đi kèm với log stream (tương tự cách Prometheus làm với metrics). Bản thân nội dung log được gom thành các chunk nén và lưu trực tiếp lên Object Storage rẻ tiền (S3, GCS).
    *   **Tại sao rẻ hơn:** Vì dung lượng index của Loki cực kỳ nhỏ (chỉ chiếm dưới 1% so với dữ liệu log thật), giảm thiểu tối đa RAM cho index và tận dụng được Object Storage giá rẻ thay vì các ổ SSD hiệu năng cao đắt đỏ như Elasticsearch.

### Câu 22: Exemplar trong hệ thống observability là gì? Nó giúp kết nối metrics và traces như thế nào trong Grafana?
*   **Gợi ý trả lời:**
    *   **Exemplar** là một tham chiếu (thường là `trace_id` hoặc `span_id`) được đính kèm trực tiếp vào một điểm dữ liệu metric cụ thể tại thời điểm nó được ghi nhận.
    *   **Cách kết nối:** Khi vẽ biểu đồ latency bằng Prometheus metric trong Grafana, nếu bật Exemplar, các điểm chấm nhỏ sẽ xuất hiện trên đồ thị. Khi di chuột vào điểm chấm đó, Grafana sẽ hiển thị `trace_id` của chính request cụ thể đã gây ra latency đó. Người dùng click vào link để mở trực tiếp distributed trace chi tiết trên Tempo/Jaeger, giúp đi từ bức tranh tổng quát (metrics) sang chi tiết lỗi (trace) chỉ bằng 1 cú click.

### Câu 23: Tại sao trong cấu hình OTel Collector, processor `batch` và `memory_limiter` lại luôn được khuyến nghị sử dụng ở hầu hết các môi trường production?
*   **Gợi ý trả lời:**
    *   **`batch` processor:** Gom các metrics/logs/traces lại thành các lô (batches) trước khi gửi đi thay vì gửi đơn lẻ từng request. Việc này giúp nén dữ liệu tốt hơn, giảm tải số lượng network requests và tăng hiệu năng xử lý của backend nhận phía sau.
    *   **`memory_limiter` processor:** Giám sát liên tục dung lượng RAM mà OTel Collector đang sử dụng. Nếu RAM vượt quá ngưỡng cấu hình (ví dụ do traffic tăng đột biến), processor này sẽ tự động drop bớt dữ liệu hoặc kích hoạt GC để tránh tình trạng Collector bị hệ điều hành kill vì lỗi Out Of Memory (OOMKilled), đảm bảo tính ổn định sống còn của Collector.

### Câu 24: Một ứng dụng Node.js chạy trong Kubernetes ghi log ra stdout dưới dạng JSON. Làm thế nào để OTel Collector (hoặc Promtail) thu thập, parse các log này, và map chúng vào Loki với các label metadata của Kubernetes như namespace, pod name, container name?
*   **Gợi ý trả lời:**
    *   **Bước 1: Thu thập:** Sử dụng OTel Collector với `filelog` receiver trỏ tới thư mục log của các container trên node (`/var/log/pods/*/*/*.log`).
    *   **Bước 2: Parse:** Dùng `json_parser` hoặc `regex_parser` trong pipeline của receiver để parse chuỗi log thô thành các trường dữ liệu có cấu trúc (level, message, trace_id...).
    *   **Bước 3: Map Metadata:** Sử dụng `k8sattributes` processor. Processor này sẽ nói chuyện với Kubernetes API Server, dựa vào thông tin IP nguồn hoặc cấu trúc tên file log để tự động đính kèm các thuộc tính của Kubernetes (như `k8s.namespace.name`, `k8s.pod.name`, `k8s.container.name`) thành resource attributes của log.
    *   **Bước 4: Gửi:** Exporter loki sẽ map các attributes này thành các Loki labels tương ứng khi gửi lên Loki server.

### Câu 25: Trình bày cách thức hoạt động của `promtool` để kiểm tra cú pháp và tính đúng đắn của các cấu hình rules (`check rules`) và scrape configuration (`check config`).
*   **Gợi ý trả lời:**
    *   `promtool check config <config-file>`: Quét file yaml cấu hình của Prometheus để phát hiện các lỗi cú pháp cấu trúc, sai định dạng thời gian (ví dụ `scrape_interval: 30`), trùng lặp job name, cấu hình relabeling sai định dạng regex hoặc thiếu các trường bắt buộc.
    *   `promtool check rules <rules-file>`: Kiểm tra cấu trúc của file recording/alerting rules. Nó đảm bảo các biểu thức logic PromQL (`expr`) hợp lệ về mặt cú pháp, các label và annotation được khai báo đúng định dạng, các trường bắt buộc như `alert`, `expr`, `for` đều có mặt. 
    *   *Lưu ý:* `promtool` chỉ kiểm tra cú pháp tĩnh offline; nó không thể kiểm tra xem target IP có sống không hoặc metric đó có thực sự tồn tại trong database hay không.

---

## 3. Mức độ: THỰC TẾ / TÌNH HUỐNG (5 câu)

### Câu 26: *[Tình huống Out of Memory]* Prometheus server trong cluster của bạn liên tục bị crash với lỗi OOM (Out Of Memory) sau mỗi vài ngày. Hãy trình bày quy trình sử dụng `promtool tsdb analyze` để điều tra nguyên nhân và các biện pháp xử lý từ cấu hình relabeling đến code của ứng dụng.
*   **Gợi ý trả lời:**
    *   **Quy trình điều tra:**
        1.  Tạo một bản copy của thư mục dữ liệu Prometheus TSDB (`prometheus-data`) ra một môi trường local để tránh xung đột ghi đè.
        2.  Chạy lệnh `promtool tsdb analyze ./prometheus-data` để phân tích cấu trúc index.
        3.  Đọc kết quả ở mục: "Label names by value count" (để tìm label có quá nhiều giá trị khác nhau) và "Highest cardinality metric names" (để tìm metric tạo ra nhiều series nhất).
    *   **Biện pháp xử lý:**
        *   *Phía ứng dụng (Code):* Nếu phát hiện lập trình viên vô tình chèn `user_id` hoặc `uuid` vào label của metric, yêu cầu gỡ bỏ ngay lập tức, chuyển các thông tin này vào log thay vì metric.
        *   *Phía Prometheus (Relabeling):* Trong khi chờ sửa code, thêm cấu hình `metric_relabel_configs` dạng `labeldrop` hoặc `labelkeep` trong file cấu hình scrape của Prometheus để lọc bỏ các label nguy hiểm trước khi ghi vào database:
            ```yaml
            metric_relabel_configs:
            - source_labels: [user_id]
              regex: "(.*)"
              action: labeldrop
            ```

### Câu 27: *[Tình huống Thiết kế SLO cho Latency]* Hệ thống API thanh toán có yêu cầu cực kỳ khắt khe: "95% request phải được xử lý dưới 200ms". Hãy thiết kế cấu hình Recording Rule trong Prometheus để tính toán SLI latency này, đặt tên rule theo đúng quy ước SRE và viết một Alerting Rule cảnh báo nếu burn rate của latency trong 1 giờ vượt quá 14 (tương ứng tiêu thụ 2% error budget trong 1 giờ).
*   **Gợi ý trả lời:**
    *   **Bước 1: Cấu hình Recording Rule (tính tỷ lệ request đạt chuẩn):**
        ```yaml
        groups:
        - name: payment-latency-sli
          rules:
          - record: service:http_requests_under_200ms:rate5m
            expr: sum(rate(http_request_duration_seconds_bucket{service="payment-service", le="0.2"}[5m]))
          - record: service:http_requests:rate5m
            expr: sum(rate(http_request_duration_seconds_count{service="payment-service"}[5m]))
          # Tính toán SLI (tỷ lệ thành công):
          - record: service:latency_sli_ratio:rate5m
            expr: service:http_requests_under_200ms:rate5m / service:http_requests:rate5m
        ```
    *   **Bước 2: Tính toán Burn Rate (SLO target = 95% -> allowed failure ratio = 0.05):**
        $$\text{Failure ratio} = 1 - \text{SLI}$$
        $$\text{Burn Rate} = \frac{1 - \text{service:latency_sli_ratio:rate5m}}{0.05}$$
        ```yaml
          - record: service:latency_burn_rate:1h
            expr: (1 - service:latency_sli_ratio:rate5m) / 0.05
        ```
    *   **Bước 3: Cấu hình Alerting Rule:**
        ```yaml
          - alert: PaymentLatencyFastBurn
            expr: service:latency_burn_rate:1h > 14
            for: 2m
            labels:
              severity: critical
            annotations:
              summary: "Payment API đang vi phạm nghiêm trọng SLO Latency (Burn Rate > 14)"
        ```

### Câu 28: *[Tình huống Distributed Tracing]* Hệ thống của bạn gồm 3 microservices viết bằng 3 ngôn ngữ khác nhau: Service A (Go) gọi Service B (Java), Service B gọi Service C (Node.js). Bạn phát hiện ra khi xem trên Grafana Tempo, trace bị đứt gãy thành 3 trace riêng lẻ thay vì 1 trace xuyên suốt. Hãy chỉ ra nguyên nhân và cách khắc phục chi tiết ở code/config của các service này.
*   **Gợi ý trả lời:**
    *   **Nguyên nhân:** Đứt gãy Context Propagation. Service A gửi đi không kèm trace header, hoặc Service B nhận được nhưng không trích xuất (inject/extract) header để truyền tiếp cho Service C. Có thể do các service dùng các định dạng header không tương thích (ví dụ Service A gửi chuẩn W3C `traceparent` nhưng Service B lại mong đợi chuẩn Zipkin `b3`).
    *   **Cách khắc phục:**
        1.  **Thống nhất định dạng (Propagator):** Cấu hình toàn bộ SDK của 3 service sử dụng chung chuẩn W3C TraceContext (mặc định của OTel).
        2.  **Sửa code Service A (Go):** Đảm bảo khi gọi HTTP Client sang Service B phải truyền context của Go đi kèm:
            ```go
            req, _ := http.NewRequestWithContext(ctx, "GET", "http://service-b", nil)
            ```
        3.  **Sửa code Service B (Java):** Đảm bảo sử dụng spring-web OTel instrumentation hoặc nếu viết thủ công phải cấu hình interceptor để tự động trích xuất header từ request đi vào và đưa vào span context hiện tại trước khi gọi Service C.
        4.  **Sửa code Service C (Node.js):** Kích hoạt OTel HTTP plugin để nó tự động đọc header `traceparent` từ incoming request và thiết lập làm parent span.

### Câu 29: *[Tình huống Tail-based Sampling]* Hệ thống xử lý 20,000 RPS. Bạn muốn lưu lại 100% các trace bị lỗi (HTTP status code >= 500 hoặc latency > 2s) nhưng chỉ muốn lưu 1% các trace thành công thông thường để tiết kiệm dung lượng lưu trữ của Tempo. Hãy cấu hình một pipeline OTel Collector sử dụng tail-based sampling processor để đáp ứng yêu cầu này.
*   **Gợi ý trả lời:**
    *   Cấu hình `tail_sampling` processor trong file `collector-config.yaml`:
        ```yaml
        processors:
          tail_sampling:
            decision_wait: 10s # Đợi 10 giây để thu thập đủ các span của một trace trước khi quyết định
            num_traces: 10000
            expected_new_traces_per_sec: 2000
            policies:
              # Chính sách 1: Lưu 100% các trace có lỗi (HTTP >= 500)
              - name: error-conditions
                type: status_code
                status_code: {status_codes: [ERROR]}
              # Chính sách 2: Lưu 100% các trace chạy quá 2 giây (2000ms)
              - name: slow-latency-conditions
                type: latency
                latency: {threshold_ms: 2000}
              # Chính sách 3: Lấy mẫu 1% (0.01) các request thành công thông thường
              - name: success-probabilistic
                type: probabilistic
                probabilistic: {sampling_percentage: 1.0}
        ```
    *   Sau đó, đưa `tail_sampling` vào danh sách `processors` của pipeline `traces` trong phần `service.pipelines.traces`.

### Câu 30: *[Tình huống Log Cardinality Explosion]* Đội ứng dụng đã thêm label `request_id` trực tiếp vào label set của Loki. Sau vài ngày, Loki bị nghẽn và không thể query được do số lượng stream tăng vọt (cardinality explosion). Hãy giải thích tại sao hành động này gây lỗi và đưa ra giải pháp sửa đổi cấu hình thu thập log hoặc câu truy vấn LogQL để vẫn có thể tìm log theo `request_id` mà không làm hỏng Loki.
*   **Gợi ý trả lời:**
    *   **Tại sao gây lỗi:** Trong Loki, mỗi tổ hợp nhãn (label set) duy nhất tạo ra một log stream. Do `request_id` là giá trị độc nhất cho mỗi request (cardinality vô hạn), việc đưa nó làm label khiến Loki phải tạo ra hàng triệu stream nhỏ, dẫn đến phình to kích thước file index trên RAM/Disk, làm cạn kiệt tài nguyên Loki server.
    *   **Giải pháp khắc phục:**
        1.  **Gỡ bỏ label:** Sửa cấu hình Promtail/OTel Collector để loại bỏ `request_id` khỏi danh sách labels gửi lên Loki. Hãy để thông tin `request_id` nằm trong phần thân của log (payload JSON).
        2.  **Sử dụng LogQL Parser:** Khi cần truy vấn log theo `request_id`, thay vì query dạng label `{request_id="abc"}`, ta sẽ sử dụng bộ lọc text hoặc parser của LogQL:
            *   *Cách 1 (Filter text đơn giản):*
                ```logql
                {service_name="api-service"} |= "abc-request-id-123"
                ```
            *   *Cách 2 (Parser JSON chuyên nghiệp nếu log ghi dạng JSON):*
                ```logql
                {service_name="api-service"} | json | request_id = "abc-request-id-123"
                ```
            Cách này giúp Loki tìm kiếm trực tiếp trong các block log đã nén mà không cần tạo index riêng cho `request_id`, bảo vệ hiệu năng của hệ thống.
