# Ngày C - Lệnh thực hành: Argo Rollouts và Canary

Các ví dụ dùng `namespace=platform`, `service=api-service`, image `ghcr.io/example/api-service`, và Rollout tên `api-service`.

## Argo Rollouts kubectl plugin

### Theo dõi rollout

```bash
# MỤC ĐÍCH: Xem trạng thái rollout theo thời gian thực.
# KHI DÙNG: Ngay sau khi đổi image hoặc apply Rollout mới.
$ kubectl argo rollouts get rollout api-service -n platform --watch
--- kết quả mong đợi ---
Name:            api-service
Namespace:       platform
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
Images:          ghcr.io/example/api-service:v2.0.0 (canary)
                 ghcr.io/example/api-service:v1.0.0 (stable)
Replicas:
  Desired:       4
  Current:       5
  Updated:       1
  Ready:         5
Steps:
  ✔ setWeight: 10
  ❯ analysis: api-service-burn-rate
  • setWeight: 30
💡 MẸO: Giữ lệnh này chạy trong một terminal riêng khi làm canary.
⚠️ LƯU Ý: Nếu status Paused, kiểm tra xem đang chờ pause thủ công hay chờ AnalysisRun.
```

### Đổi image để kích hoạt canary

```bash
# MỤC ĐÍCH: Cập nhật image của Rollout và bắt đầu rollout mới.
# KHI DÙNG: Khi deploy version mới của api-service.
$ kubectl argo rollouts set image api-service api-service=ghcr.io/example/api-service:v2.0.0 -n platform
--- kết quả mong đợi ---
rollout "api-service" image updated
💡 MẸO: Dùng tag bất biến hoặc digest trong production để tránh tag bị ghi đè.
⚠️ LƯU Ý: Lệnh này sửa live state; trong GitOps chuẩn, hãy commit thay đổi image vào Git.
```

### Promote rollout

```bash
# MỤC ĐÍCH: Cho rollout đi tiếp qua bước pause hiện tại.
# KHI DÙNG: Khi analysis pass và bạn cần approve thủ công để tiếp tục.
$ kubectl argo rollouts promote api-service -n platform
--- kết quả mong đợi ---
rollout 'api-service' promoted
💡 MẸO: Promote thủ công nên đi kèm bằng chứng từ dashboard hoặc AnalysisRun.
⚠️ LƯU Ý: Promote có thể bỏ qua thời gian quan sát cần thiết nếu dùng quá sớm.
```

### Abort rollout

```bash
# MỤC ĐÍCH: Dừng canary và trả traffic về stable.
# KHI DÙNG: Khi error rate, burn rate hoặc smoke test cho thấy version mới xấu.
$ kubectl argo rollouts abort api-service -n platform
--- kết quả mong đợi ---
rollout 'api-service' aborted
💡 MẸO: Sau abort, giữ lại log và AnalysisRun để postmortem.
⚠️ LƯU Ý: Abort không sửa Git; hãy revert commit hoặc cập nhật manifest sau đó.
```

### Retry rollout

```bash
# MỤC ĐÍCH: Chạy lại rollout sau khi đã sửa nguyên nhân fail.
# KHI DÙNG: Khi canary trước đó Aborted nhưng bạn muốn thử lại version đã sửa.
$ kubectl argo rollouts retry rollout api-service -n platform
--- kết quả mong đợi ---
rollout 'api-service' retried
💡 MẸO: Retry phù hợp khi lỗi do dependency tạm thời; nếu image lỗi, hãy đổi image trước.
⚠️ LƯU Ý: Retry cùng image lỗi sẽ thất bại lại với cùng lý do.
```

### Liệt kê rollout

```bash
# MỤC ĐÍCH: Xem danh sách Rollout trong namespace.
# KHI DÙNG: Khi kiểm tra inventory progressive delivery.
$ kubectl argo rollouts list rollouts -n platform
--- kết quả mong đợi ---
NAME          STRATEGY   STATUS      STEP  SET-WEIGHT  READY  DESIRED  UP-TO-DATE  AVAILABLE
api-service   Canary     Healthy     5/5   100         4/4    4        4           4
💡 MẸO: Lệnh này nhanh hơn `kubectl get rollout` khi cần xem trạng thái tổng quan.
⚠️ LƯU Ý: Namespace sai là lý do phổ biến khiến danh sách trống.
```

### Xem AnalysisRun

```bash
# MỤC ĐÍCH: Xem chi tiết một AnalysisRun cụ thể.
# KHI DÙNG: Khi rollout pause, fail hoặc bạn cần biết metric nào không đạt.
$ kubectl argo rollouts get analysisrun api-service-burn-rate-5m -n platform
--- kết quả mong đợi ---
Name:        api-service-burn-rate-5m
Namespace:   platform
Status:      Successful
Metric Results:
  availability-burn-rate:
    Phase: Successful
    Measurements:
    - Phase: Successful
      Value: 0.42
  latency-p99:
    Phase: Successful
    Measurements:
    - Phase: Successful
      Value: 0.091
💡 MẸO: Xem metric result trước khi quyết định promote thủ công.
⚠️ LƯU Ý: AnalysisRun cũ có thể bị garbage collect nếu lịch sử giữ quá ít.
```

### Liệt kê AnalysisRun

```bash
# MỤC ĐÍCH: Liệt kê các AnalysisRun do Rollout tạo.
# KHI DÙNG: Khi cần tìm tên AnalysisRun mới nhất.
$ kubectl argo rollouts list analysisruns -n platform
--- kết quả mong đợi ---
NAME                         STATUS       AGE
api-service-smoke-7c9b8      Successful   8m
api-service-burn-rate-5m     Successful   6m
api-service-burn-rate-10m    Running      1m
💡 MẸO: Dùng AGE để tìm AnalysisRun liên quan rollout hiện tại.
⚠️ LƯU Ý: Nhiều AnalysisRun cùng tên tiền tố có thể thuộc các rollout revision khác nhau.
```

### Pause rollout

```bash
# MỤC ĐÍCH: Tạm dừng rollout tại trạng thái hiện tại.
# KHI DÙNG: Khi cần giữ canary ở một mức traffic để điều tra thêm.
$ kubectl argo rollouts pause api-service -n platform
--- kết quả mong đợi ---
rollout 'api-service' paused
💡 MẸO: Pause giúp bạn giữ traffic canary ổn định trong lúc xem dashboard.
⚠️ LƯU Ý: Đừng quên resume; rollout pause quá lâu có thể gây nhầm lẫn trong GitOps.
```

### Resume rollout

```bash
# MỤC ĐÍCH: Tiếp tục rollout đã pause.
# KHI DÙNG: Sau khi điều tra xong và muốn rollout đi tiếp.
$ kubectl argo rollouts resume api-service -n platform
--- kết quả mong đợi ---
rollout 'api-service' resumed
💡 MẸO: Chạy `get rollout --watch` ngay sau resume.
⚠️ LƯU Ý: Resume không sửa metric fail; nếu analysis vẫn fail, rollout sẽ abort.
```

## Argo Rollouts dashboard

### Mở dashboard local

```bash
# MỤC ĐÍCH: Mở UI local để xem Rollout, ReplicaSet và AnalysisRun.
# KHI DÙNG: Khi bạn muốn quan sát trực quan thay vì chỉ dùng terminal.
$ kubectl argo rollouts dashboard -n platform --port 3100
--- kết quả mong đợi ---
INFO[0000] Argo Rollouts Dashboard is now available at http://localhost:3100/rollouts
💡 MẸO: Dashboard rất hữu ích khi giải thích canary cho người mới.
⚠️ LƯU Ý: Dashboard local không thay thế RBAC và audit trong môi trường production.
```

## Lệnh kubectl hữu ích khi canary

### Xem ReplicaSet stable và canary

```bash
# MỤC ĐÍCH: Kiểm tra ReplicaSet nào là stable và canary.
# KHI DÙNG: Khi muốn xác nhận version mới chỉ chạy một phần replica.
$ kubectl get replicasets -n platform -l app.kubernetes.io/name=api-service --show-labels
--- kết quả mong đợi ---
NAME                     DESIRED  CURRENT  READY  AGE  LABELS
api-service-5df45d7b9c   4        4        4      1h   app.kubernetes.io/name=api-service,version=stable
api-service-7c8f7f74c9   1        1        1      5m   app.kubernetes.io/name=api-service,version=canary
💡 MẸO: Label `version=canary` giúp Prometheus tách metric canary và stable.
⚠️ LƯU Ý: Replica count không phải lúc nào cũng bằng traffic weight nếu có ingress traffic routing.
```

### Describe rollout

```bash
# MỤC ĐÍCH: Xem event và condition chi tiết của Rollout.
# KHI DÙNG: Khi rollout bị ProgressDeadlineExceeded, Paused hoặc Degraded.
$ kubectl describe rollout api-service -n platform
--- kết quả mong đợi ---
Name:         api-service
Namespace:    platform
Strategy:     Canary
Conditions:
  Type             Status  Reason
  Available        True    AvailableReason
  Progressing      True    NewReplicaSetAvailable
Events:
  Normal  RolloutUpdated  Rollout updated to revision 2
  Normal  AnalysisRun     Created AnalysisRun api-service-burn-rate-5m
💡 MẸO: Event cuối thường nói rõ rollout đang chờ gì.
⚠️ LƯU Ý: Describe dài; đọc từ Conditions và Events trước.
```

### Watch AnalysisRun

```bash
# MỤC ĐÍCH: Theo dõi AnalysisRun được tạo trong rollout.
# KHI DÙNG: Khi rollout đang ở bước analysis.
$ kubectl get analysisrun -n platform -w
--- kết quả mong đợi ---
NAME                         STATUS       AGE
api-service-smoke-7c9b8      Running      10s
api-service-smoke-7c9b8      Successful   1m
api-service-burn-rate-5m     Running      2m
api-service-burn-rate-5m     Successful   7m
💡 MẸO: Dùng terminal này song song với `get rollout --watch`.
⚠️ LƯU Ý: Nếu AnalysisRun Inconclusive, hãy kiểm tra query Prometheus có trả dữ liệu không.
```
