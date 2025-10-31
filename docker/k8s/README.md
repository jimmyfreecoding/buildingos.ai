# BuildingOS Kubernetes 部署指南

本目录包含了在 Kubernetes 集群中部署 BuildingOS 系统的所有配置文件和脚本。

## 📁 文件结构

```
k8s/
├── namespace.yaml          # 命名空间和配置
├── storage.yaml           # 存储类和持久卷配置
├── database.yaml          # 数据库服务配置
├── application.yaml       # 应用服务配置
├── ingress.yaml          # Ingress 和 LoadBalancer 配置
├── deploy-k8s.ps1        # 自动部署脚本
└── README.md             # 本文档
```

## 🚀 快速部署

### 1. 前置条件

- Kubernetes 集群（版本 1.20+）
- kubectl 已配置并可访问集群
- 华为云 SWR 镜像已推送（使用 `../push-to-swr.ps1`）

### 2. 一键部署

```powershell
# 创建命名空间并部署所有服务
./deploy-k8s.ps1 -CreateNamespace

# 指定镜像版本
./deploy-k8s.ps1 -CreateNamespace -ImageVersion "v1.0.0"

# 更新现有部署
./deploy-k8s.ps1 -UpdateImages -ImageVersion "v1.1.0"

# 重新部署（先删除再创建）
./deploy-k8s.ps1 -DeleteFirst -CreateNamespace
```

### 3. 手动部署

```bash
# 1. 创建命名空间和配置
kubectl apply -f namespace.yaml

# 2. 创建存储资源
kubectl apply -f storage.yaml

# 3. 部署数据库服务
kubectl apply -f database.yaml

# 4. 等待数据库就绪
kubectl wait --for=condition=ready pod -l app=postgres -n buildingos --timeout=300s

# 5. 部署应用服务
kubectl apply -f application.yaml

# 6. 部署 Ingress（可选）
kubectl apply -f ingress.yaml
```

## 🔧 配置说明

### 存储配置

- **PostgreSQL**: 10Gi 持久存储
- **Redis**: 2Gi 持久存储  
- **TDengine**: 20Gi 持久存储
- **Grafana**: 5Gi 持久存储
- **Backend Data**: 5Gi 持久存储

### 资源配置

| 服务 | CPU 请求 | CPU 限制 | 内存请求 | 内存限制 | 副本数 |
|------|----------|----------|----------|----------|--------|
| Frontend | 100m | 500m | 128Mi | 256Mi | 2 |
| Backend | 500m | 1000m | 512Mi | 1Gi | 2 |
| PostgreSQL | 250m | 1000m | 256Mi | 1Gi | 1 |
| Redis | 100m | 500m | 128Mi | 512Mi | 1 |
| TDengine | 500m | 2000m | 512Mi | 2Gi | 1 |
| Grafana | 250m | 500m | 256Mi | 512Mi | 1 |

### 网络配置

#### ClusterIP 服务（集群内访问）
- `buildingos-web`: 80
- `buildingos-backend`: 3001
- `postgres`: 5432
- `redis`: 6379
- `tdengine`: 6030, 6041
- `grafana`: 3000

#### LoadBalancer 服务（外部访问）
- `buildingos-web-lb`: 80
- `buildingos-backend-lb`: 3001
- `grafana-lb`: 3000

## 🌐 访问方式

### 1. LoadBalancer（推荐用于云环境）

部署后自动获取外部 IP：

```bash
kubectl get services -n buildingos
```

### 2. Ingress（需要 Ingress Controller）

配置域名解析后访问：
- 主应用: `http://buildingos.local`
- API: `http://buildingos.local/api`
- Grafana: `http://grafana.buildingos.local`

### 3. Port Forward（本地开发）

```bash
# 前端应用
kubectl port-forward -n buildingos service/buildingos-web 8080:80

# 后端 API
kubectl port-forward -n buildingos service/buildingos-backend 3001:3001

# Grafana
kubectl port-forward -n buildingos service/grafana 3000:3000
```

## 🔍 监控和管理

### 查看服务状态

```bash
# 查看所有资源
kubectl get all -n buildingos

# 查看 Pod 状态
kubectl get pods -n buildingos -o wide

# 查看服务状态
kubectl get services -n buildingos

# 查看存储状态
kubectl get pv,pvc -n buildingos
```

### 查看日志

```bash
# 查看后端日志
kubectl logs -f deployment/buildingos-backend -n buildingos

# 查看前端日志
kubectl logs -f deployment/buildingos-web -n buildingos

# 查看数据库日志
kubectl logs -f deployment/postgres -n buildingos
```

### 扩容和更新

```bash
# 扩容后端服务
kubectl scale deployment buildingos-backend --replicas=3 -n buildingos

# 更新镜像
kubectl set image deployment/buildingos-backend \
  backend=swr.cn-north-4.myhuaweicloud.com/buildingos/buildingos-backend:v1.1.0 \
  -n buildingos

# 查看更新状态
kubectl rollout status deployment/buildingos-backend -n buildingos

# 回滚更新
kubectl rollout undo deployment/buildingos-backend -n buildingos
```

## 🛠️ 故障排查

### 常见问题

1. **Pod 无法启动**
   ```bash
   kubectl describe pod [pod-name] -n buildingos
   kubectl logs [pod-name] -n buildingos
   ```

2. **存储问题**
   ```bash
   kubectl get pv,pvc -n buildingos
   kubectl describe pvc [pvc-name] -n buildingos
   ```

3. **网络问题**
   ```bash
   kubectl get services -n buildingos
   kubectl get endpoints -n buildingos
   ```

4. **镜像拉取失败**
   ```bash
   # 检查镜像是否存在
   docker pull swr.cn-north-4.myhuaweicloud.com/buildingos/buildingos-backend:latest
   
   # 检查集群是否能访问 SWR
   kubectl run test --image=swr.cn-north-4.myhuaweicloud.com/buildingos/buildingos-backend:latest --rm -it -- /bin/sh
   ```

### 清理部署

```bash
# 删除所有资源
kubectl delete namespace buildingos

# 或者逐个删除
kubectl delete -f ingress.yaml
kubectl delete -f application.yaml
kubectl delete -f database.yaml
kubectl delete -f storage.yaml
kubectl delete -f namespace.yaml
```

## 📋 部署检查清单

- [ ] Kubernetes 集群可访问
- [ ] kubectl 已配置
- [ ] 华为云 SWR 镜像已推送
- [ ] 存储类已配置（如使用动态存储）
- [ ] Ingress Controller 已安装（如使用 Ingress）
- [ ] 域名解析已配置（如使用 Ingress）
- [ ] 防火墙规则已配置
- [ ] 监控和日志收集已配置

## 🔐 安全建议

1. **更新默认密码**: 修改 `namespace.yaml` 中的默认密码
2. **使用 Secret**: 敏感信息使用 Kubernetes Secret 存储
3. **网络策略**: 配置 NetworkPolicy 限制 Pod 间通信
4. **RBAC**: 配置适当的角色和权限
5. **镜像安全**: 定期更新基础镜像，扫描安全漏洞

## 📞 支持

如遇到问题，请检查：
1. Kubernetes 集群状态
2. 镜像是否正确推送到 SWR
3. 存储和网络配置
4. 查看 Pod 和服务日志