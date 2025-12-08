# BuildingOS AI - 微服务架构部署指南

## 📋 系统概述

BuildingOS AI 是一个基于微服务架构的智能建筑管理系统，包含以下核心服务：

- **PostgreSQL**: 关系型数据库
- **Redis**: 缓存服务
- **EMQX**: MQTT消息队列
- **TDengine**: 时序数据库
- **Grafana**: 数据可视化平台

## 🚀 快速启动

### 系统要求

- Docker Engine 20.10+
- Docker Compose 2.0+
- 可用内存: 至少 4GB
- 可用磁盘空间: 至少 10GB

### 编译前后端
docker compose -p buildingos -f docker/docker-compose.full.yml --profile init up -d web-init
docker-compose -f docker-compose.full.yml build web 
docker-compose -f docker-compose.full.yml up web 
docker-compose -f docker-compose.full.yml build backend 
docker-compose -f docker-compose.full.yml up backend 

### 推送镜像到 SWR

```bash
.\docker\push-all-to-swr.ps1 -UseHardcodedLogin -Version latest -Region cn-east-3 -Namespace geeqee
```

### 部署生产环境
- 首次初始化（仅第一次或重置）： docker compose -f docker/docker-compose.production.yml --profile init up -d web-init
- 上线： docker compose -f docker/docker-compose.production.yml up -d web backend
- 验证： http://localhost/os/ 与 http://localhost:3001/health 返回 200

### 启动所有服务

```bash
# 启动所有微服务
docker-compose -f docker/docker-compose.microservices.yml up -d

# 查看服务状态
docker-compose -f docker/docker-compose.microservices.yml ps

# 查看服务日志
docker-compose -f docker/docker-compose.microservices.yml logs -f
```

### 启动单个服务

```bash
# 启动PostgreSQL
docker-compose -f docker/docker-compose.microservices.yml up -d postgres

# 启动TDengine
docker-compose -f docker/docker-compose.microservices.yml up -d tdengine

# 启动Grafana
docker-compose -f docker/docker-compose.microservices.yml up -d grafana

# 启动EMQX
docker-compose -f docker/docker-compose.microservices.yml up -d emqx

# 启动Redis
docker-compose -f docker/docker-compose.microservices.yml up -d redis
```

### 停止服务

```bash
# 停止所有服务
docker-compose -f docker/docker-compose.microservices.yml down

# 停止并删除数据卷（谨慎使用）
docker-compose -f docker/docker-compose.microservices.yml down -v
```

## 🌐 Web管理界面

### 1. Grafana 数据可视化平台
- **访问地址**: http://localhost:3000
- **默认账号**: `admin`
- **默认密码**: `grafana123`
- **功能**: 数据可视化、监控仪表板

### 2. TDengine Explorer
- **访问地址**: http://localhost:6060
- **默认账号**: `root`
- **默认密码**: `taosdata`
- **功能**: TDengine数据库管理

### 3. EMQX Dashboard
- **访问地址**: http://localhost:18083
- **默认账号**: `admin`
- **默认密码**: `emqx123`
- **功能**: MQTT消息队列管理

## 📊 Grafana 数据源配置指南

### 配置 TDengine 数据源

1. **登录 Grafana**
   - 访问 http://localhost:3000
   - 使用账号 `admin` / `grafana123` 登录

2. **添加 TDengine 数据源**
   - 点击左侧菜单 "Connections" → "Data sources"
   - 点击 "Add data source"
   - 搜索并选择 "TDengine"

3. **配置连接参数**
   ```
   Name: TDengine
   Host: http://buildingos-tdengine:6041
   User: root
   Password: taosdata
   ```

4. **测试连接**
   - 点击 "Save & Test"
   - 看到绿色的 "Data source is working" 表示配置成功

### 配置 PostgreSQL 数据源

1. **添加 PostgreSQL 数据源**
   - 点击 "Add data source"
   - 选择 "PostgreSQL"

2. **配置连接参数**
   ```
   Name: PostgreSQL
   Host: buildingos-postgres:5432
   Database: buildingos
   User: buildingos
   Password: buildingos
   SSL Mode: disable
   ```

3. **测试连接**
   - 点击 "Save & Test"
   - 确认连接成功

### 导入预设仪表板

1. **TDengine 仪表板**
   - 在数据源配置页面点击 "Dashboards" 选项卡
   - 选择 "TDengine for 3.x" 点击导入
   - 访问 "Dashboards" → 搜索 "TDinsight"

2. **PostgreSQL 仪表板**
   - 可以从 Grafana 官方仪表板库导入
   - 推荐使用 Dashboard ID: 9628 (PostgreSQL Database)

## 🔧 服务端口说明

| 服务 | 端口 | 用途 |
|------|------|------|
| PostgreSQL | 5432 | 数据库连接 |
| Redis | 6379 | 缓存服务 |
| EMQX MQTT | 1883 | MQTT协议 |
| EMQX WebSocket | 8083 | MQTT over WebSocket |
| EMQX Dashboard | 18083 | Web管理界面 |
| TDengine Client | 6030 | 客户端连接 |
| TDengine REST | 6041 | RESTful API |
| TDengine Explorer | 6060 | Web管理界面 |
| Grafana | 3000 | Web界面 |

## 🛠️ 常见问题排除

### 1. 容器启动失败
```bash
# 查看容器状态
docker ps -a

# 查看容器日志
docker logs <container_name>

# 重启特定服务
docker-compose -f docker/docker-compose.microservices.yml restart <service_name>
```

### 2. Grafana 数据源连接失败
- **问题**: Bad Gateway 或 Connection Refused
- **解决**: 确保使用容器名称而不是 localhost
  - ✅ 正确: `buildingos-tdengine:6041`
  - ❌ 错误: `localhost:6041`

### 3. 端口冲突
```bash
# 检查端口占用
netstat -tulpn | grep <port>

# 修改 docker-compose.yml 中的端口映射
ports:
  - "新端口:容器端口"
```

### 4. 数据持久化
- 所有数据存储在 Docker 卷中
- 数据卷位置: `/var/lib/docker/volumes/`
- 备份数据卷: `docker run --rm -v <volume_name>:/data -v $(pwd):/backup alpine tar czf /backup/backup.tar.gz /data`

## 📝 开发说明

### 环境变量配置
主要环境变量在 `docker-compose.microservices.yml` 中定义：

- **PostgreSQL**: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- **Redis**: `requirepass` 参数
- **EMQX**: `EMQX_DASHBOARD__DEFAULT_USERNAME`, `EMQX_DASHBOARD__DEFAULT_PASSWORD`
- **TDengine**: `TAOS_FQDN`, `TAOS_FIRST_EP`
- **Grafana**: `GF_SECURITY_ADMIN_USER`, `GF_SECURITY_ADMIN_PASSWORD`

### 自定义配置
- TDengine Explorer 配置: `docker/explorer.toml`
- 可根据需要修改各服务的配置文件

## 🔒 安全建议

1. **修改默认密码**: 生产环境中务必修改所有默认密码
2. **网络隔离**: 使用防火墙限制外部访问
3. **SSL/TLS**: 为Web界面启用HTTPS
4. **定期备份**: 设置自动备份策略
5. **监控告警**: 配置系统监控和告警

## 📞 技术支持

如遇到问题，请检查：
1. Docker 和 Docker Compose 版本
2. 系统资源使用情况
3. 容器日志信息
4. 网络连接状态

---

**版本**: v1.0.0  
**更新时间**: 2025-09-23  
**维护者**: BuildingOS AI Team