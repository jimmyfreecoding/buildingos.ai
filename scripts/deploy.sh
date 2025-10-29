#!/bin/bash

# BuildingOS 部署脚本
# 使用方法: ./deploy.sh [环境] [版本]
# 示例: ./deploy.sh production v1.0.0

set -e

# 默认配置
ENVIRONMENT=${1:-staging}
VERSION=${2:-latest}
COMPOSE_FILE="docker/deploy/docker-compose.prod.yml"
ENV_FILE="docker/deploy/.env.${ENVIRONMENT}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要的文件
check_prerequisites() {
    log_info "检查部署前置条件..."
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Docker Compose 文件不存在: $COMPOSE_FILE"
        exit 1
    fi
    
    if [ ! -f "$ENV_FILE" ]; then
        log_error "环境配置文件不存在: $ENV_FILE"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装"
        exit 1
    fi
    
    log_info "前置条件检查通过"
}

# 备份数据
backup_data() {
    if [ "$ENVIRONMENT" = "production" ]; then
        log_info "备份生产环境数据..."
        
        # 创建备份目录
        BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        # 备份 PostgreSQL
        docker exec buildingos-postgres pg_dump -U buildingos buildingos > "$BACKUP_DIR/postgres_backup.sql"
        
        # 备份 Redis
        docker exec buildingos-redis redis-cli --rdb /data/dump.rdb
        docker cp buildingos-redis:/data/dump.rdb "$BACKUP_DIR/redis_backup.rdb"
        
        # 备份 TDengine
        docker exec buildingos-tdengine taos -s "backup database buildingos to '/var/lib/taos/backup'"
        docker cp buildingos-tdengine:/var/lib/taos/backup "$BACKUP_DIR/tdengine_backup"
        
        log_info "数据备份完成: $BACKUP_DIR"
    fi
}

# 拉取最新镜像
pull_images() {
    log_info "拉取 Docker 镜像 (版本: $VERSION)..."
    
    export VERSION="$VERSION"
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull
    
    log_info "镜像拉取完成"
}

# 部署服务
deploy_services() {
    log_info "部署服务..."
    
    export VERSION="$VERSION"
    
    # 停止旧服务
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down
    
    # 启动新服务
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    
    log_info "服务部署完成"
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    # 等待服务启动
    sleep 30
    
    # 检查服务状态
    SERVICES=("buildingos-backend" "buildingos-web" "buildingos-postgres" "buildingos-redis" "buildingos-tdengine")
    
    for service in "${SERVICES[@]}"; do
        if docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
            log_info "✓ $service 运行正常"
        else
            log_error "✗ $service 运行异常"
            docker logs "$service" --tail 50
            exit 1
        fi
    done
    
    # API 健康检查
    if curl -f http://localhost/health > /dev/null 2>&1; then
        log_info "✓ API 健康检查通过"
    else
        log_error "✗ API 健康检查失败"
        exit 1
    fi
    
    log_info "健康检查通过"
}

# 清理旧镜像
cleanup() {
    log_info "清理旧镜像和容器..."
    
    docker system prune -f
    docker image prune -f
    
    log_info "清理完成"
}

# 回滚函数
rollback() {
    log_warn "开始回滚到上一个版本..."
    
    # 获取上一个版本
    PREVIOUS_VERSION=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep buildingos-backend | head -2 | tail -1 | cut -d: -f2)
    
    if [ -z "$PREVIOUS_VERSION" ]; then
        log_error "未找到可回滚的版本"
        exit 1
    fi
    
    log_info "回滚到版本: $PREVIOUS_VERSION"
    
    export VERSION="$PREVIOUS_VERSION"
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    
    log_info "回滚完成"
}

# 主函数
main() {
    log_info "开始部署 BuildingOS ($ENVIRONMENT 环境, 版本: $VERSION)"
    
    check_prerequisites
    
    # 如果是生产环境，进行备份
    if [ "$ENVIRONMENT" = "production" ]; then
        backup_data
    fi
    
    pull_images
    deploy_services
    health_check
    cleanup
    
    log_info "部署成功完成!"
    log_info "访问地址: http://$(hostname -I | awk '{print $1}')"
}

# 错误处理
trap 'log_error "部署失败，正在回滚..."; rollback' ERR

# 执行主函数
main "$@"