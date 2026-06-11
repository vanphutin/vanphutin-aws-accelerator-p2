# Ngày C - Lý thuyết: Progressive Delivery và Canary

## 0. Cách dùng tài liệu này

Đọc `theory.md` để hiểu cách giảm rủi ro release, luyện lệnh trong `commands.md`, rồi làm `lab.md` để chạy canary bằng Argo Rollouts. Ngày C nối trực tiếp với Ngày B: AnalysisTemplate sẽ dùng recording rule `service:availability_burn_rate:1h` để quyết định tiếp tục hay abort canary.

## 1. Vì sao cần Progressive Delivery?

Ẩn dụ: Release 100% người dùng cùng lúc giống mở nhà hàng mới cho 10,000 khách ngay ngày đầu. Nếu bếp hỏng, tất cả khách đều chịu ảnh hưởng. Progressive Delivery mở cửa từng phần nhỏ, quan sát, rồi mới mở rộng.

Định nghĩa kỹ thuật: Progressive Delivery là cách đưa version mới ra production theo từng bước, kết hợp traffic shifting, quan sát telemetry và quyết định promote hoặc abort.

```text
Big bang deploy

100% traffic -> version mới
     |
     v
Nếu lỗi: 100% người dùng bị ảnh hưởng

Progressive Delivery

5% traffic  -> version mới -> quan sát -> 30% -> quan sát -> 100%
95% traffic -> version ổn định
```

> Vì sao điều này quan trọng?
> Mục tiêu không phải deploy chậm hơn. Mục tiêu là phát hiện lỗi khi blast radius còn nhỏ.

### Blue/Green và Canary

Blue/Green dùng hai môi trường gần như giống nhau. Bạn deploy version mới vào môi trường green, test, rồi switch traffic từ blue sang green.

```text
Blue/Green

Trước switch: 100% traffic -> blue
Sau switch:   100% traffic -> green
```

Canary gửi một phần nhỏ traffic sang version mới trước.

```text
Canary

Traffic splitter
   |
   +--> 95% stable
   |
   +--> 5% canary
```

Tên "canary" xuất phát từ cách thợ mỏ từng dùng chim canary để phát hiện khí độc sớm trong hầm mỏ. Trong phần mềm, canary là nhóm traffic nhỏ giúp phát hiện lỗi trước khi toàn bộ người dùng bị ảnh hưởng.

Blast radius:

```text
1000 RPS * 5% = 50 RPS

Nếu canary lỗi, khoảng 50 request/giây gặp version mới,
không phải toàn bộ 1000 request/giây.
```

> Hiểu lầm thường gặp:
> Canary không tự an toàn. Nó chỉ an toàn khi có metric tốt, ngưỡng rõ và cơ chế abort đáng tin cậy.

### Vòng lặp quyết định rollout

```text
Deploy version mới
        |
        v
Shift một phần traffic
        |
        v
Quan sát SLO, latency, error, logs, traces
        |
        +------ tốt ------> Promote
        |
        +------ xấu ------> Abort và trả traffic về stable
```

> Vì sao điều này quan trọng?
> Progressive Delivery biến release thành vòng lặp kiểm soát rủi ro, không phải hành động "hy vọng mọi thứ ổn".

## 2. Traffic management hoạt động như thế nào?

Ẩn dụ: Traffic manager giống nhân viên điều phối ở cửa nhà hàng. Người đó quyết định bao nhiêu khách vào khu bếp cũ và bao nhiêu khách thử khu bếp mới.

Các lựa chọn phổ biến:

```text
Client
  |
  v
Traffic manager
  |
  +--> stable service -> stable pods
  |
  +--> canary service -> canary pods
```

| Cách | Cơ chế | Ưu điểm | Hạn chế | Khi chọn |
| --- | --- | --- | --- | --- |
| Kubernetes native | Service và selector | Đơn giản, không cần ingress mesh | Không chia % traffic chính xác theo request | Lab nhỏ, workload nội bộ |
| NGINX Ingress | Annotation `nginx.ingress.kubernetes.io/canary-weight` | Dễ dùng với ingress phổ biến | Chủ yếu HTTP ingress | Web/API qua NGINX |
| Istio VirtualService | Weighted route, header route | Chính xác, hỗ trợ A/B, mesh policy | Phức tạp hơn | Microservices nhiều traffic rule |
| AWS ALB | Weighted target groups | Tích hợp AWS managed ingress | Phụ thuộc ALB controller | EKS dùng ALB |

```text
NGINX canary

Ingress stable: host api.local -> api-service-stable
Ingress canary: host api.local -> api-service-canary, weight=10
```

> Vì sao điều này quan trọng?
> Argo Rollouts quyết định rollout, nhưng traffic manager mới thật sự chia traffic. Chọn sai lớp traffic sẽ làm canary không phản ánh production thật.

## 3. Argo Rollouts

Ẩn dụ: Kubernetes `Deployment` giống thang cuốn chỉ đi lên theo một tốc độ. Argo Rollouts giống thang có chiếu nghỉ: đi một đoạn, dừng lại kiểm tra, rồi quyết định đi tiếp hoặc quay xuống.

Định nghĩa kỹ thuật: Argo Rollouts thay thế `Deployment` bằng `Rollout` CRD để hỗ trợ canary, blue/green, analysis, manual approval và traffic routing.

```text
Rollouts Controller
      |
      v
Watch Rollout CRD
      |
      +--> quản lý ReplicaSet stable
      +--> quản lý ReplicaSet canary
      +--> tạo AnalysisRun
      +--> cập nhật traffic routing
      |
      v
Promote hoặc Abort
```

> Vì sao điều này quan trọng?
> `Deployment` biết rollout pod, nhưng không biết hỏi Prometheus xem version mới có đang tiêu error budget quá nhanh không.

### Anatomy của Rollout CRD

```text
spec.strategy.canary
  |
  +-- steps
  |     +-- setWeight: 10
  |     +-- pause: 5m hoặc manual
  |     +-- analysis: chạy AnalysisTemplate
  |
  +-- canaryMetadata / stableMetadata
  |
  +-- trafficRouting
  |
  +-- maxSurge / maxUnavailable
```

`steps` là cầu thang rollout:

- `setWeight`: chuyển X% traffic sang canary.
- `pause`: chờ một khoảng thời gian hoặc chờ người approve thủ công.
- `analysis`: chạy metric check trước khi đi tiếp.

`canaryMetadata` và `stableMetadata` gắn label khác nhau lên pod để Prometheus phân biệt version.

`trafficRouting` nối Rollout với NGINX, Istio hoặc ALB.

`maxSurge` và `maxUnavailable` kiểm soát số pod thêm hoặc thiếu trong lúc rollout.

```text
10% traffic -> analysis -> 30% traffic -> analysis -> 100%
     |             |             |             |
 canary pods   Prometheus    canary pods   Prometheus
```

> Hiểu lầm thường gặp:
> `setWeight: 10` không luôn đồng nghĩa 10% pod. Nếu có traffic routing, nó là trọng số traffic. Nếu không có traffic routing, Argo Rollouts dùng tỷ lệ replica để xấp xỉ.

### AnalysisTemplate

Ẩn dụ: AnalysisTemplate là checklist kiểm định chất lượng. Nếu món ăn mặn, bếp không được phục vụ cho toàn bộ khách.

Định nghĩa kỹ thuật: `AnalysisTemplate` định nghĩa các metric cần kiểm tra. `AnalysisRun` là lần chạy cụ thể của template trong một rollout.

Provider phổ biến:

- `prometheus`: query Prometheus.
- `web`: gọi HTTP endpoint.
- `job`: chạy Kubernetes Job.
- `datadog`, `newrelic`: query backend vendor.

Các field chính:

- `successCondition`: điều kiện pass.
- `failureCondition`: điều kiện fail.
- `count`: số lần đo.
- `interval`: khoảng cách giữa các lần đo.
- `initialDelay`: đợi metric tích lũy trước khi đo.
- `failureLimit`: số lần fail được phép trước khi AnalysisRun fail.
- `inconclusiveLimit`: số lần không kết luận được phép.

```text
Analysis timing

setWeight 10
    |
    v
initialDelay 2m
    |
    v
query mỗi 1m, count=5
    |
    +--> pass: đi tiếp
    +--> fail: abort
```

Background analysis chạy song song suốt rollout. Inline analysis nằm trong `steps` và chặn rollout cho đến khi pass hoặc fail.

> Vì sao điều này quan trọng?
> Inline analysis phù hợp gate quan trọng. Background analysis phù hợp quan sát liên tục trong cả rollout.

### Kết nối Ngày B với Ngày C

Ở Ngày B, bạn đã tạo recording rule:

```promql
service:availability_burn_rate:1h{namespace="platform",service="api-service"}
```

Canary nên dùng burn rate thay vì raw error rate vì burn rate đặt lỗi vào ngữ cảnh SLO và error budget.

```text
Raw error rate: 1%
  |
  +-- có thể rất xấu nếu SLO 99.9%
  +-- có thể ít xấu hơn nếu SLO 95%

Burn rate:
  |
  +-- đã chuẩn hóa theo error budget
```

Khuyến nghị `initialDelay` tối thiểu bằng 2 lần scrape interval. Nếu Prometheus scrape mỗi 30s, đặt `initialDelay: 2m` để có đủ sample ổn định.

> Vì sao điều này quan trọng?
> Canary quyết định dựa trên dữ liệu. Dữ liệu chưa kịp tích lũy sẽ tạo kết luận sai.

## 4. Vòng đời Rollout

```text
Progressing
    |
    v
Paused -----> Promoting -----> Healthy
    |
    v
Degraded -----> Aborting -----> Aborted
```

Khi abort:

1. Traffic được trả về stable.
2. ReplicaSet canary bị scale down theo chính sách.
3. Stable ReplicaSet tiếp tục phục vụ.
4. Rollout status chuyển `Degraded` hoặc `Aborted`.
5. Người vận hành sửa image/config rồi `retry rollout`.

```text
Canary fail

10% canary traffic
        |
        v
AnalysisRun failure
        |
        v
100% traffic -> stable
```

Lệnh override thủ công:

- `kubectl argo rollouts abort api-service`
- `kubectl argo rollouts promote api-service`
- `kubectl argo rollouts retry rollout api-service`

> Hiểu lầm thường gặp:
> Promote thủ công không có nghĩa version tốt. Nó chỉ bỏ qua gate hiện tại. Hãy dùng khi bạn có bằng chứng ngoài hệ thống analysis.

### ArgoCD và Argo Rollouts

Ẩn dụ: ArgoCD là người giữ Git làm nguồn sự thật; Rollouts Controller là người điều phối release từng bước. Hai người phải hiểu vai trò của nhau.

```text
Git
 |
 v
ArgoCD apply Rollout CRD
 |
 v
Rollouts Controller quản lý ReplicaSet, Service selector, AnalysisRun
 |
 v
ArgoCD đọc health của Rollout
```

ArgoCD 2.x có health check built-in cho Rollout resource. Điều này giúp ArgoCD không coi rollout đang pause/analysis là lỗi sync thông thường.

> Vì sao điều này quan trọng?
> Nếu ArgoCD và Rollouts không phối hợp, bạn dễ nhầm progressive rollout hợp lệ thành drift hoặc degraded sai.

## 5. Flagger - lựa chọn thay thế

Ẩn dụ: Argo Rollouts thay `Deployment` bằng loại resource mới. Flagger giống một lớp điều phối bọc quanh `Deployment` hiện có bằng `Canary` CRD.

```text
Flagger

Canary CRD
   |
   +--> đọc Deployment
   +--> tạo canary service
   +--> cấu hình traffic router
   +--> query metrics
   +--> promote hoặc rollback
```

| Khía cạnh | Argo Rollouts | Flagger |
| --- | --- | --- |
| Mô hình CRD | Dùng `Rollout` thay `Deployment` | Dùng `Canary` bọc `Deployment` |
| Traffic routing | NGINX, Istio, ALB, SMI, plugins | Istio, Linkerd, NGINX, App Mesh, Gateway API |
| Analysis providers | Prometheus, web, job, Datadog, New Relic | Prometheus và metric template |
| Tích hợp ArgoCD | Rất tự nhiên trong hệ Argo | Tốt nhưng không cùng bộ Argo |
| Độ khó học | Cần hiểu Rollout CRD | Dễ nếu đã có Deployment |
| Khi chọn | Muốn kiểm soát rollout từng step và AnalysisRun rõ | Muốn bọc Deployment hiện có và tự động hóa canary nhanh |

```text
Chọn nhanh

Cần step rollout chi tiết, manual promote, analysis inline?
        |
        v
Argo Rollouts

Muốn bọc Deployment hiện tại với canary tự động?
        |
        v
Flagger
```

> Vì sao điều này quan trọng?
> Tool nào cũng có trade-off. Chọn theo mô hình vận hành của đội, không chỉ theo độ phổ biến.
