# D1 - Commands Cheat Sheet

File này gồm các lệnh cần thiết để thực hành và verify D1. Chạy từng nhóm, không paste tất cả một lúc. Production engineer không bắn pháo hoa trong terminal.

## 0. Kiểm Tra Context

```bash
kubectl config current-context
kubectl cluster-info
kubectl version
kubectl get nodes
```

Kiểm tra API resources:

```bash
kubectl api-resources | grep -E "pods|deployments|roles|rolebindings|validatingadmission"
kubectl api-versions | grep -E "apps|rbac.authorization.k8s.io|admissionregistration.k8s.io"
```

Windows PowerShell alternative:

```powershell
kubectl api-resources | Select-String "pods|deployments|roles|rolebindings|validatingadmission"
kubectl api-versions | Select-String "apps|rbac.authorization.k8s.io|admissionregistration.k8s.io"
```

## 1. Namespace

```bash
kubectl create namespace dev
kubectl create namespace prod
kubectl get namespaces
```

Nếu đã có YAML:

```bash
kubectl apply -f rbac/namespace-dev.yaml
```

## 2. RBAC Apply Và Inspect

Apply RBAC manifests:

```bash
kubectl apply -f rbac/dev-deployer-role.yaml
kubectl apply -f rbac/dev-user-rolebinding.yaml
kubectl apply -f rbac/webapp-serviceaccount.yaml
```

Hoặc apply cả folder:

```bash
kubectl apply -f rbac/
```

Inspect:

```bash
kubectl get role -n dev
kubectl describe role dev-deployer -n dev
kubectl get rolebinding -n dev
kubectl describe rolebinding dev-user-deployer -n dev
kubectl get serviceaccount -n dev
kubectl describe serviceaccount webapp-sa -n dev
```

## 3. RBAC Verification Bằng can-i

Allowed path:

```bash
kubectl auth can-i create pods --namespace dev --as dev-user
kubectl auth can-i create deployments --namespace dev --as dev-user
kubectl auth can-i get deployments --namespace dev --as dev-user
kubectl auth can-i patch deployments --namespace dev --as dev-user
kubectl auth can-i delete deployments --namespace dev --as dev-user
```

Expected:

```text
yes
```

Denied resource:

```bash
kubectl auth can-i create secrets --namespace dev --as dev-user
kubectl auth can-i create services --namespace dev --as dev-user
kubectl auth can-i create configmaps --namespace dev --as dev-user
```

Expected:

```text
no
```

Wrong namespace:

```bash
kubectl auth can-i create deployments --namespace prod --as dev-user
kubectl auth can-i delete pods --namespace prod --as dev-user
```

Expected:

```text
no
```

List all permissions in namespace:

```bash
kubectl auth can-i --list --namespace dev --as dev-user
```

ServiceAccount impersonation:

```bash
kubectl auth can-i list pods -n dev --as system:serviceaccount:dev:webapp-sa
```

Note: bạn cần có quyền impersonation để `--as` hoạt động.

## 4. Workload Dùng ServiceAccount

Kiểm tra ServiceAccount trong Deployment/Pod:

```bash
kubectl get pod -n dev -o wide
kubectl get pod <pod-name> -n dev -o jsonpath="{.spec.serviceAccountName}"
```

PowerShell:

```powershell
kubectl get pod <pod-name> -n dev -o jsonpath="{.spec.serviceAccountName}"
```

Expected:

```text
webapp-sa
```

## 5. Gatekeeper Install

Cài đặt Gatekeeper release theo official docs hiện tại:

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.22.2/deploy/gatekeeper.yaml
```

Kiểm tra:

```bash
kubectl get ns gatekeeper-system
kubectl get pods -n gatekeeper-system
kubectl wait --for=condition=Ready pod -l control-plane=controller-manager -n gatekeeper-system --timeout=180s
kubectl get crd | grep gatekeeper
```

PowerShell:

```powershell
kubectl get crd | Select-String gatekeeper
```

Helm alternative:

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper/gatekeeper --name-template=gatekeeper --namespace gatekeeper-system --create-namespace
```

## 6. Gatekeeper Policy Apply

Apply ConstraintTemplate:

```bash
kubectl apply -f policies/gatekeeper/require-limits-template.yaml
kubectl apply -f policies/gatekeeper/disallow-latest-template.yaml
```

Apply Constraint ở dryrun trước:

```bash
kubectl apply -f policies/gatekeeper/require-limits-dryrun.yaml
kubectl apply -f policies/gatekeeper/disallow-latest-dryrun.yaml
```

List constraints:

```bash
kubectl get constraints
kubectl describe <constraint-kind> <constraint-name>
```

Chuyển sang deny:

```bash
kubectl apply -f policies/gatekeeper/require-limits-deny.yaml
kubectl apply -f policies/gatekeeper/disallow-latest-deny.yaml
```

## 7. Test Admission Policy: Resource Limits

Server dry-run trước khi apply thật:

```bash
kubectl apply --dry-run=server -f manifests/bad-pod-no-limits.yaml
kubectl apply --dry-run=server -f manifests/good-pod-with-limits.yaml
```

Apply bad manifest:

```bash
kubectl apply -f manifests/bad-pod-no-limits.yaml
```

Expected khi enforce:

```text
Error from server ... admission webhook ... denied the request
```

Chứng minh Pod không tồn tại:

```bash
kubectl get pod bad-pod -n dev
kubectl get pods -n dev
```

Apply good manifest:

```bash
kubectl apply -f manifests/good-pod-with-limits.yaml
kubectl get pod good-pod -n dev
kubectl describe pod good-pod -n dev
```

Cleanup:

```bash
kubectl delete pod good-pod -n dev
```

## 8. Test Admission Policy: Image latest

Bad:

```bash
kubectl apply --dry-run=server -f manifests/latest-pod.yaml
kubectl apply -f manifests/latest-pod.yaml
```

Expected:

```text
reject nếu image: nginx:latest
```

Good:

```bash
kubectl apply --dry-run=server -f manifests/pinned-image-pod.yaml
kubectl apply -f manifests/pinned-image-pod.yaml
kubectl get pod pinned-image-pod -n dev
```

Cleanup:

```bash
kubectl delete pod pinned-image-pod -n dev
```

## 9. ValidatingAdmissionPolicy: Approved Registry

Kiểm tra Kubernetes version:

```bash
kubectl version
kubectl api-resources | grep ValidatingAdmissionPolicy
```

PowerShell:

```powershell
kubectl api-resources | Select-String ValidatingAdmissionPolicy
```

Apply policy:

```bash
kubectl apply -f policies/vap/approved-registry-policy.yaml
```

Apply binding ở Warn + Audit trước:

```bash
kubectl apply -f policies/vap/approved-registry-binding-audit.yaml
```

Test image ngoài approved registry:

```bash
kubectl apply --dry-run=server -f manifests/dockerhub-nginx-pod.yaml
```

Chuyển sang Deny:

```bash
kubectl apply -f policies/vap/approved-registry-binding-deny.yaml
```

Test lại:

```bash
kubectl apply --dry-run=server -f manifests/dockerhub-nginx-pod.yaml
```

Expected:

```text
dockerhub-nginx-pod -> reject khi Deny
ecr-approved-pod   -> allow nếu image startsWith approved ECR prefix
```

Inspect:

```bash
kubectl get validatingadmissionpolicy
kubectl get validatingadmissionpolicybinding
kubectl describe validatingadmissionpolicy <policy-name>
kubectl describe validatingadmissionpolicybinding <binding-name>
```

## 10. Kyverno Alternative Commands

Cài đặt Kyverno bằng Helm:

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
```

Kiểm tra:

```bash
kubectl get pods -n kyverno
kubectl get crd | grep kyverno
```

PowerShell:

```powershell
kubectl get crd | Select-String kyverno
```

Apply Kyverno policy nếu dùng alternative:

```bash
kubectl apply -f policies/kyverno/
```

## 11. Debug Commands

Kiểm tra event:

```bash
kubectl get events -n dev --sort-by=.lastTimestamp
```

Describe object:

```bash
kubectl describe pod <pod-name> -n dev
```

Admission dry-run:

```bash
kubectl apply --dry-run=server -f <manifest.yaml>
```

Check YAML server-side:

```bash
kubectl diff -f <manifest.yaml>
```

## 12. Cleanup

Delete test pods:

```bash
kubectl delete pod bad-pod good-pod latest-pod pinned-image-pod -n dev --ignore-not-found
```

Delete policies:

```bash
kubectl delete -f policies/vap/ --ignore-not-found
kubectl delete -f policies/gatekeeper/ --ignore-not-found
```

Delete RBAC lab:

```bash
kubectl delete namespace dev --ignore-not-found
kubectl delete namespace prod --ignore-not-found
```

Uninstall Gatekeeper prebuilt:

```bash
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.22.2/deploy/gatekeeper.yaml
```

Uninstall Kyverno Helm:

```bash
helm uninstall kyverno -n kyverno
kubectl delete namespace kyverno --ignore-not-found
```
