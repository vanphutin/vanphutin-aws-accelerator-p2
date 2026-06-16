# D1 - Kubernetes Security Core: Theory, Evidence, Production Mindset

## Mục tiêu

D1 giúp bạn hiểu và thực hành lớp bảo vệ đầu tiên của Kubernetes platform:

- RBAC: ai được làm gì, với resource nào, trong phạm vi nào.
- ServiceAccount: identity của workload chạy bên trong cluster.
- `kubectl auth can-i`: cách verify quyền thay vì đoán.
- Admission policy: chặn manifest xấu trước khi object được lưu vào cluster.
- OPA/Rego và Gatekeeper: viết policy linh hoạt cho Kubernetes.
- ValidatingAdmissionPolicy: policy native của Kubernetes dùng CEL.
- Kyverno: alternative Kubernetes-native cho policy management.

Production mindset của D1: không chỉ "deploy được", mà phải deploy trong guardrail rõ ràng.

```text
kubectl apply
   |
   v
Authentication: bạn là ai?
   |
   v
Authorization/RBAC: bạn có được làm action này không?
   |
   v
Admission: manifest có đúng chuẩn security/platform không?
   |
   v
Persist vào etcd
```

Nguồn chính:

- Kubernetes RBAC: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- kubectl auth can-i: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/
- Kubernetes Admission Control: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/
- ValidatingAdmissionPolicy: https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/
- OPA docs: https://www.openpolicyagent.org/docs
- Gatekeeper docs: https://open-policy-agent.github.io/gatekeeper/website/docs/
- Kyverno docs: https://kyverno.io/docs/

## 1. Production Scenario

Công ty có namespace `dev` cho team developer deploy ứng dụng. Nếu cấp `cluster-admin` cho developer, một lệnh sai có thể:

- xóa Secret của namespace khác,
- sửa ConfigMap production,
- tạo Service public không kiểm soát,
- deploy Pod privileged,
- dùng image `:latest` không trace được version,
- deploy container không có resource limits làm node bị áp lực CPU/RAM.

Mục tiêu production:

```text
Developer được deploy app trong namespace dev
nhưng không được vượt quá ranh giới namespace,
không được tạo resource ngoài phạm vi,
và manifest phải đạt chuẩn security/platform.
```

D1 không phải học thuộc YAML. D1 là học cách thiết kế guardrail.

## 2. RBAC: Authentication Khác Authorization

Kubernetes access control có nhiều bước. RBAC nằm ở bước authorization.

- Authentication: xác định request đến từ identity nào.
- Authorization: identity đó có được phép thực hiện action không.
- Admission: request đã được authorize rồi, nhưng object có hợp lệ không.

Ví dụ:

```text
dev-user authenticated thành công
dev-user được create deployments trong namespace dev
nhưng Deployment dùng image :latest
=> RBAC allow, Admission policy có thể reject
```

## 3. RBAC Object Model

### Role

`Role` định nghĩa quyền trong một namespace.

Ví dụ logic:

```text
Trong namespace dev:
- được get/list/watch/create/update/patch/delete pods
- được get/list/watch/create/update/patch/delete deployments
```

`Role` không gán quyền cho ai. Nó chỉ mô tả permission.

### RoleBinding

`RoleBinding` gán `Role` cho subject.

Subject có thể là:

- `User`
- `Group`
- `ServiceAccount`

Ví dụ:

```text
Role dev-deployer
gán cho User dev-user
trong namespace dev
```

### ClusterRole

`ClusterRole` định nghĩa quyền cấp cluster, hoặc định nghĩa bộ quyền có thể được reuse qua nhiều namespace.

Dùng `ClusterRole` khi:

- resource là cluster-scoped, ví dụ `nodes`, `namespaces`, `persistentvolumes`,
- cần role dùng chung cho nhiều namespace,
- cần aggregate permissions cho platform/admin.

### ClusterRoleBinding

`ClusterRoleBinding` gán `ClusterRole` trên toàn cluster. Đây là object cần cẩn trọng. Sai một dòng có thể mở quyền qua tất cả namespace.

Rule thực tế:

```text
Nếu chỉ cần quyền trong namespace, dùng Role + RoleBinding.
Nếu cần quyền toàn cluster, mới cần ClusterRoleBinding.
```

## 4. RBAC Rule: apiGroups, Resources, Verbs

Một rule RBAC cần 3 thành phần quan trọng:

```yaml
apiGroups: [...]
resources: [...]
verbs: [...]
```

### apiGroups

`apiGroups` không phải tên cluster, không phải `k8s`, không phải `minikube`.

Nó là group của Kubernetes API.

Ví dụ:

```text
pods        -> apiGroups: [""]
services    -> apiGroups: [""]
secrets     -> apiGroups: [""]
deployments -> apiGroups: ["apps"]
jobs        -> apiGroups: ["batch"]
```

`apiGroups: [""]` nghĩa là core API group, không phải "không có quyền".

`apiGroups: ["*"]` là wildcard. Dùng wildcard trong production phải có lý do rõ ràng, vì nó làm permission mở hơn cần thiết.

### resources

`resources` là tên loại Kubernetes object:

```text
pods
deployments
services
secrets
configmaps
namespaces
```

Nên viết plural resource name để rõ ràng:

```text
deployments
services
pods
```

### verbs

Kubernetes không có verb tên `CRUD`.

Thường gặp:

```text
get
list
watch
create
update
patch
delete
deletecollection
```

Map với CRUD:

```text
Create -> create
Read   -> get/list/watch
Update -> update/patch
Delete -> delete
```

## 5. User vs ServiceAccount

Đây là lỗi rất phổ biến.

```text
User           = người hoặc CI/CD identity dùng kubectl/kubeconfig
ServiceAccount = identity của Pod chạy trong cluster
```

Trong lab:

```text
dev-user  -> User được RoleBinding để deploy app
webapp-sa -> ServiceAccount gán vào Pod/Deployment
```

Nếu bind nhầm:

- Bind Role cho `ServiceAccount dev-user`: người dùng `dev-user` vẫn không có quyền.
- Cấp quyền quá rộng cho ServiceAccount: nếu app bị compromise, attacker có token để thao tác cluster.

Production rule:

```text
Người deploy và workload runtime phải là hai identity riêng.
Không cấp quyền runtime nếu workload không cần gọi Kubernetes API.
```

## 6. kubectl auth can-i

`kubectl auth can-i` dùng để kiểm tra một action có được authorize hay không.

Pattern:

```bash
kubectl auth can-i <verb> <resource> --namespace <namespace> --as <user>
```

Ví dụ:

```bash
kubectl auth can-i create deployments --namespace dev --as dev-user
kubectl auth can-i create secrets --namespace dev --as dev-user
kubectl auth can-i create deployments --namespace prod --as dev-user
```

Production mindset:

```text
Test allowed path.
Test denied path.
Test wrong namespace.
Test subresource nếu cần, ví dụ pods/log.
```

## 7. Admission Control: Vì Sao RBAC Không Đủ

RBAC chỉ trả lời:

```text
Ai có được tạo Deployment không?
```

Admission policy trả lời:

```text
Deployment được tạo có đạt chuẩn không?
```

Theo Kubernetes docs, admission controller intercept request trước khi resource được persist, sau khi request đã authenticated và authorized.

Ví dụ RBAC allow nhưng admission reject:

```text
dev-user được create deployments
nhưng deployment:
- image: nginx:latest
- thiếu resources.limits
- privileged: true
=> admission policy reject
```

Admission control có thể:

- mutating: sửa object trước khi lưu,
- validating: chỉ kiểm tra và allow/reject.

Gatekeeper và ValidatingAdmissionPolicy trong D1 thuộc nhóm validating policy.

## 8. OPA Và Rego

OPA tách policy decision khỏi application/platform enforcement.

Mental model:

```text
Input JSON/YAML
   |
   v
Rego policy
   |
   v
Decision: allow/deny/violations/structured output
```

Trong Kubernetes admission, input thường là AdmissionReview object. Gatekeeper đưa object đang review vào:

```text
input.review.object
```

Ví dụ field path cần tư duy:

```text
input.review.object.spec.containers[_].image
input.review.object.spec.containers[_].resources.limits.cpu
input.review.object.spec.containers[_].resources.limits.memory
```

Rego mạnh khi policy:

- phức tạp,
- cần loop qua danh sách container,
- cần helper function,
- cần referential data,
- cần policy library.

Điểm cẩn thận:

- Rego có learning curve.
- Policy sai có thể tạo cảm giác an toàn giả.
- Cần test policy như test code.

## 9. Gatekeeper: ConstraintTemplate vs Constraint

Gatekeeper dùng OPA Constraint Framework để enforce policy trên Kubernetes.

Hai object cần nhớ:

```text
ConstraintTemplate = định nghĩa policy logic và schema parameters
Constraint         = áp dụng template vào resource nào, với parameter nào, enforcementAction nào
```

Theo docs Gatekeeper, ConstraintTemplate gồm Rego code và schema của Constraint đi kèm.

### ConstraintTemplate

Dùng để định nghĩa:

- tên kind mới của constraint, ví dụ `K8sRequiredLimits`,
- Rego logic phát hiện violation,
- schema cho `parameters`.

### Constraint

Dùng để định nghĩa:

- match kind nào, namespace nào,
- parameter cụ thể,
- enforcement action.

Gatekeeper có các enforcement action quan trọng:

```text
deny   -> reject admission request
dryrun -> ghi nhận violation, không reject
warn   -> cảnh báo client
```

Production rollout nên:

```text
dryrun/warn trước
fix workload vi phạm
deny sau
```

## 10. Policy D1 Cần Biết

### Require Resource Limits

Bad Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod
spec:
  containers:
  - name: app
    image: nginx:1.27
```

Vi phạm vì container không có:

```text
spec.containers[i].resources.limits.cpu
spec.containers[i].resources.limits.memory
```

Nếu Pod có 2 containers và chỉ 1 container thiếu limits, policy nên reject cả Pod.

Lý do: mọi container đều có thể gây memory leak hoặc CPU pressure.

### Block `:latest`

Bad:

```text
nginx:latest
```

Tốt hơn:

```text
nginx:1.27
```

Production-grade:

```text
nginx@sha256:<digest>
```

Cẩn thận bypass:

```text
nginx
```

Nếu policy chỉ check `endsWith(":latest")`, image `nginx` có thể lọt. Production policy tốt hơn nên chặn cả image không có tag hoặc bắt digest.

### Approved Registry

Chỉ cho image từ registry đã approve, ví dụ:

```text
123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/
```

Logic nên dùng:

```text
image startsWith approved_registry_prefix
```

Không nên dùng:

```text
image contains "amazonaws"
```

Vì contains dễ bị bypass bằng tên image/registry giả.

## 11. ValidatingAdmissionPolicy

ValidatingAdmissionPolicy là admission policy native trong Kubernetes, stable từ Kubernetes v1.30.

Nó dùng CEL, không cần external webhook callout như nhiều policy engine bên ngoài.

Thành phần:

```text
ValidatingAdmissionPolicy        = logic abstract của policy
ValidatingAdmissionPolicyBinding = gán policy vào scope/resource và action
Parameter resource               = tùy chọn, dùng khi policy cần config động
```

Ít nhất cần:

```text
ValidatingAdmissionPolicy
ValidatingAdmissionPolicyBinding
```

`validationActions` quan trọng:

```text
Deny  -> reject request
Warn  -> trả warning về client
Audit -> ghi violation vào audit event
```

Production rollout:

```text
Warn + Audit -> quan sát và sửa app
Deny         -> enforce sau khi đã an toàn
```

Use case D1:

```text
Chỉ allow Pod/Deployment nếu mọi container image startsWith ECR prefix đã approve.
```

## 12. Gatekeeper vs ValidatingAdmissionPolicy vs Kyverno

### Gatekeeper

Dùng khi:

- đã quen OPA/Rego,
- policy phức tạp,
- cần library/referential data,
- đã có ecosystem Gatekeeper sẵn.

Trade-off:

- cần cài controller/webhook,
- Rego có learning curve,
- cần quản trị availability/performance của webhook.

### ValidatingAdmissionPolicy

Dùng khi:

- policy validation tương đối gọn,
- muốn native Kubernetes,
- muốn CEL,
- không muốn external HTTP webhook cho logic đơn giản.

Trade-off:

- validation-focused,
- không thay thế mọi khả năng của policy engine đầy đủ,
- cần nắm CEL và version Kubernetes.

### Kyverno

Kyverno là cloud native policy engine, ban đầu được built cho Kubernetes. Kyverno hỗ trợ viết policy bằng YAML và CEL, quản lý policy như Kubernetes resources, enforce qua admission controller/CLI/runtime, và có các khả năng validate, mutate, generate, cleanup, image verification, policy exception.

Dùng khi:

- team thích policy YAML-native,
- cần mutate/generate/image verification với syntax gần Kubernetes,
- muốn onboarding nhanh hơn Rego.

Trade-off:

- vẫn là một controller/policy engine phải vận hành (operate),
- syntax và behavior riêng của Kyverno cần học và test.

## 13. Common Mistakes Của Người Mới

1. Dùng `cluster-admin` cho dev vì "cho nhanh".

Production risk: blast radius toàn cluster.

2. Nhầm `User` với `ServiceAccount`.

Production risk: user không có quyền thật, hoặc Pod có quyền quá rộng.

3. Dùng wildcard:

```yaml
apiGroups: ["*"]
resources: ["*"]
verbs: ["*"]
```

Production risk: khó audit, khó chứng minh least privilege.

4. Chỉ test `yes`, không test `no`.

Production risk: không phát hiện quyền vượt scope.

5. Tưởng RBAC chặn được manifest xấu.

RBAC không biết image có `:latest` hay container có limits không.

6. Enforce policy ngay trên prod.

Production risk: chặn rollout hợp lệ, gây incident.

7. Policy chỉ check happy-path.

Ví dụ chỉ chặn `:latest`, nhưng bỏ lọt `nginx` không tag.

8. Không test multi-container.

Pod có sidecar thiếu limits vẫn nguy hiểm.

## 14. D1 Production Checklist

RBAC:

- Namespace riêng cho team/env.
- Role theo least privilege.
- RoleBinding đúng subject.
- Không dùng wildcard nếu không cần.
- Verify bằng `kubectl auth can-i`.
- Test namespace đúng và namespace sai.

ServiceAccount:

- Workload có ServiceAccount riêng.
- Không dùng default ServiceAccount cho app quan trọng.
- Không cấp quyền Kubernetes API nếu app không cần.

Admission:

- Require resource limits.
- Chặn `:latest` và image không pin.
- Approved registry.
- Audit/Warn trước, Deny sau.
- Test bad manifest và good manifest.

Operations:

- Có rollback plan cho policy.
- Có exception process có owner và expiry.
- Có audit/report violation.
- Policy nằm trong Git, review như code.

## 15. Prompt Mentor Nâng Cấp Cho D1

Dùng prompt này khi muốn tiếp tục học D1 theo mentor mode:

```text
Bạn là Senior DevOps Engineer với security mindset và production-ready thinking.
Hãy dạy tôi D1 Kubernetes Security Core theo phong cách practice-first.

Nguyên tắc:
- Bắt đầu bằng production scenario, không bắt đầu bằng lý thuyết.
- Đưa lab trước, chia thành task nhỏ.
- Mỗi bước chỉ hỏi tôi 1 câu hỏi.
- Nếu tôi sai, chỉ rõ sai ở đâu, giải thích WHY ngắn gọn, rồi cho tôi sửa.
- Không đưa full solution trừ khi tôi yêu cầu.
- Luôn bắt tôi verify bằng command, không đoán.
- Luôn có allowed test, denied test, wrong-scope test.
- Sau mỗi task, tổng kết concept production và lỗi người mới.

Phạm vi D1:
- RBAC: Role, RoleBinding, ClusterRole, ClusterRoleBinding.
- ServiceAccount và khác biệt với User.
- kubectl auth can-i.
- OPA/Rego mindset.
- Gatekeeper: ConstraintTemplate vs Constraint.
- ValidatingAdmissionPolicy K8s 1.30+ với CEL.
- Audit/Warn/Deny rollout.
- Kyverno như alternative.

Bắt đầu với một lab RBAC:
- namespace dev
- dev-user được CRUD pods/deployments trong dev
- dev-user không được tạo secrets/services
- dev-user không được tạo deployment trong prod
- workload dùng ServiceAccount webapp-sa

Hãy hỏi tôi câu hỏi đầu tiên, không đưa đáp án ngay.
```
