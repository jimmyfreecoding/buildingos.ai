# BuildingOS AI - K8s 演示环境部署指南

本项目提供了一套适用于低配演示服务器（建议 2核 CPU, 4GB 内存）的 Kubernetes 部署方案。

## 1. 前置要求

- **操作系统**: Ubuntu 24.04 (推荐)
- **K8s 环境**: 推荐安装 [K3s](https://k3s.io/) (轻量化 Kubernetes)
- **工具**: 已安装 `kubectl` 并配置好权限

## 2. 配置镜像拉取权限 (Critical)

由于演示环境使用的镜像是私有的（华为云 SWR），必须先创建 `imagePullSecret`。

### 方式 A：使用账号密码创建 (推荐)
替换以下命令中的 `<用户名>` 和 `<密码>` 为你的华为云 SWR 凭据：

```bash
kubectl create namespace buildingos-demo

kubectl create secret docker-registry swr-registry-key \
  --docker-server=swr.cn-east-3.myhuaweicloud.com \
  --docker-username=cn-east-3@HPUA47E21TXTL1E4MHAJ \
  --docker-password=615e168df23e9bf7f95b5414b6e0c88b0cfaa9438f53fda6f64a691d4982a5ab \
  --namespace=buildingos-demo



```

### 方式 B：复用本地 Docker 登录状态
如果你已经在服务器上执行过 `docker login`，可以直接复用配置：

```bash
kubectl create namespace buildingos-demo

kubectl create secret generic swr-registry-key \
  --from-file=.dockerconfigjson=$HOME/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson \
  --namespace=buildingos-demo
```

## 3. 部署步骤

请严格按照以下顺序执行部署，以确保依赖关系正确：

```bash
# 1. 部署基础基础设施 (Postgres, Redis, EMQX)
kubectl apply -f infra.yaml

# 2. 部署时序数据库与 Node-RED
kubectl apply -f addons.yaml

# 3. 部署流媒体服务器
kubectl apply -f zlm.yaml

# 4. 部署业务应用
kubectl apply -f apps.yaml

# 5. 部署入口网关
kubectl apply -f ingress.yaml
```

## 4. 验证与访问

### 检查运行状态
```bash
# 观察所有 Pod 是否变为 Running 状态
kubectl get pods -n buildingos-demo -w
```

### 访问路径
部署完成后，可以通过服务器 IP 访问以下服务：

- **系统前端**: `http://<服务器IP>/`
- **管理后台 API**: `http://<服务器IP>/api`
- **EMQX 控制台**: `http://<服务器IP>/emqx` (admin / emqx_prod_2024)
- **Node-RED 编辑器**: `http://<服务器IP>:1880`

## 5. 常用运维命令

- **查看服务日志**: `kubectl logs -f <pod-name> -n buildingos-demo`
- **重启后端应用**: `kubectl rollout restart deployment backend -n buildingos-demo`
- **一键清理环境**: `kubectl delete ns buildingos-demo`

## 6. 演示建议
演示时，可以手动删除一个 Pod (如 `backend`)，展示 K8s 的自愈能力（Pod 会被立刻重新拉起）。
