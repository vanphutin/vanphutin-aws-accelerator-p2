# Hướng Dẫn Thực Hành: CLI Commands, Manifests & Templates (Day 3)

Tài liệu này bao gồm các Kubernetes Manifests quản trị tài nguyên (ResourceQuota, LimitRange), kịch bản giả lập sự cố (Chaos Mesh), lệnh cấu hình giám sát chi phí AWS (AWS CLI) và các biểu mẫu vận hành chuẩn (SRE Runbook & Postmortem templates).

---

## 1. Cấu hình Giới Hạn Tài Nguyên: ResourceQuota & LimitRange

### 1.1. Manifest: ResourceQuota (`production-quota.yaml`)
Giới hạn tổng tài nguyên cho namespace `production`.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-resource-quota
  namespace: production
spec:
  hard:
    # Compute limits
    requests.cpu: "10"       # Tổng CPU request tối đa của cả namespace
    requests.memory: 20Gi    # Tổng RAM request tối đa của cả namespace
    limits.cpu: "20"         # Tổng CPU limit tối đa
    limits.memory: 40Gi      # Tổng RAM limit tối đa
    
    # Object count limits
    pods: "30"               # Tối đa 30 Pods
    services: "10"           # Tối đa 10 Services
    services.loadbalancers: "2" # Chỉ được phép tạo tối đa 2 LoadBalancer Services
    secrets: "50"            # Tối đa 50 Secrets
    
    # Storage limits
    requests.storage: 100Gi  # Tổng dung lượng PVC tối đa
    persistentvolumeclaims: "10" # Tối đa 10 PVCs
```

### 1.2. Manifest: LimitRange (`production-limit-range.yaml`)
Định nghĩa cấu hình tài nguyên mặc định và min/max cho từng container đơn lẻ trong namespace `production`.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limit-range
  namespace: production
spec:
  limits:
    - type: Container
      max:
        cpu: "2"
        memory: 4Gi
      min:
        cpu: 100m
        memory: 64Mi
      default:
        cpu: 500m
        memory: 512Mi
      defaultRequest:
        cpu: 200m
        memory: 256Mi
```

---

## 2. Chaos Engineering: Cài đặt & Tạo Kịch Bản Sự Cố (Chaos Mesh)

### 2.1. Cài đặt Chaos Mesh qua Helm
```bash
# Thêm Chaos Mesh Helm repo
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Tạo namespace riêng biệt
kubectl create namespace chaos-mesh

# Cài đặt Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace=chaos-mesh \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock
```

### 2.2. Manifest: Pod Failure Chaos (`pod-kill-chaos.yaml`)
Tạo kịch bản ngẫu nhiên tắt Pod (giả lập Pod đột tử) đối với các Pod có label `app=payment` trong namespace `production` mỗi 30 giây.

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: payment-pod-failure
  namespace: production
spec:
  action: pod-kill # Hành động: Giết chết container pod
  mode: one        # Chỉ giết 1 pod tại 1 thời điểm
  duration: '10m'  # Tổng thời gian chạy kịch bản chaos là 10 phút
  scheduler:
    cron: '@every 30s' # Cứ mỗi 30 giây thực hiện hành động 1 lần
  selector:
    namespaces:
      - production
    labelSelectors:
      'app': 'payment'
```

### 2.3. Manifest: Network Latency Chaos (`network-delay-chaos.yaml`)
Giả lập lỗi nghẽn mạng: Thêm độ trễ 200ms vào toàn bộ traffic đi ra/vào của Pod ứng dụng.

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-delay-test
  namespace: production
spec:
  action: delay # Hành động: Thêm độ trễ (delay)
  mode: all     # Áp dụng cho tất cả Pods được lọc
  selector:
    namespaces:
      - production
    labelSelectors:
      'app': 'frontend'
  delay:
    latency: '200ms' # Thêm 200ms độ trễ mạng
    jitter: '10ms'   # Độ lệch ngẫu nhiên +-10ms
  direction: to      # Áp dụng cho traffic đi ra từ Pod
  duration: '5m'     # Kéo dài trong 5 phút rồi tự khôi phục
```

---

## 3. AWS Cost Anomaly Detection: Quản Lý Chi Phí Qua AWS CLI

### 3.1. Tạo Trình Giám Sát Chi Phí Bất Thường (Cost Monitor)
Tạo Monitor dạng giám sát chi phí dịch vụ AWS (như EC2, RDS, EKS).

```bash
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "AWS-Services-Cost-Monitor",
    "MonitorType": "DIMENSIONAL",
    "MonitorDimension": "SERVICE"
  }' \
  --region us-east-1
```
*Ghi chú: Lệnh trả về `MonitorArn`. Bạn cần lưu ARN này lại để dùng ở bước tạo Subscription.*

### 3.2. Tạo Đăng Ký Nhận Cảnh Báo (Cost Subscription)
Tạo subscription gửi cảnh báo về Email khi phát hiện bất thường chi phí vượt quá 50 USD/ngày.

```bash
aws ce create-anomaly-subscription \
  --anomaly-subscription '{
    "SubscriptionName": "Daily-Cost-Spike-Alert",
    "Threshold": 50.0,
    "Frequency": "DAILY",
    "MonitorArnList": ["arn:aws:ce::123456789012:anomalymonitor/your-monitor-uuid"],
    "Subscribers": [
      {
        "Address": "devops-alerts@company.com",
        "Type": "EMAIL"
      }
    ]
  }' \
  --region us-east-1
```

---

## 4. Runbook & Postmortem Templates (Chuẩn SRE)

### 4.1. Runbook Template: Xử lý sự cố Pod bị lỗi `OOMKilled` (Memory Leak)
Lưu file này dưới dạng `RUNBOOK-OOMKILLED.md`.

```markdown
# Runbook: Xử Lý Sự Cố Pod OOMKilled (Exit Code 137)

## 1. Thông Tin Chung
* **Mã Lỗi:** `OOMKilled` (Pod bị Kubernetes hoặc OS OOM-killer giết do vượt quá memory limit).
* **Độ ưu tiên:** High (P2)
* **Người chịu trách nhiệm chính:** On-call SRE / Backend Lead.

## 2. Các Bước Kiểm Tra & Chẩn Đoán (Triage)
1. **Xác định Pod và Namespace bị lỗi:**
   ```bash
   kubectl get pods -A | grep -i oomkilled
   ```
2. **Kiểm tra trạng thái lịch sử của Pod lỗi:**
   ```bash
   kubectl describe pod <pod_name> -n <namespace>
   ```
   *Tìm dòng:* `Last State: Terminated`, `Reason: OOMKilled`, `Exit Code: 137`.
3. **Kiểm tra đồ thị RAM sử dụng trên Grafana/Prometheus:**
   * Truy cập Dashboard: `Kubernetes / Pod Resources`.
   * Quan sát đồ thị Memory Usage của Pod trước khi sập: Nếu RAM tăng tuyến tính hình răng cưa hoặc tăng vọt đột biến ➔ Xác nhận lỗi Memory Leak của code.

## 3. Các Bước Khắc Phục Tạm Thời (Mitigation)
1. **Giải pháp nhanh (Tăng Memory Limit tạm thời):**
   Nếu dịch vụ đang bị downtime, thực hiện scale tăng memory limit của Pod lên gấp 1.5 lần thông qua lệnh edit trực tiếp (hoặc update helm value trong GitOps):
   ```bash
   kubectl set resources deployment/<deployment_name> -n <namespace> --limits=memory=<new_limit_value>
   ```
2. **Khởi động lại Pod (nếu pod bị treo và chưa tự restart):**
   ```bash
   kubectl rollout restart deployment/<deployment_name> -n <namespace>
   ```

## 4. Giải Pháp Triệt Để (Root Cause Resolution)
1. Export dump bộ nhớ (Heap Dump) của ứng dụng để Dev team phân tích các biến toàn cục rò rỉ.
2. Điều chỉnh lại `LimitRange` của Namespace nếu giới hạn cũ quá bé so với nhu cầu thực tế của ứng dụng.
```

### 4.2. Incident Postmortem Template (Google SRE Style)
Lưu file này dưới dạng `POSTMORTEM-TEMPLATE.md`.

```markdown
# Incident Postmortem: [Tên Sự Cố] - [Ngày Xảy Ra]

**Chủ trì họp:** [Tên SRE/DevOps]  
**Người ghi biên bản:** [Tên]  
**Trạng thái:** DRAFT / COMPLETED  

---

## 1. Tóm Tắt Sự Cố (Summary)
* **Mô tả ngắn:** [Ví dụ: Hệ thống Payment không thanh toán được do Service Account bị thu hồi quyền truy cập AWS ASM].
* **Thời gian gián đoạn:** [Ví dụ: 45 phút, từ 14:00 đến 14:45 UTC+7].
* **Mức độ ảnh hưởng:** [Ví dụ: 15% tổng số giao dịch thanh toán bị thất bại].
* **Hành động khắc phục:** [Ví dụ: Thực hiện rollback cấu hình IAM Role Binding của Service Account].

## 2. Dòng Thời Gian Sự Cố (Timeline)
* **14:00:** Lỗi bắt đầu phát sinh sau khi chạy pipeline deployment của bản build `#120`.
* **14:05:** Hệ thống giám sát Grafana kích hoạt Alert `Pod restart loops` gửi về Slack.
* **14:10:** Kỹ sư On-call tiếp nhận sự cố và bắt đầu điều tra logs.
* **14:25:** Phát hiện log lỗi: `AccessDenied: User is not authorized to perform secretsmanager:GetSecretValue`.
* **14:35:** Xác định nguyên nhân do file deployment mới xóa nhầm annotation IAM Role ARN trên ServiceAccount.
* **14:40:** Thực hiện deploy bản vá rollback hotfix.
* **14:45:** Hệ thống phục hồi hoàn toàn, các giao dịch thanh toán thành công trở lại.

## 3. Phân Tích Nguyên Nhân Gốc Rễ (Root Cause Analysis)
* *Tại sao hệ thống lỗi?* Vì Pod không đọc được secret database từ AWS Secrets Manager.
* *Tại sao không đọc được?* Vì SA bị mất quyền IAM.
* *Tại sao SA mất quyền?* Annotation chứa Role ARN bị xóa khỏi manifest.
* *Tại sao bị xóa?* Nhà phát triển đã dọn dẹp nhầm file YAML trong đợt refactor cấu hình mà không chạy kiểm thử tích hợp (integration test) môi trường staging.

## 4. Các Hành Động Khắc Phục & Phòng Ngừa (Action Items)

| ID | Hành Động | Loại công việc | Người chịu trách nhiệm | Hạn chót | Trạng thái |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **ACT-01** | Viết test case CI kiểm tra tính tồn tại của IAM annotations trong file YAML trước khi apply. | Phòng ngừa (CI) | @developer-a | 2026-06-25 | OPEN |
| **ACT-02** | Bật cơ chế Alert khi API Server từ chối lệnh gọi Secrets Manager lên AWS. | Giám sát | @sre-b | 2026-06-20 | COMPLETED |
```
