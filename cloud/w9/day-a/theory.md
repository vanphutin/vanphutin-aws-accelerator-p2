# Ngày A - Lý thuyết: GitOps và CI/CD

## 0. Cách dùng tài liệu này

Hãy đọc `theory.md` trước để nắm mô hình tư duy, sau đó luyện từng lệnh trong `commands.md`, rồi làm `lab.md` để chạy toàn bộ luồng trên cluster `minikube` tên `local-dev`. Mục tiêu của ngày này là hiểu vì sao Git trở thành nguồn sự thật, CI chỉ kiểm tra và chuẩn bị thay đổi, còn controller như ArgoCD hoặc Flux mới là thành phần kéo trạng thái mong muốn vào Kubernetes.

## 1. GitOps là gì, và vì sao bạn nên quan tâm?

Hãy tưởng tượng một nhà hàng có cuốn sổ công thức ghi "súp cà chua", nhưng trong bếp ai đó lại nấu "súp nấm" vì đã tự ý đổi công thức. Khi khách phàn nàn, không ai biết nên tin cuốn sổ hay nồi súp đang nấu. GitOps giải quyết đúng vấn đề đó trong hạ tầng: Git là cuốn sổ công thức, cluster là căn bếp, và controller phải liên tục làm cho căn bếp nấu đúng công thức.

Định nghĩa kỹ thuật: GitOps là cách vận hành hệ thống trong đó trạng thái mong muốn được mô tả bằng file khai báo trong Git, còn một controller tự động kéo trạng thái đó vào môi trường chạy thật và liên tục sửa sai lệch.

```text
Ẩn dụ cuốn sổ công thức

Git repository                 Kubernetes cluster
--------------                 ------------------
YAML ghi:                      Trạng thái đang chạy:
api replicas: 3      ---->     api replicas: 3
image: v1.2.0                  image: v1.2.0

Nếu ai đó sửa cluster bằng tay:

Git repository                 Kubernetes cluster
--------------                 ------------------
api replicas: 3      ---->     api replicas: 1
image: v1.2.0                  image: broken-tag

GitOps controller phát hiện lệch và đưa cluster về đúng Git.
```

> Vì sao điều này quan trọng?
> Khi production gặp sự cố, bạn cần biết phải tin Git, pipeline CI, câu lệnh trên laptop, hay thao tác click trong dashboard. GitOps làm câu trả lời rõ ràng: Git là nguồn sự thật.

> Hiểu lầm thường gặp:
> GitOps không chỉ là "có dùng Git trong quá trình deploy". Nếu GitHub Actions chạy `kubectl apply` trực tiếp vào cluster, Git có tham gia, nhưng cluster vẫn không tự kéo và reconcile trạng thái mong muốn.

### Vấn đề GitOps giải quyết

Các lỗi quen thuộc trong vận hành:

- "Works on my machine": script trên máy một người chạy được, nhưng người khác không tái hiện được.
- Drift: Git nói một kiểu, production chạy một kiểu.
- Thay đổi ẩn: ai đó chạy `kubectl edit deployment api-service` trong sự cố rồi quên commit lại.
- Rollback yếu: không rõ commit hoặc artifact nào là điểm an toàn để quay về.

GitOps biến mọi thay đổi hạ tầng và ứng dụng thành một chuỗi có thể kiểm tra:

```text
Ý định của người vận hành
        |
        v
Pull request
        |
        v
Review
        |
        v
Merge commit
        |
        v
GitOps controller sync
        |
        v
Trạng thái trong cluster
```

### Bốn nguyên tắc OpenGitOps

#### 1. Declarative - khai báo điều bạn muốn

Ẩn dụ: Khi đặt phòng khách sạn, bạn nói "tôi muốn một phòng cho hai đêm", không nói "mở bảng database A, thêm dòng B, gọi API thanh toán C".

Định nghĩa kỹ thuật: Trạng thái mong muốn được mô tả bằng dữ liệu, thường là YAML, thay vì chuỗi lệnh thao tác từng bước.

Ví dụ khai báo:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: platform
spec:
  replicas: 3
```

Ví dụ mệnh lệnh:

```bash
kubectl create deployment api-service --image=ghcr.io/example/api-service:v1.0.0
kubectl scale deployment api-service --replicas=3
```

```text
Khai báo: "hãy làm thực tế giống file này"

desired.yaml
    |
    v
GitOps controller
    |
    v
Kubernetes API
```

> Vì sao điều này quan trọng?
> Trạng thái khai báo có thể review, diff, render, validate và reconcile. Script mệnh lệnh thường giấu trạng thái trong thứ tự lệnh và biến môi trường trên máy chạy.

#### 2. Versioned and immutable - có phiên bản và không sửa lịch sử

Ẩn dụ: Sổ cái ngân hàng không xóa giao dịch sai. Nó ghi thêm một giao dịch mới để đảo lại giao dịch sai.

Định nghĩa kỹ thuật: Trạng thái mong muốn được lưu trong hệ thống có lịch sử bất biến, thường là Git commit. Mỗi thay đổi có commit hash, có thể so sánh và revert.

```text
Nhánh main

a1b2c3d  Deploy api-service v1.0.0
   |
d4e5f6a  Tăng replicas lên 3
   |
f7a8b9c  Deploy api-service v2.0.0
   |
0d1e2f3  Revert v2.0.0 vì lỗi tăng
```

> Vì sao điều này quan trọng?
> Commit hash là câu trả lời bền vững cho hai câu hỏi quan trọng nhất khi có sự cố: "đã đổi gì?" và "quay lại thế nào?"

#### 3. Pulled automatically - cluster tự kéo từ Git

Ẩn dụ: Một văn phòng an toàn không cho shipper đi vào mọi phòng. Văn phòng có phòng thư nội bộ tự nhận các gói đã được kiểm tra từ điểm giao hàng tin cậy.

Định nghĩa kỹ thuật: Agent trong cluster, ví dụ ArgoCD hoặc Flux, kéo trạng thái mong muốn từ Git. CI không cần giữ credential dài hạn để push thay đổi vào cluster.

```text
Push-based CD

GitHub Actions runner
    |
    | kubectl apply bằng cluster credential
    v
Kubernetes cluster

Pull-based GitOps

Git repository <---- ArgoCD / Flux chạy trong cluster
                         |
                         v
                  Kubernetes cluster
```

> Vì sao điều này quan trọng?
> Mô hình pull giảm rủi ro credential trong CI. GitHub Actions có thể build, test, scan và tạo artifact; cluster tự quyết định trạng thái nào được áp dụng.

#### 4. Continuously reconciled - liên tục đối chiếu thực tế với Git

Ẩn dụ: Máy điều hòa không đặt nhiệt độ một lần rồi bỏ đi. Nó liên tục đo nhiệt độ phòng và bật/tắt để đưa phòng về mức mong muốn.

Định nghĩa kỹ thuật: Controller liên tục so sánh trạng thái mong muốn trong Git với trạng thái thật trong cluster, rồi sửa để trạng thái thật khớp trạng thái mong muốn.

```text
Vòng lặp reconcile:

Đọc trạng thái mong muốn từ Git
        |
        v
Đọc trạng thái thật trong cluster
        |
        v
mong muốn == thực tế?
   |              |
  có            không
   |              |
chờ tiếp      áp dụng sửa đổi
```

> Vì sao điều này quan trọng?
> Reconciliation giúp tự hồi phục nhiều kiểu drift. Nếu ai đó xóa nhầm Service trong Kubernetes, controller có thể tạo lại.

### Push-based CD và Pull-based GitOps

```text
Push-based CD

Developer -> PR -> CI pipeline -> kubectl apply -> Cluster
                           |
                           +-- CI giữ credential deploy

Pull-based GitOps

Developer -> PR -> merge -> Git repository
                             ^
                             |
                       ArgoCD / Flux
                             |
                             v
                          Cluster
```

| Khía cạnh | Push-based CD | Pull-based GitOps |
| --- | --- | --- |
| Truy cập cluster | Runner CI thường giữ credential | Controller trong cluster giữ quyền cần thiết |
| Sửa drift | Thường chỉ apply một lần | Reconcile liên tục |
| Audit | Phụ thuộc log CI và Git | Git commit cộng lịch sử controller |
| Khôi phục | Chạy lại pipeline | Reconcile hoặc revert Git |
| Phù hợp | Dự án nhỏ, deploy đơn giản | Kubernetes production, nhiều cluster, yêu cầu audit |

> Hiểu lầm thường gặp:
> Pull-based GitOps không loại bỏ CI. CI vẫn build image, chạy test, scan artifact và mở pull request. GitOps chỉ thay đổi thành phần thực hiện mutation cuối cùng trên cluster.

### Quy ước cấu trúc Git repository

Ẩn dụ: Xưởng sản xuất tách bản vẽ sản phẩm khỏi sơ đồ điện nhà máy. Cả hai đều quan trọng, nhưng đội phụ trách khác nhau và tốc độ thay đổi khác nhau.

Ví dụ repository cấu hình ứng dụng:

```text
app-configs/
  api-service/
    base/
    overlays/
      dev/
      staging/
      prod/
```

Ví dụ repository cấu hình hạ tầng:

```text
infra-configs/
  clusters/
    local-dev/
      argocd/
      ingress/
      monitoring/
  platform/
    namespaces/
    policies/
```

Vì sao nên tách app config và infra config:

- Đội ứng dụng sở hữu manifest service, Helm values và cấu hình rollout.
- Đội platform sở hữu cluster, namespace, RBAC, ingress controller và observability.
- Quyền ghi hẹp hơn. Đội service không cần quyền sửa RBAC toàn cluster.

| Mô hình | Ưu điểm | Nhược điểm | Phù hợp |
| --- | --- | --- | --- |
| Folder-per-environment | Dễ diff giữa môi trường, một chính sách branch, promotion bằng PR rõ ràng | Repository lớn có thể nhiều file | Phần lớn đội platform |
| Branch-per-environment | Cô lập mạnh, quen với tư duy branch | Khó so sánh, dễ divergence, merge conflict | Hệ thống legacy có gate theo branch |

```text
Folder-per-environment

main
  clusters/local-dev
  clusters/staging
  clusters/prod

Branch-per-environment

dev branch      -> dev cluster
staging branch  -> staging cluster
prod branch     -> prod cluster
```

> Vì sao điều này quan trọng?
> Cách tổ chức môi trường ảnh hưởng trực tiếp đến tốc độ promotion, chất lượng review và khả năng khôi phục khi có sự cố.

## 2. GitHub Actions - pipeline CI/CD hoạt động như thế nào

Ẩn dụ: GitHub Actions giống dây chuyền sản xuất. Nguyên liệu đi vào là code hoặc manifest, mỗi trạm kiểm tra làm một việc, cuối cùng tạo ra kết quả deploy hoặc báo lỗi.

Định nghĩa kỹ thuật: GitHub Actions chạy các workflow được mô tả bằng YAML. Workflow phản ứng với event, tạo job trên runner, và thực thi các step.

```text
Cấu trúc workflow

.github/workflows/ci-plan.yml
        |
        v
Trigger: pull_request vào main
        |
        v
Jobs: yamllint, kubeval, helm-diff
        |
        v
Steps: checkout, cài tool, chạy lệnh, comment PR
        |
        v
Runner: ubuntu-latest
```

> Vì sao điều này quan trọng?
> Pipeline CI/CD là hệ thống điều khiển production. Workflow YAML cũng là code và cần được review nghiêm túc.

### Bảng thuật ngữ

| Thuật ngữ | Nghĩa dễ hiểu | Ví dụ |
| --- | --- | --- |
| `trigger` | Sự kiện khởi động workflow | `pull_request`, `push`, `workflow_dispatch` |
| `job` | Nhóm step chạy trên runner | `yamllint`, `helm-diff` |
| `step` | Một action hoặc một lệnh shell | `helm lint ./charts/api-service` |
| `runner` | Máy thực thi job | `ubuntu-latest` |
| `context` | Dữ liệu runtime từ GitHub | `${{ github.ref }}` |
| `secret` | Giá trị mã hóa đưa vào lúc chạy | `AWS_ROLE_TO_ASSUME` |
| `artifact` | File lưu lại từ một run | `plan.txt`, `coverage.html` |
| `environment` | Cổng kiểm duyệt deploy và secret theo môi trường | `production` |

### Mẫu "plan-on-PR, apply-on-merge"

Ẩn dụ: Pull request giống việc xin ý kiến thứ hai trước ca phẫu thuật. Bạn xem phim chụp, đánh giá rủi ro, thống nhất kế hoạch rồi mới mổ.

Khi mở pull request, pipeline nên chạy các bước cho biết "sẽ thay đổi gì":

```text
lint -> validate -> diff
```

Khi merge vào `main`, pipeline mới chạy thay đổi thật:

```text
helm upgrade --install
```

```text
Feature branch
      |
      v
Mở pull request
      |
      +--> yamllint
      +--> kubeval
      +--> helm diff
      |
      v
Reviewer duyệt
      |
      v
Merge vào main
      |
      v
Apply workflow
      |
      +--> environment approval gate
      +--> OIDC cloud credential
      +--> deploy
```

> Vì sao điều này quan trọng?
> Plan trên PR bắt lỗi trước khi thay đổi thành hành động production. Apply chỉ sau merge giúp production gắn với lịch sử đã được review.

> Hiểu lầm thường gặp:
> `helm diff` không deploy. Nó chỉ cho thấy sự khác biệt dự kiến. Người review vẫn phải hiểu diff có rủi ro gì.

### Quản lý secret: `GITHUB_TOKEN`, PAT và OIDC

Ẩn dụ:

- `GITHUB_TOKEN` là thẻ ra vào tạm thời cấp cho đúng một lần chạy GitHub Actions.
- PAT là chìa khóa cá nhân của một người hoặc tài khoản automation.
- OIDC giống việc trình thẻ nhân viên cho AWS hoặc GCP để nhận chìa khóa tạm thời.

| Cách dùng | Thời hạn | Phạm vi | Nên dùng khi | Rủi ro |
| --- | --- | --- | --- | --- |
| `GITHUB_TOKEN` | Một workflow run | Quyền trong repository | Comment PR, đọc code, upload artifact | Hạn chế ngoài GitHub |
| PAT | Đến khi hết hạn hoặc bị revoke | Scope do người tạo chọn | API cũ chưa hỗ trợ OIDC | Dễ cấp quá nhiều quyền |
| OIDC | Vài phút | Cloud role policy | Deploy AWS/GCP/Azure | Trust policy phải chặt |

Luồng OIDC với AWS:

```text
GitHub job xin OIDC token
        |
        v
AWS IAM kiểm tra repository, branch, environment claim
        |
        v
AWS STS cấp credential tạm thời
```

Luồng OIDC với GCP:

```text
GitHub job -> Workload Identity Federation -> impersonate service account -> deploy
```

> Vì sao điều này quan trọng?
> OIDC tránh lưu access key dài hạn trong GitHub secrets. Cloud provider quyết định workflow, branch và environment cụ thể có được assume role hay không.

### Reusable workflows

Ẩn dụ: Một chuỗi cửa hàng không viết lại checklist vệ sinh cho từng chi nhánh. Họ giữ một checklist chuẩn và các chi nhánh gọi lại checklist đó.

Định nghĩa kỹ thuật: Reusable workflow là workflow dùng trigger `workflow_call` để workflow khác gọi vào với input và secret.

```text
service-a ci.yml ----\
service-b ci.yml -----+--> reusable-notify.yml
service-c ci.yml ----/
```

Nên tách reusable workflow khi:

- Nhiều service dùng cùng một quy trình deploy, notify hoặc scan.
- Bạn muốn một luồng deploy đã được đội security review.
- Bạn muốn cập nhật hành vi chung ở một nơi.

> Hiểu lầm thường gặp:
> Reusable workflow không giống composite action. Composite action đóng gói step; reusable workflow đóng gói cả job, permission và environment.

### Caching trong GitHub Actions

Ẩn dụ: Xưởng làm việc để dụng cụ hay dùng ngay trên bàn thay vì mỗi lần phải vào kho lấy lại.

Định nghĩa kỹ thuật: `actions/cache` lưu thư mục dependency theo cache key, thường dựa trên `package-lock.json`, `go.sum` hoặc metadata layer Docker.

```text
Cache key:

Linux-node-${hashFiles('package-lock.json')}
          |
          v
Khôi phục cache node_modules nếu key khớp
          |
          v
Chỉ tải phần dependency còn thiếu
```

Chiến lược cache key:

- Có OS trong key vì dependency native khác nhau theo nền tảng.
- Có hash lockfile vì dependency đổi khi lockfile đổi.
- Có restore key để dùng lại cache gần đúng khi chưa có key chính xác.

> Vì sao điều này quan trọng?
> Cache tốt tiết kiệm thời gian và chi phí. Cache sai có thể che giấu lỗi dependency hoặc khôi phục file không tương thích.

## 3. ArgoCD - GitOps controller cho Kubernetes

ArgoCD theo dõi Git repository và làm cho Kubernetes cluster khớp với manifest trong Git.

Ẩn dụ: ArgoCD là người kiểm định chất lượng đi giữa cuốn sổ công thức và căn bếp, kiểm tra từng quầy đang nấu đúng món hay chưa.

### Kiến trúc ArgoCD

```text
                    Người dùng / CLI / UI
                             |
                             v
                      +-------------+
                      | API Server  |  Cửa trước cho UI, CLI, API, webhook
                      +-------------+
                             |
                 +-----------+-----------+
                 |                       |
                 v                       v
          +-------------+          +-------------+
          | Repo Server |          |    Dex      |
          | render Git  |          | SSO tùy chọn|
          +-------------+          +-------------+
                 |
                 v
            +---------+
            | Redis   | cache manifest đã render
            +---------+
                 |
                 v
     +------------------------+
     | Application Controller |
     | bộ não reconcile       |
     +------------------------+
                 |
                 v
          Kubernetes API
```

Vai trò từng thành phần:

- API Server: cửa trước cho CLI, UI, REST API và webhook.
- Repo Server: clone Git và render Helm, Kustomize, Jsonnet hoặc YAML thuần.
- Application Controller: so sánh desired state với live state và sync thay đổi.
- Redis: cache manifest đã render và trạng thái application để giảm tải.
- Dex: identity provider tùy chọn để SSO với GitHub, GitLab, Okta và hệ thống khác.

> Vì sao điều này quan trọng?
> Biết thành phần nào làm gì giúp debug nhanh. Lỗi render thường liên quan Repo Server; lỗi drift và sync thường liên quan Application Controller.

### Application CRD

Ẩn dụ: ArgoCD `Application` giống nhãn vận chuyển. Nó ghi gói hàng lấy từ đâu, giao đến đâu và có tự giao hay cần người bấm nút.

Định nghĩa kỹ thuật: `Application` là Kubernetes custom resource ánh xạ một source trong Git tới cluster và namespace đích.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    repoURL: https://github.com/vanphutin/vanphutin-aws-accelerator-p2.git
    targetRevision: main
    path: cloud/w9/day-a/workloads/api-service
  destination:
    server: https://kubernetes.default.svc
    namespace: platform
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

```text
Application
  |
  +-- source: Git repo, revision, path
  +-- destination: cluster, namespace
  +-- syncPolicy: manual hoặc automatic
```

> Hiểu lầm thường gặp:
> Một ArgoCD Application không bắt buộc tương ứng đúng một microservice. Nó có thể là Helm chart, một thư mục platform resources, hoặc chính các Application con.

### Quy trình sync

```text
1. Poll Git hoặc nhận webhook
          |
2. Render manifest
          |
3. Đọc object thật trong cluster
          |
4. So sánh desired với live
          |
5. Gán trạng thái:
     Synced / OutOfSync
     Healthy / Degraded / Progressing
          |
6. Apply nếu người dùng sync hoặc bật automated sync
```

> Vì sao điều này quan trọng?
> Sync status và health status trả lời hai câu hỏi khác nhau. Sync hỏi "YAML live có khớp Git không?". Health hỏi "workload có chạy tốt không?".

### App-of-Apps pattern

Vấn đề: quản lý 50 ứng dụng bằng cách click UI 50 lần không thể mở rộng.

Ẩn dụ: Một playlist tổng chứa nhiều playlist con. Bạn bật playlist tổng, nó tổ chức phần còn lại.

```text
root-app
  |
  +-- postgres child app       wave 1
  +-- api-service child app    wave 2
  +-- frontend child app       wave 3
  +-- monitoring child app     wave 4
```

Root Application trỏ đến thư mục chứa manifest của các child Application. ArgoCD tạo các child app, rồi mỗi child app quản lý workload riêng.

> Vì sao điều này quan trọng?
> App-of-Apps giúp đội platform bootstrap cluster nhất quán. Ở Ngày C, cùng mô hình này có thể quản lý Argo Rollouts `Rollout` thay cho `Deployment` thường.

### Sync Waves

Ẩn dụ: Xây nhà phải làm móng trước, dựng tường sau, rồi mới làm mái.

Định nghĩa kỹ thuật: Sync wave sắp thứ tự resource bằng annotation `argocd.argoproj.io/sync-wave`. Số nhỏ hơn chạy trước.

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

```text
Dòng thời gian sync

wave 0: Namespace, RBAC
   |
wave 1: postgres
   |
wave 2: api-service
   |
wave 3: ingress
```

> Vì sao điều này quan trọng?
> Phụ thuộc giữa resource là thật. API cần database không nên khởi động trước khi database được apply và khỏe.

### Sync Hooks

Ẩn dụ: Một buổi diễn có việc làm trước giờ diễn, trong lúc diễn, sau khi diễn thành công, và cả kế hoạch khi buổi diễn thất bại.

| Hook | Chạy khi nào | Ví dụ |
| --- | --- | --- |
| `PreSync` | Trước resource bình thường | Job kiểm tra migration database |
| `Sync` | Trong quá trình sync | Job tùy chỉnh chạy cùng app |
| `PostSync` | Sau khi sync thành công | Job smoke test |
| `SyncFail` | Sau khi sync thất bại | Gửi thông báo incident |

```text
PreSync -> Sync waves -> PostSync
              |
              v
           SyncFail nếu lỗi
```

> Hiểu lầm thường gặp:
> Hook không thay thế readiness probe. Hook xử lý workflow deploy; probe cho Kubernetes biết pod đã sẵn sàng và còn sống hay không.

### Health checks

Ẩn dụ: Hệ thống giao hàng có thể báo "đã giao", nhưng bạn vẫn cần kiểm tra món hàng bên trong có nguyên vẹn không.

Định nghĩa kỹ thuật: ArgoCD health check kiểm tra Kubernetes resources và quyết định chúng là `Healthy`, `Progressing`, `Degraded`, `Suspended` hoặc `Missing`.

ArgoCD có health check built-in cho các resource phổ biến như Deployment, Service, Job và Ingress. Với custom resource, bạn có thể dùng Lua health script.

```lua
hs = {}
if obj.status ~= nil and obj.status.ready == true then
  hs.status = "Healthy"
  hs.message = "resource is ready"
else
  hs.status = "Progressing"
  hs.message = "waiting for ready status"
end
return hs
```

```text
Git sync status:     Synced
Runtime health:      Degraded

Ý nghĩa:
YAML đã khớp Git, nhưng ứng dụng chưa khỏe.
```

> Vì sao điều này quan trọng?
> GitOps không nên dừng ở việc apply YAML. An toàn production phụ thuộc vào việc biết resource đã thật sự khỏe hay chưa.

### RBAC trong ArgoCD

Ẩn dụ: Tòa nhà văn phòng dùng thẻ ra vào. Đội finance vào phòng finance, đội engineering vào lab, khách chỉ vào sảnh.

Định nghĩa kỹ thuật: ArgoCD RBAC kiểm soát ai được xem, sync, sửa hoặc xóa application. `AppProject` thêm guardrail cho source repository, cluster đích, namespace đích và loại resource được phép quản lý.

```text
AppProject: platform
  |
  +-- source repo được phép:
  |     https://github.com/vanphutin/vanphutin-aws-accelerator-p2.git
  |
  +-- destination được phép:
  |     server: https://kubernetes.default.svc
  |     namespace: platform
  |
  +-- roles:
        read-only
        deployer
        admin
```

> Vì sao điều này quan trọng?
> Cluster nhiều đội cần ranh giới rõ. Project ngăn một đội vô tình deploy vào namespace của đội khác hoặc từ repository không tin cậy.

## 4. Flux - GitOps controller thay thế

Flux cũng là GitOps controller trong hệ sinh thái CNCF. ArgoCD thường được chọn khi đội cần UI mạnh và mô hình Application rõ ràng. Flux thường được chọn khi đội muốn bộ controller Kubernetes-native và workflow dựa hoàn toàn trên CRD.

Ẩn dụ: ArgoCD giống tháp điều khiển có dashboard lớn. Flux giống một nhóm thợ chuyên môn hóa, mỗi người phụ trách một đoạn của dây chuyền.

```text
Kiến trúc Flux

GitRepository / HelmRepository / OCIRepository
        |
        v
 source-controller  ---> tạo artifact
        |
        +------------------+
        |                  |
        v                  v
kustomize-controller   helm-controller
        |                  |
        v                  v
 Kubernetes objects     Helm releases
        |
        v
notification-controller -> Slack, Teams, webhook
```

Các CRD chính:

- `GitRepository`: chỉ cho Flux biết Git repo và revision cần theo dõi.
- `HelmRepository`: chỉ đến Helm chart repository.
- `OCIRepository`: chỉ đến OCI artifact như chart hoặc manifest bundle.
- `Kustomization`: nói Flux render và apply path nào.
- `HelmRelease`: nói Flux cài hoặc upgrade chart nào.

| Tính năng | ArgoCD | Flux |
| --- | --- | --- |
| UI | UI built-in là tính năng lớn | UI là tùy chọn qua add-on |
| Mô hình CRD | `Application` và `AppProject` là trung tâm | Nhiều toolkit CRD chia trách nhiệm |
| Multi-tenancy | AppProject và RBAC | Kubernetes RBAC và controller impersonation |
| Reconcile | Pull và so sánh trạng thái app | Pull và reconcile source/kustomize/helm object |
| Helm | Render Helm trong ArgoCD | `HelmRelease` controller quản lý release |
| Cộng đồng | Rất lớn trong platform team | Rất lớn trong GitOps/toolkit team |
| Độ khó học | Dễ nhập môn nhờ UI | Kubernetes-native hơn nhưng nhiều CRD hơn |
| Khi nên chọn | Cần UI, app inventory, sync thủ công rõ | Cần CRD composition và controller toolkit |

> Vì sao điều này quan trọng?
> Cả hai đều hợp lệ. Lựa chọn đúng phụ thuộc cách đội bạn muốn mô hình hóa ownership, visibility và automation.

## 5. Chiến lược rollback khi có sự cố

Ẩn dụ: Khi đoàn tàu đi nhầm đường, bạn có thể sửa lịch trình, bẻ ghi bằng tay, hoặc yêu cầu hệ thống điều khiển quay về tuyến đã được phê duyệt trước đó. Mỗi cách có tốc độ và rủi ro khác nhau.

### Cách 1: `git revert`

`git revert` tạo một commit mới đảo ngược commit cũ.

Nên dùng khi:

- Thay đổi xấu đến từ Git.
- Bạn muốn lịch sử ghi rõ lỗi và cách sửa.
- Bạn muốn ArgoCD hoặc Flux tự phục hồi qua luồng reconcile bình thường.

```text
Dòng thời gian

commit A: api v1.0.0 khỏe
commit B: api v2.0.0 lỗi
commit C: revert commit B

ArgoCD thấy commit C -> sync lại trạng thái v1.0.0 -> app phục hồi
```

Luồng cơ bản:

```bash
git revert f7a8b9c
git push origin main
argocd app sync api-service
```

> Vì sao điều này quan trọng?
> `git revert` giữ Git là nguồn sự thật. Đây thường là rollback sạch nhất trong GitOps.

### Cách 2: `kubectl rollout undo`

`kubectl rollout undo` yêu cầu Kubernetes chuyển Deployment về ReplicaSet revision trước.

Nên dùng khi:

- Sự cố đang rất khẩn cấp.
- Git hoặc ArgoCD tạm thời không dùng được.
- Bạn hiểu thao tác này đi vòng qua GitOps.

```text
Git ghi:       image v2.0.0
Cluster chạy:  image v1.0.0 sau rollout undo

Kết quả: drift
```

> Hiểu lầm thường gặp:
> `kubectl rollout undo` không sai trong tình huống khẩn cấp, nhưng nó tạo drift nếu Git vẫn chứa trạng thái xấu. GitOps controller có thể apply lại phiên bản lỗi sau đó.

### Cách 3: ArgoCD rollback qua UI hoặc CLI

ArgoCD có thể deploy lại một revision từng được sync trước đó.

Nên dùng khi:

- Bạn cần rollback nhanh nhưng vẫn muốn đi qua GitOps controller.
- Bạn muốn lịch sử và health check của ArgoCD tham gia.
- Bạn sẽ follow-up bằng Git change nếu cần.

```text
argocd app history api-service
        |
        v
argocd app rollback api-service 3
        |
        v
ArgoCD apply revision cũ
```

> Vì sao điều này quan trọng?
> ArgoCD rollback nhanh về mặt vận hành, nhưng đội vẫn cần đảm bảo Git phản ánh trạng thái mong muốn cuối cùng.

### Bảng so sánh rollback

| Chiến lược | Tốc độ | An toàn | Lịch sử Git | Rủi ro drift | Nên dùng cho |
| --- | --- | --- | --- | --- | --- |
| `git revert` | Trung bình | Cao | Có commit sửa rõ ràng | Thấp | Khôi phục GitOps bình thường |
| `kubectl rollout undo` | Nhanh | Trung bình | Không có nếu chưa commit sau đó | Cao | Break-glass khẩn cấp |
| ArgoCD rollback | Nhanh | Cao nếu follow-up Git | Có trong ArgoCD history, chưa chắc có commit sửa | Trung bình | Khôi phục nhanh có kiểm soát |

```text
Đường quyết định đề xuất

Production đang sập nghiêm trọng?
        |
   +----+----+
   |         |
  có       không
   |         |
break-glass git revert
rồi commit
sửa Git
```

> Vì sao điều này quan trọng?
> Một rollback chưa hoàn tất cho đến khi nguồn sự thật và cluster đang chạy đồng ý với nhau.
