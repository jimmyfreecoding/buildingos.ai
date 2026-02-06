# BuildingOS AI - K8s 演示环境部署指南 (2节点高可用版)

本项目提供了一套适用于 **2 节点 (8核 16G)** 资源的 Kubernetes 演示方案，重点展示 **负载均衡** 和 **主备切换** 能力。

## 1. 架构与资源规划

| 组件 | 副本数 | 高可用策略 | 资源 (CPU/Mem) | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| **Frontend** | 2 | **负载均衡** (PodAntiAffinity) | 50m / 64Mi | 强制分布在不同节点，任一节点挂掉服务不中断 |
| **Backend** | 1 | **主备切换** (K8s Reschedule) | 100m / 128Mi | 节点挂掉后，K8s 自动在另一节点拉起新实例 |
| **Postgres** | 1 | **数据漂移** (Local Path) | 100m / 128Mi | 配合 K3s Local Path，数据绑定在特定节点 |
| **EMQX** | 1 | 主备切换 | 100m / 128Mi | - |
| **Node-RED** | 1 | 主备切换 (Recreate) | 50m / 128Mi | 防止多实例逻辑冲突 |

## 2. 集群扩容 (Adding Nodes)

要实现高可用演示，你需要至少 **2 台** 机器（内网互通）。

### 第一步：在主节点 (Master) 获取 Token
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
# 输出示例: K10abc123...::server:xyz789
```

### 第二步：在新节点 (Worker) 加入集群
在第二台机器上执行（替换 `<MASTER_IP>` 和 `<TOKEN>`）：
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<TOKEN> sh -
```

### 第三步：验证节点
在 Master 执行 `kubectl get nodes`，应看到两个节点均为 `Ready`。

## 3. 部署与配置

### 前置条件
1.  **创建命名空间**: `kubectl create ns buildingos-demo`
2.  **创建镜像密钥**: (参考下方“配置镜像拉取权限”)

### 部署指令
```bash
# 1. 基础设施 (DB, Redis, MQTT)
kubectl apply -f infra.yaml

# 2. 业务组件 (前端负载均衡 + 后端主备)
kubectl apply -f apps.yaml

# 3. 辅助组件
kubectl apply -f addons.yaml
kubectl apply -f zlm.yaml

# 4. 路由网关
kubectl apply -f ingress.yaml
```

## 4. 高可用演示剧本

### 场景 A：前端无缝故障转移 (负载均衡)
1.  **操作**: 拔掉 Node 1 网线（或 `systemctl stop k3s`）。
2.  **现象**: 访问前端页面，完全无感知，流量自动切换到 Node 2 上的前端 Pod。
3.  **原理**: `replicas: 2` + `podAntiAffinity` 确保了双机双活。

### 场景 B：后端自动愈合 (主备切换)
1.  **操作**: 关掉后端 Pod 所在的节点。
2.  **现象**: 服务暂时中断约 1 分钟（取决于 K8s 判定节点失联的时间），随后在另一节点自动启动新 Pod，服务恢复。
3.  **原理**: K8s 控制器检测到 Pod 状态 Unknown，自动触发重新调度。

## 5. 配置镜像拉取权限 (Critical)

```bash
kubectl create secret docker-registry swr-registry-key \
  --docker-server=swr.cn-east-3.myhuaweicloud.com \
  --docker-username=<你的用户名> \
  --docker-password=<你的密码> \
  --namespace=buildingos-demo
```

## 6. 访问路径
- **前端**: `http://<服务器IP>/`
- **后端 API**: `http://<服务器IP>/v1` (Ingress 自动剥离前缀)
- **管理后台**: `http://<服务器IP>/os/`
