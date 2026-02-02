# BuildingOS AI 生产环境 K8s 部署指南 (5节点集群)

本项目提供了一套适用于大规模写字楼（如望朝中心）生产负荷的 Kubernetes 部署方案。该方案基于 5 节点集群规划（3 Master + 2 Worker 可扩展），支持 10 万个 IoT 节点及百万级数据并发写入。

## 1. 资源规划概览

根据望朝中心（12.5万㎡）业务估算，集群规格如下：

| 组件 | 副本数 | CPU (Req/Limit) | Memory (Req/Limit) | 高可用策略 |
| :--- | :--- | :--- | :--- | :--- |
| **PostgreSQL** | 2 | 2c / 4c | 4Gi / 8Gi | Master-Slave + StatefulSet |
| **TDengine** | 3 | 4c / 8c | 8Gi / 16Gi | Cluster Mode + StatefulSet |
| **EMQX** | 3-5 | 2c / 4c | 4Gi / 8Gi | K8s DNS Cluster |
| **Backend** | 4-6 | 1c / 2c | 1Gi / 2Gi | HPA + PodAntiAffinity |
| **Frontend** | 3-5 | 200m / 1c | 256Mi / 512Mi | PodAntiAffinity + Ingress |
| **ZLMediaKit** | 3 | 4c / 8c | 4Gi / 8Gi | Cluster Mode |

## 2. 部署前置条件

### 2.1 存储类准备
生产环境必须配置分布式存储（如 Ceph, Longhorn 或云盘），并确保集群中有默认的 `StorageClass`。

### 2.2 创建命名空间与密钥
```bash
kubectl create namespace buildingos-prod

# 创建私有仓库拉取密钥
kubectl create secret docker-registry swr-registry-key \
  --docker-server=swr.cn-east-3.myhuaweicloud.com \
  --docker-username=cn-east-3@HPUA47E21TXTL1E4MHAJ \
  --docker-password=615e168df23e9bf7f95b5414b6e0c88b0cfaa9438f53fda6f64a691d4982a5ab \
  --namespace=buildingos-prod
```

## 3. 部署步骤

请严格按顺序执行：

### 第一步：基础设施 (DB, Cache, MQTT)
```bash
kubectl apply -f infra.yaml
```
*验证*: 确保 `postgres-0`, `redis-0`, `emqx-*` 进入 Running 状态。

### 第二步：时序数据库与流程引擎
```bash
kubectl apply -f addons.yaml
```
*说明*: TDengine 采用 Headless Service 进行集群内部通信。Node-RED 保持 1 副本以保证逻辑一致性。

### 第三步：业务应用与网关
```bash
kubectl apply -f apps.yaml
```
*说明*: 后端与前端均配置了“反亲和性” (Anti-Affinity)，确保 Pod 均匀分布在不同的物理节点上。

## 4. 高可用详解

### 4.1 数据库高可用 (PostgreSQL)
采用 `StatefulSet` 部署。生产建议引入 **CloudNativePG** 或 **Patroni** 算子以实现自动故障切换。当前 YAML 预留了 2 副本结构。

### 4.2 消息中间件高可用 (EMQX)
通过 `EMQX_CLUSTER__DISCOVERY_STRATEGY=k8s` 自动发现节点。Service `buildingos-emqx` 负责在所有运行中的 EMQX 节点间进行负载均衡。

### 4.3 业务自愈与扩展
- **PodAntiAffinity**: 防止单台服务器宕机导致整个服务不可用。
- **HPA (建议)**: 生产环境应根据 CPU/内存指标配置 HPA (Horizontal Pod Autoscaler)，实现业务自动扩缩容。

## 5. 常用上线指令

- **滚动更新后端**: `kubectl rollout restart deployment backend -n buildingos-prod`
- **查看集群资源占用**: `kubectl top nodes`
- **查看特定组件日志**: `kubectl logs -f deployment/backend -n buildingos-prod`
- **查看集群事件**: `kubectl get events -n buildingos-prod --sort-by='.lastTimestamp'`
