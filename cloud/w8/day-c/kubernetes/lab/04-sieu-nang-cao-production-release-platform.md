# Lab 04 - Siêu nâng cao: Mô phỏng triển khai production cho một dịch vụ nội bộ

## Bối cảnh

Bạn là Senior Kubernetes Engineer trong một công ty đang chuẩn hóa cách triển khai service nội bộ lên Kubernetes. Team ứng dụng muốn deploy một API tên `orders-api`. Yêu cầu không chỉ là "chạy được", mà phải đủ tiêu chuẩn vận hành thực tế: cấu hình tách biệt, secret, rollout an toàn, autoscaling, giới hạn traffic bằng NetworkPolicy, persistent storage cho cache, Ingress nội bộ, health check, debug plan, rollback plan và runbook vận hành.

Lab này là bài tổng hợp có tính thực tế cao nhất. Bạn sẽ thiết kế một mini production release trong namespace riêng, có nhiều lớp kiểm soát và có tiêu chí nghiệm thu rõ ràng. Không cần cloud LoadBalancer thật, nhưng manifest phải theo hướng có thể chuyển sang môi trường thật với thay đổi tối thiểu.

## Mục tiêu

Sau khi hoàn thành lab, bạn cần chứng minh được:

* Thiết kế tài nguyên Kubernetes theo hướng production-minded.
* Tách `base workload`, `networking`, `configuration`, `storage`, `autoscaling` và `operations`.
* Cấu hình probes, resources, rollout strategy và PodDisruptionBudget.
* Áp dụng NetworkPolicy theo nguyên tắc least privilege.
* Sử dụng Ingress để định tuyến HTTP theo host/path.
* Dùng HPA để scale theo CPU.
* Thiết kế runbook debug và rollback.
* Tạo được bộ manifest có thể apply lại từ đầu.

## Namespace

Tạo namespace:

```text
lab-production
```

Tất cả object phải nằm trong namespace này, trừ những object cluster-scoped nếu bạn chủ động dùng thêm. Lab này không yêu cầu tạo object cluster-scoped.

## Kiến trúc mong muốn

```mermaid
graph TD
  User["Internal user / tester"] --> Ingress["Ingress orders.internal.local"]
  Ingress --> WebSvc["Service orders-api"]
  WebSvc --> Pods["Deployment orders-api"]
  Pods --> PVC["PVC orders-cache"]
  Pods --> CM["ConfigMap orders-config"]
  Pods --> Secret["Secret orders-secret"]
  HPA["HPA orders-api"] --> Pods
  PDB["PodDisruptionBudget"] -. bảo vệ availability .-> Pods
  NPIngress["NetworkPolicy allow-ingress-controller"] -. kiểm soát ingress .-> Pods
  NPOps["NetworkPolicy allow-ops-client"] -. cho phép test client .-> Pods
```

## Bài toán nghiệp vụ

`orders-api` là service xử lý đơn hàng. Trong lab, bạn có thể dùng `nginx:1.27-alpine` để mô phỏng HTTP server, nhưng manifest phải được thiết kế như một service production:

* Có nhiều replica.
* Không dùng image `latest`.
* Có resource request/limit.
* Có readiness/liveness/startup probe nếu phù hợp.
* Có rolling update không downtime.
* Có autoscaling.
* Có cấu hình qua ConfigMap.
* Có secret giả lập.
* Có PVC cho cache.
* Có Service và Ingress.
* Có NetworkPolicy.
* Có runbook kiểm tra và rollback.

## Tài nguyên bắt buộc

| Nhóm | Object | Tên |
|---|---|---|
| Namespace | Namespace | `lab-production` |
| Configuration | ConfigMap | `orders-config` |
| Configuration | Secret | `orders-secret` |
| Storage | PVC | `orders-cache` |
| Workload | Deployment | `orders-api` |
| Networking | Service | `orders-api` |
| Networking | Ingress | `orders-api` |
| Security | NetworkPolicy | `orders-api-ingress` |
| Security | NetworkPolicy | `orders-api-ops-client` |
| Reliability | HPA | `orders-api` |
| Reliability | PodDisruptionBudget | `orders-api` |

## Yêu cầu ConfigMap

Tạo `orders-config` gồm:

```text
APP_NAME=orders-api
APP_ENV=production-like
LOG_LEVEL=info
CACHE_PATH=/var/cache/orders
PUBLIC_BASE_URL=http://orders.internal.local
```

Các key này phải được inject vào container dưới dạng environment variables.

## Yêu cầu Secret

Tạo `orders-secret` gồm:

```text
DATABASE_URL=postgres://orders:change-me@postgres.internal:5432/orders
JWT_SIGNING_KEY=local-lab-signing-key
PAYMENT_PROVIDER_TOKEN=fake-payment-token
```

Trong lab, các secret này chỉ là dữ liệu giả lập. Tuy nhiên cách dùng phải giống thực tế:

* Không đưa secret vào ConfigMap.
* Không echo secret ra logs.
* Không viết secret trực tiếp vào command container.

## Yêu cầu Storage

Tạo PVC `orders-cache`:

* Request storage: `2Gi`.
* Access mode: `ReadWriteOnce`.
* Dùng StorageClass mặc định nếu có.

Mount PVC vào container tại:

```text
/var/cache/orders
```

Nếu cluster không có StorageClass mặc định, bạn phải ghi lại lý do PVC `Pending` và đề xuất cách xử lý trong môi trường thật.

## Yêu cầu Deployment

Tạo Deployment `orders-api`:

* Replicas ban đầu: `3`.
* Image: `nginx:1.27-alpine`.
* Container name: `orders-api`.
* Container port: `80`.
* Label bắt buộc:
  * `app: orders-api`
  * `tier: backend`
  * `part-of: commerce`
* Strategy:
  * `type: RollingUpdate`
  * `maxSurge: 1`
  * `maxUnavailable: 0`
* Resource requests:
  * CPU: `200m`
  * Memory: `256Mi`
* Resource limits:
  * CPU: `1000m`
  * Memory: `512Mi`
* Readiness probe:
  * HTTP GET `/`
  * port `80`
  * period `5s`
* Liveness probe:
  * HTTP GET `/`
  * port `80`
  * initial delay hợp lý
* Startup probe:
  * HTTP GET `/`
  * port `80`
  * cho phép app có thời gian warm up
* Mount PVC `orders-cache`.
* Inject ConfigMap và Secret.

## Yêu cầu Service

Tạo Service `orders-api`:

* Type: `ClusterIP`.
* Selector match label `app: orders-api`.
* Port: `80`.
* TargetPort: `80`.

Sau khi tạo, kiểm tra EndpointSlice không rỗng.

## Yêu cầu Ingress

Tạo Ingress `orders-api`:

* Host: `orders.internal.local`.
* Path: `/`.
* PathType: `Prefix`.
* Backend Service: `orders-api`, port `80`.

Nếu dùng Minikube, bạn có thể cần:

```bash
minikube addons enable ingress
```

Để test local, có thể cần map host vào IP ingress hoặc dùng `curl` với header `Host`.

## Yêu cầu NetworkPolicy

Tạo hai policy.

### Policy 1 - `orders-api-ingress`

Mục tiêu: chỉ cho ingress controller gọi tới `orders-api`.

Vì label của ingress controller khác nhau giữa môi trường, bạn cần:

* Xác định namespace và label của ingress controller.
* Viết policy cho phép traffic TCP 80 từ namespace/pod ingress controller.
* Nếu không xác định được label ổn định trong môi trường local, ghi rõ giả định trong file notes.

### Policy 2 - `orders-api-ops-client`

Mục tiêu: cho phép Pod vận hành nội bộ test service.

Policy này cho phép ingress TCP 80 từ Pod có label:

```text
role=ops-client
```

trong cùng namespace.

## Yêu cầu HPA

Tạo HPA `orders-api`:

* API: `autoscaling/v2`.
* Target Deployment: `orders-api`.
* Min replicas: `3`.
* Max replicas: `8`.
* CPU average utilization: `60`.

Nếu HPA không hoạt động, bạn phải debug và ghi lại nguyên nhân:

* metrics-server thiếu.
* CPU request thiếu.
* HPA target sai.
* workload không tạo đủ CPU load.

## Yêu cầu PodDisruptionBudget

Tạo PDB `orders-api`:

* Chọn Pod bằng label `app: orders-api`.
* `minAvailable: 2`.

Giải thích trong notes vì sao PDB không thay thế readiness probe và cũng không đảm bảo chống node crash đột ngột.

## Bài test nghiệm thu

### Test 1 - Apply từ đầu

Bạn phải có thể chạy:

```bash
kubectl delete namespace lab-production
kubectl apply -f .
```

hoặc apply theo thứ tự manifest đã ghi rõ.

Hệ thống phải trở về trạng thái:

* Namespace tồn tại.
* PVC Bound.
* Deployment Available.
* 3 Pod Ready.
* Service có EndpointSlice.
* HPA target đúng Deployment.
* PDB tồn tại.

### Test 2 - Truy cập qua Service

Tạo Pod ops client:

```bash
kubectl run ops-client --image=busybox:1.36 --restart=Never -n lab-production --labels=role=ops-client -- sh -c "sleep 3600"
```

Exec vào Pod:

```bash
kubectl exec -it ops-client -n lab-production -- sh
```

Kiểm tra:

```sh
nslookup orders-api
wget -qO- http://orders-api
```

### Test 3 - Truy cập qua Ingress

Tùy môi trường, kiểm tra bằng một trong các cách:

```bash
curl -H "Host: orders.internal.local" http://<INGRESS_IP>/
```

hoặc:

```bash
curl http://orders.internal.local/
```

Bạn phải ghi lại cách xác định `INGRESS_IP`.

### Test 4 - NetworkPolicy

Tạo một Pod không có label `role=ops-client` và thử gọi `orders-api`.

Kỳ vọng:

* Nếu CNI enforce NetworkPolicy: request bị chặn.
* Nếu CNI không enforce: request vẫn đi qua, và bạn phải ghi rõ hạn chế môi trường.

### Test 5 - Rolling update không downtime

Cập nhật image sang:

```text
nginx:1.26-alpine
```

Trong lúc rollout, liên tục gọi Service từ `ops-client`.

Kỳ vọng:

* `kubectl rollout status` thành công.
* Service vẫn có endpoint Ready.
* Không có thời điểm tất cả Pod unavailable vì `maxUnavailable: 0`.

### Test 6 - Rollback sự cố production

Cập nhật image sang:

```text
nginx:broken-production-release
```

Bạn cần:

* Xác định rollout bị lỗi.
* Không xóa Deployment.
* Rollback bằng `kubectl rollout undo`.
* Verify Service hoạt động lại.
* Ghi lại timeline sự cố.

### Test 7 - HPA

Tạo load nếu môi trường có metrics-server:

```bash
kubectl run load-generator --image=busybox:1.36 --restart=Never -n lab-production --labels=role=ops-client -- sh -c "while true; do wget -q -O- http://orders-api >/dev/null; done"
```

Quan sát:

```bash
kubectl get hpa orders-api -n lab-production -w
kubectl get deployment orders-api -n lab-production -w
```

Nếu replicas không tăng, phân tích nguyên nhân thay vì chỉ kết luận "HPA lỗi".

## Deliverables

Trong thư mục làm bài, bạn cần có:

```text
00-namespace.yaml
01-config-secret.yaml
02-storage.yaml
03-deployment.yaml
04-service.yaml
05-ingress.yaml
06-networkpolicy.yaml
07-hpa.yaml
08-pdb.yaml
RUNBOOK.md
```

`RUNBOOK.md` phải có:

* Cách deploy từ đầu.
* Cách kiểm tra health.
* Cách test Service.
* Cách test Ingress.
* Cách debug Pod không Ready.
* Cách debug Service không có endpoint.
* Cách debug HPA `unknown`.
* Cách rollback release lỗi.
* Cách dọn dẹp lab.

## Gợi ý

* Tạo manifest theo nhóm, apply namespace trước.
* Với Secret, dùng `stringData` để tránh tự base64 thủ công trong lab.
* Dùng `kubectl explain` để kiểm tra field của HPA, PDB và probes.
* Với Ingress, lỗi thường nằm ở thiếu ingress controller, host không resolve hoặc backend Service sai.
* Với NetworkPolicy, luôn test cả case được phép và bị chặn.
* Với rolling update, luôn dùng `kubectl rollout status`.
* Với PVC, Pending thường do thiếu StorageClass hoặc provisioner.

## Checklist nghiệm thu

* [ ] Có đầy đủ manifest và `RUNBOOK.md`.
* [ ] Apply lại từ đầu thành công.
* [ ] Deployment có 3 Pod Ready.
* [ ] PVC Bound và được mount vào Pod.
* [ ] ConfigMap/Secret được inject vào Pod.
* [ ] Service có EndpointSlice.
* [ ] Ingress có rule đúng host/path.
* [ ] NetworkPolicy được test hai chiều: allowed và blocked.
* [ ] HPA tồn tại và target đúng Deployment.
* [ ] PDB bảo vệ tối thiểu 2 Pod available.
* [ ] Rolling update thành công.
* [ ] Rollback image lỗi thành công.
* [ ] RUNBOOK mô tả đủ quy trình vận hành.

## Tiêu chí đánh giá

Lab đạt mức siêu nâng cao khi người khác có thể nhận repo manifest của bạn, đọc `RUNBOOK.md`, deploy lại trên một cluster khác, hiểu rõ giả định môi trường, và vận hành được service mà không cần bạn ngồi cạnh giải thích.

