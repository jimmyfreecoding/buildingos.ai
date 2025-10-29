# BuildingOS 部署和发布指南

## 📋 目录

1. [部署架构概述](#部署架构概述)
2. [镜像管理策略](#镜像管理策略)
3. [CI/CD 流水线](#cicd-流水线)
4. [部署方案](#部署方案)
5. [版本管理](#版本管理)
6. [监控和维护](#监控和维护)

## 🏗️ 部署架构概述

### 环境分层

```
开发环境 (Development) → 测试环境 (Staging) → 生产环境 (Production)
     ↓                      ↓                      ↓
  本地开发                 功能测试               正式发布
  快速迭代                 集成测试               稳定运行
```

### 服务架构

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │   Web Frontend  │    │   Backend API   │
│    (Nginx)      │────│    (React)      │────│   (Node.js)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
        ┌───────────────────────────────────────────────┼───────────────────┐
        │                                               │                   │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │      Redis      │    │    TDengine     │    │      EMQX       │
│   (主数据库)     │    │     (缓存)      │    │   (时序数据)     │    │   (消息队列)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🐳 镜像管理策略

### 1. 镜像仓库选择

**推荐方案：阿里云容器镜像服务 (ACR)**

```bash
# 镜像命名规范
registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-backend:v1.0.0
registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-web:v1.0.0
```

**优势：**
- 国内访问速度快
- 与阿里云 ECS 集成良好
- 支持镜像安全扫描
- 提供镜像加速服务

### 2. 镜像标签策略

```bash
# 版本标签
v1.0.0, v1.0.1, v1.1.0

# 环境标签
latest          # 最新稳定版本
develop         # 开发分支
staging         # 测试环境
production      # 生产环境

# 特殊标签
hotfix-v1.0.1   # 热修复版本
feature-xxx     # 功能分支
```

### 3. 镜像构建和推送

#### 方案一：CI/CD 自动构建（推荐）

```yaml
# GitHub Actions 自动构建
- name: Build and push Docker image
  uses: docker/build-push-action@v5
  with:
    context: .
    file: ./docker/Dockerfile.backend
    push: true
    tags: |
      registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-backend:${{ github.sha }}
      registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-backend:latest
```

#### 方案二：本地构建推送

```bash
# 构建镜像
docker build -f docker/Dockerfile.backend -t buildingos-backend:v1.0.0 .
docker build -f docker/Dockerfile.web -t buildingos-web:v1.0.0 .

# 标记镜像
docker tag buildingos-backend:v1.0.0 registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-backend:v1.0.0
docker tag buildingos-web:v1.0.0 registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-web:v1.0.0

# 推送镜像
docker push registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-backend:v1.0.0
docker push registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-web:v1.0.0
```

#### 方案三：镜像文件传输（不推荐）

```bash
# 导出镜像
docker save buildingos-backend:v1.0.0 > buildingos-backend-v1.0.0.tar
docker save buildingos-web:v1.0.0 > buildingos-web-v1.0.0.tar

# 传输到服务器
scp *.tar user@server:/opt/images/

# 在服务器上导入
docker load < buildingos-backend-v1.0.0.tar
docker load < buildingos-web-v1.0.0.tar
```

**注意：** 镜像文件传输方案不推荐，因为：
- 文件体积大，传输慢
- 版本管理困难
- 无法利用镜像层缓存
- 安全性较低

## 🚀 CI/CD 流水线

### 1. 流水线阶段

```mermaid
graph LR
    A[代码提交] --> B[代码检查]
    B --> C[单元测试]
    C --> D[构建镜像]
    D --> E[推送镜像]
    E --> F[部署测试]
    F --> G[集成测试]
    G --> H[部署生产]
```

### 2. 触发条件

| 分支/标签 | 触发动作 | 部署环境 |
|-----------|----------|----------|
| `develop` | 自动部署 | 测试环境 |
| `main` | 自动构建 | 无 |
| `v*.*.*` | 自动部署 | 生产环境 |
| `PR` | 构建测试 | 无 |

### 3. 环境变量配置

在 GitHub Secrets 中配置：

```bash
# 镜像仓库认证
ALIYUN_REGISTRY_USERNAME=your_username
ALIYUN_REGISTRY_PASSWORD=your_password

# 服务器连接
STAGING_HOST=staging.buildingos.com
STAGING_USERNAME=deploy
STAGING_SSH_KEY=-----BEGIN PRIVATE KEY-----

PRODUCTION_HOST=prod.buildingos.com
PRODUCTION_USERNAME=deploy
PRODUCTION_SSH_KEY=-----BEGIN PRIVATE KEY-----

# 通知配置
SLACK_WEBHOOK=https://hooks.slack.com/services/xxx
```

## 🎯 部署方案

### 1. 服务器准备

#### 系统要求

```bash
# 操作系统：Ubuntu 20.04 LTS 或 CentOS 8
# 内存：最小 8GB，推荐 16GB
# 存储：最小 100GB SSD
# CPU：最小 4 核，推荐 8 核
```

#### 安装 Docker 环境

```bash
# Ubuntu
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. 部署步骤

#### 初次部署

```bash
# 1. 克隆代码
git clone https://github.com/your-org/buildingos.git
cd buildingos

# 2. 配置环境变量
cp docker/deploy/.env.prod.example docker/deploy/.env.prod
vim docker/deploy/.env.prod

# 3. 执行部署
chmod +x scripts/deploy.sh
./scripts/deploy.sh production v1.0.0
```

#### 更新部署

```bash
# 1. 拉取最新代码
git pull origin main

# 2. 部署新版本
./scripts/deploy.sh production v1.1.0
```

### 3. 配置文件说明

#### 环境变量配置 (.env.prod)

```bash
# 镜像配置
DOCKER_REGISTRY=registry.cn-hangzhou.aliyuncs.com/buildingos
VERSION=v1.0.0

# 数据库配置
DB_PASSWORD=your_secure_password
REDIS_PASSWORD=your_redis_password

# 监控配置
GRAFANA_PASSWORD=your_grafana_password

# 备份配置
BACKUP_ENABLED=true
BACKUP_SCHEDULE=0 2 * * *
```

## 📊 版本管理

### 1. 语义化版本控制

```bash
# 版本格式：MAJOR.MINOR.PATCH
v1.0.0  # 主版本.次版本.修订版本

# 版本递增规则
MAJOR: 不兼容的 API 修改
MINOR: 向下兼容的功能性新增
PATCH: 向下兼容的问题修正
```

### 2. 分支策略

```bash
main        # 主分支，稳定版本
develop     # 开发分支，最新功能
feature/*   # 功能分支
hotfix/*    # 热修复分支
release/*   # 发布分支
```

### 3. 发布流程

```bash
# 1. 创建发布分支
git checkout -b release/v1.1.0 develop

# 2. 更新版本号
npm version 1.1.0

# 3. 合并到主分支
git checkout main
git merge release/v1.1.0

# 4. 创建标签
git tag -a v1.1.0 -m "Release version 1.1.0"
git push origin v1.1.0

# 5. 自动触发部署
```

## 🔄 回滚策略

### 1. 快速回滚

```bash
# 回滚到上一个版本
./scripts/deploy.sh production v1.0.0

# 或使用回滚脚本
./scripts/rollback.sh
```

### 2. 数据库回滚

```bash
# 恢复数据库备份
docker exec -i buildingos-postgres psql -U buildingos -d buildingos < backups/20231201_020000/postgres_backup.sql
```

## 📈 监控和维护

### 1. 健康检查

```bash
# 检查服务状态
docker-compose -f docker/deploy/docker-compose.prod.yml ps

# 查看服务日志
docker-compose -f docker/deploy/docker-compose.prod.yml logs -f

# API 健康检查
curl -f http://localhost/health
```

### 2. 性能监控

- **Grafana 面板**: http://your-server:3000
- **系统监控**: CPU、内存、磁盘使用率
- **应用监控**: API 响应时间、错误率
- **数据库监控**: 连接数、查询性能

### 3. 日志管理

```bash
# 查看应用日志
docker logs buildingos-backend --tail 100 -f

# 日志轮转配置
# 在 docker-compose.yml 中配置
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 4. 备份策略

```bash
# 自动备份 (crontab)
0 2 * * * /opt/buildingos/scripts/backup.sh full
0 */6 * * * /opt/buildingos/scripts/backup.sh incremental

# 手动备份
./scripts/backup.sh full
```

## 🔒 安全最佳实践

### 1. 网络安全

```bash
# 防火墙配置
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable
```

### 2. 容器安全

```yaml
# 使用非 root 用户
user: "1001:1001"

# 只读文件系统
read_only: true

# 资源限制
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '0.5'
```

### 3. 密钥管理

```bash
# 使用 Docker Secrets
echo "your_password" | docker secret create db_password -

# 在 compose 文件中引用
secrets:
  - db_password
```

## 🚨 故障排除

### 常见问题

1. **容器启动失败**
   ```bash
   # 查看详细日志
   docker logs container_name --details
   ```

2. **数据库连接失败**
   ```bash
   # 检查网络连接
   docker network ls
   docker network inspect buildingos-network
   ```

3. **镜像拉取失败**
   ```bash
   # 检查镜像仓库认证
   docker login registry.cn-hangzhou.aliyuncs.com
   ```

### 应急处理

1. **服务异常**：立即回滚到上一个稳定版本
2. **数据丢失**：从最近的备份恢复
3. **性能问题**：扩容服务器资源或横向扩展

## 📞 支持联系

- **技术支持**: tech-support@buildingos.com
- **紧急联系**: +86-xxx-xxxx-xxxx
- **文档更新**: 请提交 PR 到文档仓库

---

**最后更新**: 2024年1月
**版本**: v1.0.0