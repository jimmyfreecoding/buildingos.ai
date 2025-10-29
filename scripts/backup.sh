#!/bin/bash

# BuildingOS 数据备份脚本
# 使用方法: ./backup.sh [备份类型]
# 备份类型: full(完整备份), incremental(增量备份)

set -e

BACKUP_TYPE=${1:-full}
BACKUP_BASE_DIR="/opt/buildingos/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/$BACKUP_TYPE/$TIMESTAMP"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 创建备份目录
create_backup_dir() {
    log_info "创建备份目录: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
}

# 备份 PostgreSQL 数据库
backup_postgres() {
    log_info "备份 PostgreSQL 数据库..."
    
    if docker ps --filter "name=buildingos-postgres" --filter "status=running" | grep -q buildingos-postgres; then
        docker exec buildingos-postgres pg_dump -U buildingos -d buildingos --verbose > "$BACKUP_DIR/postgres_backup.sql"
        
        # 压缩备份文件
        gzip "$BACKUP_DIR/postgres_backup.sql"
        
        log_info "PostgreSQL 备份完成: postgres_backup.sql.gz"
    else
        log_warn "PostgreSQL 容器未运行，跳过备份"
    fi
}

# 备份 Redis 数据
backup_redis() {
    log_info "备份 Redis 数据..."
    
    if docker ps --filter "name=buildingos-redis" --filter "status=running" | grep -q buildingos-redis; then
        # 触发 Redis 保存
        docker exec buildingos-redis redis-cli BGSAVE
        
        # 等待保存完成
        sleep 5
        
        # 复制 RDB 文件
        docker cp buildingos-redis:/data/dump.rdb "$BACKUP_DIR/redis_backup.rdb"
        
        log_info "Redis 备份完成: redis_backup.rdb"
    else
        log_warn "Redis 容器未运行，跳过备份"
    fi
}

# 备份 TDengine 数据
backup_tdengine() {
    log_info "备份 TDengine 数据..."
    
    if docker ps --filter "name=buildingos-tdengine" --filter "status=running" | grep -q buildingos-tdengine; then
        # 创建 TDengine 备份目录
        docker exec buildingos-tdengine mkdir -p /var/lib/taos/backup
        
        # 执行备份
        docker exec buildingos-tdengine taos -s "backup database buildingos to '/var/lib/taos/backup'"
        
        # 复制备份文件
        docker cp buildingos-tdengine:/var/lib/taos/backup "$BACKUP_DIR/tdengine_backup"
        
        # 压缩备份
        tar -czf "$BACKUP_DIR/tdengine_backup.tar.gz" -C "$BACKUP_DIR" tdengine_backup
        rm -rf "$BACKUP_DIR/tdengine_backup"
        
        log_info "TDengine 备份完成: tdengine_backup.tar.gz"
    else
        log_warn "TDengine 容器未运行，跳过备份"
    fi
}

# 备份应用配置文件
backup_configs() {
    log_info "备份应用配置文件..."
    
    CONFIG_DIR="$BACKUP_DIR/configs"
    mkdir -p "$CONFIG_DIR"
    
    # 备份 Docker Compose 文件
    cp docker/deploy/docker-compose.prod.yml "$CONFIG_DIR/"
    cp docker/deploy/.env.prod "$CONFIG_DIR/"
    
    # 备份 SSL 证书
    if [ -d "docker/ssl-certs" ]; then
        cp -r docker/ssl-certs "$CONFIG_DIR/"
    fi
    
    # 备份 Grafana 配置
    if [ -d "docker/grafana" ]; then
        cp -r docker/grafana "$CONFIG_DIR/"
    fi
    
    log_info "配置文件备份完成"
}

# 备份 Docker 卷数据
backup_volumes() {
    log_info "备份 Docker 卷数据..."
    
    VOLUMES_DIR="$BACKUP_DIR/volumes"
    mkdir -p "$VOLUMES_DIR"
    
    # 获取所有相关的卷
    VOLUMES=$(docker volume ls --filter name=buildingos --format "{{.Name}}")
    
    for volume in $VOLUMES; do
        log_info "备份卷: $volume"
        
        # 创建临时容器来备份卷
        docker run --rm \
            -v "$volume":/source:ro \
            -v "$VOLUMES_DIR":/backup \
            alpine:latest \
            tar -czf "/backup/${volume}.tar.gz" -C /source .
    done
    
    log_info "Docker 卷备份完成"
}

# 创建备份清单
create_manifest() {
    log_info "创建备份清单..."
    
    MANIFEST_FILE="$BACKUP_DIR/backup_manifest.txt"
    
    cat > "$MANIFEST_FILE" << EOF
BuildingOS 备份清单
==================

备份时间: $(date)
备份类型: $BACKUP_TYPE
备份目录: $BACKUP_DIR

文件列表:
$(ls -la "$BACKUP_DIR")

系统信息:
- Docker 版本: $(docker --version)
- Docker Compose 版本: $(docker-compose --version)
- 系统版本: $(uname -a)

容器状态:
$(docker ps --filter name=buildingos)

卷信息:
$(docker volume ls --filter name=buildingos)
EOF

    log_info "备份清单创建完成: backup_manifest.txt"
}

# 清理旧备份
cleanup_old_backups() {
    log_info "清理旧备份文件..."
    
    # 保留最近 7 天的完整备份
    find "$BACKUP_BASE_DIR/full" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    
    # 保留最近 3 天的增量备份
    find "$BACKUP_BASE_DIR/incremental" -type d -mtime +3 -exec rm -rf {} + 2>/dev/null || true
    
    log_info "旧备份清理完成"
}

# 验证备份完整性
verify_backup() {
    log_info "验证备份完整性..."
    
    # 检查关键文件是否存在
    REQUIRED_FILES=(
        "postgres_backup.sql.gz"
        "redis_backup.rdb"
        "tdengine_backup.tar.gz"
        "backup_manifest.txt"
    )
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [ -f "$BACKUP_DIR/$file" ]; then
            log_info "✓ $file 存在"
        else
            log_warn "✗ $file 不存在"
        fi
    done
    
    # 计算备份大小
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
    log_info "备份总大小: $BACKUP_SIZE"
}

# 发送备份通知
send_notification() {
    log_info "发送备份通知..."
    
    # 这里可以集成邮件、Slack 或其他通知服务
    # 示例：发送到 Slack
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"BuildingOS 备份完成\\n类型: $BACKUP_TYPE\\n时间: $(date)\\n大小: $(du -sh "$BACKUP_DIR" | cut -f1)\"}" \
            "$SLACK_WEBHOOK_URL"
    fi
}

# 主函数
main() {
    log_info "开始 BuildingOS 数据备份 (类型: $BACKUP_TYPE)"
    
    create_backup_dir
    backup_postgres
    backup_redis
    backup_tdengine
    backup_configs
    backup_volumes
    create_manifest
    verify_backup
    cleanup_old_backups
    send_notification
    
    log_info "备份完成! 备份位置: $BACKUP_DIR"
    log_info "备份大小: $(du -sh "$BACKUP_DIR" | cut -f1)"
}

# 错误处理
trap 'log_error "备份过程中发生错误"' ERR

# 执行主函数
main "$@"