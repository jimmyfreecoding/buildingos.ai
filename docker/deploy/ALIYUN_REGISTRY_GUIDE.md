# 阿里云容器镜像服务使用指南

## 🚀 快速开始

### 1. 开通阿里云容器镜像服务

1. 登录 [阿里云控制台](https://ecs.console.aliyun.com/)
2. 搜索"容器镜像服务"或访问 [容器镜像服务控制台](https://cr.console.aliyun.com/)
3. 选择**个人版**（免费）或**企业版**（付费，功能更强）
4. 选择地域（推荐：华东1-杭州）

### 2. 创建命名空间

```bash
# 在控制台创建命名空间，例如：buildingos
# 命名空间相当于组织名，用于管理多个镜像仓库
```

### 3. 创建镜像仓库

为每个服务创建独立的镜像仓库：

| 仓库名称 | 描述 | 访问级别 |
|---------|------|----------|
| `buildingos-backend` | 后端服务镜像 | 私有 |
| `buildingos-web` | 前端服务镜像 | 私有 |
| `postgres` | PostgreSQL数据库 | 私有 |
| `redis` | Redis缓存 | 私有 |
| `tdengine` | TDengine时序数据库 | 私有 |
| `emqx` | MQTT消息服务 | 私有 |

## 🔐 配置访问凭证

### 方法1：使用访问凭证（推荐）

1. 进入容器镜像服务控制台
2. 点击右上角头像 → 访问凭证
3. 设置Registry登录密码
4. 记录以下信息：
   ```bash
   Registry地址: registry.cn-hangzhou.aliyuncs.com
   用户名: 您的阿里云账号
   密码: 刚设置的Registry密码
   ```

### 方法2：使用临时Token（CI/CD推荐）

```bash
# 获取临时访问Token
aliyun cr GetAuthorizationToken --region cn-hangzhou
```

## 📦 本地镜像推送

### 1. 登录阿里云镜像仓库

```bash
# 使用访问凭证登录
docker login registry.cn-hangzhou.aliyuncs.com
# 输入用户名和密码

# 或者一行命令登录
echo "your-password" | docker login registry.cn-hangzhou.aliyuncs.com -u your-username --password-stdin
```

### 2. 构建并推送应用镜像

```bash
# 构建后端镜像
cd buildingos.ai
docker build -f docker/Dockerfile.backend -t buildingos-backend:latest .

# 标记镜像
docker tag buildingos-backend:latest registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-backend:latest
docker tag buildingos-backend:latest registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-backend:v1.0.0

# 推送镜像
docker push registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-backend:latest
docker push registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-backend:v1.0.0
```

```bash
# 构建前端镜像
docker build -f docker/Dockerfile.web -t buildingos-web:latest .

# 标记并推送
docker tag buildingos-web:latest registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-web:latest
docker push registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-web:latest
```

### 3. 推送基础设施镜像

```bash
# 拉取官方镜像并重新标记
docker pull postgres:15-alpine
docker tag postgres:15-alpine registry.cn-hangzhou.aliyuncs.com/buildingos/postgres:15-alpine
docker push registry.cn-hangzhou.aliyuncs.com/buildingos/postgres:15-alpine

docker pull redis:7-alpine
docker tag redis:7-alpine registry.cn-hangzhou.aliyuncs.com/buildingos/redis:7-alpine
docker push registry.cn-hangzhou.aliyuncs.com/buildingos/redis:7-alpine

docker pull tdengine/tdengine:3.0.4.0
docker tag tdengine/tdengine:3.0.4.0 registry.cn-hangzhou.aliyuncs.com/buildingos/tdengine:3.0.4.0
docker push registry.cn-hangzhou.aliyuncs.com/buildingos/tdengine:3.0.4.0

docker pull emqx/emqx:5.1
docker tag emqx/emqx:5.1 registry.cn-hangzhou.aliyuncs.com/buildingos/emqx:5.1
docker push registry.cn-hangzhou.aliyuncs.com/buildingos/emqx:5.1
```

## 🤖 GitHub Actions 自动化

### 配置 GitHub Secrets

在 GitHub 仓库设置中添加以下 Secrets：

```bash
ALIYUN_REGISTRY_URL=registry.cn-hangzhou.aliyuncs.com
ALIYUN_REGISTRY_USERNAME=your-aliyun-username
ALIYUN_REGISTRY_PASSWORD=your-registry-password
ALIYUN_REGISTRY_NAMESPACE=buildingos
```

### CI/CD 流水线配置

我们的 <mcfile name="ci-cd.yml" path="c:\githubproject\buildingos_build\buildingos.ai\.github\workflows\ci-cd.yml"></mcfile> 已经配置好了自动化推送：

```yaml
# 应用镜像构建和推送
- name: Build and push backend image
  run: |
    docker build -f docker/Dockerfile.backend -t ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/buildingos-backend:${{ env.VERSION }} .
    docker push ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/buildingos-backend:${{ env.VERSION }}

- name: Build and push web image
  run: |
    docker build -f docker/Dockerfile.web -t ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/buildingos-web:${{ env.VERSION }} .
    docker push ${{ env.REGISTRY }}/${{ env.NAMESPACE }}/buildingos-web:${{ env.VERSION }}
```

## 🔍 镜像管理

### 查看镜像列表

```bash
# 在阿里云控制台查看
# 或使用 API 查询
curl -H "Authorization: Bearer $TOKEN" \
  https://cr.cn-hangzhou.aliyuncs.com/v2/buildingos/buildingos-backend/tags/list
```

### 镜像版本管理

```bash
# 语义化版本标签
v1.0.0, v1.0.1, v1.1.0  # 正式版本
latest                   # 最新版本
stable                   # 稳定版本
dev                      # 开发版本
```

### 清理旧镜像

```bash
# 在阿里云控制台设置自动清理规则
# 或手动删除不需要的版本
```

## 🚀 服务器拉取镜像

### 1. 服务器登录阿里云镜像仓库

```bash
# 在生产服务器上登录
docker login registry.cn-hangzhou.aliyuncs.com
```

### 2. 拉取镜像

```bash
# 拉取最新应用镜像
docker pull registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-backend:latest
docker pull registry.cn-hangzhou.aliyuncs.com/buildingos/buildingos-web:latest

# 拉取基础设施镜像
docker pull registry.cn-hangzhou.aliyuncs.com/buildingos/postgres:15-alpine
docker pull registry.cn-hangzhou.aliyuncs.com/buildingos/redis:7-alpine
```

### 3. 使用部署脚本

我们的 <mcfile name="deploy.sh" path="c:\githubproject\buildingos_build\buildingos.ai\docker\deploy\deploy.sh"></mcfile> 已经集成了自动拉取：

```bash
# 自动拉取最新镜像并部署
./deploy.sh --app-only
```

## 💰 费用说明

### 个人版（免费）
- **存储空间**：1GB
- **流量**：1GB/月
- **镜像仓库数量**：300个
- **适用场景**：个人项目、小团队

### 企业版（付费）
- **存储空间**：按需付费
- **流量**：按需付费
- **功能增强**：漏洞扫描、镜像同步等
- **适用场景**：企业级项目

## 🔒 安全最佳实践

### 1. 访问控制
```bash
# 设置镜像仓库为私有
# 使用RAM用户而非主账号
# 定期轮换访问密钥
```

### 2. 网络安全
```bash
# 配置VPC访问控制
# 使用专有网络内网访问
# 启用访问日志审计
```

### 3. 镜像安全
```bash
# 启用镜像漏洞扫描
# 使用官方基础镜像
# 定期更新基础镜像
```

## 🚨 常见问题

### 1. 登录失败
```bash
# 检查用户名密码
# 确认Registry地址正确
# 检查网络连接

# 重新设置Registry密码
```

### 2. 推送失败
```bash
# 检查镜像标签格式
# 确认仓库已创建
# 检查网络带宽

# 正确的标签格式
registry.cn-hangzhou.aliyuncs.com/namespace/repository:tag
```

### 3. 拉取慢
```bash
# 使用阿里云ECS服务器
# 选择同地域的Registry
# 配置镜像加速器
```

## 📞 技术支持

- **阿里云文档**：[容器镜像服务文档](https://help.aliyun.com/product/60716.html)
- **API参考**：[容器镜像服务API](https://help.aliyun.com/document_detail/60743.html)
- **工单支持**：阿里云控制台提交工单
- **社区支持**：阿里云开发者社区

---

通过以上配置，您就可以将 BuildingOS 的所有镜像发布到阿里云，实现高效的容器化部署！