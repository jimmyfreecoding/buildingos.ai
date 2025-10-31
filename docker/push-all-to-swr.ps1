param(
    [string]$Version = "latest",
    [string]$Region = "cn-east-3", 
    [string]$Namespace = "geeqee",
    [switch]$UseHardcodedLogin = $false
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    switch ($Color) {
        "Red" { Write-Host $Message -ForegroundColor Red }
        "Green" { Write-Host $Message -ForegroundColor Green }
        "Yellow" { Write-Host $Message -ForegroundColor Yellow }
        "Blue" { Write-Host $Message -ForegroundColor Blue }
        default { Write-Host $Message }
    }
}

$SWR_REGISTRY = "swr.$Region.myhuaweicloud.com"
$HARDCODED_USERNAME = "cn-east-3@HQVLKZGBVNHQJDXVQHQY"
$HARDCODED_PASSWORD = "f4c2c8b7c8b8e8b4b8b4b8b4b8b4b8b4b8b4b8b4b8b4b8b4b8b4b8b4b8b4b8b4"

Write-ColorOutput "=== BuildingOS AI - Push All Containers to SWR ===" "Blue"
Write-ColorOutput "Version: $Version" "Yellow"
Write-ColorOutput "Region: $Region" "Yellow"
Write-ColorOutput "Namespace: $Namespace" "Yellow"
Write-ColorOutput "Registry: $SWR_REGISTRY" "Yellow"

# Check Docker
Write-ColorOutput "[INFO] Checking Docker service..." "Blue"
try {
    docker version | Out-Null
    Write-ColorOutput "[SUCCESS] Docker is running" "Green"
} catch {
    Write-ColorOutput "[ERROR] Docker is not running" "Red"
    exit 1
}

# Login to SWR
if ($UseHardcodedLogin) {
    Write-ColorOutput "[INFO] Logging in to SWR with hardcoded credentials..." "Blue"
    try {
        echo $HARDCODED_PASSWORD | docker login $SWR_REGISTRY --username $HARDCODED_USERNAME --password-stdin
        Write-ColorOutput "[SUCCESS] SWR login successful" "Green"
    } catch {
        Write-ColorOutput "[ERROR] SWR login failed: $_" "Red"
        exit 1
    }
} else {
    Write-ColorOutput "[INFO] Please login to SWR manually" "Yellow"
    Write-ColorOutput "Command: docker login $SWR_REGISTRY" "Yellow"
    exit 1
}

# Define images to push
$imageList = @(
    "docker-web:latest,$SWR_REGISTRY/$Namespace/buildingos-web:$Version,Frontend Service",
    "docker-backend:latest,$SWR_REGISTRY/$Namespace/buildingos-backend:$Version,Backend Service", 
    "postgres:15,$SWR_REGISTRY/$Namespace/postgres:15,PostgreSQL Database",
    "redis:7-alpine,$SWR_REGISTRY/$Namespace/redis:7-alpine,Redis Cache",
    "tdengine/tdengine:3.3.2.0,$SWR_REGISTRY/$Namespace/tdengine:3.3.2.0,TDengine Database",
    "emqx/emqx:5.8.0,$SWR_REGISTRY/$Namespace/emqx:5.8.0,EMQX MQTT Broker",
    "grafana/grafana:11.2.0,$SWR_REGISTRY/$Namespace/grafana:11.2.0,Grafana Dashboard",
    "zlmediakit/zlmediakit:master,$SWR_REGISTRY/$Namespace/zlmediakit:master,ZLMediaKit Server"
)

$successCount = 0
$totalCount = $imageList.Count

foreach ($imageInfo in $imageList) {
    $parts = $imageInfo.Split(',')
    $localImage = $parts[0]
    $remoteImage = $parts[1] 
    $imageName = $parts[2]
    
    Write-ColorOutput "`n[INFO] Processing $imageName..." "Blue"
    
    # Check if local image exists
    try {
        docker image inspect $localImage | Out-Null
        Write-ColorOutput "[INFO] Local image $localImage exists" "Green"
    } catch {
        Write-ColorOutput "[WARNING] Local image $localImage not found, skipping..." "Yellow"
        continue
    }
    
    # Tag image
    Write-ColorOutput "[INFO] Tagging image: $remoteImage" "Blue"
    try {
        docker tag $localImage $remoteImage
        Write-ColorOutput "[SUCCESS] Tag created successfully" "Green"
    } catch {
        Write-ColorOutput "[ERROR] Failed to create tag: $_" "Red"
        continue
    }
    
    # Push image
    Write-ColorOutput "[INFO] Pushing image to SWR..." "Blue"
    try {
        docker push $remoteImage
        Write-ColorOutput "[SUCCESS] $imageName pushed successfully" "Green"
        $successCount++
    } catch {
        Write-ColorOutput "[ERROR] $imageName push failed: $_" "Red"
    }
}

# Summary
Write-ColorOutput "`n=== Push Results ===" "Blue"
Write-ColorOutput "Successfully pushed: $successCount/$totalCount" "Green"

if ($successCount -eq $totalCount) {
    Write-ColorOutput "[SUCCESS] All images pushed successfully!" "Green"
} else {
    Write-ColorOutput "[WARNING] Some images failed to push" "Yellow"
}

Write-ColorOutput "`n=== Usage Examples ===" "Blue"
Write-ColorOutput "1. Basic usage: .\push-all-to-swr.ps1 -UseHardcodedLogin" "Yellow"
Write-ColorOutput "2. With version: .\push-all-to-swr.ps1 -UseHardcodedLogin -Version 'v1.0.0'" "Yellow"
Write-ColorOutput "3. Different region: .\push-all-to-swr.ps1 -UseHardcodedLogin -Region 'cn-north-4'" "Yellow"
Write-ColorOutput "4. Custom namespace: .\push-all-to-swr.ps1 -UseHardcodedLogin -Namespace 'myproject'" "Yellow"