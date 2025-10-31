# BuildingOS AI 部署指南

本指南提供了 BuildingOS AI 系统的完整部署流程，包括本地容器构建和推送到华为云 SWR 的详细步骤。

## 目录

- [本地容器构建](#本地容器构建)
- [推送容器到华为云 SWR](#推送容器到华为云-swr)
- [系统架构](#系统架构)
- [故障排除](#故障排除)

## 本地容器构建

### 前置要求

- Docker Desktop 已安装并运行
- Docker Compose 已安装
- 确保有足够的磁盘空间（至少 10GB）

### 一键构建所有容器

使用以下命令构建 `docker-compose.full.yml` 中定义的所有服务：

```bash
docker-compose -f docker-compose.full.yml build
```

此命令将构建以下服务：
- **前端服务** (`web`): 基于 Nginx 的 Vue.js 应用
- **后端服务** (`backend`): 基于 Node.js 的 NestJS API 服务

其他服务（PostgreSQL、Redis、TDengine、EMQX、Grafana、ZLMediaKit）使用官方镜像，无需构建。

### 验证构建结果

构建完成后，可以使用以下命令查看本地镜像：

```bash
# 查看所有镜像
docker images

# 查看 BuildingOS 相关镜像
docker images | findstr buildingos
```

## 推送容器到华为云 SWR

### 方法一：使用自动化脚本（推荐）

我们提供了一个 PowerShell 脚本来自动化推送所有容器到华为云 SWR。

#### 脚本特性

- 包含硬编码的登录凭据（开发测试用）
- 自动推送所有相关镜像
- 彩色输出和详细日志
- 错误处理和重试机制
- 推送结果统计

#### 使用方法

```powershell
# 基本用法（使用硬编码登录）
.\push-all-to-swr.ps1 -UseHardcodedLogin

# 指定版本标签
.\push-all-to-swr.ps1 -UseHardcodedLogin -Version "v1.0.0"

# 指定华为云区域
.\push-all-to-swr.ps1 -UseHardcodedLogin -Region "cn-north-4"

# 指定 SWR 命名空间
.\push-all-to-swr.ps1 -UseHardcodedLogin -Namespace "myproject"

# 组合使用
.\push-all-to-swr.ps1 -UseHardcodedLogin -Version "v1.0.1" -Region "cn-east-3" -Namespace "geeqee"
```

#### 脚本参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-Version` | string | "latest" | 镜像版本标签 |
| `-Region` | string | "cn-east-3" | 华为云区域 |
| `-Namespace` | string | "geeqee" | SWR 命名空间 |
| `-UseHardcodedLogin` | switch | false | 使用硬编码登录凭据 |



**注意**: 本指南中的硬编码凭据仅用于开发测试环境，生产环境请使用安全的凭据管理方案。

---

## 🚀 新服务器一键部署

### 概述

使用现有的 `docker-compose.production.yml` 文件，可以在新服务器上一键部署完整的 BuildingOS AI 系统。该配置文件使用华为云 SWR 镜像，包含完整的服务配置、数据卷和网络设置。

### 前置要求

1. **Docker 和 Docker Compose**
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install docker.io docker-compose-plugin
   
   # CentOS/RHEL
   sudo yum install docker docker-compose
   
   # 启动 Docker 服务
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

2. **华为云 SWR 登录**
   ```bash
   docker login swr.cn-east-3.myhuaweicloud.com
   # 输入用户名和密码
   ```

### 一键部署命令

```bash
# 下载配置文件（如果需要）
wget https://raw.githubusercontent.com/your-repo/buildingos.ai/main/docker/docker-compose.production.yml

# 一键启动所有服务
docker-compose -f docker-compose.production.yml up -d
```

### 服务配置详情

`docker-compose.production.yml` 包含以下 8 个服务：

| 服务 | 镜像 | 端口 | 说明 |
|------|------|------|------|
| **前端** | `swr.cn-east-3.myhuaweicloud.com/geeqee/buildingos-web:latest` | 80 | React + Nginx |
| **后端** | `swr.cn-east-3.myhuaweicloud.com/geeqee/buildingos-backend:latest` | 3001 | NestJS API |
| **PostgreSQL** | `postgres:15` | 5432 | 主数据库 |
| **Redis** | `redis:7-alpine` | 6379 | 缓存服务 |
| **TDengine** | `tdengine/tdengine:3.3.2.0` | 6030,6041 | 时序数据库 |
| **EMQX** | `emqx/emqx:5.8.0` | 1883,8083,18083 | MQTT 消息代理 |
| **ZLMediaKit** | `zlmediakit/zlmediakit:master` | 1935,8080,8554 | 流媒体服务器 |
| **Grafana** | `grafana/grafana:11.2.0` | 3000 | 监控面板 |

### 自动配置功能

✅ **数据持久化卷**：
- `buildingos_prod_postgres_data` - PostgreSQL 数据
- `buildingos_prod_redis_data` - Redis 数据
- `buildingos_prod_tdengine_data` - TDengine 数据
- `buildingos_prod_grafana_data` - Grafana 配置
- `buildingos_prod_emqx_data` - EMQX 配置
- `buildingos_prod_zlmediakit_data` - 流媒体数据

✅ **网络配置**：
- 独立的生产网络 `buildingos-prod-network`
- 服务间自动发现和通信

✅ **健康检查**：
- 每个服务都配置了健康检查
- 自动重启失败的服务

✅ **资源限制**：
- 生产环境的内存和 CPU 限制
- 防止资源过度使用

### 服务访问地址

部署完成后，可通过以下地址访问各服务：

| 服务 | 访问地址 | 默认凭据 |
|------|----------|----------|
| **前端应用** | `http://服务器IP:80` | - |
| **后端 API** | `http://服务器IP:3001` | - |
| **Grafana 监控** | `http://服务器IP:3000` | admin/grafana_prod_2024 |
| **EMQX 管理** | `http://服务器IP:18083` | admin/emqx_prod_2024 |

### 部署验证

```bash
# 检查所有服务状态
docker-compose -f docker-compose.production.yml ps

# 查看服务日志
docker-compose -f docker-compose.production.yml logs -f

# 检查特定服务
docker-compose -f docker-compose.production.yml logs backend
```

### 常用管理命令

```bash
# 停止所有服务
docker-compose -f docker-compose.production.yml down

# 重启特定服务
docker-compose -f docker-compose.production.yml restart backend

# 更新镜像并重启
docker-compose -f docker-compose.production.yml pull
docker-compose -f docker-compose.production.yml up -d

# 查看资源使用情况
docker stats
```

### 环境变量配置

可以通过 `.env` 文件自定义密码：

```bash
# 创建 .env 文件
cat > .env << EOF
POSTGRES_PASSWORD=your_secure_postgres_password
REDIS_PASSWORD=your_secure_redis_password
EMQX_PASSWORD=your_secure_emqx_password
GRAFANA_PASSWORD=your_secure_grafana_password
EOF
```

### 故障排除

1. **服务启动失败**
   ```bash
   # 查看详细日志
   docker-compose -f docker-compose.production.yml logs service_name
   
   # 检查容器状态
   docker ps -a
   ```

2. **网络连接问题**
   ```bash
   # 检查网络
   docker network ls
   docker network inspect buildingos-prod-network
   ```

3. **数据卷问题**
   ```bash
   # 查看数据卷
   docker volume ls
   docker volume inspect buildingos_prod_postgres_data
   ```

### 优势总结

- 🚀 **一键部署**：单条命令启动完整系统
- 🔒 **生产就绪**：使用华为云 SWR 镜像，稳定可靠
- 📊 **完整监控**：内置 Grafana 监控面板
- 💾 **数据持久化**：所有重要数据自动持久化
- 🔧 **易于维护**：标准 Docker Compose 管理
- 🛡️ **安全配置**：生产环境安全设置