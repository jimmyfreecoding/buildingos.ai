# BuildingOS 生产环境一键部署脚本
# 用于在目标机器上快速部署 BuildingOS 系统

param(
    [string]$SWRRegion = "cn-east-3",
    [string]$SWRNamespace = "geeqee",
    [switch]$InitData = $false,
    [switch]$SkipPull = $false,
    [string]$Version = "latest"
)

$SWR_REGISTRY = "swr.$SWRRegion.myhuaweicloud.com"

# 颜色输出函数
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Step {
    param([string]$Message)
    Write-Host "🚀 $Message" -ForegroundColor Cyan
}

# 检查 Docker 和 Docker Compose
function Test-Prerequisites {
    Write-Step "检查系统环境..."
    
    # 检查 Docker
    try {
        docker --version | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker command failed"
        }
        Write-Info "✅ Docker 已安装"
    } catch {
        Write-Error "❌ Docker 未安装或未启动，请先安装 Docker"
        exit 1
    }
    
    # 检查 Docker Compose
    try {
        docker-compose --version | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker Compose command failed"
        }
        Write-Info "✅ Docker Compose 已安装"
    } catch {
        Write-Error "❌ Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    }
    
    # 检查 Docker 服务状态
    try {
        docker info | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker service not running"
        }
        Write-Info "✅ Docker 服务正在运行"
    } catch {
        Write-Error "❌ Docker 服务未启动，请启动 Docker 服务"
        exit 1
    }
}

# 创建生产环境配置
function Initialize-ProductionConfig {
    Write-Step "初始化生产环境配置..."
    
    # 创建环境变量文件
    $envContent = @"
# BuildingOS 生产环境配置
POSTGRES_PASSWORD=buildingos_prod_$(Get-Random -Minimum 1000 -Maximum 9999)
REDIS_PASSWORD=redis_prod_$(Get-Random -Minimum 1000 -Maximum 9999)
TDENGINE_PASSWORD=taos_prod_$(Get-Random -Minimum 1000 -Maximum 9999)
JWT_SECRET=BuildingOS_JWT_$(Get-Random -Minimum 100000 -Maximum 999999)
MQTT_PASSWORD=mqtt_prod_$(Get-Random -Minimum 1000 -Maximum 9999)

# SWR 配置
SWR_REGISTRY=$SWR_REGISTRY
SWR_NAMESPACE=$SWRNamespace
IMAGE_VERSION=$Version

# 部署时间
DEPLOY_TIME=$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    
    $envContent | Out-File -FilePath ".env.production" -Encoding UTF8
    Write-Info "✅ 生产环境配置文件已创建: .env.production"
}

# 拉取镜像
function Pull-Images {
    if ($SkipPull) {
        Write-Warn "跳过镜像拉取步骤"
        return
    }
    
    Write-Step "拉取华为云 SWR 镜像..."
    
    $images = @(
        "$SWR_REGISTRY/$SWRNamespace/buildingos-web:$Version",
        "$SWR_REGISTRY/$SWRNamespace/buildingos-backend:$Version"
    )
    
    foreach ($image in $images) {
        Write-Info "拉取镜像: $image"
        try {
            docker pull $image
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to pull $image"
            }
            Write-Info "✅ $image 拉取成功"
        } catch {
            Write-Error "❌ 拉取镜像失败: $image"
            Write-Error "请检查："
            Write-Host "1. 网络连接是否正常" -ForegroundColor Yellow
            Write-Host "2. 是否已登录华为云 SWR: docker login $SWR_REGISTRY" -ForegroundColor Yellow
            Write-Host "3. 镜像是否存在于 SWR 仓库中" -ForegroundColor Yellow
            exit 1
        }
    }
}

# 初始化数据卷
function Initialize-DataVolumes {
    if (-not $InitData) {
        Write-Info "跳过数据卷初始化（使用 -InitData 参数启用）"
        return
    }
    
    Write-Step "初始化生产数据卷..."
    
    # 检查是否存在 init-production-data.sh 脚本
    if (Test-Path "init-production-data.sh") {
        Write-Info "执行数据初始化脚本..."
        try {
            bash init-production-data.sh
            Write-Info "✅ 数据卷初始化完成"
        } catch {
            Write-Warn "⚠️ 数据初始化脚本执行失败，继续部署..."
        }
    } else {
        Write-Warn "未找到数据初始化脚本，跳过数据卷初始化"
    }
}

# 部署服务
function Deploy-Services {
    Write-Step "部署 BuildingOS 生产环境..."
    
    # 检查 docker-compose.production.yml 是否存在
    if (-not (Test-Path "docker-compose.production.yml")) {
        Write-Error "❌ 未找到 docker-compose.production.yml 文件"
        exit 1
    }
    
    try {
        # 停止现有服务（如果存在）
        Write-Info "停止现有服务..."
        docker-compose -f docker-compose.production.yml down 2>$null
        
        # 启动服务
        Write-Info "启动生产环境服务..."
        docker-compose -f docker-compose.production.yml up -d
        
        if ($LASTEXITCODE -ne 0) {
            throw "Docker Compose up failed"
        }
        
        Write-Info "✅ 服务启动成功"
        
    } catch {
        Write-Error "❌ 服务部署失败"
        Write-Error "错误信息: $_"
        
        # 显示服务状态
        Write-Info "当前服务状态："
        docker-compose -f docker-compose.production.yml ps
        exit 1
    }
}

# 健康检查
function Test-ServiceHealth {
    Write-Step "执行服务健康检查..."
    
    $maxRetries = 30
    $retryCount = 0
    
    Write-Info "等待服务启动完成..."
    
    while ($retryCount -lt $maxRetries) {
        $retryCount++
        Write-Host "." -NoNewline
        
        try {
            # 检查后端服务
            $response = Invoke-WebRequest -Uri "http://localhost:3001/" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host ""
                Write-Info "✅ 后端服务健康检查通过"
                break
            }
        } catch {
            if ($retryCount -eq $maxRetries) {
                Write-Host ""
                Write-Warn "⚠️ 后端服务健康检查超时，但服务可能仍在启动中"
                break
            }
        }
        
        Start-Sleep -Seconds 2
    }
    
    # 检查前端服务
    try {
        $response = Invoke-WebRequest -Uri "http://localhost/" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Info "✅ 前端服务健康检查通过"
        }
    } catch {
        Write-Warn "⚠️ 前端服务健康检查失败，请检查服务状态"
    }
}

# 显示部署结果
function Show-DeploymentResult {
    Write-Step "部署完成！"
    
    Write-Host ""
    Write-Info "🎉 BuildingOS 生产环境部署成功！"
    Write-Host ""
    Write-Info "📋 服务访问地址："
    Write-Host "前端应用: http://localhost/" -ForegroundColor Cyan
    Write-Host "后端 API: http://localhost:3001/" -ForegroundColor Cyan
    Write-Host "Grafana: http://localhost:3000/" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Info "📊 服务状态："
    docker-compose -f docker-compose.production.yml ps
    
    Write-Host ""
    Write-Info "🔧 常用管理命令："
    Write-Host "查看日志: docker-compose -f docker-compose.production.yml logs -f [service_name]" -ForegroundColor Yellow
    Write-Host "重启服务: docker-compose -f docker-compose.production.yml restart [service_name]" -ForegroundColor Yellow
    Write-Host "停止服务: docker-compose -f docker-compose.production.yml down" -ForegroundColor Yellow
    Write-Host "更新服务: ./deploy-production.ps1 -Version [new_version]" -ForegroundColor Yellow
}

# 主执行流程
function Main {
    Write-Info "🚀 BuildingOS 生产环境部署开始..."
    Write-Info "SWR 仓库: $SWR_REGISTRY/$SWRNamespace"
    Write-Info "镜像版本: $Version"
    Write-Host ""
    
    Test-Prerequisites
    Initialize-ProductionConfig
    Pull-Images
    Initialize-DataVolumes
    Deploy-Services
    Test-ServiceHealth
    Show-DeploymentResult
}

# 执行主流程
try {
    Main
} catch {
    Write-Error "部署过程中发生错误: $_"
    Write-Host ""
    Write-Info "🔍 故障排查建议："
    Write-Host "1. 检查 Docker 服务是否正常运行" -ForegroundColor Yellow
    Write-Host "2. 检查网络连接是否正常" -ForegroundColor Yellow
    Write-Host "3. 检查是否已登录华为云 SWR" -ForegroundColor Yellow
    Write-Host "4. 检查系统资源是否充足" -ForegroundColor Yellow
    Write-Host "5. 查看详细日志: docker-compose -f docker-compose.production.yml logs" -ForegroundColor Yellow
    exit 1
}