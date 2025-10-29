# BuildingOS 分离式部署 - 5分钟快速指南

## 🎯 核心概念

BuildingOS 采用**分离式容器部署**架构：
- **基础设施容器**：数据库、缓存等，更新频率低
- **应用容器**：前后端代码，更新频率高

这样设计的好处：代码更新时只需重新部署应用容器，基础设施保持稳定运行。

## 📋 服务器要求

- **操作系统**：Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- **硬件配置**：2核CPU，4GB内存，20GB存储
- **网络要求**：能访问阿里云镜像仓库

## 🐳 Docker 环境安装

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 重新登录以应用用户组变更
```

## ⚡ 5分钟快速部署

### 步骤1：获取代码
```bash
git clone <your-repository-url>
cd buildingos.ai/docker/deploy
```

### 步骤2：配置环境
```bash
# 复制环境变量模板
cp .env.prod.example .env.prod

# 编辑配置文件（必须修改密码！）
nano .env.prod
```

**重要配置项**：
```bash
# 镜像仓库配置
DOCKER_REGISTRY=registry.cn-hangzhou.aliyuncs.com/buildingos

# 版本控制
BACKEND_VERSION=latest
WEB_VERSION=latest

# 数据库密码（必须修改！）
POSTGRES_PASSWORD=your-strong-password-here
REDIS_PASSWORD=your-redis-password-here

# 服务器配置
SERVER_HOST=0.0.0.0
```

### 步骤3：一键部署
```bash
# 赋予执行权限
chmod +x deploy.sh

# 首次完整部署
./deploy.sh

# 等待部署完成（约2-3分钟）
```

### 步骤4：验证部署
```bash
# 检查服务状态
docker-compose -f docker-compose.prod.yml ps

# 测试服务访问
curl -f http://localhost/health      # 前端健康检查
curl -f http://localhost:3000/health # 后端健康检查
```

## 🎯 访问地址

部署成功后，可以通过以下地址访问：

| 服务 | 地址 | 说明 |
|------|------|------|
| **主应用** | http://your-server | BuildingOS 主界面 |
| **Grafana** | http://your-server:3000 | 监控面板 |
| **TDengine** | http://your-server:6060 | 时序数据库管理 |
| **EMQX** | http://your-server:18083 | MQTT 管理界面 |

**默认账号：**
- Grafana: admin / [你设置的密码]
- TDengine: root / taosdata
- EMQX: admin / public

## 🔄 日常操作

### 查看服务状态
```bash
docker-compose -f docker-compose.prod.yml ps
```

### 查看日志
```bash
# 查看所有服务日志
docker-compose -f docker-compose.prod.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose.prod.yml logs -f backend
```

### 重启服务
```bash
# 重启所有服务
docker-compose -f docker-compose.prod.yml restart

# 重启特定服务
docker-compose -f docker-compose.prod.yml restart backend
```

### 更新版本
```bash
# 更新到新版本
../../scripts/deploy.sh production v1.1.0

# 回滚到旧版本
../../scripts/deploy.sh production v1.0.0
```

## 🛠️ 故障排除

### 常见问题

**1. 端口被占用**
```bash
# 检查端口占用
netstat -tlnp | grep :80
netstat -tlnp | grep :3000

# 停止占用端口的服务
sudo systemctl stop nginx
sudo systemctl stop apache2
```

**2. 内存不足**
```bash
# 检查内存使用
free -h
docker stats

# 清理 Docker 资源
docker system prune -f
```

**3. 磁盘空间不足**
```bash
# 检查磁盘使用
df -h

# 清理 Docker 镜像
docker image prune -f
```

**4. 服务启动失败**
```bash
# 查看详细错误
docker-compose -f docker-compose.prod.yml logs [service_name]

# 重新构建并启动
docker-compose -f docker-compose.prod.yml up -d --force-recreate
```

## 📞 获取帮助

- **详细文档**: 查看 `README.md`
- **完整指南**: 查看 `../../docs/DEPLOYMENT_GUIDE.md`
- **脚本说明**: 查看 `../../scripts/` 目录

## ⚠️ 安全提醒

1. **修改默认密码**: 部署前必须修改 `.env.prod` 中的所有密码
2. **配置防火墙**: 只开放必要的端口
3. **定期备份**: 设置自动备份任务
4. **监控告警**: 配置 Grafana 告警规则
5. **SSL 证书**: 生产环境建议配置 HTTPS

---

🎉 **恭喜！你已成功部署 BuildingOS！**