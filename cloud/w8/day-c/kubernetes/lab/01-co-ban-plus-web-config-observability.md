# Lab 01 - Cơ bản Plus: Triển khai Web App có cấu hình, health check và debug

## Bối cảnh

Bạn được giao triển khai một ứng dụng web nội bộ đơn giản cho team Platform. Ứng dụng chạy bằng `nginx`, nhận cấu hình qua `ConfigMap`, nhận một giá trị nhạy cảm giả lập qua `Secret`, expose trong cluster bằng `Service`, và phải có health check để Kubernetes biết khi nào Pod sẵn sàng nhận traffic.

Lab này được gọi là "cơ bản plus" vì không chỉ yêu cầu tạo Pod hoặc Deployment đơn giản. Bạn phải phối hợp nhiều object thường gặp trong CKAD: `Namespace`, `ConfigMap`, `Secret`, `Deployment`, `Service`, `readinessProbe`, `livenessProbe`, resource requests/limits, logs và troubleshooting.

## Mục tiêu

Sau khi hoàn thành lab, bạn cần chứng minh được:

* Tạo workload bằng YAML, không chỉ dùng command imperative.
* Inject cấu hình vào container bằng biến môi trường.
* Sử dụng `ConfigMap` và `Secret` đúng mục đích.
* Tạo `Deployment` có nhiều replica và rollout ổn định.
* Expose workload bằng `ClusterIP Service`.
* Kiểm tra app bằng Pod tạm trong cùng namespace.
* Debug được các lỗi cơ bản như selector sai, Pod không Ready hoặc thiếu biến môi trường.

## Yêu cầu môi trường

* Có Kubernetes cluster local hoặc remote.
* Có `kubectl` trỏ tới đúng context.
* Namespace lab phải tách riêng, không dùng `default`.
* Không cần Ingress hoặc LoadBalancer.

## Tài nguyên cần tạo

Tạo namespace:

```text
lab-basic-plus
```

Tạo các object sau trong namespace đó:

| Object | Tên bắt buộc | Ghi chú |
|---|---|---|
| ConfigMap | `web-config` | Chứa cấu hình không nhạy cảm |
| Secret | `web-secret` | Chứa token giả lập |
| Deployment | `web-app` | Chạy `nginx:1.27-alpine` |
| Service | `web-app` | Type `ClusterIP`, port `80` |

## Yêu cầu chi tiết

### 1. Namespace

Tạo namespace `lab-basic-plus`. Tất cả tài nguyên của lab phải nằm trong namespace này.

Bạn cần chứng minh namespace hiện tại đã được set đúng hoặc mọi command đều dùng `-n lab-basic-plus`.

### 2. ConfigMap

Tạo `ConfigMap` tên `web-config` có tối thiểu các key sau:

```text
APP_NAME=platform-demo
APP_ENV=training
LOG_LEVEL=info
```

Các giá trị này phải được đưa vào container dưới dạng environment variables.

### 3. Secret

Tạo `Secret` tên `web-secret` có key:

```text
API_TOKEN=dev-token-123
```

Bạn có thể dùng `stringData` trong YAML để dễ đọc khi viết manifest. Không dùng `ConfigMap` để chứa token.

### 4. Deployment

Tạo `Deployment` tên `web-app` với các yêu cầu:

* Image: `nginx:1.27-alpine`.
* Replica: `3`.
* Label template bắt buộc có `app: web-app`.
* Container name: `nginx`.
* Container port: `80`.
* Inject toàn bộ key từ `web-config`.
* Inject key `API_TOKEN` từ `web-secret`.
* Có `readinessProbe` HTTP GET tới `/` port `80`.
* Có `livenessProbe` HTTP GET tới `/` port `80`.
* Có resource requests/limits:
  * request CPU: `100m`
  * request memory: `128Mi`
  * limit CPU: `500m`
  * limit memory: `256Mi`

### 5. Service

Tạo `Service` tên `web-app`:

* Type: `ClusterIP`.
* Selector phải match đúng Pod label.
* Service port: `80`.
* Target port: `80`.

### 6. Kiểm tra truy cập nội bộ

Tạo một Pod tạm bằng `busybox:1.36` hoặc image tương đương để kiểm tra DNS và HTTP:

```bash
kubectl run test-client --image=busybox:1.36 --rm -it --restart=Never -n lab-basic-plus -- sh
```

Từ trong Pod test, kiểm tra:

```sh
nslookup web-app
wget -qO- http://web-app
```

Bạn không cần giữ Pod test sau khi kiểm tra.

## Ràng buộc

* Không dùng `kubectl expose` làm kết quả cuối nếu không lưu được YAML.
* Không dùng image `latest`.
* Không hard-code token trong command của container.
* Không dùng `NodePort`.
* Không tạo tài nguyên ngoài namespace `lab-basic-plus`.

## Gợi ý

* Dùng `kubectl create configmap ... --dry-run=client -o yaml` để sinh nhanh YAML ConfigMap.
* Dùng `kubectl create secret generic ... --dry-run=client -o yaml` nếu muốn sinh Secret nhanh.
* Dùng `kubectl create deployment web-app --image=nginx:1.27-alpine --dry-run=client -o yaml` để lấy khung Deployment rồi chỉnh lại.
* Nếu Service không truy cập được, kiểm tra theo thứ tự: Service selector, Pod label, EndpointSlice, readiness probe.
* Nếu Pod không Ready, dùng `kubectl describe pod` trước khi xem logs.

## Checklist hoàn thành

* [ ] Namespace `lab-basic-plus` tồn tại.
* [ ] `ConfigMap web-config` có đủ ba key yêu cầu.
* [ ] `Secret web-secret` có key `API_TOKEN`.
* [ ] `Deployment web-app` có 3 Pod Ready.
* [ ] Pod có request/limit CPU và memory.
* [ ] Pod có readiness và liveness probe.
* [ ] `Service web-app` có endpoint backend.
* [ ] Pod tạm gọi được `http://web-app`.

## Lệnh kiểm tra gợi ý

```bash
kubectl get all -n lab-basic-plus
kubectl get cm,secret -n lab-basic-plus
kubectl rollout status deployment/web-app -n lab-basic-plus
kubectl get endpointslice -n lab-basic-plus -l kubernetes.io/service-name=web-app
kubectl describe deployment web-app -n lab-basic-plus
kubectl describe service web-app -n lab-basic-plus
```

## Tình huống lỗi cần tự tạo và tự sửa

Sau khi lab chạy đúng, hãy tự tạo ít nhất hai lỗi sau rồi sửa lại:

1. Đổi selector của Service thành `app: wrong`.
2. Đổi readiness path từ `/` thành `/not-found`.
3. Xóa Secret rồi quan sát Deployment/Pod phản ứng như thế nào.
4. Đổi image thành một tag không tồn tại để xem `ImagePullBackOff`.

Với mỗi lỗi, ghi lại:

* Triệu chứng nhìn thấy qua `kubectl get`.
* Thông tin quan trọng trong `kubectl describe`.
* Cách sửa manifest.
* Lệnh verify sau khi sửa.

## Tiêu chí đánh giá

Hoàn thành tốt khi bạn có thể xóa toàn bộ namespace, apply lại manifest từ đầu và hệ thống trở về trạng thái chạy đúng mà không cần thao tác thủ công ngoài YAML.

