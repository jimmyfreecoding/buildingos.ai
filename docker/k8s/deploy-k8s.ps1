# BuildingOS Kubernetes 部署脚本
# 用于在 Kubernetes 集群中部署 BuildingOS 系统

param(
    [string]$Namespace = "buildingos",
    [string]$SWRRegion = "cn-east-3",
    [string]$SWRNamespace = "geeqee",
    [string]$ImageVersion = "latest",
    [switch]$CreateNamespace = $false,
    [switch]$UpdateImages = $false,
    [switch]$DryRun = $false,
    [switch]$DeleteFirst = $false
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

# 检查 kubectl 是否可用
function Test-KubernetesConnection {
    Write-Step "检查 Kubernetes 连接..."
    
    try {
        kubectl version --client --short | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "kubectl command failed"
        }
        Write-Info "✅ kubectl 已安装"
    } catch {
        Write-Error "❌ kubectl 未安装或不可用"
        Write-Error "请安装 kubectl 并配置集群连接"
        exit 1
    }
    
    try {
        kubectl cluster-info | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "cluster connection failed"
        }
        Write-Info "✅ Kubernetes 集群连接正常"
    } catch {
        Write-Error "❌ 无法连接到 Kubernetes 集群"
        Write-Error "请检查 kubeconfig 配置"
        exit 1
    }
}

# 创建或检查命名空间
function Initialize-Namespace {
    Write-Step "初始化命名空间..."
    
    $namespaceExists = kubectl get namespace $Namespace 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "✅ 命名空间 '$Namespace' 已存在"
    } else {
        if ($CreateNamespace) {
            Write-Info "创建命名空间 '$Namespace'..."
            if ($DryRun) {
                Write-Info "[DRY-RUN] kubectl apply -f namespace.yaml"
            } else {
                kubectl apply -f namespace.yaml
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "❌ 创建命名空间失败"
                    exit 1
                }
                Write-Info "✅ 命名空间创建成功"
            }
        } else {
            Write-Error "❌ 命名空间 '$Namespace' 不存在"
            Write-Error "使用 -CreateNamespace 参数自动创建命名空间"
            exit 1
        }
    }
}

# 更新镜像版本
function Update-ImageVersions {
    if (-not $UpdateImages) {
        return
    }
    
    Write-Step "更新镜像版本到 $ImageVersion..."
    
    $files = @("application.yaml")
    
    foreach ($file in $files) {
        if (Test-Path $file) {
            Write-Info "更新 $file 中的镜像版本..."
            
            $content = Get-Content $file -Raw
            $content = $content -replace ":latest", ":$ImageVersion"
            $content = $content -replace "swr\.[^/]+\.myhuaweicloud\.com", $SWR_REGISTRY
            
            if ($DryRun) {
                Write-Info "[DRY-RUN] 将更新 $file 中的镜像版本"
            } else {
                $content | Set-Content $file -Encoding UTF8
                Write-Info "✅ $file 镜像版本已更新"
            }
        }
    }
}

# 删除现有部署
function Remove-ExistingDeployment {
    if (-not $DeleteFirst) {
        return
    }
    
    Write-Step "删除现有部署..."
    
    $files = @(
        "ingress.yaml",
        "application.yaml", 
        "database.yaml",
        "storage.yaml",
        "namespace.yaml"
    )
    
    foreach ($file in $files) {
        if (Test-Path $file) {
            Write-Info "删除 $file 中的资源..."
            if ($DryRun) {
                Write-Info "[DRY-RUN] kubectl delete -f $file"
            } else {
                kubectl delete -f $file --ignore-not-found=true
            }
        }
    }
    
    Write-Info "等待资源清理完成..."
    Start-Sleep -Seconds 10
}

# 部署存储资源
function Deploy-Storage {
    Write-Step "部署存储资源..."
    
    if ($DryRun) {
        Write-Info "[DRY-RUN] kubectl apply -f storage.yaml"
    } else {
        kubectl apply -f storage.yaml
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ 存储资源部署失败"
            exit 1
        }
        Write-Info "✅ 存储资源部署成功"
    }
}

# 部署数据库服务
function Deploy-Databases {
    Write-Step "部署数据库服务..."
    
    if ($DryRun) {
        Write-Info "[DRY-RUN] kubectl apply -f database.yaml"
    } else {
        kubectl apply -f database.yaml
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ 数据库服务部署失败"
            exit 1
        }
        Write-Info "✅ 数据库服务部署成功"
        
        # 等待数据库服务就绪
        Write-Info "等待数据库服务启动..."
        kubectl wait --for=condition=ready pod -l app=postgres -n $Namespace --timeout=300s
        kubectl wait --for=condition=ready pod -l app=redis -n $Namespace --timeout=300s
        kubectl wait --for=condition=ready pod -l app=tdengine -n $Namespace --timeout=300s
        Write-Info "✅ 数据库服务已就绪"
    }
}

# 部署应用服务
function Deploy-Applications {
    Write-Step "部署应用服务..."
    
    if ($DryRun) {
        Write-Info "[DRY-RUN] kubectl apply -f application.yaml"
    } else {
        kubectl apply -f application.yaml
        if ($LASTEXITCODE -ne 0) {
            Write-Error "❌ 应用服务部署失败"
            exit 1
        }
        Write-Info "✅ 应用服务部署成功"
        
        # 等待应用服务就绪
        Write-Info "等待应用服务启动..."
        kubectl wait --for=condition=ready pod -l app=buildingos-backend -n $Namespace --timeout=300s
        kubectl wait --for=condition=ready pod -l app=buildingos-web -n $Namespace --timeout=300s
        kubectl wait --for=condition=ready pod -l app=grafana -n $Namespace --timeout=300s
        Write-Info "✅ 应用服务已就绪"
    }
}

# 部署 Ingress
function Deploy-Ingress {
    Write-Step "部署 Ingress 配置..."
    
    if ($DryRun) {
        Write-Info "[DRY-RUN] kubectl apply -f ingress.yaml"
    } else {
        kubectl apply -f ingress.yaml
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "⚠️ Ingress 部署失败，可能需要先安装 Ingress Controller"
        } else {
            Write-Info "✅ Ingress 配置部署成功"
        }
    }
}

# 显示部署状态
function Show-DeploymentStatus {
    Write-Step "部署状态检查..."
    
    Write-Info "📊 Pod 状态："
    kubectl get pods -n $Namespace -o wide
    
    Write-Host ""
    Write-Info "🔗 Service 状态："
    kubectl get services -n $Namespace
    
    Write-Host ""
    Write-Info "📡 Ingress 状态："
    kubectl get ingress -n $Namespace
    
    Write-Host ""
    Write-Info "💾 存储状态："
    kubectl get pv,pvc -n $Namespace
    
    Write-Host ""
    Write-Info "🎉 BuildingOS 已部署到 Kubernetes 集群！"
    Write-Host ""
    
    # 获取访问地址
    Write-Info "🌐 访问地址："
    
    # 检查 LoadBalancer 服务
    $webLB = kubectl get service buildingos-web-lb -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    $backendLB = kubectl get service buildingos-backend-lb -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    $grafanaLB = kubectl get service grafana-lb -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    
    if ($webLB) {
        Write-Host "前端应用: http://$webLB/" -ForegroundColor Cyan
    }
    if ($backendLB) {
        Write-Host "后端 API: http://$backendLB:3001/" -ForegroundColor Cyan
    }
    if ($grafanaLB) {
        Write-Host "Grafana: http://$grafanaLB:3000/" -ForegroundColor Cyan
    }
    
    if (-not ($webLB -or $backendLB -or $grafanaLB)) {
        Write-Host "使用 kubectl port-forward 进行本地访问：" -ForegroundColor Yellow
        Write-Host "kubectl port-forward -n $Namespace service/buildingos-web 8080:80" -ForegroundColor Yellow
        Write-Host "kubectl port-forward -n $Namespace service/buildingos-backend 3001:3001" -ForegroundColor Yellow
        Write-Host "kubectl port-forward -n $Namespace service/grafana 3000:3000" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Info "🔧 常用管理命令："
    Write-Host "查看日志: kubectl logs -f deployment/buildingos-backend -n $Namespace" -ForegroundColor Yellow
    Write-Host "扩容应用: kubectl scale deployment buildingos-backend --replicas=3 -n $Namespace" -ForegroundColor Yellow
    Write-Host "更新镜像: kubectl set image deployment/buildingos-backend backend=$SWR_REGISTRY/$SWRNamespace/buildingos-backend:new-version -n $Namespace" -ForegroundColor Yellow
    Write-Host "删除部署: kubectl delete namespace $Namespace" -ForegroundColor Yellow
}

# 主执行流程
function Main {
    Write-Info "🚀 BuildingOS Kubernetes 部署开始..."
    Write-Info "命名空间: $Namespace"
    Write-Info "SWR 仓库: $SWR_REGISTRY/$SWRNamespace"
    Write-Info "镜像版本: $ImageVersion"
    
    if ($DryRun) {
        Write-Warn "🔍 DRY-RUN 模式：仅显示将要执行的操作"
    }
    
    Write-Host ""
    
    Test-KubernetesConnection
    Initialize-Namespace
    Update-ImageVersions
    Remove-ExistingDeployment
    Deploy-Storage
    Deploy-Databases
    Deploy-Applications
    Deploy-Ingress
    
    if (-not $DryRun) {
        Show-DeploymentStatus
    }
}

# 执行主流程
try {
    Main
} catch {
    Write-Error "部署过程中发生错误: $_"
    Write-Host ""
    Write-Info "🔍 故障排查建议："
    Write-Host "1. 检查 kubectl 配置: kubectl config current-context" -ForegroundColor Yellow
    Write-Host "2. 检查集群状态: kubectl get nodes" -ForegroundColor Yellow
    Write-Host "3. 检查命名空间: kubectl get namespaces" -ForegroundColor Yellow
    Write-Host "4. 查看事件: kubectl get events -n $Namespace --sort-by='.lastTimestamp'" -ForegroundColor Yellow
    Write-Host "5. 查看 Pod 日志: kubectl logs -n $Namespace [pod-name]" -ForegroundColor Yellow
    exit 1
}