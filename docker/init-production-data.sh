#!/bin/bash

# 生产环境数据初始化脚本
# 用于清理开发数据并初始化生产环境

set -e

echo "🚀 开始初始化生产环境数据..."

# 检查是否在生产环境
if [ "$NODE_ENV" != "production" ]; then
    echo "❌ 警告：当前不是生产环境，脚本退出"
    exit 1
fi

# 备份现有数据（如果存在）
BACKUP_DIR="/backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 备份现有数据到 $BACKUP_DIR"

# 备份 PostgreSQL 数据
if docker volume ls | grep -q "buildingos_postgres_data"; then
    echo "备份 PostgreSQL 数据..."
    docker run --rm \
        -v buildingos_postgres_data:/source \
        -v "$BACKUP_DIR":/backup \
        alpine tar czf /backup/postgres_data.tar.gz -C /source .
fi

# 备份 Redis 数据
if docker volume ls | grep -q "buildingos_redis_data"; then
    echo "备份 Redis 数据..."
    docker run --rm \
        -v buildingos_redis_data:/source \
        -v "$BACKUP_DIR":/backup \
        alpine tar czf /backup/redis_data.tar.gz -C /source .
fi

# 备份 TDengine 数据
if docker volume ls | grep -q "buildingos_tdengine_data"; then
    echo "备份 TDengine 数据..."
    docker run --rm \
        -v buildingos_tdengine_data:/source \
        -v "$BACKUP_DIR":/backup \
        alpine tar czf /backup/tdengine_data.tar.gz -C /source .
fi

# 备份 Grafana 数据
if docker volume ls | grep -q "buildingos_grafana_data"; then
    echo "备份 Grafana 数据..."
    docker run --rm \
        -v buildingos_grafana_data:/source \
        -v "$BACKUP_DIR":/backup \
        alpine tar czf /backup/grafana_data.tar.gz -C /source .
fi

echo "✅ 数据备份完成"

# 创建生产环境数据卷（如果不存在）
echo "🔧 创建生产环境数据卷..."

docker volume create buildingos_prod_postgres_data
docker volume create buildingos_prod_redis_data
docker volume create buildingos_prod_tdengine_data
docker volume create buildingos_prod_grafana_data
docker volume create buildingos_prod_emqx_data
docker volume create buildingos_prod_backend_uploads
docker volume create buildingos_prod_backend_backups

echo "✅ 生产环境数据卷创建完成"

# 初始化数据库结构（不包含测试数据）
echo "🗄️ 初始化数据库结构..."

# 这里可以添加数据库初始化 SQL 脚本
# docker run --rm \
#     -v buildingos_prod_postgres_data:/var/lib/postgresql/data \
#     -v ./init-scripts:/docker-entrypoint-initdb.d \
#     postgres:15 \
#     /docker-entrypoint.sh postgres

echo "✅ 生产环境数据初始化完成"
echo "🎉 可以使用 docker-compose.production.yml 启动生产环境"