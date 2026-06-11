# Ngày C - Lab: Canary với Argo Rollouts

Lab này dùng cluster `kind` từ Ngày A và Prometheus từ Ngày B để chạy canary cho `api-service`. Bạn sẽ cài Argo Rollouts, cài NGINX Ingress, deploy stable v1, trigger canary v2, quan sát AnalysisRun, ép lỗi, xem automatic abort, rồi retry với v3 khỏe.

## Điều kiện chuẩn bị

Bạn cần:

- Cluster `kind` tên `local-dev` từ Ngày A vẫn chạy.
- Prometheus từ Ngày B vẫn chạy tại `http://localhost:9090`.
- `helm` 3.x.
- `kubectl` đang trỏ tới context `kind-local-dev`.
- `kubectl argo rollouts` plugin.
- `k6` để chạy load test.

Kiểm tra:

```bash
kubectl config current-context
kubectl get nodes
curl -s http://localhost:9090/-/ready
k6 version
```

--- kết quả mong đợi ---

```text
kind-local-dev
NAME                      STATUS   ROLES           AGE   VERSION
local-dev-control-plane   Ready    control-plane   1d    v1.29.2
local-dev-worker          Ready    <none>          1d    v1.29.2
local-dev-worker2         Ready    <none>          1d    v1.29.2
Prometheus Server is Ready.
k6 v0.49.0
```

✓ Điểm kiểm tra: cluster, Prometheus và k6 đều sẵn sàng.

## Bước 1: Cài Argo Rollouts controller và kubectl plugin

Mục tiêu: cài controller trong namespace `argo-rollouts` và đảm bảo CLI plugin dùng được.

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts \
  --create-namespace \
  --wait \
  --timeout 10m

kubectl -n argo-rollouts get pods
kubectl argo rollouts version
```

--- kết quả mong đợi ---

```text
Release "argo-rollouts" does not exist. Installing it now.
NAME: argo-rollouts
STATUS: deployed

NAME                                      READY   STATUS    RESTARTS   AGE
argo-rollouts-6dfb7c8b8b-hk6m7            1/1     Running   0          90s

kubectl-argo-rollouts: v1.7.2
```

Nếu plugin chưa có, cài bằng lệnh sau trên Linux amd64:

```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/download/v1.7.2/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
kubectl argo rollouts version
```

✓ Điểm kiểm tra: `kubectl argo rollouts version` in ra version.

## Bước 2: Cài NGINX Ingress Controller

Mục tiêu: có traffic router để Argo Rollouts điều chỉnh canary weight.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.watchIngressWithoutClass=false \
  --set controller.ingressClassResource.name=nginx \
  --set controller.ingressClass=nginx \
  --wait \
  --timeout 10m

kubectl -n ingress-nginx get pods
```

--- kết quả mong đợi ---

```text
NAME                                        READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-7c5f75fcb9-qx8rm   1/1     Running   0          2m
```

Thêm host local:

```bash
grep -q 'api.local' /etc/hosts || echo '127.0.0.1 api.local' | sudo tee -a /etc/hosts
```

✓ Điểm kiểm tra: NGINX controller Running và `api.local` trỏ về `127.0.0.1`.

### Nếu có sự cố

Nếu bạn dùng Windows, thêm dòng `127.0.0.1 api.local` vào file `C:\Windows\System32\drivers\etc\hosts` bằng quyền Administrator.

## Bước 3: Deploy stable v1 bằng Rollout và Ingress

Mục tiêu: tạo namespace `platform`, services stable/canary, ingress và Rollout với image v1.

```bash
kubectl create namespace platform --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f day-c/rollouts/ingress-stable.yaml
kubectl apply -f day-c/rollouts/ingress-canary.yaml
kubectl apply -f day-c/rollouts/rollout.yaml

kubectl argo rollouts get rollout api-service -n platform
kubectl -n platform get svc,ingress,rollout
```

--- kết quả mong đợi ---

```text
rollout.argoproj.io/api-service created

Name:            api-service
Namespace:       platform
Status:          ✔ Healthy
Strategy:        Canary
Images:          ghcr.io/example/api-service:v1.0.0 (stable)
Replicas:
  Desired:       4
  Ready:         4

NAME                         TYPE        CLUSTER-IP      PORT(S)
service/api-service-stable    ClusterIP   10.96.40.10    80/TCP
service/api-service-canary    ClusterIP   10.96.41.10    80/TCP
```

✓ Điểm kiểm tra: Rollout `api-service` ở trạng thái `Healthy`.

## Bước 4: Apply AnalysisTemplates và nối Prometheus từ day-b

Mục tiêu: cài smoke test, burn-rate analysis và tạo DNS trong cluster để gọi Prometheus local.

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: prometheus-operated
  namespace: monitoring
spec:
  type: ExternalName
  externalName: host.docker.internal
  ports:
    - name: http
      port: 9090
      targetPort: 9090
YAML

kubectl apply -f day-c/rollouts/analysis-template-smoke.yaml
kubectl apply -f day-c/rollouts/analysis-template-burn-rate.yaml
kubectl -n platform get analysistemplate
```

--- kết quả mong đợi ---

```text
service/prometheus-operated created
analysistemplate.argoproj.io/api-service-smoke created
analysistemplate.argoproj.io/api-service-burn-rate created

NAME                    AGE
api-service-smoke       10s
api-service-burn-rate   10s
```

✓ Điểm kiểm tra: cả hai AnalysisTemplate tồn tại trong namespace `platform`.

### Nếu có sự cố

Nếu AnalysisRun báo không gọi được Prometheus, kiểm tra DNS từ trong cluster:

```bash
kubectl -n platform run dns-test --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- \
  curl -s http://prometheus-operated.monitoring.svc.cluster.local:9090/-/ready
```

## Bước 5: Trigger canary bằng image v2

Mục tiêu: cập nhật image lên v2 và quan sát rollout đi qua smoke test, 10%, analysis, 30%, analysis.

```bash
kubectl argo rollouts set image api-service api-service=ghcr.io/example/api-service:v2.0.0 -n platform
kubectl argo rollouts get rollout api-service -n platform --watch
```

--- kết quả mong đợi ---

```text
Name:            api-service
Namespace:       platform
Status:          ॥ Paused
Strategy:        Canary
Images:          ghcr.io/example/api-service:v2.0.0 (canary)
                 ghcr.io/example/api-service:v1.0.0 (stable)
Steps:
  ✔ analysis: api-service-smoke
  ✔ setWeight: 10
  ❯ analysis: api-service-burn-rate
  • setWeight: 30
  • analysis: api-service-burn-rate
  • setWeight: 100
```

✓ Điểm kiểm tra: rollout tạo canary ReplicaSet và bắt đầu AnalysisRun.

## Bước 6: Kiểm tra AnalysisRun và metric canary/stable

Mục tiêu: xác nhận AnalysisRun đang chạy và Prometheus có metric phân biệt `version=canary`.

```bash
kubectl argo rollouts list analysisruns -n platform
kubectl get analysisrun -n platform -w
```

--- kết quả mong đợi ---

```text
NAME                            STATUS       AGE
api-service-smoke-7c9b8         Successful   2m
api-service-burn-rate-5m        Running      1m
```

Query Prometheus:

```bash
promtool query instant http://localhost:9090 'sum by (version) (rate(http_requests_total{namespace="platform",service="api-service"}[5m]))'
```

--- kết quả mong đợi ---

```text
{version="stable"} => 45.21 @[1780986000.000]
{version="canary"} => 5.02 @[1780986000.000]
```

✓ Điểm kiểm tra: Prometheus có cả `version=stable` và `version=canary`.

## Bước 7: Mô phỏng canary failure bằng cách bật failure mode

Mục tiêu: làm canary trả lỗi để AnalysisRun fail.

```bash
CANARY_POD="$(kubectl -n platform get pod -l app.kubernetes.io/name=api-service,version=canary -o jsonpath='{.items[0].metadata.name}')"
kubectl -n platform exec "$CANARY_POD" -- \
  curl -s -X POST http://127.0.0.1:8080/admin/failure-mode \
  -H 'Content-Type: application/json' \
  -d '{"enabled":true,"error_rate":1.0}'

kubectl -n platform logs "$CANARY_POD" --tail=20
```

--- kết quả mong đợi ---

```text
{"status":"ok","failure_mode":true,"error_rate":1}
{"level":"warn","service":"api-service","message":"failure mode enabled","error_rate":1}
```

✓ Điểm kiểm tra: canary pod xác nhận `failure_mode=true`.

### Nếu có sự cố

Nếu image lab của bạn không có endpoint `/admin/failure-mode`, mô phỏng bằng image lỗi:

```bash
kubectl argo rollouts set image api-service api-service=ghcr.io/example/api-service:broken -n platform
```

## Bước 8: Quan sát AnalysisRun fail và automatic abort

Mục tiêu: thấy failureCondition kích hoạt, rollout abort và traffic quay về stable.

```bash
kubectl argo rollouts get rollout api-service -n platform --watch
kubectl argo rollouts list analysisruns -n platform
kubectl -n platform get ingress api-service-canary -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}{"\n"}'
```

--- kết quả mong đợi ---

```text
Status:          ✖ Degraded
Message:         RolloutAborted: AnalysisRun api-service-burn-rate-5m failed

NAME                         STATUS       AGE
api-service-burn-rate-5m     Failed       7m

0
```

Kiểm tra traffic:

```bash
for i in $(seq 1 10); do curl -s -I http://api.local/health | grep -i x-service-version || true; done
```

--- kết quả mong đợi ---

```text
x-service-version: stable
x-service-version: stable
x-service-version: stable
```

✓ Điểm kiểm tra: canary weight về `0` và traffic quay lại stable.

## Bước 9: Sửa image, retry rollout và promote thành công

Mục tiêu: đổi sang v3 khỏe, retry rollout và quan sát promote lên 100%.

```bash
kubectl argo rollouts set image api-service api-service=ghcr.io/example/api-service:v3.0.0 -n platform
kubectl argo rollouts retry rollout api-service -n platform
kubectl argo rollouts get rollout api-service -n platform --watch
```

--- kết quả mong đợi ---

```text
rollout "api-service" image updated
rollout 'api-service' retried

Name:            api-service
Namespace:       platform
Status:          ✔ Healthy
Strategy:        Canary
Images:          ghcr.io/example/api-service:v3.0.0 (stable)
Steps:
  ✔ analysis: api-service-smoke
  ✔ setWeight: 10
  ✔ analysis: api-service-burn-rate
  ✔ setWeight: 30
  ✔ analysis: api-service-burn-rate
  ✔ setWeight: 100
```

✓ Điểm kiểm tra: Rollout `Healthy` và stable image là v3.

## Bước 10: Chạy k6 load test trong lúc rollout

Mục tiêu: tạo tải trong quá trình canary và xác nhận threshold pass.

```bash
BASE_URL=http://api.local k6 run day-c/k6/load-test.js
```

--- kết quả mong đợi ---

```text
Tóm tắt k6 load test
p95 latency: 84.21 ms
http_req_failed: 0.002

checks.........................: 100.00% ✓ 12000 ✗ 0
http_req_duration..............: avg=25.4ms min=2.1ms med=18.2ms max=160.8ms p(95)=84.21ms
http_req_failed................: 0.20%  ✓ 24    ✗ 11976
canary_error_rate..............: 0.00%
```

Để xuất metrics k6 sang Prometheus remote write:

```bash
K6_PROMETHEUS_RW_SERVER_URL=http://localhost:9090/api/v1/write \
BASE_URL=http://api.local \
k6 run -o experimental-prometheus-rw day-c/k6/load-test.js
```

✓ Điểm kiểm tra: `http_req_duration p95 < 200ms`, `http_req_failed < 1%`, và `canary_error_rate < 1%`.

## Dọn dẹp

```bash
kubectl delete -f day-c/rollouts/rollout.yaml --ignore-not-found
kubectl delete -f day-c/rollouts/analysis-template-burn-rate.yaml --ignore-not-found
kubectl delete -f day-c/rollouts/analysis-template-smoke.yaml --ignore-not-found
kubectl delete -f day-c/rollouts/ingress-canary.yaml --ignore-not-found
kubectl delete -f day-c/rollouts/ingress-stable.yaml --ignore-not-found
```

## Những gì bạn đã học

- Progressive Delivery giảm blast radius bằng cách đưa traffic sang version mới theo từng bước.
- Argo Rollouts thay `Deployment` bằng `Rollout` để hỗ trợ canary, analysis và abort.
- NGINX Ingress canary annotation cho phép chia traffic HTTP theo phần trăm.
- AnalysisTemplate có thể dùng burn rate từ day-b để quyết định rollout.
- Automatic abort trả traffic về stable khi metric vượt ngưỡng fail.
- k6 giúp tạo tải thực tế để kiểm chứng latency và error threshold trong rollout.

## Câu hỏi suy ngẫm

1. Vì sao burn rate thường đáng tin hơn raw error rate khi dùng làm canary gate?
2. Nếu canary chỉ nhận 5% traffic, bạn cần bao lâu để có đủ dữ liệu đáng tin trước khi promote?
3. Khi nào bạn nên dùng manual promote thay vì để AnalysisRun tự quyết định?

## Bước tiếp theo

- Đọc Argo Rollouts canary strategy: https://argoproj.github.io/argo-rollouts/features/canary/
- Đọc AnalysisTemplate và AnalysisRun: https://argoproj.github.io/argo-rollouts/features/analysis/
- Đọc NGINX traffic routing với Argo Rollouts: https://argoproj.github.io/argo-rollouts/features/traffic-management/nginx/
- Đọc k6 thresholds: https://k6.io/docs/using-k6/thresholds/
