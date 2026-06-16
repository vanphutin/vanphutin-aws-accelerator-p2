# Hướng Dẫn Thực Hành: CLI Commands & Manifests (RBAC, Gatekeeper, Kyverno, VAP)

Tài liệu này cung cấp các câu lệnh CLI cần thiết và các Kubernetes Manifests hoàn chỉnh (Production-ready) để triển khai và kiểm tra RBAC, OPA Gatekeeper, Kyverno và ValidatingAdmissionPolicy.

---

## 1. Kiểm tra & Giám sát RBAC (RBAC Inspection & Auditing)

### 1.1. Kiểm tra quyền tự phục vụ (Self-authorization query)
Sử dụng `kubectl auth can-i` để tự kiểm tra quyền của User hiện tại hoặc ServiceAccount khác.

```bash
# Kiểm tra xem tài khoản hiện tại có được quyền tạo Deployments không
kubectl auth can-i create deployments

# Kiểm tra xem có được quyền đọc Secrets trong namespace "default" không
kubectl auth can-i get secrets --namespace default

# Kiểm tra mạo danh (Impersonate) quyền của một ServiceAccount cụ thể
kubectl auth can-i get secrets \
  --as=system:serviceaccount:staging:app-serviceaccount \
  --namespace staging

# Kiểm tra quyền thực hiện một hành động cụ thể trên một resource cụ thể
kubectl auth can-i delete pods/log --namespace production
```

### 1.2. Liệt kê và quét quyền hạn trong Cluster
Sử dụng CLI để truy xuất thông tin phân quyền.

```bash
# Liệt kê tất cả các RoleBinding trong tất cả các Namespace kèm Role mà chúng liên kết
kubectl get rolebindings,clusterrolebindings --all-namespaces \
  -o custom-columns='NAMESPACE:.metadata.namespace,BINDING-NAME:.metadata.name,ROLE-KIND:.roleRef.kind,ROLE-NAME:.roleRef.name'

# Quét xem ai đang giữ quyền cluster-admin (quyền tối cao)
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name, .subjects'
```

### 1.3. Sử dụng công cụ bên thứ ba (RBAC audit tools)
Các DevOps Engineer thường dùng `kubectl-who-can` (plugin cài qua Krew) hoặc `rbac-lookup` để tìm mối nguy hiểm.

```bash
# Cài đặt qua Krew
kubectl krew install who-can

# Kiểm tra xem những ai (User/Group/SA) có quyền xóa (delete) Nodes
kubectl who-can delete nodes

# Kiểm tra xem những ai có quyền "impersonate" (mạo danh) trong cluster
kubectl who-can impersonate users
```

---

## 2. OPA Gatekeeper: Thực hành

### 2.1. Cài đặt Gatekeeper qua Helm Chart
```bash
# Thêm Gatekeeper Helm repository
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

# Cập nhật repo
helm repo update

# Triển khai Gatekeeper lên cluster (Namespace: gatekeeper-system)
helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --set replicaCount=3 \
  --set auditInterval=60
```

### 2.2. Manifest: ConstraintTemplate & Constraint (Ví dụ bắt buộc Container phải có Resource Limits)

#### Bước 1: Tạo ConstraintTemplate (`template-require-limits.yaml`)
Logic kiểm tra bằng Rego để đảm bảo mọi container đều có config memory limit.

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8scontainerexistlimits
spec:
  crd:
    spec:
      names:
        kind: K8sContainerExistLimits
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8scontainerexistlimits

        violation[{"msg": msg}] {
          general_violation(msg)
        }

        general_violation(msg) {
          container := input.review.object.spec.template.spec.containers[_]
          not container.resources.limits.memory
          msg := sprintf("Container <%v> does not have memory limits defined.", [container.name])
        }
```

#### Bước 2: Tạo Constraint (`constraint-require-limits.yaml`)
Áp dụng Template trên cho các Deployments trong namespace `production`.

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sContainerExistLimits
metadata:
  name: deployments-must-have-memory-limits
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces:
      - "production"
```

### 2.3. Lệnh kiểm tra vi phạm (Audit & Logs)
```bash
# Áp dụng template và constraint
kubectl apply -f template-require-limits.yaml
kubectl apply -f constraint-require-limits.yaml

# Xem danh sách vi phạm (Violations) do Audit Controller phát hiện
kubectl get k8scontainerexistlimits deployments-must-have-memory-limits -o yaml
```

---

## 3. Kyverno: Thực hành

### 3.1. Cài đặt Kyverno qua Helm
```bash
# Thêm Kyverno Helm repository
helm repo add kyverno https://kyverno.github.io/kyverno/

# Cập nhật repo
helm repo update

# Cài đặt Kyverno
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set admissionController.replicas=3
```

### 3.2. Manifest: ClusterPolicy (Ngăn chặn Container chạy với quyền Root và bắt buộc Read-only Root Filesystem)
Đây là một policy bảo mật chuẩn sản xuất (production-ready).

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-root-and-require-readonly-fs
  annotations:
    policies.kyverno.io/title: Secure Containers Only
    policies.kyverno.io/category: Pod Security Standards
    policies.kyverno.io/severity: High
    policies.kyverno.io/description: >-
      Containers must run as non-root user and root filesystem must be read-only.
spec:
  validationFailureAction: Enforce  # Enforce = Chặn cứng, Audit = Chỉ ghi log cảnh báo
  background: true
  rules:
    - name: check-run-as-non-root
      match:
        any:
        - resources:
            kinds:
              - Pod
      validate:
        message: "Running as root user is prohibited. Please set securityContext.runAsNonRoot to true."
        pattern:
          spec:
            securityContext:
              runAsNonRoot: true
    - name: check-readonly-root-filesystem
      match:
        any:
        - resources:
            kinds:
              - Pod
      validate:
        message: "Root filesystem must be read-only. Please set securityContext.readOnlyRootFilesystem to true."
        pattern:
          spec:
            containers:
              - securityContext:
                  readOnlyRootFilesystem: true
```

### 3.3. Kiểm tra Policy bằng Kyverno CLI (Local testing)
Để tránh ảnh hưởng đến cluster, bạn có thể kiểm tra offline policy bằng CLI.

```bash
# Tải Kyverno CLI
# Trên Windows (Powershell):
# Invoke-WebRequest -Uri https://github.com/kyverno/kyverno/releases/download/v1.12.0/kyverno-cli_v1.12.0_windows_x86_64.zip -OutFile kyverno.zip

# Lệnh kiểm tra Resource YAML offline với Policy file
kyverno apply /path/to/policy.yaml --resource /path/to/resource-manifest.yaml
```

---

## 4. ValidatingAdmissionPolicy (VAP): Thực hành (K8s 1.30+)

### 4.1. Kiểm tra tính năng VAP trên Cluster
Từ Kubernetes 1.30, VAP đã được bật sẵn mặc định ở trạng thái GA. Hãy chạy lệnh này để kiểm tra xem API Server đã hỗ trợ tài nguyên VAP chưa:

```bash
kubectl api-resources | grep validatingadmissionpolicy
```
*Kết quả mong đợi:*
`validatingadmissionpolicies       admissionregistration.k8s.io/v1 ...`

### 4.2. Manifest: ValidatingAdmissionPolicy & Binding (Sử dụng CEL)
Ví dụ sau sẽ tạo một chính sách bằng CEL: **Chỉ cho phép replicas tối đa là 3 đối với Deployments trong môi trường staging**.

#### Bước 1: Tạo Policy Định nghĩa (`vap-max-replicas.yaml`)
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: max-replicas-policy
spec:
  failurePolicy: Fail  # Chặn request nếu có lỗi xử lý xảy ra
  matchConstraints:
    resourceRules:
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["deployments"]
  variables:
    - name: maxAllowed
      expression: "3"
  validations:
    - expression: "object.spec.replicas <= double(variables.maxAllowed)"
      messageExpression: "'Replicas count (' + string(object.spec.replicas) + ') exceeds the limit of ' + string(variables.maxAllowed)"
```

#### Bước 2: Tạo Binding Liên kết (`vap-max-replicas-binding.yaml`)
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: max-replicas-policy-binding
spec:
  policyName: max-replicas-policy
  validationActions: [Deny]  # Deny = Chặn cứng, Warn = Đưa cảnh báo nhưng vẫn cho tạo, Audit = Lưu audit logs
  matchResources:
    namespaceSelector:
      matchLabels:
        environment: staging
```

### 4.3. Kiểm thử hoạt động của VAP
1. Gán label `environment=staging` cho namespace kiểm thử:
   ```bash
   kubectl create namespace test-staging
   kubectl label namespace test-staging environment=staging
   ```

2. Áp dụng chính sách:
   ```bash
   kubectl apply -f vap-max-replicas.yaml
   kubectl apply -f vap-max-replicas-binding.yaml
   ```

3. Thử deploy một Deployment có replicas = 5 vào namespace `test-staging` (`test-deploy.yaml`):
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: web-app
     namespace: test-staging
   spec:
     replicas: 5
     selector:
       matchLabels:
         app: web
     template:
       metadata:
         labels:
           app: web
       spec:
         containers:
         - name: nginx
           image: nginx:alpine
   ```

   Chạy lệnh:
   ```bash
   kubectl apply -f test-deploy.yaml
   ```

   *Kết quả lỗi trả về từ API Server:*
   `Error from server (Forbidden): error when creating "test-deploy.yaml": deployments.apps "web-app" is forbidden: ValidatingAdmissionPolicy 'max-replicas-policy' with binding 'max-replicas-policy-binding' denied request: Replicas count (5) exceeds the limit of 3`
