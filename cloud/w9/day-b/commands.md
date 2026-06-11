# Ngày B - Lệnh thực hành: Observability, SLO/SLI và OTel

Các ví dụ dùng `namespace=platform`, `service=api-service`, Prometheus tại `http://localhost:9090`, Loki tại `http://localhost:3100`, Alertmanager tại `http://localhost:9093`, và Grafana tại `http://localhost:3000`.

## Lệnh OTel Collector

### Validate cấu hình Collector

```bash
# MỤC ĐÍCH: Kiểm tra file cấu hình OTel Collector có hợp lệ không.
# KHI DÙNG: Trước khi restart Collector hoặc commit thay đổi pipeline.
$ otelcol validate --config day-b/otel/collector-config.yaml
--- kết quả mong đợi ---
Configuration is valid
💡 MẸO: Chạy validate trong CI để bắt lỗi sai tên receiver, processor hoặc exporter.
⚠️ LƯU Ý: Validate cú pháp không chứng minh backend như Loki hoặc Tempo đang reachable.
```

### Liệt kê component có trong binary

```bash
# MỤC ĐÍCH: Xem binary Collector hỗ trợ receiver, processor, exporter nào.
# KHI DÙNG: Khi cấu hình báo lỗi "unknown type" cho một component.
$ otelcol components
--- kết quả mong đợi ---
buildinfo:
    command: otelcol
receivers:
    otlp
    prometheus
    filelog
processors:
    batch
    memory_limiter
    resourcedetection
exporters:
    otlp
    prometheusremotewrite
    loki
extensions:
    health_check
    pprof
    zpages
💡 MẸO: Dùng bản opentelemetry-collector-contrib nếu cần exporter như loki hoặc receiver filelog.
⚠️ LƯU Ý: Binary core và contrib có danh sách component khác nhau.
```

### Chạy Collector với config cụ thể

```bash
# MỤC ĐÍCH: Khởi động Collector bằng file cấu hình trong repo.
# KHI DÙNG: Khi chạy lab local hoặc debug pipeline trước khi đưa vào Kubernetes.
$ otelcol --config day-b/otel/collector-config.yaml --set service.telemetry.logs.level=info
--- kết quả mong đợi ---
2026-06-09T11:00:00.100+0700    info    service@v0.103.0/service.go:115  Setting up own telemetry...
2026-06-09T11:00:00.210+0700    info    service@v0.103.0/service.go:178  Starting otelcol...
2026-06-09T11:00:00.410+0700    info    healthcheckextension@v0.103.0/healthcheckextension.go:35  Health Check state change  {"status": "ready"}
💡 MẸO: Thêm --set để override nhanh một giá trị nhỏ mà không sửa file.
⚠️ LƯU Ý: Nếu port 4317 hoặc 4318 đã bận, Collector sẽ fail ngay lúc start.
```

## Lệnh Prometheus và promtool

### Kiểm tra rule file

```bash
# MỤC ĐÍCH: Validate recording rule và alerting rule.
# KHI DÙNG: Trước khi reload Prometheus hoặc merge rule mới.
$ promtool check rules day-b/prometheus/rules/slo-availability.yaml day-b/prometheus/rules/slo-latency.yaml
--- kết quả mong đợi ---
Checking day-b/prometheus/rules/slo-availability.yaml
  SUCCESS: 12 rules found

Checking day-b/prometheus/rules/slo-latency.yaml
  SUCCESS: 8 rules found
💡 MẸO: Đây là lệnh bắt buộc trong CI cho mọi thay đổi alert.
⚠️ LƯU Ý: promtool check rules không biết metric có thật hay không; nó chỉ kiểm tra cú pháp rule.
```

### Kiểm tra Prometheus config

```bash
# MỤC ĐÍCH: Validate file scrape config của Prometheus.
# KHI DÙNG: Trước khi reload hoặc restart Prometheus.
$ promtool check config day-b/prometheus/scrape-config.yaml
--- kết quả mong đợi ---
Checking day-b/prometheus/scrape-config.yaml
 SUCCESS: day-b/prometheus/scrape-config.yaml is valid prometheus config file syntax
💡 MẸO: Kiểm tra config trước khi mount vào container để tránh Prometheus không khởi động.
⚠️ LƯU Ý: Config đúng cú pháp vẫn có thể scrape 0 target nếu label hoặc annotation sai.
```

### Query instant

```bash
# MỤC ĐÍCH: Chạy một PromQL tại thời điểm hiện tại.
# KHI DÙNG: Khi kiểm tra nhanh metric hoặc recording rule.
$ promtool query instant http://localhost:9090 'service:availability_burn_rate:1h{namespace="platform",service="api-service"}'
--- kết quả mong đợi ---
service:availability_burn_rate:1h{namespace="platform",service="api-service"} => 0.23 @[1780981200.000]
💡 MẸO: Query recording rule trước khi dùng nó trong alert hoặc canary analysis.
⚠️ LƯU Ý: Nếu kết quả rỗng, kiểm tra label `namespace` và `service` trước khi sửa PromQL.
```

### Query range

```bash
# MỤC ĐÍCH: Chạy PromQL trên một khoảng thời gian.
# KHI DÙNG: Khi muốn xem burn rate thay đổi theo thời gian.
$ promtool query range http://localhost:9090 'service:availability_burn_rate:1h{namespace="platform",service="api-service"}' --start=2026-06-09T10:00:00+07:00 --end=2026-06-09T11:00:00+07:00 --step=5m
--- kết quả mong đợi ---
service:availability_burn_rate:1h{namespace="platform",service="api-service"} =>
1780974000 0.12
1780974300 0.15
1780974600 0.18
1780974900 0.23
💡 MẸO: Step nên gần với độ phân giải dashboard, ví dụ 30s hoặc 1m cho debug ngắn.
⚠️ LƯU Ý: Khoảng thời gian quá dài với step quá nhỏ có thể tạo query rất nặng.
```

### Phân tích TSDB

```bash
# MỤC ĐÍCH: Tìm metric hoặc label gây cardinality cao trong Prometheus TSDB.
# KHI DÙNG: Khi Prometheus dùng nhiều RAM hoặc query chậm bất thường.
$ promtool tsdb analyze ./prometheus-data
--- kết quả mong đợi ---
Block ID: 01J0ABCDE123456789XYZ
Duration: 2h0m0s
Series: 15420
Label names by value count:
  user_id: 9120
  pod: 320
  status_code: 6
Highest cardinality metric names:
  http_requests_total: 9820
💡 MẸO: Tập trung xử lý label có value count lớn bất thường trước.
⚠️ LƯU Ý: Chỉ chạy lệnh này trên bản copy hoặc volume local không bị Prometheus ghi đồng thời.
```

## Lệnh Loki và logcli

### Query log

```bash
# MỤC ĐÍCH: Tìm log lỗi của api-service trong Loki.
# KHI DÙNG: Khi alert error rate tăng và bạn cần xem event chi tiết.
$ logcli --addr=http://localhost:3100 query '{service_name="api-service",namespace="platform"} |= "error"' --since=15m --limit=20
--- kết quả mong đợi ---
2026-06-09T11:05:01+07:00 {"level":"error","service":"api-service","trace_id":"4bf92f...","message":"order creation failed"}
2026-06-09T11:05:14+07:00 {"level":"error","service":"api-service","trace_id":"91ab2c...","message":"simulated failure"}
💡 MẸO: Query bằng label trước, sau đó mới thêm filter nội dung để giảm chi phí.
⚠️ LƯU Ý: Đừng đưa `trace_id` thành label Loki; hãy để trong nội dung JSON log.
```

### Liệt kê label

```bash
# MỤC ĐÍCH: Xem Loki đang có các label nào.
# KHI DÙNG: Khi bạn không chắc label service hoặc namespace tên là gì.
$ logcli --addr=http://localhost:3100 labels --since=1h
--- kết quả mong đợi ---
__name__
container
namespace
pod
service_name
severity
💡 MẸO: Sau khi biết label name, dùng `logcli labels service_name` để xem value.
⚠️ LƯU Ý: Label quá nhiều giá trị là dấu hiệu thiết kế log label chưa tốt.
```

### Liệt kê series

```bash
# MỤC ĐÍCH: Xem các log stream khớp selector.
# KHI DÙNG: Khi kiểm tra cardinality hoặc stream nào đang sinh nhiều log.
$ logcli --addr=http://localhost:3100 series '{namespace="platform"}' --since=30m
--- kết quả mong đợi ---
{namespace="platform",service_name="api-service",pod="api-service-5df45d7b9c-h6f8n"}
{namespace="platform",service_name="otel-collector",pod="otel-collector-7f6c8d9"}
💡 MẸO: Series giúp bạn phát hiện label như `pod` làm tăng số stream theo mỗi deploy.
⚠️ LƯU Ý: Selector quá rộng trên môi trường lớn có thể query chậm.
```

### Thống kê query

```bash
# MỤC ĐÍCH: Xem lượng dữ liệu Loki phải đọc cho một query.
# KHI DÙNG: Khi tối ưu LogQL hoặc dashboard log panel.
$ logcli --addr=http://localhost:3100 stats '{service_name="api-service"} |= "error"' --since=1h
--- kết quả mong đợi ---
Summary:
  bytes processed: 18 MB
  lines processed: 12400
  total entries: 37
  execution time: 210ms
💡 MẸO: Nếu bytes processed lớn, thêm label selector hẹp hơn trước filter nội dung.
⚠️ LƯU Ý: Query log không nên là nguồn alert chính nếu cùng tín hiệu có thể đo bằng metrics.
```

## Lệnh Alertmanager và amtool

### Kiểm tra config Alertmanager

```bash
# MỤC ĐÍCH: Validate cấu hình route, receiver và template của Alertmanager.
# KHI DÙNG: Trước khi reload Alertmanager.
$ amtool check-config alertmanager.yml
--- kết quả mong đợi ---
Checking 'alertmanager.yml'  SUCCESS
Found:
 - global config
 - route
 - 1 inhibit rules
 - 2 receivers
 - 1 templates
💡 MẸO: Chạy check-config trước khi áp dụng route production.
⚠️ LƯU Ý: Config hợp lệ chưa đảm bảo webhook Slack hoặc PagerDuty reachable.
```

### Query alert đang firing

```bash
# MỤC ĐÍCH: Liệt kê alert hiện có trong Alertmanager.
# KHI DÙNG: Khi xác nhận burn rate alert đã firing hoặc resolved.
$ amtool --alertmanager.url=http://localhost:9093 alert query alertname=AvailabilityFastBurn
--- kết quả mong đợi ---
Alertname             Starts At                Summary
AvailabilityFastBurn  2026-06-09 11:15:00 UTC api-service đang đốt error budget quá nhanh
💡 MẸO: Thêm label matcher như service=api-service để lọc chính xác.
⚠️ LƯU Ý: Alert pending nằm ở Prometheus, chưa chắc đã xuất hiện trong Alertmanager.
```

### Tạo silence

```bash
# MỤC ĐÍCH: Tạm tắt notification cho alert khớp label trong một khoảng thời gian.
# KHI DÙNG: Khi bảo trì có kế hoạch và không muốn spam on-call.
$ amtool --alertmanager.url=http://localhost:9093 silence add alertname=AvailabilitySlowBurn service=api-service --duration=2h --comment='Bảo trì lab local-dev' --author='platform-learner'
--- kết quả mong đợi ---
3f1a2b4c-7d8e-90ab-cdef-111122223333
💡 MẸO: Silence nên có duration ngắn và comment rõ lý do.
⚠️ LƯU Ý: Silence không sửa sự cố; nó chỉ tắt notification.
```

## Lệnh Grafana CLI

### Cài plugin

```bash
# MỤC ĐÍCH: Cài plugin Grafana từ registry chính thức.
# KHI DÙNG: Khi dashboard cần datasource hoặc panel chưa có sẵn.
$ grafana-cli --pluginsDir /var/lib/grafana/plugins plugins install grafana-clock-panel 2.1.8
--- kết quả mong đợi ---
installing grafana-clock-panel @ 2.1.8
from: https://grafana.com/api/plugins/grafana-clock-panel/versions/2.1.8/download
into: /var/lib/grafana/plugins
✔ Installed grafana-clock-panel successfully
Restart grafana after installing plugins
💡 MẸO: Pin version plugin để tránh dashboard đổi hành vi bất ngờ.
⚠️ LƯU Ý: Sau khi cài plugin, cần restart Grafana để load plugin.
```

### Liệt kê plugin

```bash
# MỤC ĐÍCH: Xem các plugin Grafana đã cài.
# KHI DÙNG: Khi kiểm tra môi trường trước khi import dashboard.
$ grafana-cli --pluginsDir /var/lib/grafana/plugins plugins ls
--- kết quả mong đợi ---
installed plugins:
grafana-clock-panel @ 2.1.8
grafana-piechart-panel @ 1.6.4
💡 MẸO: Ghi lại danh sách plugin trong tài liệu vận hành để tái tạo Grafana nhanh.
⚠️ LƯU Ý: Một số panel cũ có thể không tương thích với Grafana version mới.
```
