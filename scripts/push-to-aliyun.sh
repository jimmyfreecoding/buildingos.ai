#!/bin/bash

# BuildingOS 镜像推送到阿里云脚本
# 使用方法: ./push-to-aliyun.sh [选项]

set -e

# 默认配置
REGISTRY="registry.cn-hangzhou.aliyuncs.com"
NAMESPACE="buildingos"
VERSION="latest"
BUILD_APPS=true
BUILD_INFRA=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
BuildingOS 镜像推送到阿里云脚本

使用方法:
    $0 [选项]

选项:
    -r, --registry REGISTRY     镜像仓库地址 (默认: registry.cn-hangzhou.aliyuncs.com)
    -n, --namespace NAMESPACE   命名空间 (默认: buildingos)
    -v, --version VERSION       镜像版本 (默认: latest)
    -a, --apps-only            仅构建和推送应用镜像
    -i, --infra-only           仅推送基础设施镜像
    -A, --all                  构建和推送所有镜像
    -l, --login                仅执行登录操作
    -h, --help                 显示此帮助信息

示例:
    $0                         # 构建并推送应用镜像
    $0 -v v1.2.3              # 推送指定版本
    $0 --all                   # 推送所有镜像
    $0 --infra-only            # 仅推送基础设施镜像
    $0 --login                 # 仅登录阿里云镜像仓库

环境变量:
    ALIYUN_REGISTRY_USERNAME   阿里云用户名
    ALIYUN_REGISTRY_PASSWORD   阿里云Registry密码
EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--registry)
                REGISTRY="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -a|--apps-only)
                BUILD_APPS=true
                BUILD_INFRA=false
                shift
                ;;
            -i|--infra-only)
                BUILD_APPS=false
                BUILD_INFRA=true
                shift
                ;;
            -A|--all)
                BUILD_APPS=true
                BUILD_INFRA=true
                shift
                ;;
            -l|--login)
                login_registry
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装或不在 PATH 中"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未运行"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 登录阿里云镜像仓库
login_registry() {
    log_info "登录阿里云镜像仓库..."
    
    if [[ -n "$ALIYUN_REGISTRY_USERNAME" && -n "$ALIYUN_REGISTRY_PASSWORD" ]]; then
        echo "$ALIYUN_REGISTRY_PASSWORD" | docker login "$REGISTRY" -u "$ALIYUN_REGISTRY_USERNAME" --password-stdin
    else
        log_warning "未设置环境变量 ALIYUN_REGISTRY_USERNAME 和 ALIYUN_REGISTRY_PASSWORD"
        log_info "请手动登录:"
        docker login "$REGISTRY"
    fi
    
    log_success "登录成功"
}

# 构建应用镜像
build_app_images() {
    log_info "构建应用镜像..."
    
    # 检查 Dockerfile 是否存在
    if [[ ! -f "docker/Dockerfile.backend" ]]; then
        log_error "未找到 docker/Dockerfile.backend"
        exit 1
    fi
    
    if [[ ! -f "docker/Dockerfile.web" ]]; then
        log_error "未找到 docker/Dockerfile.web"
        exit 1
    fi
    
    # 构建后端镜像
    log_info "构建后端镜像..."
    docker build -f docker/Dockerfile.backend -t "buildingos-backend:$VERSION" .
    
    # 构建前端镜像
    log_info "构建前端镜像..."
    docker build -f docker/Dockerfile.web -t "buildingos-web:$VERSION" .
    
    log_success "应用镜像构建完成"
}

# 推送应用镜像
push_app_images() {
    log_info "推送应用镜像..."
    
    # 标记并推送后端镜像
    local backend_image="$REGISTRY/$NAMESPACE/buildingos-backend:$VERSION"
    docker tag "buildingos-backend:$VERSION" "$backend_image"
    docker push "$backend_image"
    
    # 如果是 latest 版本，同时推送 latest 标签
    if [[ "$VERSION" != "latest" ]]; then
        local backend_latest="$REGISTRY/$NAMESPACE/buildingos-backend:latest"
        docker tag "buildingos-backend:$VERSION" "$backend_latest"
        docker push "$backend_latest"
    fi
    
    # 标记并推送前端镜像
    local web_image="$REGISTRY/$NAMESPACE/buildingos-web:$VERSION"
    docker tag "buildingos-web:$VERSION" "$web_image"
    docker push "$web_image"
    
    # 如果是 latest 版本，同时推送 latest 标签
    if [[ "$VERSION" != "latest" ]]; then
        local web_latest="$REGISTRY/$NAMESPACE/buildingos-web:latest"
        docker tag "buildingos-web:$VERSION" "$web_latest"
        docker push "$web_latest"
    fi
    
    log_success "应用镜像推送完成"
}

# 推送基础设施镜像
push_infra_images() {
    log_info "推送基础设施镜像..."
    
    # 基础设施镜像列表
    declare -A infra_images=(
        ["postgres:15-alpine"]="postgres:15-alpine"
        ["redis:7-alpine"]="redis:7-alpine"
        ["tdengine/tdengine:3.0.4.0"]="tdengine:3.0.4.0"
        ["emqx/emqx:5.1"]="emqx:5.1"
        ["zlmediakit/zlmediakit:master"]="zlmediakit:master"
        ["grafana/grafana:latest"]="grafana:latest"
    )
    
    for source_image in "${!infra_images[@]}"; do
        target_tag="${infra_images[$source_image]}"
        target_image="$REGISTRY/$NAMESPACE/$target_tag"
        
        log_info "处理镜像: $source_image -> $target_image"
        
        # 拉取官方镜像
        docker pull "$source_image"
        
        # 重新标记
        docker tag "$source_image" "$target_image"
        
        # 推送到阿里云
        docker push "$target_image"
    done
    
    log_success "基础设施镜像推送完成"
}

# 清理本地镜像
cleanup_images() {
    log_info "清理本地临时镜像..."
    
    # 清理构建的应用镜像
    if [[ "$BUILD_APPS" == true ]]; then
        docker rmi "buildingos-backend:$VERSION" 2>/dev/null || true
        docker rmi "buildingos-web:$VERSION" 2>/dev/null || true
    fi
    
    # 清理 dangling 镜像
    docker image prune -f
    
    log_success "清理完成"
}

# 显示推送结果
show_results() {
    log_success "镜像推送完成！"
    echo
    log_info "推送的镜像:"
    
    if [[ "$BUILD_APPS" == true ]]; then
        echo "  - $REGISTRY/$NAMESPACE/buildingos-backend:$VERSION"
        echo "  - $REGISTRY/$NAMESPACE/buildingos-web:$VERSION"
        if [[ "$VERSION" != "latest" ]]; then
            echo "  - $REGISTRY/$NAMESPACE/buildingos-backend:latest"
            echo "  - $REGISTRY/$NAMESPACE/buildingos-web:latest"
        fi
    fi
    
    if [[ "$BUILD_INFRA" == true ]]; then
        echo "  - $REGISTRY/$NAMESPACE/postgres:15-alpine"
        echo "  - $REGISTRY/$NAMESPACE/redis:7-alpine"
        echo "  - $REGISTRY/$NAMESPACE/tdengine:3.0.4.0"
        echo "  - $REGISTRY/$NAMESPACE/emqx:5.1"
        echo "  - $REGISTRY/$NAMESPACE/zlmediakit:master"
        echo "  - $REGISTRY/$NAMESPACE/grafana:latest"
    fi
    
    echo
    log_info "下一步操作:"
    echo "  1. 更新服务器上的 .env.prod 文件中的版本号"
    echo "  2. 在服务器上执行: ./deploy.sh --app-only"
    echo "  3. 验证部署: curl -f http://your-server/health"
}

# 主函数
main() {
    echo "BuildingOS 镜像推送到阿里云"
    echo "================================"
    
    # 解析参数
    parse_args "$@"
    
    # 检查依赖
    check_dependencies
    
    # 登录阿里云
    login_registry
    
    # 构建和推送应用镜像
    if [[ "$BUILD_APPS" == true ]]; then
        build_app_images
        push_app_images
    fi
    
    # 推送基础设施镜像
    if [[ "$BUILD_INFRA" == true ]]; then
        push_infra_images
    fi
    
    # 清理临时镜像
    cleanup_images
    
    # 显示结果
    show_results
}

# 错误处理
trap 'log_error "脚本执行失败，退出码: $?"' ERR

# 执行主函数
main "$@"