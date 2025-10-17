# 部署 Nginx 並理解 Kubernetes 架構

用 kubectl 連到 docker-desktop

```bash
kubectl config use-context docker-desktop
kubectl get nodes
```

## 建立 Nginx Deployment（3 個 replicas 並且確認 Deployment 狀態

### 新增 [nginx-deploy.yaml](./nginx-deploy.yaml)

### 建立/更新 => 等待佈署完成 => 確認結果

#### 建立 Nginx Deployment

```bash
kubectl apply -f nginx-deploy.yaml
```

```
=> deployment.apps/nginx-deploy created
```

#### 等待 deployment 完成

```bash
kubectl rollout status deploy/nginx-deploy
```

```
=> Waiting for deployment "nginx-deploy" rollout to finish: 0 of 3 updated replicas are available...
Waiting for deployment "nginx-deploy" rollout to finish: 1 of 3 updated replicas are available...
Waiting for deployment "nginx-deploy" rollout to finish: 2 of 3 updated replicas are available...
deployment "nginx-deploy" successfully rolled out
```

#### 確認 Nginx Deployment

```bash
kubectl get pods -l app=nginx-lab -o wide
```

```
NAME                            READY   STATUS    RESTARTS   AGE   IP         NODE             NOMINATED NODE   READINESS GATES
nginx-deploy-5d5fd77c89-4p695   1/1     Running   0          24s   10.1.0.8   docker-desktop   <none>           <none>
nginx-deploy-5d5fd77c89-hkb52   1/1     Running   0          24s   10.1.0.7   docker-desktop   <none>           <none>
nginx-deploy-5d5fd77c89-nff7d   1/1     Running   0          24s   10.1.0.6   docker-desktop   <none>           <none>
```

這邊確認 Pods 狀態為 `Running`

## 建立 NodePort Service 和 Service 可以正常導流量至 Pod

### 新增 [nginx-svc.yaml](./nginx-svc.yaml)

### Service 從宣告到驗證的三步驟：建立 => 查設定 => 查端點

#### 建立/更新 Service（把 YAML 的 NodePort/selector 等宣告套進叢集）

```bash
kubectl apply -f nginx-svc.yaml
```

```
=> service/nginx-svc created
```

#### 查看 Service 配置（確認 TYPE=NodePort、PORTS、NODE-PORT=30080 等對外資訊）。

```bash
kubectl get svc nginx-svc
```

```
=> NAME        TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
nginx-svc   NodePort   10.96.252.29   <none>        80:30080/TCP   22s
```

#### 查看實際後端目標（應列出 3 個 PodIP:80；若為空表示 selector 沒綁到任何 Pod）

```bash
kubectl get endpoints nginx-svc
```

```
NAME        ENDPOINTS                             AGE
nginx-svc   10.1.0.6:80,10.1.0.7:80,10.1.0.8:80   55s
```

#### 測試是否有導流(外部與叢內各驗一次)

(Docker Desktop 本機）外部驗證

```bash
# 看到 HTTP/1.1 200 OK 即通過
curl -I http://127.0.0.1:30080
```

結果

```
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Wed, 15 Oct 2025 05:55:21 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Wed, 16 Apr 2025 12:55:34 GMT
Connection: keep-alive
ETag: "67ffa8c6-267"
Accept-Ranges: bytes
```

叢內驗證（確保 Service 內部導流 OK）

```bash
# 臨時跑一個測試 Pod，從叢內打 Service
kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- \
  wget -qO- http://nginx-svc
# 有回傳 Nginx 預設頁 HTML 就通過（離開後 Pod 會自動刪除）
```

結果

```
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
pod "tmp" deleted from default namespace
```

## 觀察並理解以下 Kubernetes 概念

-   Pod 與 ReplicaSet 的關係
-   Deployment 的自動擴縮和 Pod 修復機制
-   Service 如何透過 selector 導流量到 Pod

### Pod 與 ReplicaSet 的關係

當 Deployment 需要資源時，會透過 ReplicaSet 來管理 Pod，三者的關係如下:

-   Deployment 管理 ReplicaSet
-   ReplicaSet 管理 Pod
-   Pod 是實際運行應用程式的單位

以下操作可以觀察 Deployment、ReplicaSet、Pod 三者的關係、以及它們之間的擁有者（ownerReferences）。

#### 看 Deployment、ReplicaSet、Pod 關係

可以用這個指令同時看到 Deployment、ReplicaSet、Pod

```bash
kubectl get deploy,rs,pod -l app=nginx-lab
```

```
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deploy   3/3     3            3           67m

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deploy-5d5fd77c89   3         3         3       67m

NAME                                READY   STATUS    RESTARTS   AGE
pod/nginx-deploy-5d5fd77c89-4p695   1/1     Running   0          67m
pod/nginx-deploy-5d5fd77c89-hkb52   1/1     Running   0          67m
pod/nginx-deploy-5d5fd77c89-nff7d   1/1     Running   0          67m
```

-   deployment.apps/nginx-deploy 是 Deployment
-   replicaset.apps/nginx-deploy-5d5fd77c89 是 ReplicaSet
-   pod/nginx-deploy-5d5fd77c89-4p695 等是 Pod

#### 看 ReplicaSet 的詳細資訊

```bash
kubectl describe rs -l app=nginx-lab | grep -E "Name:|Controlled By|Replicas|Selector|Labels" -n
```

```
1:Name:           nginx-deploy-5d5fd77c89
3:Selector:       app=nginx-lab,pod-template-hash=5d5fd77c89
4:Labels:         app=nginx-lab
9:Controlled By:  Deployment/nginx-deploy
10:Replicas:       3 current / 3 desired
13:  Labels:  app=nginx-lab
25:  Node-Selectors:  <none>
```

看到 Controlled By: Deployment/nginx-deploy 表示這個 ReplicaSet 是被 Deployment 所控制

#### 看某個 Pod 的擁有者（ownerReferences）

```bash
POD=$(kubectl get po -l app=nginx-lab -o jsonpath='{.items[0].metadata.name}')
kubectl get pod $POD -o jsonpath='{.metadata.ownerReferences}'
echo
```

會看到 pod 的 ownerReferences 指向 ReplicaSet

```
[{"apiVersion":"apps/v1","blockOwnerDeletion":true,"controller":true,"kind":"ReplicaSet","name":"nginx-deploy-5d5fd77c89","uid":"fcecb0ff-f6d8-404d-aa0a-e133f1b0b437"}]
```

透過 kind 和 name 可以知道這個 Pod 是被哪個 ReplicaSet 所擁有

#### 透過 ReplicaSet 的 ownerReferences 可以知道它是被哪個 Deployment 所擁有

```bash
kubectl get rs -l app=nginx-lab -o jsonpath='{.items[0].metadata.ownerReferences}'
echo
```

看 name 和 kind 能看到 rs 的 ownerReferences 指向 Deployment

```
[{"apiVersion":"apps/v1","blockOwnerDeletion":true,"controller":true,"kind":"Deployment","name":"nginx-deploy","uid":"006d04ae-51cb-4ae0-9c4b-0452289ce44c"}]
```

### Deployment 的自動擴縮和 Pod 修復機制

#### Deployment 擴縮（手動擴縮）

看目前副本數

```bash
kubectl get deploy/nginx-deploy
```

```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deploy   3/3     3            3           3h1m
```

擴到 5 個

```bash
kubectl scale deploy/nginx-deploy --replicas=5
```

```
deployment.apps/nginx-deploy scaled
```

觀察至收斂（看到 5 個 Pod 都 READY）

```bash
kubectl get deploy,rs,pod -l app=nginx-lab
```

```
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deploy   5/5     5            5           3h2m

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deploy-5d5fd77c89   5         5         5       3h2m

NAME                                READY   STATUS    RESTARTS   AGE
pod/nginx-deploy-5d5fd77c89-4p695   1/1     Running   0          3h2m
pod/nginx-deploy-5d5fd77c89-559jg   1/1     Running   0          45s
pod/nginx-deploy-5d5fd77c89-hkb52   1/1     Running   0          3h2m
pod/nginx-deploy-5d5fd77c89-ht7sq   1/1     Running   0          45s
pod/nginx-deploy-5d5fd77c89-nff7d   1/1     Running   0          3h2m
```

縮回 3 個

```bash
kubectl scale deploy/nginx-deploy --replicas=3
```

```
deployment.apps/nginx-deploy scaled
```

看是否收斂

```bash
kubectl get deploy,rs,pod -l app=nginx-lab
```

```
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deploy   3/3     3            3           3h3m

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deploy-5d5fd77c89   3         3         3       3h3m

NAME                                READY   STATUS    RESTARTS   AGE
pod/nginx-deploy-5d5fd77c89-4p695   1/1     Running   0          3h3m
pod/nginx-deploy-5d5fd77c89-hkb52   1/1     Running   0          3h3m
pod/nginx-deploy-5d5fd77c89-nff7d   1/1     Running   0          3h3m
```

#### Pod 修復機制

刪除一個 Pod

```bash
kubectl get pod -l app=nginx-lab -o name | head -n1 | xargs kubectl delete
```

```
pod "nginx-deploy-5d5fd77c89-4p695" deleted from default namespace
```

看有沒有自動補回來

```bash
kubectl get pods -l app=nginx-lab -w
```

```
nginx-deploy-5d5fd77c89-dcwwx   1/1     Running   0          69s
nginx-deploy-5d5fd77c89-hkb52   1/1     Running   0          3h16m
nginx-deploy-5d5fd77c89-nff7d   1/1     Running   0          3h16m
```

### Service 如何透過 selector 導流量到 Pod

#### 套用並確認基本狀態

`kubectl apply -f nginx-deploy.yaml`
`kubectl apply -f nginx-svc.yaml`

看 Pod
`kubectl get pods -l app=nginx-lab -o wide --show-labels`

看 Service
`kubectl get svc nginx-svc`

#### 觀察「selector → Endpoints」對應

```bash
kubectl get endpointslice -l kubernetes.io/service-name=nginx-svc -o wide
```

會出現

```
NAME              ADDRESSTYPE   PORTS   ENDPOINTS                     AGE
nginx-svc-tk6ld   IPv4          80      10.1.0.7,10.1.0.6,10.1.0.13   24h
```

#### 測試 Service 導流

```bash
curl -i http://localhost:30080/
```

會看到 Nginx 預設頁面

```html
HTTP/1.1 200 OK Server: nginx/1.27.5 Date: Thu, 16 Oct 2025 06:42:01 GMT Content-Type: text/html Content-Length: 615
Last-Modified: Wed, 16 Apr 2025 12:55:34 GMT Connection: keep-alive ETag: "67ffa8c6-267" Accept-Ranges: bytes

<!DOCTYPE html>
<html>
    <head>
        <title>Welcome to nginx!</title>
        <style>
            html {
                color-scheme: light dark;
            }
            body {
                width: 35em;
                margin: 0 auto;
                font-family: Tahoma, Verdana, Arial, sans-serif;
            }
        </style>
    </head>
    <body>
        <h1>Welcome to nginx!</h1>
        <p>
            If you see this page, the nginx web server is successfully installed and working. Further configuration is
            required.
        </p>

        <p>
            For online documentation and support please refer to <a href="http://nginx.org/">nginx.org</a>.<br />
            Commercial support is available at
            <a href="http://nginx.com/">nginx.com</a>.
        </p>

        <p><em>Thank you for using nginx.</em></p>
    </body>
</html>
```
