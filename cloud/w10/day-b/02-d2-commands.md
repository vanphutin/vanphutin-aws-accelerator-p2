# Hướng Dẫn Thực Hành: CLI Commands & Manifests (Secrets Management & Supply Chain Security)

Tài liệu này cung cấp các câu lệnh thực tế và cấu hình YAML hoàn chỉnh cho việc quản lý Secrets (AWS Secrets Manager, ESO, Sealed Secrets), quét lỗ hổng (Trivy), và ký/xác thực ảnh container (Cosign, Kyverno).

---

## 1. AWS Secrets Manager & External Secrets Operator (ESO)

### 1.1. Tạo Secret trên AWS Secrets Manager qua AWS CLI
```bash
aws secretsmanager create-secret \
  --name "production/app/db-credentials" \
  --description "Database credentials for production application" \
  --secret-string '{"username":"prod_db_user","password":"SuperSecurePassword2026"}' \
  --region ap-southeast-1
```

### 1.2. Cài đặt External Secrets Operator (ESO) qua Helm
```bash
# Thêm Helm Repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Cài đặt ESO
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --set installCRDs=true
```

### 1.3. Cấu hình ClusterSecretStore (Xác thực bằng AWS IAM Roles for Service Accounts - IRSA)
Tài nguyên này thiết lập kết nối toàn hệ thống tới AWS Secrets Manager.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secretsmanager-store
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-southeast-1
      auth:
        jwt:
          # Sử dụng IRSA (IAM Roles for Service Accounts) của EKS
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
```

### 1.4. Tạo ExternalSecret đồng bộ hóa tự động mỗi 1 giờ (`refreshInterval: 1h`)
Tạo tài nguyên để đồng bộ dữ liệu về K8s Secret gốc có tên `app-db-secret`.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-db-externalsecret
  namespace: production
spec:
  refreshInterval: 1h  # Tự động đồng bộ lại mỗi 1 giờ
  secretStoreRef:
    name: aws-secretsmanager-store
    kind: ClusterSecretStore
  target:
    name: app-db-secret  # Tên K8s Secret được tự động sinh ra
    creationPolicy: Owner
  data:
    - secretKey: DB_USER
      remoteRef:
        key: "production/app/db-credentials"
        property: username
    - secretKey: DB_PASSWORD
      remoteRef:
        key: "production/app/db-credentials"
        property: password
```

---

## 2. Sealed Secrets (Bitnami): Thực hành GitOps Offline

### 2.1. Cài đặt Sealed Secrets Controller
```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm install sealed-secrets-controller sealed-secrets/sealed-secrets \
  --namespace kube-system
```

### 2.2. Tạo và mã hóa Secret bằng `kubeseal`
```bash
# 1. Tạo một K8s Secret thô ở local (Không đẩy file này lên Git)
kubectl create secret generic my-db-secret \
  --from-literal=password='SuperSecretPass' \
  --dry-run=client -o yaml > my-secret-raw.yaml

# 2. Sử dụng kubeseal để mã hóa bất đối xứng thành SealedSecret
# kubeseal tự động kết nối cluster để lấy public key từ controller
kubeseal --format=yaml < my-secret-raw.yaml > my-sealedsecret.yaml

# 3. An toàn xóa file raw đi
rm my-secret-raw.yaml

# 4. Áp dụng file sealedsecret.yaml lên cluster (Có thể đẩy file này lên Git công khai)
kubectl apply -f my-sealedsecret.yaml
```

---

## 3. Trivy: Quét lỗ hổng trong CI Pipeline

### 3.1. Chạy Trivy quét cục bộ (Local Scan)
```bash
# Quét lỗ hổng của Container Image và xuất kết quả dạng bảng
trivy image nginx:alpine

# Quét chỉ lọc ra các lỗ hổng mức độ HIGH và CRITICAL
trivy image --severity HIGH,CRITICAL nginx:alpine
```

### 3.2. Cấu hình Exception Policy (`.trivyignore`)
Nếu muốn bỏ qua các CVE chưa có bản vá hoặc được đánh giá là an toàn trong môi trường hiện tại:
Tạo file `.trivyignore` ở thư mục gốc dự án:
```text
# Lỗi CVE-2023-44487: Đã kiểm tra cấu hình HTTP/2 ở reverse proxy ngoài, bỏ qua quét
CVE-2023-44487

# Lỗi CVE-2024-12345: Thư viện này không sử dụng trong runtime thực tế
CVE-2024-12345
```

### 3.3. Tích hợp Trivy vào GitHub Actions Pipeline
Đoạn cấu hình pipeline mẫu tự động quét ảnh container khi build, và đánh sập build nếu phát hiện lỗi nguy hiểm.

```yaml
name: Secure Build and Scan

on:
  push:
    branches: [ "main" ]

jobs:
  build-and-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build local container image
        run: |
          docker build -t my-app:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'my-app:${{ github.sha }}'
          format: 'table'
          exit-code: '1' # Đánh sập build (exit code 1) nếu phát hiện lỗi bảo mật thỏa mãn bộ lọc
          ignore-unfixed: true # Bỏ qua các CVE chưa có bản vá để tránh nghẽn CI
          severity: 'CRITICAL,HIGH'
```

---

## 4. Cosign: Ký và Xác thực Container Image

### 4.1. Tạo cặp khóa dùng Key-based Signing
```bash
# Sinh cặp khóa cosign.key (private) và cosign.pub (public)
# Cosign sẽ yêu cầu nhập passphrase bảo mật cho private key
cosign generate-key-pair
```

### 4.2. Ký Container Image bằng Key-based Method
```bash
# Thực hiện ký số và đẩy signature lên registry
cosign sign --key cosign.key my-registry.io/company/my-app:v1.0.0
```

### 4.3. Ký Container Image bằng Keyless Method (Trong GitHub Actions)
Trong môi trường CI đáng tin cậy hỗ trợ OIDC, chạy câu lệnh sau mà không cần chỉ định key.

```bash
# Kích hoạt tính năng keyless signing của Sigstore
export COSIGN_EXPERIMENTAL=1
cosign sign my-registry.io/company/my-app:v1.0.0
```
*(Fulcio sẽ tự động bắt tay với GitHub OIDC để lấy chứng chỉ 10 phút, Rekor sẽ ghi nhận log công khai).*

### 4.4. Kiểm tra chữ ký thủ công bằng CLI
```bash
# Xác thực ảnh bằng file Public Key
cosign verify --key cosign.pub my-registry.io/company/my-app:v1.0.0
```

---

## 5. Kyverno: Tự động Xác thực chữ ký ở Admission Control

### 5.1. Manifest: Kyverno ClusterPolicy xác thực chữ ký ảnh
Policy này sẽ chặn bất cứ Pod nào thuộc namespace `production` sử dụng image từ registry `my-registry.io` mà chưa được ký bởi file public key tương ứng.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
  annotations:
    policies.kyverno.io/title: Verify Image Signatures
    policies.kyverno.io/category: Software Supply Chain Security
    policies.kyverno.io/severity: Critical
    policies.kyverno.io/description: >-
      Verify that container images deployed to production namespaces are signed 
      by the corporate Cosign public key.
spec:
  validationFailureAction: Enforce # Chặn đứng việc tạo Pod nếu không thỏa mãn
  background: false
  rules:
    - name: verify-corporate-signature
      match:
        any:
        - resources:
            namespaces:
              - production
            kinds:
              - Pod
      verifyImages:
        - imageReferences:
            - "my-registry.io/company/*"
          attestations: []
          authority:
            key: |
              -----BEGIN PUBLIC KEY-----
              MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE4bpx/n8UoZ0gY6Q2wD9wV3E5d3m1
              fL2z3gH/D6b2e0u4vE/tH+QcQz6H2m1O/n9U8m1P3gH/D6b2e0u4vE/tH+QcQz==
              -----END PUBLIC KEY-----
```
*(Hãy thay thế đoạn PUBLIC KEY bằng nội dung file `cosign.pub` thực tế của bạn).*
