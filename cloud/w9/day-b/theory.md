# Ngày B - Lý thuyết: Observability, SLO/SLI và OpenTelemetry

## 0. Cách dùng tài liệu này

Đọc `theory.md` để hiểu khái niệm, dùng `commands.md` để luyện công cụ, rồi làm `lab.md` để dựng stack gồm Prometheus, Grafana, Loki, Tempo, OTel Collector và ứng dụng `api-service`. Ngày B tạo nền cho Ngày C: các recording rule burn rate ở đây sẽ được Argo Rollouts dùng làm tín hiệu canary.

## 1. Observability và Monitoring khác nhau thế nào?

Ẩn dụ: Monitoring giống bảng đèn cảnh báo trong xe hơi: bạn biết trước các câu hỏi cần hỏi như "động cơ có quá nóng không?". Observability giống hộp đen máy bay: khi có sự cố lạ, bạn có đủ dữ liệu để hỏi câu mới mà không cần cài thêm cảm biến.

Định nghĩa ngắn:

- Monitoring: bạn biết trước câu hỏi và tạo cảnh báo/dashboard cho câu hỏi đó.
- Observability: hệ thống phát ra đủ dữ liệu để bạn điều tra các câu hỏi mới mà chưa dự đoán trước.

```text
Monitoring

Câu hỏi biết trước -> metric/alert cố định -> cảnh báo

Observability

Sự cố mới -> truy vấn dữ liệu đã thu thập -> giả thuyết -> kiểm chứng
```

> Vì sao điều này quan trọng?
> Production luôn có lỗi mới. Nếu chỉ monitoring các câu hỏi cũ, bạn sẽ thấy "có lỗi" nhưng không biết lỗi nằm ở đâu hoặc vì sao.

### Ba trụ cột: metrics, logs, traces

Ẩn dụ: Khi khách hàng nói đơn hàng chậm, bạn cần ba loại bằng chứng. Metrics cho biết "đang chậm thật không?", logs cho biết "đã xảy ra chuyện gì?", traces cho biết "chậm ở service nào trong hành trình request?".

| Trụ cột | Trả lời câu hỏi | Ưu điểm | Chi phí | Ví dụ |
| --- | --- | --- | --- | --- |
| Metrics | Có gì bất thường? | Nhanh, rẻ, dễ alert | Mất chi tiết từng request | Error rate tăng từ 0.2% lên 5% |
| Logs | Chính xác chuyện gì xảy ra? | Chi tiết, dễ đọc sự kiện | Tốn lưu trữ, query chậm nếu quá nhiều | `payment declined` với order id |
| Traces | Request đi qua đâu và chậm ở đâu? | Tốt cho microservices | Cần instrumentation và sampling | Span database mất 800ms |

```text
Một request đi qua 3 service

User
 |
 v
api-service ---------> order-service ---------> payment-service
 | metrics: R,E,D       | metrics: R,E,D        | metrics: R,E,D
 | logs: JSON event     | logs: JSON event      | logs: JSON event
 | trace span A         | trace span B          | trace span C
 |
 v
Trace tổng: A -> B -> C, cùng trace_id
```

> Hiểu lầm thường gặp:
> "Có log là đủ observability" là sai. Log chi tiết nhưng khó alert ở quy mô lớn. Metrics, logs và traces bổ sung cho nhau.

### Cardinality

Ẩn dụ: Một thư viện sắp sách theo thể loại sẽ dễ tìm. Nếu sắp theo số căn cước của từng độc giả từng mượn sách, số ngăn kệ sẽ nổ tung.

Định nghĩa kỹ thuật: Cardinality là số tổ hợp label khác nhau tạo ra time series. Trong Prometheus, metric name cộng label set tạo thành một time series riêng.

```text
Metric tốt:
http_requests_total{service="api-service",status_code="200"}
http_requests_total{service="api-service",status_code="500"}

Metric xấu:
http_requests_total{service="api-service",user_id="u-123456789"}
http_requests_total{service="api-service",user_id="u-987654321"}
...
hàng triệu time series
```

Nhãn tốt thường có ít giá trị:

- `service`
- `namespace`
- `method`
- `status_code`
- `route`

Nhãn nguy hiểm thường có rất nhiều giá trị:

- `user_id`
- `email`
- `request_id`
- `session_id`
- raw URL chứa ID

> Vì sao điều này quan trọng?
> High cardinality làm Prometheus tốn RAM, tăng dung lượng WAL, query chậm và có thể crash. Thiết kế label là quyết định kiến trúc, không chỉ là chi tiết code.

## 2. OpenTelemetry - chuẩn instrumentation chung

Trước OpenTelemetry, mỗi vendor observability có SDK riêng. Chuyển từ Datadog sang Grafana Tempo hoặc New Relic thường đồng nghĩa sửa code nhiều nơi. OpenTelemetry giải quyết bằng một chuẩn chung.

Ẩn dụ: OTel giống USB-C cho observability. Ứng dụng nói một chuẩn, còn phía sau bạn có thể cắm vào nhiều backend khác nhau.

```text
Ứng dụng
  |
  | SDK tạo metrics, logs, traces
  v
Exporter trong app
  |
  v
OTel Collector
  |
  +--> Prometheus / Mimir / Thanos
  +--> Loki
  +--> Tempo
  +--> Datadog / New Relic
```

> Vì sao điều này quan trọng?
> OTel giảm vendor lock-in và chuẩn hóa cách đặt tên dữ liệu. Đội app không cần học từng SDK vendor.

### OTel Collector

Ẩn dụ: Collector giống trung tâm phân loại bưu kiện. Bưu kiện đi vào từ nhiều cửa, được dán nhãn/lọc/gộp, rồi gửi đến nhiều nơi.

Các thành phần:

- Receivers: cửa nhận dữ liệu, ví dụ `otlp`, `prometheus`, `filelog`.
- Processors: xử lý dữ liệu, ví dụ `batch`, `memory_limiter`, `k8sattributes`.
- Exporters: nơi gửi dữ liệu đi, ví dụ `prometheusremotewrite`, `loki`, `otlp/tempo`.
- Connectors: nối pipeline này sang pipeline khác khi cần chuyển dạng dữ liệu.

```text
OTel Collector pipeline

receivers
  otlp
  prometheus
  filelog
     |
     v
processors
  memory_limiter -> k8sattributes -> batch
     |
     v
exporters
  prometheusremotewrite
  otlp/tempo
  loki
```

> Hiểu lầm thường gặp:
> Collector không thay thế Prometheus, Loki hay Tempo. Nó là lớp thu thập, xử lý và chuyển tiếp dữ liệu đến backend.

### Auto-instrumentation và manual instrumentation

Ẩn dụ: Auto-instrumentation giống camera an ninh tự lắp ở cửa ra vào, ghi lại luồng chung. Manual instrumentation giống bạn đặt thêm camera trong két sắt vì đó là phần nghiệp vụ quan trọng.

- Auto-instrumentation: thêm agent hoặc preload package để tự tạo span cho HTTP, DB, queue.
- Manual instrumentation: code tự tạo span/metric cho logic nghiệp vụ.

Ví dụ Node.js trước khi thêm span:

```javascript
app.get('/api/orders', async (req, res) => {
  const orders = await loadOrders();
  res.json({ orders });
});
```

Sau khi thêm span thủ công:

```javascript
app.get('/api/orders', async (req, res) => {
  const span = tracer.startSpan('orders.list');
  span.setAttribute('service.name', 'api-service');
  const orders = await loadOrders();
  span.end();
  res.json({ orders });
});
```

```text
Auto span:    HTTP GET /api/orders
Manual span:        orders.list
Manual span:             db.query.orders
```

> Vì sao điều này quan trọng?
> Auto-instrumentation cho bạn baseline nhanh. Manual instrumentation giúp giải thích điều người dùng thật sự quan tâm, ví dụ tạo đơn hàng, thanh toán, kiểm tồn kho.

### Context propagation

Ẩn dụ: Một kiện hàng đi qua nhiều kho cần cùng mã tracking. Nếu mỗi kho tự tạo mã mới, bạn không nối được hành trình.

Định nghĩa kỹ thuật: Context propagation truyền `trace_id` và metadata qua header HTTP/gRPC để các service khác nhau ghi span vào cùng trace.

W3C TraceContext dùng header `traceparent`:

```text
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01

00                                version
4bf92f3577b34da6a3ce929d0e0e4736  trace_id
00f067aa0ba902b7                  parent_span_id
01                                trace flags
```

```text
api-service tạo trace_id
        |
        v
order-service nhận traceparent và tạo span con
        |
        v
payment-service nhận cùng trace_id và tạo span con
```

> Vì sao điều này quan trọng?
> Không có context propagation, distributed tracing chỉ còn nhiều mảnh rời rạc và không trả lời được request chậm ở đâu.

### Sampling

Ẩn dụ: Bạn không thể lưu video 4K của mọi camera mãi mãi. Bạn chọn lưu toàn bộ đoạn có báo động, còn đoạn bình thường chỉ lấy mẫu.

- Head-based sampling: quyết định giữ hay bỏ ngay khi trace bắt đầu. Nhanh và đơn giản, nhưng có thể bỏ mất trace lỗi.
- Tail-based sampling: quyết định sau khi trace kết thúc. Thông minh hơn vì thấy kết quả cuối, nhưng cần collector giữ dữ liệu tạm và phức tạp hơn.

```text
Head-based
request bắt đầu -> quyết định sample -> xử lý request

Tail-based
request bắt đầu -> thu span tạm -> thấy lỗi/chậm -> quyết định giữ
```

> Vì sao điều này quan trọng?
> Sampling sai có thể làm bạn mất đúng trace cần điều tra. Service quan trọng thường giữ toàn bộ error trace và chỉ sample request thành công.

## 3. Prometheus - metrics để xây SLO

Ẩn dụ: Prometheus giống nhân viên đi từng máy đo trong nhà máy mỗi 30 giây, ghi số vào sổ, rồi cho bạn hỏi "trong 5 phút vừa rồi tốc độ lỗi là bao nhiêu?".

Định nghĩa kỹ thuật: Prometheus scrape endpoint metrics, lưu time series, cho query bằng PromQL và gửi alert qua Alertmanager.

```text
Targets /metrics
      |
      v
Prometheus scrape
      |
      v
TSDB + WAL
      |
      +--> PromQL dashboard
      +--> Alert rules
      +--> Remote write
```

### Data model và metric types

Một time series là metric name cộng label:

```text
http_requests_total{namespace="platform",service="api-service",status_code="500"}
```

| Loại metric | Ẩn dụ | Khi dùng |
| --- | --- | --- |
| Counter | Công-tơ mét chỉ tăng | Tổng số request, tổng số lỗi |
| Gauge | Đồng hồ xăng lên xuống | CPU hiện tại, queue depth |
| Histogram | Chia request vào các xô thời gian | Latency percentiles, kích thước response |
| Summary | Tính percentile trong app | Ít dùng hơn histogram vì khó aggregate |

```text
Histogram buckets

<= 0.05s:  100 request
<= 0.10s:  180 request
<= 0.20s:  240 request
<= 0.50s:  260 request
```

> Vì sao điều này quan trọng?
> Chọn sai metric type làm PromQL khó hoặc sai. Latency SLO gần như luôn nên dùng histogram để aggregate nhiều instance.

### PromQL từng bước

Ẩn dụ: PromQL giống ngôn ngữ hỏi sổ đo của nhà máy. Bạn có thể hỏi tốc độ tăng, percentile, hoặc tỷ lệ lỗi theo cửa hàng.

`rate()` và `irate()`:

```promql
rate(http_requests_total[5m])
irate(http_requests_total[5m])
```

- `rate()` lấy trung bình trong cửa sổ thời gian, phù hợp alert.
- `irate()` dùng hai điểm gần nhất, nhạy hơn, phù hợp dashboard debug ngắn hạn.

`histogram_quantile()`:

```promql
histogram_quantile(
  0.99,
  sum by (le) (
    rate(http_request_duration_seconds_bucket{service="api-service"}[5m])
  )
)
```

Ý nghĩa: "99% request trong 5 phút vừa rồi có latency thấp hơn bao nhiêu giây?"

Recording rule:

```yaml
record: service:http_requests:rate5m
expr: sum(rate(http_requests_total{service="api-service"}[5m]))
```

Quy ước tên `level:metric:operations` giúp đọc nhanh:

```text
service : http_requests : rate5m
  |            |          |
level       metric     phép tính/cửa sổ
```

Alert rule:

```yaml
alert: AvailabilityFastBurn
expr: service:availability_burn_rate:1h{service="api-service"} > 14
for: 5m
labels:
  severity: critical
annotations:
  summary: "api-service đang đốt error budget quá nhanh"
```

> Hiểu lầm thường gặp:
> `for: 5m` không có nghĩa query nhìn lại 5 phút. Nó nghĩa là điều kiện phải đúng liên tục 5 phút trước khi alert firing.

### Scrape config và remote write

Prometheus có thể scrape target tĩnh hoặc dùng Kubernetes service discovery.

```text
static_configs
  |
  v
Danh sách target cố định

kubernetes_sd_configs
  |
  v
Tự phát hiện pod/service/node theo label và annotation
```

Remote write gửi sample sang backend dài hạn như Thanos hoặc Mimir.

```text
Prometheus local TSDB + WAL
        |
        v
remote_write queue
        |
        v
Mimir / Thanos Receive
```

> Vì sao điều này quan trọng?
> Prometheus local rất mạnh cho alert và query gần thời gian thực, nhưng không phải lựa chọn tối ưu cho lưu trữ dài hạn nhiều tháng. Remote write tách alerting local khỏi lưu trữ dài hạn.

## 4. Phương pháp SLO / SLI

Ẩn dụ: Nếu đội sản phẩm nói "hệ thống ổn", đội vận hành nói "không ổn", còn khách hàng nói "rất chậm", bạn cần thước đo chung. SLO là thước đo đó.

Thuật ngữ:

- SLI: chỉ số đo thật, ví dụ phần trăm request thành công.
- SLO: mục tiêu, ví dụ 99.9% request thành công.
- SLA: cam kết hợp đồng có thể có phạt, thường thấp hơn SLO một chút.
- Error budget: phần không hoàn hảo được phép, bằng `1 - SLO`.

```text
User journey -> Critical User Journey -> SLI -> SLO -> Alert

"Đặt hàng"
    |
"POST /api/orders thành công trong < 200ms"
    |
availability SLI, latency SLI
    |
99.9% availability, p99 < 200ms
```

> Vì sao điều này quan trọng?
> SLO biến reliability thành cuộc thảo luận có số liệu. Khi còn error budget, bạn có thể release nhanh hơn; khi hết budget, ưu tiên ổn định.

### Công thức SLI phổ biến

Availability:

```text
good requests / total requests
```

Error rate:

```text
bad requests / total requests
```

Latency:

```text
requests dưới ngưỡng latency / total requests
```

Throughput:

```text
requests per second
```

Quality:

```text
responses đúng nghiệp vụ / total responses
```

### Error budget và burn rate

Ví dụ: SLO 99.9% nghĩa là error budget 0.1%.

Với 1000 RPS trong 30 ngày:

```text
30d * 24h * 3600s * 1000 RPS * 0.001 = 2,592,000 lỗi được phép
```

Burn rate trả lời: "Bạn đang tiêu error budget nhanh gấp bao nhiêu lần tốc độ cho phép?"

```text
burn rate = observed error ratio / error budget ratio

SLO 99.9% -> budget ratio = 0.001
error ratio hiện tại = 0.014
burn rate = 0.014 / 0.001 = 14
```

```text
Burn rate 1  -> tiêu đúng tốc độ cho phép
Burn rate 6  -> tiêu nhanh gấp 6 lần
Burn rate 14 -> tiêu nhanh gấp 14 lần
```

> Vì sao điều này quan trọng?
> Raw error rate 1% có thể nghiêm trọng hoặc không tùy SLO. Burn rate đặt lỗi vào ngữ cảnh error budget.

### Multi-window burn rate theo Google SRE

Ẩn dụ: Một cảm biến khói cực nhạy báo nhanh nhưng dễ ồn; một cảm biến nhiệt chậm hơn nhưng chắc hơn. Bạn dùng cả hai để vừa phát hiện nhanh vừa giảm báo động giả.

Vấn đề của single-window alert:

- Cửa sổ ngắn: phát hiện nhanh nhưng dễ nhiễu.
- Cửa sổ dài: ít nhiễu hơn nhưng báo quá chậm.

Giải pháp:

- Fast burn: cửa sổ 1h, pending 5m, ngưỡng 14x.
- Slow burn: cửa sổ 6h, pending 30m, ngưỡng 6x.

```text
Sự cố bắt đầu
     |
     +---- sau ~5 phút: fast burn firing nếu burn rate 1h > 14
     |
     +---------------------- sau ~30 phút: slow burn firing nếu burn rate 6h > 6
```

PromQL availability fast burn:

```promql
service:availability_burn_rate:1h{namespace="platform",service="api-service"} > 14
```

PromQL availability slow burn:

```promql
service:availability_burn_rate:6h{namespace="platform",service="api-service"} > 6
```

```text
service:availability_burn_rate:1h
  =
service:availability_error_ratio:rate1h / 0.001
```

| SLO | Error budget | Fast burn tham khảo | Slow burn tham khảo |
| --- | --- | --- | --- |
| 99% | 1% | 14x | 6x |
| 99.5% | 0.5% | 14x | 6x |
| 99.9% | 0.1% | 14x | 6x |
| 99.95% | 0.05% | 14x | 6x |

> Hiểu lầm thường gặp:
> Ngưỡng 14x và 6x không thay đổi theo SLO, nhưng công thức burn rate có mẫu số là error budget. SLO càng cao thì cùng error ratio sẽ tạo burn rate càng lớn.

## 5. Grafana và Loki

Ẩn dụ: Grafana là kính quan sát trung tâm. Prometheus, Loki và Tempo là các kho dữ liệu khác nhau; Grafana giúp bạn nhìn chúng trong cùng một phòng điều khiển.

```text
Prometheus metrics ----\
Loki logs --------------+--> Grafana dashboard, Explore, alert
Tempo traces ----------/
```

### Thiết kế dashboard

USE method cho hạ tầng:

- Utilization: tài nguyên đang dùng bao nhiêu.
- Saturation: hàng đợi hoặc nghẽn ở đâu.
- Errors: lỗi nào đang xảy ra.

RED method cho service:

- Rate: lưu lượng request.
- Errors: tỷ lệ lỗi.
- Duration: latency.

```text
Dashboard service tốt

Hàng 1: SLO status và error budget
Hàng 2: Error rate và burn rate
Hàng 3: Latency p50/p95/p99 và request rate
```

> Vì sao điều này quan trọng?
> Dashboard tốt bắt đầu từ câu hỏi vận hành, không bắt đầu từ việc nhồi mọi graph có thể vẽ.

### Loki và LogQL

Ẩn dụ: Loki giống Prometheus cho logs. Nó index label, không index toàn bộ nội dung log như Elasticsearch, nên rẻ hơn nhưng cần chọn label cẩn thận.

```text
Ứng dụng ghi log JSON
        |
        v
OTel Collector / Promtail
        |
        v
Loki
        |
        v
Grafana Explore
```

Ví dụ LogQL:

```logql
{service_name="api-service",namespace="platform"} |= "error"
```

Metric query từ log:

```logql
rate({service_name="api-service"} |= "error" [5m])
```

| Khía cạnh | Loki | Elasticsearch |
| --- | --- | --- |
| Mô hình index | Index label, nội dung log lưu dạng chunk | Index nhiều field trong log |
| Chi phí | Thường thấp hơn | Thường cao hơn |
| Query full-text | Hạn chế hơn | Mạnh hơn |
| Phù hợp | Kubernetes logs, label rõ | Tìm kiếm log phức tạp |

> Hiểu lầm thường gặp:
> Đừng đưa `request_id` vào label Loki. Hãy để nó trong nội dung log để query khi cần.

### Exemplars

Ẩn dụ: Khi nhìn graph latency có một đỉnh nhọn, exemplar giống chiếc ghim gắn trực tiếp vào một trace cụ thể gây ra đỉnh đó.

```text
Prometheus graph p99 spike
        |
        v
Exemplar trace_id
        |
        v
Tempo trace chi tiết
        |
        v
Loki logs cùng trace_id
```

> Vì sao điều này quan trọng?
> Exemplars nối metrics với traces, giúp bạn đi từ "p99 tăng" đến một request thật mà không phải đoán.
