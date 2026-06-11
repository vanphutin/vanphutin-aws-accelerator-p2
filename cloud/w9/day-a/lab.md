# Ngày A - Lab: GitOps với ArgoCD và GitHub Actions

Lab này giúp bạn tự tay dựng cluster `local-dev`, cài ArgoCD, deploy mô hình App-of-Apps, tạo lỗi bằng image sai, phục hồi bằng `git revert`, rồi so sánh với `kubectl rollout undo`.

## Điều kiện chuẩn bị

Bạn cần các công cụ sau:

- `kind` v0.22+ để tạo Kubernetes cluster local.
- `kubectl` tương thích với Kubernetes v1.29+.
- `helm` 3.x để cài ArgoCD.
- `argocd` CLI v2.10+.
- `gh` CLI đã đăng nhập GitHub.
- Repository đã có remote `origin` là `https://github.com/vanphutin/vanphutin-aws-accelerator-p2.git`.

Kiểm tra nhanh:

```bash
kind version
kubectl version --client
helm version
argocd version --client
gh auth status
git remote -v
```

--- kết quả mong đợi ---

```text
kind v0.22.0 go1.21.7 linux/amd64
Client Version: v1.29.3
version.BuildInfo{Version:"v3.15.4", GitCommit:"..."}
argocd: v2.10.7+...
github.com
  ✓ Logged in to github.com account vanphutin
origin  https://github.com/vanphutin/vanphutin-aws-accelerator-p2.git (fetch)
origin  https://github.com/vanphutin/vanphutin-aws-accelerator-p2.git (push)
```

✓ Điểm kiểm tra: tất cả lệnh version chạy được và `gh auth status` báo đã đăng nhập.

## Bước 1: Tạo cluster `kind` local

Mục tiêu: tạo một Kubernetes cluster local tên `local-dev` có port map sẵn cho ingress ở các ngày sau.

```bash
cat > kind-local-dev.yaml <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: local-dev
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
  - role: worker
  - role: worker
YAML

kind create cluster --config kind-local-dev.yaml
kubectl cluster-info --context kind-local-dev
kubectl get nodes -o wide
```

--- kết quả mong đợi ---

```text
Creating cluster "local-dev" ...
 ✓ Ensuring node image (kindest/node:v1.29.2)
 ✓ Preparing nodes
 ✓ Writing configuration
 ✓ Starting control-plane
 ✓ Installing CNI
 ✓ Installing StorageClass
 ✓ Joining worker nodes
Set kubectl context to "kind-local-dev"

Kubernetes control plane is running at https://127.0.0.1:xxxxx

NAME                      STATUS   ROLES           AGE   VERSION
local-dev-control-plane   Ready    control-plane   60s   v1.29.2
local-dev-worker          Ready    <none>          45s   v1.29.2
local-dev-worker2         Ready    <none>          45s   v1.29.2
```

✓ Điểm kiểm tra: `kubectl get nodes` có 3 node trạng thái `Ready`.

## Bước 2: Cài ArgoCD bằng Helm và đăng nhập

Mục tiêu: cài ArgoCD vào namespace `argocd`, forward UI/API về máy local, đăng nhập bằng mật khẩu ban đầu rồi đổi sang mật khẩu lab dễ nhớ.

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

kubectl create namespace argocd

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version 7.6.12 \
  --set configs.params."server\.insecure"=true \
  --wait \
  --timeout 10m

kubectl -n argocd get pods
```

--- kết quả mong đợi ---

```text
Release "argocd" does not exist. Installing it now.
NAME: argocd
LAST DEPLOYED: Tue Jun  9 10:00:00 2026
NAMESPACE: argocd
STATUS: deployed

NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          2m
argocd-applicationset-controller-6f8cc7b9cc-bd2tf   1/1     Running   0          2m
argocd-dex-server-7d96579f6d-q22fg                  1/1     Running   0          2m
argocd-redis-658c7cdb9c-hzggm                       1/1     Running   0          2m
argocd-repo-server-6d674746d9-6s7xm                 1/1     Running   0          2m
argocd-server-67b6f8df5f-7m5np                      1/1     Running   0          2m
```

Mở một terminal riêng và giữ port-forward chạy:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

--- kết quả mong đợi ---

```text
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
```

Trong terminal chính:

```bash
INITIAL_PASSWORD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode)"
argocd login localhost:8080 --username admin --password "$INITIAL_PASSWORD" --insecure
argocd account update-password --account admin --current-password "$INITIAL_PASSWORD" --new-password 'local-dev-admin'
argocd relogin --username admin --password 'local-dev-admin'
```

--- kết quả mong đợi ---

```text
'admin:login' logged in successfully
Context 'localhost:8080' updated
Password updated
'admin:login' logged in successfully
Context 'localhost:8080' updated
```

✓ Điểm kiểm tra: bạn vào được UI tại `http://localhost:8080` bằng user `admin` và password `local-dev-admin`.

### Nếu có sự cố

Nếu port `8080` đã bận, dùng port khác:

```bash
kubectl -n argocd port-forward svc/argocd-server 18080:80
argocd login localhost:18080 --username admin --password 'local-dev-admin' --insecure
```

## Bước 3: Apply `root-app.yaml` và quan sát App-of-Apps

Mục tiêu: dùng root app để tạo child app `postgres` trước, rồi `api-service` sau nhờ sync wave.

```bash
kubectl apply -f day-a/argocd/project.yaml
kubectl apply -f day-a/argocd/root-app.yaml

argocd app get root-app --refresh
argocd app sync root-app --timeout 300
argocd app list --project platform
```

--- kết quả mong đợi ---

```text
appproject.argoproj.io/platform created
application.argoproj.io/root-app created

Name:               argocd/root-app
Project:            platform
Sync Status:        OutOfSync from main (a1b2c3d)
Health Status:      Healthy

TIMESTAMP                  GROUP        KIND         NAMESPACE  NAME         STATUS  HEALTH
2026-06-09T10:10:10+07:00  argoproj.io  Application  argocd     postgres     Synced  Healthy
2026-06-09T10:10:12+07:00  argoproj.io  Application  argocd     api-service  Synced  Healthy

NAME                 CLUSTER                         NAMESPACE  PROJECT   STATUS  HEALTH
argocd/postgres      https://kubernetes.default.svc  platform   platform  Synced  Healthy
argocd/api-service   https://kubernetes.default.svc  platform   platform  Synced  Healthy
argocd/root-app      https://kubernetes.default.svc  argocd     platform  Synced  Healthy
```

Kiểm tra thứ tự wave:

```bash
kubectl -n argocd get applications postgres api-service \
  -o custom-columns=NAME:.metadata.name,WAVE:.metadata.annotations.argocd\\.argoproj\\.io/sync-wave,SYNC:.status.sync.status,HEALTH:.status.health.status
kubectl -n platform get pods,svc
```

--- kết quả mong đợi ---

```text
NAME          WAVE   SYNC     HEALTH
postgres      1      Synced   Healthy
api-service   2      Synced   Healthy

NAME                               READY   STATUS    RESTARTS   AGE
pod/api-service-5df45d7b9c-h6f8n   1/1     Running   0          90s
pod/postgres-0                     1/1     Running   0          2m

NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
service/api-service   ClusterIP   10.96.120.10    <none>        80/TCP
service/postgres      ClusterIP   10.96.130.20    <none>        5432/TCP
```

✓ Điểm kiểm tra: `postgres` có wave `1`, `api-service` có wave `2`, và cả hai đều `Healthy`.

### Nếu có sự cố

Nếu child app không xuất hiện, kiểm tra source path của root app:

```bash
argocd app get root-app
argocd app logs root-app
kubectl -n argocd logs deploy/argocd-repo-server --tail=100
```

## Bước 4: Mô phỏng deploy lỗi bằng image không tồn tại

Mục tiêu: tạo thay đổi xấu trong Git, để ArgoCD sync đúng Git nhưng health chuyển sang `Degraded`.

```bash
git checkout -b lab/day-a-bad-image
sed -i.bak 's#ghcr.io/example/api-service:v1.0.0#ghcr.io/example/api-service:does-not-exist#g' day-a/workloads/api-service/deployment.yaml
rm day-a/workloads/api-service/deployment.yaml.bak
git add day-a/workloads/api-service/deployment.yaml
git commit -m "lab: simulate bad api-service image"
git push origin lab/day-a-bad-image

gh pr create \
  --title "lab: simulate bad api-service image" \
  --body "Mô phỏng lỗi image để quan sát ArgoCD health Degraded." \
  --base main \
  --head lab/day-a-bad-image

gh pr merge --merge --delete-branch
git checkout main
git pull --ff-only

argocd app sync api-service --timeout 300
argocd app get api-service --refresh
kubectl -n platform get pods
```

--- kết quả mong đợi ---

```text
[lab/day-a-bad-image 9f8e7d6] lab: simulate bad api-service image
 1 file changed, 1 insertion(+), 1 deletion(-)
✓ Created pull request vanphutin/vanphutin-aws-accelerator-p2#42
✓ Merged pull request #42 (lab: simulate bad api-service image)

Name:               argocd/api-service
Sync Status:        Synced to main (9f8e7d6)
Health Status:      Degraded

NAME                           READY   STATUS             RESTARTS   AGE
api-service-7c8f7f74c9-j2m7q   0/1     ImagePullBackOff   0          90s
postgres-0                     1/1     Running            0          10m
```

✓ Điểm kiểm tra: ArgoCD báo `Synced` nhưng `Degraded`, còn pod `api-service` ở trạng thái `ImagePullBackOff`.

### Nếu có sự cố

Nếu ArgoCD chưa thấy commit mới, ép refresh:

```bash
argocd app get api-service --hard-refresh
argocd app sync api-service --timeout 300
```

## Bước 5: Phục hồi bằng `git revert`

Mục tiêu: sửa source of truth bằng commit revert, rồi để ArgoCD tự sync về image khỏe.

```bash
BAD_COMMIT="$(git log --oneline -1 --format=%H)"
git revert --no-edit "$BAD_COMMIT"
git push origin main

argocd app get api-service --hard-refresh
argocd app sync api-service --timeout 300
argocd app get api-service --refresh
kubectl -n platform rollout status deployment/api-service --timeout=180s
kubectl -n platform get pods
```

--- kết quả mong đợi ---

```text
[main 1a2b3c4] Revert "lab: simulate bad api-service image"
 Date: Tue Jun 9 10:25:00 2026 +0700
 1 file changed, 1 insertion(+), 1 deletion(-)

Name:               argocd/api-service
Sync Status:        Synced to main (1a2b3c4)
Health Status:      Healthy

deployment "api-service" successfully rolled out
NAME                               READY   STATUS    RESTARTS   AGE
api-service-5df45d7b9c-h6f8n       1/1     Running   0          45s
postgres-0                         1/1     Running   0          14m
```

✓ Điểm kiểm tra: Git có commit revert, ArgoCD `Healthy`, và pod `api-service` chạy lại.

## Bước 6: So sánh với `kubectl rollout undo`

Mục tiêu: tự tạo thay đổi ngoài Git, rollback bằng Kubernetes, rồi quan sát drift giữa Git và cluster.

```bash
kubectl -n platform set image deployment/api-service api-service=ghcr.io/example/api-service:v2.0.0
kubectl -n platform rollout status deployment/api-service --timeout=120s
kubectl -n platform rollout history deployment/api-service

kubectl -n platform rollout undo deployment/api-service
kubectl -n platform rollout status deployment/api-service --timeout=120s

argocd app diff api-service
argocd app get api-service --refresh
```

--- kết quả mong đợi ---

```text
deployment.apps/api-service image updated
deployment "api-service" successfully rolled out

deployment.apps/api-service
REVISION  CHANGE-CAUSE
1         <none>
2         <none>

deployment.apps/api-service rolled back
deployment "api-service" successfully rolled out

===== apps/Deployment platform/api-service ======
< image: ghcr.io/example/api-service:v1.0.0
---
> image: ghcr.io/example/api-service:v2.0.0

Name:               argocd/api-service
Sync Status:        OutOfSync from main (1a2b3c4)
Health Status:      Healthy
```

✓ Điểm kiểm tra: app có thể `Healthy` nhưng `OutOfSync`, chứng minh live state đã lệch Git.

### Nếu có sự cố

Nếu ArgoCD tự sửa quá nhanh vì self-heal, bạn vẫn có thể xem event gần nhất:

```bash
kubectl -n argocd get events --sort-by=.lastTimestamp | tail -20
argocd app history api-service
```

## Bước 7: Sửa drift bằng hard refresh và sync

Mục tiêu: đưa cluster quay lại đúng source of truth trong Git.

```bash
argocd app get api-service --hard-refresh
argocd app sync api-service --prune --timeout 300
argocd app get api-service --refresh
kubectl -n platform get deployment api-service -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

--- kết quả mong đợi ---

```text
Name:               argocd/api-service
Sync Status:        Synced to main (1a2b3c4)
Health Status:      Healthy

ghcr.io/example/api-service:v1.0.0
```

✓ Điểm kiểm tra: ArgoCD `Synced` và live image khớp lại với Git.

## Những gì bạn đã học

- GitOps dùng Git làm nguồn sự thật và controller để kéo trạng thái vào cluster.
- Pull-based GitOps giảm nhu cầu cấp cluster credential dài hạn cho CI.
- GitHub Actions nên dùng mẫu plan-on-PR và apply-on-merge để review rủi ro trước deploy.
- ArgoCD App-of-Apps giúp bootstrap nhiều application bằng một root app.
- Sync wave đảm bảo resource phụ thuộc được apply theo thứ tự.
- `git revert` giữ đúng luồng GitOps hơn `kubectl rollout undo`, vì không tạo drift lâu dài.

## Câu hỏi suy ngẫm

1. Nếu một service bị lỗi do config trong Git, khi nào bạn chọn `git revert`, khi nào chọn ArgoCD rollback, và vì sao?
2. Trong một tổ chức có nhiều team, AppProject nên giới hạn source repo và namespace như thế nào để tránh deploy nhầm?
3. Nếu CI có quyền `kubectl apply` trực tiếp vào production, rủi ro bảo mật và audit nào xuất hiện so với mô hình ArgoCD pull-based?

## Bước tiếp theo

- Đọc ArgoCD Application spec: https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/
- Đọc ArgoCD Sync Waves và Hooks: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/
- Đọc ArgoCD Projects: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/
- Đọc GitHub Actions OIDC: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect
