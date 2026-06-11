# Ngày A - Lệnh thực hành: GitOps và CI/CD

Tất cả ví dụ dùng `namespace=platform`, `cluster=local-dev`, `service=api-service`, image `ghcr.io/example/api-service`, và repository `https://github.com/vanphutin/vanphutin-aws-accelerator-p2.git`.

## Lệnh ArgoCD CLI

### Đăng nhập

```bash
# MỤC ĐÍCH: Xác thực ArgoCD CLI với API server đang được port-forward ở máy local.
# KHI DÙNG: Sau khi cài ArgoCD local và forward service argocd-server về localhost.
$ argocd login localhost:8080 --username admin --password 'local-dev-admin' --insecure
--- kết quả mong đợi ---
'admin:login' logged in successfully
Context 'localhost:8080' updated
💡 MẸO: Dùng --grpc-web nếu ingress hoặc proxy của bạn gặp lỗi với HTTP/2 gRPC.
⚠️ LƯU Ý: --insecure chấp nhận được cho lab local, không nên dùng cho endpoint production.
```

### Tạo application

```bash
# MỤC ĐÍCH: Tạo ArgoCD Application cho api-service từ một path trong Git.
# KHI DÙNG: Khi đưa workload Kubernetes mới vào quản lý bằng GitOps.
$ argocd app create api-service --project platform --repo https://github.com/vanphutin/vanphutin-aws-accelerator-p2.git --revision main --path cloud/w9/day-a/workloads/api-service --dest-server https://kubernetes.default.svc --dest-namespace platform --sync-policy automated --auto-prune --self-heal
--- kết quả mong đợi ---
application 'api-service' created
💡 MẸO: Luôn đặt --project cụ thể để app không thể deploy ra ngoài namespace được phép.
⚠️ LƯU Ý: --path phải trỏ tới nội dung render được: YAML thuần, Helm chart hoặc Kustomize.
```

### Sync application

```bash
# MỤC ĐÍCH: Áp dụng trạng thái mong muốn từ Git vào cluster.
# KHI DÙNG: Sau khi tạo app hoặc khi app đang OutOfSync và bạn muốn reconcile ngay.
$ argocd app sync api-service --prune --timeout 300
--- kết quả mong đợi ---
TIMESTAMP                  GROUP        KIND        NAMESPACE  NAME         STATUS  HEALTH   HOOK  MESSAGE
2026-06-09T09:30:10+07:00  apps         Deployment  platform   api-service  Synced  Healthy        deployment.apps/api-service configured
2026-06-09T09:30:10+07:00               Service     platform   api-service  Synced  Healthy        service/api-service unchanged
Name:               argocd/api-service
Sync Status:        Synced to main (a1b2c3d)
Health Status:      Healthy
💡 MẸO: Dùng --dry-run trước nếu muốn xem thứ tự apply mà chưa thay đổi cluster.
⚠️ LƯU Ý: --prune sẽ xóa object live đã bị bỏ khỏi Git; hãy kiểm tra ownership trước.
```

### Diff application

```bash
# MỤC ĐÍCH: Hiển thị khác biệt giữa desired state trong Git và live state trong cluster.
# KHI DÙNG: Khi app OutOfSync hoặc bạn nghi ngờ có người sửa cluster bằng tay.
$ argocd app diff api-service --server-side-diff
--- kết quả mong đợi ---
===== apps/Deployment platform/api-service ======
10c10
<   replicas: 2
---
>   replicas: 3
💡 MẸO: Server-side diff gần với hành vi admission của Kubernetes hơn diff client-side.
⚠️ LƯU Ý: Diff có thể khác nếu webhook hoặc default field trong cluster tự thêm giá trị.
```

### Xem chi tiết application

```bash
# MỤC ĐÍCH: Kiểm tra sync status, health, source, destination và resource đang được quản lý.
# KHI DÙNG: Khi debug hoặc sau khi sync để xác nhận trạng thái.
$ argocd app get api-service --refresh
--- kết quả mong đợi ---
Name:               argocd/api-service
Project:            platform
Server:             https://kubernetes.default.svc
Namespace:          platform
URL:                https://localhost:8080/applications/api-service
Repo:               https://github.com/vanphutin/vanphutin-aws-accelerator-p2.git
Target:             main
Path:               cloud/w9/day-a/workloads/api-service
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune, Self Heal)
Sync Status:        Synced to main (a1b2c3d)
Health Status:      Healthy
💡 MẸO: --refresh yêu cầu ArgoCD đọc lại Git và cluster trước khi in kết quả.
⚠️ LƯU Ý: Synced không đồng nghĩa Healthy; luôn đọc cả hai dòng.
```

### Liệt kê application

```bash
# MỤC ĐÍCH: Liệt kê các ArgoCD Application mà tài khoản của bạn thấy được.
# KHI DÙNG: Khi kiểm tra inventory hoặc phạm vi quản lý của project.
$ argocd app list --project platform
--- kết quả mong đợi ---
NAME                  CLUSTER                         NAMESPACE  PROJECT   STATUS  HEALTH   SYNCPOLICY
argocd/postgres       https://kubernetes.default.svc  platform   platform  Synced  Healthy  Auto-Prune
argocd/api-service    https://kubernetes.default.svc  platform   platform  Synced  Healthy  Auto-Prune
💡 MẸO: Thêm -o wide khi cần thấy repo URL và target revision.
⚠️ LƯU Ý: RBAC có thể ẩn application mà bạn không có quyền xem.
```

### Rollback application

```bash
# MỤC ĐÍCH: Deploy lại một revision cũ trong lịch sử ArgoCD Application.
# KHI DÙNG: Khi cần rollback có kiểm soát sau một revision mới bị lỗi.
$ argocd app rollback api-service 3 --timeout 300
--- kết quả mong đợi ---
Application 'api-service' rollback started
TIMESTAMP                  GROUP  KIND        NAMESPACE  NAME         STATUS  HEALTH
2026-06-09T09:42:22+07:00  apps   Deployment  platform   api-service  Synced  Healthy
💡 MẸO: Chạy argocd app history api-service trước để lấy ID revision đúng.
⚠️ LƯU Ý: Nếu Git vẫn chứa version lỗi, hãy follow-up bằng git revert để tránh drift.
```

### Xóa application

```bash
# MỤC ĐÍCH: Xóa ArgoCD Application và có thể xóa luôn resource do app quản lý.
# KHI DÙNG: Khi retire workload khỏi GitOps.
$ argocd app delete api-service --cascade --yes
--- kết quả mong đợi ---
application 'api-service' deleted
💡 MẸO: Dùng --cascade=false nếu chỉ muốn dừng ArgoCD quản lý nhưng giữ resource live.
⚠️ LƯU Ý: --cascade có thể xóa workload production; kiểm tra kỹ tên app và project.
```

### Tạo project

```bash
# MỤC ĐÍCH: Tạo AppProject giới hạn source repository và destination.
# KHI DÙNG: Trước khi onboarding nhóm workload mới vào ArgoCD.
$ argocd proj create platform --description 'Platform workloads for local-dev' --src https://github.com/vanphutin/vanphutin-aws-accelerator-p2.git --dest https://kubernetes.default.svc,platform
--- kết quả mong đợi ---
project 'platform' created
💡 MẸO: Bắt đầu với quyền hẹp rồi mở dần khi có nhu cầu rõ.
⚠️ LƯU Ý: Format destination là server,namespace; sai dấu phẩy có thể làm app sync thất bại.
```

### Thêm destination cho project

```bash
# MỤC ĐÍCH: Cho phép project deploy vào namespace platform trên in-cluster API server.
# KHI DÙNG: Khi thêm namespace hoặc cluster đích mới cho project đã có.
$ argocd proj add-destination platform https://kubernetes.default.svc platform
--- kết quả mong đợi ---
project 'platform' updated
💡 MẸO: Chạy argocd proj get platform để xác nhận destination list.
⚠️ LƯU Ý: Dùng '*' cho namespace hoặc server rất tiện nhưng làm yếu ranh giới tenant.
```

### Cho phép cluster-scoped resource

```bash
# MỤC ĐÍCH: Cho phép project quản lý một loại resource ở phạm vi cluster.
# KHI DÙNG: Khi app platform cần tạo resource an toàn như Namespace.
$ argocd proj allow-cluster-resource platform '' Namespace
--- kết quả mong đợi ---
project 'platform' updated
💡 MẸO: API group rỗng '' nghĩa là core API group của Kubernetes.
⚠️ LƯU Ý: Cluster-scoped resource vượt qua ranh giới namespace; chỉ allow danh sách thật ngắn.
```

## Lệnh `kubectl rollout`

### Xem lịch sử rollout

```bash
# MỤC ĐÍCH: Xem các revision Deployment mà Kubernetes còn lưu.
# KHI DÙNG: Trước khi quyết định rollback về revision nào.
$ kubectl rollout history deployment/api-service -n platform
--- kết quả mong đợi ---
deployment.apps/api-service
REVISION  CHANGE-CAUSE
1         kubectl apply --filename=deployment.yaml
2         kubectl set image deployment/api-service api-service=ghcr.io/example/api-service:v2.0.0 --namespace=platform
💡 MẸO: Gắn annotation kubernetes.io/change-cause để lịch sử có ý nghĩa.
⚠️ LƯU Ý: Revision cũ sẽ biến mất nếu revisionHistoryLimit quá thấp.
```

### Rollback bằng Kubernetes

```bash
# MỤC ĐÍCH: Yêu cầu Kubernetes đưa Deployment về ReplicaSet revision trước.
# KHI DÙNG: Tình huống khẩn cấp khi GitOps tooling không dùng được hoặc quá chậm.
$ kubectl rollout undo deployment/api-service -n platform --to-revision=1
--- kết quả mong đợi ---
deployment.apps/api-service rolled back
💡 MẸO: Tạo git revert ngay sau emergency undo để đưa Git về cùng trạng thái.
⚠️ LƯU Ý: ArgoCD có thể apply lại trạng thái xấu trong Git nếu selfHeal đang bật.
```

### Theo dõi rollout

```bash
# MỤC ĐÍCH: Chờ Deployment rollout hoàn tất hoặc timeout.
# KHI DÙNG: Sau khi đổi image, rollback hoặc sync app.
$ kubectl rollout status deployment/api-service -n platform --timeout=120s
--- kết quả mong đợi ---
Waiting for deployment "api-service" rollout to finish: 1 old replicas are pending termination...
deployment "api-service" successfully rolled out
💡 MẸO: Dùng trong script để fail nhanh nếu pod không Ready.
⚠️ LƯU Ý: Rollout thành công chỉ nói readiness pass, chưa chứng minh business health tốt.
```

### Tạm dừng rollout

```bash
# MỤC ĐÍCH: Tạm dừng Deployment rollout trước khi thêm pod mới được cập nhật.
# KHI DÙNG: Khi rollout có dấu hiệu bất thường và bạn cần thời gian kiểm tra.
$ kubectl rollout pause deployment/api-service -n platform
--- kết quả mong đợi ---
deployment.apps/api-service paused
💡 MẸO: Pause không dừng các pod đã được tạo trước đó.
⚠️ LƯU Ý: Deployment đang pause có thể làm GitOps sync sau đó bị kẹt.
```

### Tiếp tục rollout

```bash
# MỤC ĐÍCH: Tiếp tục rollout đã bị pause.
# KHI DÙNG: Sau khi xác minh version mới ổn hoặc khi hoàn tất kiểm tra.
$ kubectl rollout resume deployment/api-service -n platform
--- kết quả mong đợi ---
deployment.apps/api-service resumed
💡 MẸO: Chạy rollout status ngay sau resume.
⚠️ LƯU Ý: Resume một rollout xấu sẽ tiếp tục rollout xấu; kiểm tra image trước.
```

## Lệnh Flux CLI

### Bootstrap GitHub

```bash
# MỤC ĐÍCH: Cài Flux controller và nối cluster với GitHub repository.
# KHI DÙNG: Khi bootstrap GitOps cho cluster mới.
$ flux bootstrap github --owner=vanphutin --repository=vanphutin-aws-accelerator-p2 --branch=main --path=cloud/w9/day-a/flux/local-dev --personal=true --components-extra=image-reflector-controller,image-automation-controller
--- kết quả mong đợi ---
► connecting to github.com
► cloning branch "main" from Git repository "https://github.com/vanphutin/vanphutin-aws-accelerator-p2.git"
► generating component manifests
✔ committed sync manifests to "main" ("a1b2c3d")
► installing components in "flux-system" namespace
✔ bootstrap finished
💡 MẸO: Với repository tổ chức, dùng --personal=false và owner là tên organization.
⚠️ LƯU Ý: Bootstrap commit file vào repo; hãy chạy trên đúng branch và path.
```

### Xem toàn bộ resource Flux

```bash
# MỤC ĐÍCH: Xem trạng thái source và workload do Flux quản lý.
# KHI DÙNG: Khi kiểm tra sức khỏe hoặc debug Flux.
$ flux get all --all-namespaces
--- kết quả mong đợi ---
NAMESPACE     NAME                            REVISION        SUSPENDED  READY  MESSAGE
flux-system   gitrepository/flux-system       main/a1b2c3d     False      True   stored artifact for revision 'main/a1b2c3d'
flux-system   kustomization/flux-system       main/a1b2c3d     False      True   Applied revision: main/a1b2c3d
platform      kustomization/api-service       main/d4e5f6a     False      True   Applied revision: main/d4e5f6a
💡 MẸO: READY=False cộng cột MESSAGE thường chỉ ra lệnh cần chạy tiếp.
⚠️ LƯU Ý: Flux resource có thể nằm trong namespace tenant, không chỉ flux-system.
```

### Reconcile Git source

```bash
# MỤC ĐÍCH: Yêu cầu Flux fetch revision Git mới ngay lập tức.
# KHI DÙNG: Sau khi push commit và không muốn chờ interval.
$ flux reconcile source git flux-system -n flux-system --with-source
--- kết quả mong đợi ---
► annotating GitRepository flux-system in flux-system namespace
✔ GitRepository annotated
◎ waiting for GitRepository reconciliation
✔ fetched revision main/d4e5f6a
💡 MẸO: Kết hợp với reconcile kustomization khi cần sync đầu-cuối ngay.
⚠️ LƯU Ý: Lệnh này chưa chắc apply manifest nếu controller phụ thuộc chưa reconcile.
```

### Reconcile Kustomization

```bash
# MỤC ĐÍCH: Yêu cầu Flux apply một Kustomization ngay lập tức.
# KHI DÙNG: Sau khi source đã fetch xong hoặc sau khi sửa lỗi apply.
$ flux reconcile kustomization api-service -n platform --with-source
--- kết quả mong đợi ---
► annotating Kustomization api-service in platform namespace
✔ Kustomization annotated
◎ waiting for Kustomization reconciliation
✔ applied revision main/d4e5f6a
💡 MẸO: --with-source giúp refresh Git trước khi apply.
⚠️ LƯU Ý: Health check fail có thể làm Kustomization NotReady dù object đã được apply.
```

### Trace resource

```bash
# MỤC ĐÍCH: Xem Flux object nào đang quản lý một Kubernetes resource.
# KHI DÙNG: Khi debug ownership hoặc hành vi prune.
$ flux trace deployment api-service -n platform
--- kết quả mong đợi ---
Object:         Deployment/platform/api-service
Kustomization: platform/api-service
GitRepository: flux-system/flux-system
Revision:      main/d4e5f6a
Status:        Ready
💡 MẸO: Trace rất hữu ích trước khi xóa resource bằng tay.
⚠️ LƯU Ý: Lệnh hoạt động tốt nhất khi resource có inventory label của Flux.
```

### Xem log Flux

```bash
# MỤC ĐÍCH: Stream log từ Flux controllers.
# KHI DÙNG: Khi hành vi fetch, render, apply hoặc notification không rõ.
$ flux logs --all-namespaces --level=error --since=30m
--- kết quả mong đợi ---
2026-06-09T10:10:14.123+0700 error Kustomization/platform/api-service dry-run failed: Deployment.apps "api-service" is invalid
💡 MẸO: Bắt đầu với --level=error, rồi mở rộng sang --level=info nếu cần.
⚠️ LƯU Ý: Log controller có thể nhiều; lọc thêm --kind hoặc --name khi debug cụ thể.
```

## Lệnh GitHub CLI

### Chạy workflow thủ công

```bash
# MỤC ĐÍCH: Khởi động workflow có bật workflow_dispatch.
# KHI DÙNG: Khi cần chạy lại có kiểm soát, demo hoặc deploy thủ công.
$ gh workflow run ci-apply.yml --ref main -f environment=production -f service_name=api-service
--- kết quả mong đợi ---
✓ Created workflow_dispatch event for ci-apply.yml at main
💡 MẸO: Dùng gh workflow list để xác nhận đúng tên file workflow.
⚠️ LƯU Ý: Lệnh fail nếu workflow không khai báo workflow_dispatch inputs.
```

### Liệt kê workflow run

```bash
# MỤC ĐÍCH: Xem các workflow run gần đây và trạng thái của chúng.
# KHI DÙNG: Sau khi mở PR, merge hoặc trigger workflow thủ công.
$ gh run list --workflow ci-plan.yml --branch main --limit 5
--- kết quả mong đợi ---
STATUS  TITLE                         WORKFLOW              BRANCH  EVENT  ID          ELAPSED  AGE
✓       Kiểm tra manifest platform    CI kiểm tra kế hoạch  main    push   1690000011  4m12s    3m
X       Thêm rollout api-service      CI kiểm tra kế hoạch  main    push   1690000008  2m40s    1h
💡 MẸO: Thêm --json databaseId,status,conclusion,headSha khi viết script.
⚠️ LƯU Ý: Lọc theo branch có thể ẩn PR run từ feature branch.
```

### Xem chi tiết run

```bash
# MỤC ĐÍCH: Kiểm tra job, annotation và log của một workflow run.
# KHI DÙNG: Khi run fail hoặc reviewer cần bằng chứng kiểm tra.
$ gh run view 1690000011 --log-failed
--- kết quả mong đợi ---
CI kiểm tra kế hoạch #42
✓ yamllint in 38s
✓ kubeval in 44s
X helm-diff in 1m12s
helm upgrade --install api-service ./charts/api-service --namespace platform --dry-run
Error: values don't meet the schema
💡 MẸO: --log-failed giữ output tập trung vào job lỗi.
⚠️ LƯU Ý: Log có thể lộ dữ liệu nhạy cảm nếu script in biến môi trường không cẩn thận.
```

### Theo dõi run

```bash
# MỤC ĐÍCH: Theo dõi workflow run đến khi hoàn tất.
# KHI DÙNG: Trong cửa sổ deploy hoặc khi demo trực tiếp.
$ gh run watch 1690000011 --exit-status
--- kết quả mong đợi ---
Refreshing run status every 3 seconds. Press Ctrl+C to quit.

✓ main CI kiểm tra kế hoạch · 1690000011
Triggered via push about 2 minutes ago

JOBS
✓ yamllint in 38s
✓ kubeval in 44s
✓ helm-diff in 1m12s
💡 MẸO: --exit-status làm lệnh trả non-zero nếu run fail.
⚠️ LƯU Ý: Ctrl+C chỉ dừng việc watch local, không hủy workflow đang chạy.
```

### Tạo secret

```bash
# MỤC ĐÍCH: Lưu secret mã hóa cho GitHub Actions.
# KHI DÙNG: Với giá trị không thay được bằng OIDC, ví dụ Slack webhook.
$ gh secret set SLACK_WEBHOOK_URL --body 'https://hooks.slack.com/services/your-slack-webhook-url-here'
--- kết quả mong đợi ---
✓ Set Actions secret SLACK_WEBHOOK_URL for vanphutin/vanphutin-aws-accelerator-p2
💡 MẸO: Dùng environment-level secret cho deployment production.
⚠️ LƯU Ý: Không lưu AWS access key dài hạn nếu có thể dùng OIDC.
```
