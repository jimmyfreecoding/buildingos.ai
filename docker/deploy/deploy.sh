#!/bin/bash

# BuildingOS 部署脚本 v2.0
# 支持分离部署：基础设施容器和应用容器
# 使用方法：
#   ./deploy.sh                    # 完整部署
#   ./deploy.sh --app-only         # 仅更新应用容器
#   ./deploy.sh --infra-only       # 仅部署基础设施
#   ./deploy.sh --rollback         # 回滚到上一版本

set -euo pipefail

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="buildingos"
COMPOSE_FILE_FULL="${SCRIPT_DIR}/docker-compose.prod.yml"
COMPOSE_FILE_APP="${SCRIPT_DIR}/docker-compose.app.yml"
COMPOSE_FILE_INFRA="${SCRIPT_DIR}/docker-compose.infra.yml"
ENV_FILE="${SCRIPT_DIR}/.env.prod"
BACKUP_DIR="/opt/buildingos/backups"
LOG_FILE="/var/log/buildingos-deploy.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

# 显示帮助信息
show_help() {
    cat << EOF
BuildingOS 部署脚本 v2.0

使用方法:
    $0 [选项]

选项:
    --app-only          仅更新应用容器 (前后端)
    --infra-only        仅部署基础设施容器
    --rollback          回滚到上一版本
    --env ENV           指定环境 (production/staging)
    --version VERSION   指定版本号
    --help              显示此帮助信息

示例:
    $0                                    # 完整部署
    $0 --app-only                         # 仅更新应用
    $0 --app-only --env staging           # 更新测试环境应用
    $0 --infra-only                       # 仅部署基础设施
    $0 --rollback                         # 回滚部署

EOF
}

# 检查前置条件
check_prerequisites() {
    log "检查前置条件..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        error "Docker 未安装或不在 PATH 中"
    fi
    
    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose 未安装或不在 PATH 中"
    fi
    
    # 检查环境文件
    if [[ ! -f "$ENV_FILE" ]]; then
        error "环境配置文件不存在: $ENV_FILE"
    fi
    
    # 检查 Docker 服务状态
    if ! docker info &> /dev/null; then
        error "Docker 服务未运行"
    fi
    
    log "前置条件检查通过"
}

# 登录镜像仓库
login_registry() {
    log "登录阿里云容器镜像仓库..."
    
    source "$ENV_FILE"
    
    if [[ -z "${ALIYUN_REGISTRY_USERNAME:-}" ]] || [[ -z "${ALIYUN_REGISTRY_PASSWORD:-}" ]]; then
        warn "未配置阿里云镜像仓库凭证，跳过登录"
        return 0
    fi
    
    echo "$ALIYUN_REGISTRY_PASSWORD" | docker login registry.cn-hangzhou.aliyuncs.com \
        --username "$ALIYUN_REGISTRY_USERNAME" --password-stdin
    
    log "镜像仓库登录成功"
}

# 备份当前版本
backup_current_version() {
    log "备份当前版本..."
    
    if [[ -f "${SCRIPT_DIR}/backup.sh" ]]; then
        bash "${SCRIPT_DIR}/backup.sh"
    else
        warn "备份脚本不存在，跳过备份"
    fi
}

# 拉取镜像
pull_images() {
    local compose_file="$1"
    log "拉取最新镜像..."
    
    docker-compose -f "$compose_file" --env-file "$ENV_FILE" pull
    
    log "镜像拉取完成"
}

# 部署服务
deploy_services() {
    local compose_file="$1"
    local service_type="$2"
    
    log "部署 $service_type 服务..."
    
    # 停止旧服务
    docker-compose -f "$compose_file" --env-file "$ENV_FILE" down --remove-orphans
    
    # 启动新服务
    docker-compose -f "$compose_file" --env-file "$ENV_FILE" up -d
    
    log "$service_type 服务部署完成"
}

# 健康检查
health_check() {
    local max_attempts=30
    local attempt=1
    
    log "执行健康检查..."
    
    while [[ $attempt -le $max_attempts ]]; do
        info "健康检查尝试 $attempt/$max_attempts"
        
        # 检查后端服务
        if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
            log "后端服务健康检查通过"
            
            # 检查前端服务
            if curl -f -s http://localhost/health > /dev/null 2>&1; then
                log "前端服务健康检查通过"
                log "所有服务健康检查通过"
                return 0
            fi
        fi
        
        sleep 10
        ((attempt++))
    done
    
    error "健康检查失败，服务可能未正常启动"
}

# 清理旧镜像
cleanup_old_images() {
    log "清理旧镜像..."
    
    # 清理悬空镜像
    docker image prune -f
    
    # 清理超过72小时的镜像
    docker image prune -f --filter "until=72h"
    
    log "镜像清理完成"
}

# 回滚部署
rollback_deployment() {
    log "开始回滚部署..."
    
    # 查找最新的备份
    if [[ -d "$BACKUP_DIR" ]]; then
        latest_backup=$(find "$BACKUP_DIR" -name "backup_*" -type d | sort -r | head -n 1)
        
        if [[ -n "$latest_backup" ]]; then
            log "找到备份: $latest_backup"
            
            # 停止当前服务
            docker-compose -f "$COMPOSE_FILE_FULL" --env-file "$ENV_FILE" down
            
            # 恢复备份（这里需要根据实际备份策略实现）
            warn "回滚功能需要根据具体备份策略实现"
            
            # 重新启动服务
            docker-compose -f "$COMPOSE_FILE_FULL" --env-file "$ENV_FILE" up -d
            
            log "回滚完成"
        else
            error "未找到可用的备份"
        fi
    else
        error "备份目录不存在: $BACKUP_DIR"
    fi
}

# 显示部署状态
show_status() {
    log "显示服务状态..."
    
    echo -e "\n${BLUE}=== BuildingOS 服务状态 ===${NC}"
    docker-compose -f "$COMPOSE_FILE_FULL" --env-file "$ENV_FILE" ps
    
    echo -e "\n${BLUE}=== 服务访问地址 ===${NC}"
    echo "前端服务: http://localhost"
    echo "后端API: http://localhost:3000"
    echo "Grafana: http://localhost:3001"
    echo "EMQX管理: http://localhost:18083"
}

# 主函数
main() {
    local app_only=false
    local infra_only=false
    local rollback=false
    local environment="production"
    local version=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-only)
                app_only=true
                shift
                ;;
            --infra-only)
                infra_only=true
                shift
                ;;
            --rollback)
                rollback=true
                shift
                ;;
            --env)
                environment="$2"
                shift 2
                ;;
            --version)
                version="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "未知参数: $1"
                ;;
        esac
    done
    
    # 创建日志目录
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "开始 BuildingOS 部署..."
    log "部署模式: $(if $app_only; then echo "仅应用"; elif $infra_only; then echo "仅基础设施"; elif $rollback; then echo "回滚"; else echo "完整部署"; fi)"
    log "环境: $environment"
    
    # 检查前置条件
    check_prerequisites
    
    # 处理回滚
    if $rollback; then
        rollback_deployment
        show_status
        exit 0
    fi
    
    # 登录镜像仓库
    login_registry
    
    # 备份当前版本
    backup_current_version
    
    # 根据部署模式执行相应操作
    if $app_only; then
        # 仅更新应用容器
        pull_images "$COMPOSE_FILE_APP"
        deploy_services "$COMPOSE_FILE_APP" "应用"
        health_check
    elif $infra_only; then
        # 仅部署基础设施
        pull_images "$COMPOSE_FILE_INFRA"
        deploy_services "$COMPOSE_FILE_INFRA" "基础设施"
    else
        # 完整部署
        pull_images "$COMPOSE_FILE_FULL"
        deploy_services "$COMPOSE_FILE_FULL" "完整"
        health_check
    fi
    
    # 清理旧镜像
    cleanup_old_images
    
    # 显示部署状态
    show_status
    
    log "BuildingOS 部署完成！"
}

# 捕获错误并清理
trap 'error "部署过程中发生错误，请检查日志: $LOG_FILE"' ERR

# 执行主函数
main "$@"