# Ngày B - Lab: Dựng stack Observability và kiểm chứng SLO

Lab này dựng Prometheus, Grafana, Loki, Tempo, OTel Collector và Alertmanager bằng Docker Compose. Sau đó bạn chạy `api-service`, tạo traffic bằng k6, xem metrics/logs/traces và quan sát burn rate alert.

## Điều kiện chuẩn bị

Bạn cần:

- Docker Compose v2.
- Node.js 20+ và npm để chạy app trong `day-b/app/`.
- `k6` để tạo traffic.
- `promtool` để kiểm tra rule.
- `logcli` để query Loki.

Kiểm tra:

```bash
docker compose version
node --version
npm --version
k6 version
promtool --version
logcli --version
```

--- kết quả mong đợi ---

```text
Docker Compose version v2.27.0
v20.12.2
10.5.0
k6 v0.49.0
promtool, version 2.52.0
logcli, version 3.1.0
```

✓ Điểm kiểm tra: tất cả công cụ in version thành công.

## Bước 1: Khởi động stack observability bằng Docker Compose

Mục tiêu: tạo đầy đủ Prometheus, Grafana, Loki, Tempo, OTel Collector và Alertmanager.

```bash
mkdir -p day-b/runtime/rules day-b/runtime/logs day-b/runtime/grafana/provisioning/datasources

cat > day-b/runtime/prometheus.yml <<'YAML'
global:
  scrape_interval: 30s
  evaluation_interval: 30s

rule_files:
  - /etc/prometheus/rules/*.yaml

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

scrape_configs:
  - job_name: api-service
    static_configs:
      - targets:
          - host.docker.internal:9464
        labels:
          namespace: platform
          service: api-service
  - job_name: prometheus
    static_configs:
      - targets:
          - prometheus:9090
        labels:
          namespace: platform
          service: prometheus
  - job_name: otel-collector
    static_configs:
      - targets:
          - otel-collector:8888
        labels:
          namespace: platform
          service: otel-collector
YAML

cat > day-b/runtime/rules/slo.yaml <<'YAML'
groups:
  - name: api-service.slo.native
    interval: 30s
    rules:
      - record: service:http_requests:rate5m
        expr: sum by (namespace, service) (rate(http_requests_total{namespace="platform",service="api-service"}[5m]))
      - record: service:http_errors:rate5m
        expr: sum by (namespace, service) (rate(http_requests_total{namespace="platform",service="api-service",status_code=~"5.."}[5m]))
      - record: service:availability_error_ratio:rate5m
        expr: service:http_errors:rate5m / clamp_min(service:http_requests:rate5m, 0.001)
      - record: service:http_requests:rate1h
        expr: sum by (namespace, service) (rate(http_requests_total{namespace="platform",service="api-service"}[1h]))
      - record: service:http_errors:rate1h
        expr: sum by (namespace, service) (rate(http_requests_total{namespace="platform",service="api-service",status_code=~"5.."}[1h]))
      - record: service:availability_error_ratio:rate1h
        expr: service:http_errors:rate1h / clamp_min(service:http_requests:rate1h, 0.001)
      - record: service:availability_burn_rate:1h
        expr: service:availability_error_ratio:rate1h / 0.001
      - record: service:http_requests:rate6h
        expr: sum by (namespace, service) (rate(http_requests_total{namespace="platform",service="api-service"}[6h]))
      - record: service:http_errors:rate6h
        expr: sum by (namespace, service) (rate(http_requests_total{namespace="platform",service="api-service",status_code=~"5.."}[6h]))
      - record: service:availability_error_ratio:rate6h
        expr: service:http_errors:rate6h / clamp_min(service:http_requests:rate6h, 0.001)
      - record: service:availability_burn_rate:6h
        expr: service:availability_error_ratio:rate6h / 0.001
      - record: service:http_request_duration_seconds:p50
        expr: histogram_quantile(0.50, sum by (namespace, service, le) (rate(http_request_duration_seconds_bucket{namespace="platform",service="api-service"}[5m])))
      - record: service:http_request_duration_seconds:p95
        expr: histogram_quantile(0.95, sum by (namespace, service, le) (rate(http_request_duration_seconds_bucket{namespace="platform",service="api-service"}[5m])))
      - record: service:http_request_duration_seconds:p99
        expr: histogram_quantile(0.99, sum by (namespace, service, le) (rate(http_request_duration_seconds_bucket{namespace="platform",service="api-service"}[5m])))
      - alert: AvailabilityFastBurn
        expr: service:availability_burn_rate:1h{namespace="platform",service="api-service"} > 14
        for: 5m
        labels:
          severity: critical
          namespace: platform
          service: api-service
        annotations:
          summary: "api-service đang đốt error budget quá nhanh"
          description: "Burn rate 1h vượt 14x."
      - alert: AvailabilitySlowBurn
        expr: service:availability_burn_rate:6h{namespace="platform",service="api-service"} > 6
        for: 30m
        labels:
          severity: warning
          namespace: platform
          service: api-service
        annotations:
          summary: "api-service đang tiêu error budget kéo dài"
          description: "Burn rate 6h vượt 6x."
YAML

cat > day-b/runtime/alertmanager.yml <<'YAML'
global:
  resolve_timeout: 5m

route:
  receiver: local-console
  group_by:
    - alertname
    - service
  group_wait: 10s
  group_interval: 1m
  repeat_interval: 30m

receivers:
  - name: local-console
YAML

cat > day-b/runtime/tempo.yml <<'YAML'
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
        http:

storage:
  trace:
    backend: local
    local:
      path: /tmp/tempo/traces
YAML

cat > day-b/runtime/grafana/provisioning/datasources/datasources.yml <<'YAML'
apiVersion: 1

datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
  - name: Loki
    uid: loki
    type: loki
    access: proxy
    url: http://loki:3100
  - name: Tempo
    uid: tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
YAML

cat > day-b/runtime/docker-compose.yml <<'YAML'
services:
  prometheus:
    image: prom/prometheus:v2.52.0
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --web.enable-remote-write-receiver
      - --storage.tsdb.path=/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./rules:/etc/prometheus/rules:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"

  alertmanager:
    image: prom/alertmanager:v0.27.0
    command:
      - --config.file=/etc/alertmanager/alertmanager.yml
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro

  grafana:
    image: grafana/grafana:11.0.0
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro

  loki:
    image: grafana/loki:3.1.0
    command:
      - -config.file=/etc/loki/local-config.yaml
    ports:
      - "3100:3100"

  tempo:
    image: grafana/tempo:2.5.0
    command:
      - -config.file=/etc/tempo.yml
    ports:
      - "3200:3200"
      - "4317:4317"
    volumes:
      - ./tempo.yml:/etc/tempo.yml:ro

  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.103.0
    command:
      - --config=/etc/otelcol/config.yaml
    ports:
      - "4318:4318"
      - "4317:4317"
      - "8888:8888"
      - "13133:13133"
    volumes:
      - ../otel/collector-config.yaml:/etc/otelcol/config.yaml:ro
      - ./logs:/var/log/api-service:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
    depends_on:
      - prometheus
      - loki
      - tempo
YAML

promtool check rules day-b/runtime/rules/slo.yaml
docker compose -f day-b/runtime/docker-compose.yml up -d
docker compose -f day-b/runtime/docker-compose.yml ps
```

--- kết quả mong đợi ---

```text
Checking day-b/runtime/rules/slo.yaml
  SUCCESS: 17 rules found

NAME                    IMAGE                                           STATUS
runtime-prometheus-1     prom/prometheus:v2.52.0                         Up
runtime-alertmanager-1   prom/alertmanager:v0.27.0                       Up
runtime-grafana-1        grafana/grafana:11.0.0                           Up
runtime-loki-1           grafana/loki:3.1.0                               Up
runtime-tempo-1          grafana/tempo:2.5.0                              Up
runtime-otel-collector-1 otel/opentelemetry-collector-contrib:0.103.0     Up
```

✓ Điểm kiểm tra: `docker compose ps` báo cả 6 service đều `Up`.

### Nếu có sự cố

Nếu container OTel Collector restart liên tục, xem log:

```bash
docker compose -f day-b/runtime/docker-compose.yml logs --tail=100 otel-collector
```

## Bước 2: Chạy ứng dụng Node.js đã instrument

Mục tiêu: chạy `api-service` và xuất metrics ở port `9464`, traces qua OTel Collector port `4318`, logs ra file cho Collector đọc.

```bash
cd day-b/app
npm install
cd ../..

SERVICE_NAME=api-service \
SERVICE_VERSION=stable \
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces \
node day-b/app/server.js > day-b/runtime/logs/api-service.log 2>&1 &

echo $! > day-b/runtime/api-service.pid
sleep 3
curl -s http://localhost:8080/health
curl -s http://localhost:9464/metrics | head -20
```

--- kết quả mong đợi ---

```text
{"status":"ok","service":"api-service"}
# HELP target_info Target metadata
# TYPE target_info gauge
target_info{service_name="api-service",deployment_environment="local-dev"} 1
# HELP http_requests_total Tổng số HTTP request theo route, method và status_code
# TYPE http_requests_total counter
```

✓ Điểm kiểm tra: `/health` trả `status=ok` và `/metrics` có metric `http_requests_total`.

## Bước 3: Tạo traffic bằng k6

Mục tiêu: tạo request đều đặn để Prometheus có dữ liệu metrics, Loki có log và Tempo có trace.

```bash
cat > day-b/runtime/k6-traffic.js <<'JS'
import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  vus: 20,
  duration: '3m',
};

export default function () {
  if (Math.random() < 0.8) {
    http.get('http://localhost:8080/api/orders');
  } else {
    http.post(
      'http://localhost:8080/api/orders',
      JSON.stringify({ total: Math.floor(Math.random() * 100) + 1, currency: 'USD' }),
      { headers: { 'Content-Type': 'application/json' } }
    );
  }
  sleep(1);
}
JS

k6 run day-b/runtime/k6-traffic.js
```

--- kết quả mong đợi ---

```text
running (3m00.0s), 00/20 VUs, 3400 complete and 0 interrupted iterations
http_req_duration..............: avg=9.2ms  min=1.1ms med=4.4ms max=98.1ms p(90)=18.2ms p(95)=28.7ms
http_req_failed................: 9.71%  ✓ 330      ✗ 3070
iterations.....................: 3400   18.8/s
```

✓ Điểm kiểm tra: k6 hoàn tất và có cả request thành công lẫn lỗi mô phỏng khoảng 10%.

## Bước 4: Kiểm tra dữ liệu trong Prometheus, Loki và Tempo

Mục tiêu: xác minh ba trụ cột đều có dữ liệu.

```bash
promtool query instant http://localhost:9090 'service:http_requests:rate5m{namespace="platform",service="api-service"}'
logcli --addr=http://localhost:3100 query '{service="api-service"}' --since=10m --limit=5
curl -s 'http://localhost:3200/api/search?tags=service.name%3Dapi-service&limit=5'
```

--- kết quả mong đợi ---

```text
service:http_requests:rate5m{namespace="platform",service="api-service"} => 18.42 @[1780981200.000]

2026-06-09T11:10:01+07:00 {"level":"info","service":"api-service","trace_id":"...","message":"listed orders"}
2026-06-09T11:10:03+07:00 {"level":"error","service":"api-service","trace_id":"...","message":"simulated order lookup failure"}

{"traces":[{"traceID":"4bf92f3577b34da6a3ce929d0e0e4736","rootServiceName":"api-service"}]}
```

✓ Điểm kiểm tra: Prometheus có request rate, Loki có JSON log, Tempo trả danh sách trace.

### Nếu có sự cố

Nếu Loki không có log, kiểm tra file log và volume mount:

```bash
tail -20 day-b/runtime/logs/api-service.log
docker compose -f day-b/runtime/docker-compose.yml logs --tail=100 otel-collector
```

## Bước 5: Import dashboard `dashboard-slo.json`

Mục tiêu: import dashboard và xác nhận các panel có dữ liệu.

```bash
node -e "const fs=require('fs'); const dashboard=JSON.parse(fs.readFileSync('day-b/grafana/dashboard-slo.json','utf8')); fs.writeFileSync('day-b/runtime/dashboard-import.json', JSON.stringify({dashboard, overwrite:true, folderId:0}));"

curl -s -u admin:admin \
  -H 'Content-Type: application/json' \
  --data @day-b/runtime/dashboard-import.json \
  http://localhost:3000/api/dashboards/db
```

--- kết quả mong đợi ---

```json
{"id":1,"slug":"slo-api-service","status":"success","uid":"api-service-slo","url":"/d/api-service-slo/slo-api-service","version":1}
```

Mở dashboard:

```bash
printf 'http://localhost:3000/d/api-service-slo/slo-api-service?var-datasource=prometheus&var-namespace=platform&var-service=api-service\n'
```

✓ Điểm kiểm tra: Grafana hiển thị Availability, burn rate, latency và request rate.

## Bước 6: Mô phỏng outage bằng cách dừng app

Mục tiêu: làm Prometheus thấy target mất và burn rate bắt đầu tăng khi request lỗi xuất hiện.

```bash
kill "$(cat day-b/runtime/api-service.pid)"
sleep 5
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/health || true

promtool query instant http://localhost:9090 'up{job="api-service"}'
```

--- kết quả mong đợi ---

```text
000
up{instance="host.docker.internal:9464",job="api-service",namespace="platform",service="api-service"} => 0 @[1780981500.000]
```

✓ Điểm kiểm tra: `/health` không trả được và metric `up` của `api-service` bằng `0`.

## Bước 7: Quan sát fast burn và slow burn alert

Mục tiêu: xem fast burn firing sau khoảng 5 phút và slow burn firing sau khoảng 30 phút nếu lỗi kéo dài.

```bash
watch -n 30 "promtool query instant http://localhost:9090 'ALERTS{service=\"api-service\"}'"
```

--- kết quả mong đợi sau khoảng 5 phút ---

```text
ALERTS{alertname="AvailabilityFastBurn",alertstate="firing",namespace="platform",service="api-service",severity="critical"} => 1 @[1780981800.000]
```

Kiểm tra Alertmanager:

```bash
amtool --alertmanager.url=http://localhost:9093 alert query service=api-service
```

--- kết quả mong đợi ---

```text
Alertname             Starts At                Summary
AvailabilityFastBurn  2026-06-09 11:20:00 UTC api-service đang đốt error budget quá nhanh
```

✓ Điểm kiểm tra: Alertmanager hiển thị `AvailabilityFastBurn`; nếu chờ đủ 30 phút, `AvailabilitySlowBurn` cũng xuất hiện.

## Bước 8: Tính error budget còn lại bằng PromQL

Mục tiêu: tự tính phần trăm error budget còn lại dựa trên burn rate 6h.

```bash
promtool query instant http://localhost:9090 'clamp_min((1 - service:availability_burn_rate:6h{namespace="platform",service="api-service"}) * 100, 0)'
```

--- kết quả mong đợi ---

```text
{} => 83.42 @[1780982100.000]
```

Diễn giải: nếu kết quả là `83.42`, nghĩa là theo cửa sổ 6h hiện tại, service còn khoảng 83.42% error budget tương ứng với tốc độ tiêu hiện tại.

✓ Điểm kiểm tra: bạn tính được error budget remaining bằng PromQL thay vì chỉ nhìn dashboard.

## Bước 9: Khởi động lại app và xác nhận alert resolved

Mục tiêu: đưa service khỏe lại, burn rate giảm dần và alert tự resolved.

```bash
SERVICE_NAME=api-service \
SERVICE_VERSION=stable \
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces \
node day-b/app/server.js > day-b/runtime/logs/api-service.log 2>&1 &

echo $! > day-b/runtime/api-service.pid
sleep 10

curl -s http://localhost:8080/health
promtool query instant http://localhost:9090 'up{job="api-service"}'
amtool --alertmanager.url=http://localhost:9093 alert query service=api-service
```

--- kết quả mong đợi ---

```text
{"status":"ok","service":"api-service"}
up{instance="host.docker.internal:9464",job="api-service",namespace="platform",service="api-service"} => 1 @[1780982400.000]
Alertname  Starts At  Summary
```

✓ Điểm kiểm tra: app healthy, `up=1`, và alert biến mất sau khi Prometheus đánh giá lại.

## Dọn dẹp

```bash
kill "$(cat day-b/runtime/api-service.pid)" || true
docker compose -f day-b/runtime/docker-compose.yml down -v
```

## Những gì bạn đã học

- Observability khác monitoring ở khả năng trả lời câu hỏi mới trong sự cố.
- Metrics, logs và traces trả lời các loại câu hỏi khác nhau và cần được liên kết bằng `trace_id`.
- OTel Collector nhận, xử lý và chuyển tiếp telemetry qua receiver, processor và exporter.
- Prometheus recording rule giúp dashboard và alert chạy nhanh, ổn định hơn.
- SLO biến reliability thành mục tiêu đo được bằng SLI và error budget.
- Multi-window burn rate alert giúp cân bằng giữa phát hiện nhanh và giảm nhiễu.

## Câu hỏi suy ngẫm

1. Vì sao burn rate là tín hiệu tốt hơn raw error rate khi quyết định có rollback hay không?
2. Nếu một label như `user_id` làm Prometheus tăng cardinality mạnh, bạn sẽ sửa ở instrumentation, Collector hay Prometheus config?
3. Dashboard SLO nên được thiết kế cho on-call, product owner và developer khác nhau như thế nào?

## Bước tiếp theo

- Đọc OpenTelemetry Collector pipelines: https://opentelemetry.io/docs/collector/configuration/
- Đọc Prometheus recording rules và alerting rules: https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/
- Đọc Google SRE workbook về alerting on SLOs: https://sre.google/workbook/alerting-on-slos/
- Đọc Grafana Explore cho logs/traces: https://grafana.com/docs/grafana/latest/explore/
