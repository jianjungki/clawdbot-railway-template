# Railway 本地测试脚本 (PowerShell)
# 用法: .\scripts\test-local.ps1 [选项]

param(
    [Parameter(Position=0)]
    [ValidateSet('build', 'start', 'stop', 'logs', 'test', 'clean', 'full')]
    [string]$Action = 'full',
    
    [switch]$Follow,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ImageName = "moltbot-railway-test"
$ContainerName = "moltbot-test"
$Port = 8080

function Show-Help {
    Write-Host @"
Railway 本地测试脚本

用法: .\scripts\test-local.ps1 [操作] [选项]

操作:
  build    仅构建 Docker 镜像
  start    启动容器（需要先构建）
  stop     停止容器
  logs     查看容器日志
  test     测试健康检查端点
  clean    清理容器和镜像
  full     完整测试流程（默认）

选项:
  -Follow  实时跟踪日志输出
  -Help    显示此帮助信息

示例:
  .\scripts\test-local.ps1                # 运行完整测试
  .\scripts\test-local.ps1 build          # 仅构建镜像
  .\scripts\test-local.ps1 logs -Follow  # 实时查看日志
  .\scripts\test-local.ps1 test           # 测试健康检查
"@
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Build-Image {
    Write-Step "构建 Docker 镜像..."
    Write-Host "注意：这可能需要 10-20 分钟" -ForegroundColor Yellow
    docker build -t $ImageName .
    if ($LASTEXITCODE -eq 0) {
        Write-Success "镜像构建成功"
    } else {
        Write-Error-Custom "镜像构建失败"
        exit 1
    }
}

function Start-Container {
    Write-Step "启动容器..."
    
    # 检查容器是否已存在
    $existing = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}"
    if ($existing -eq $ContainerName) {
        Write-Host "容器已存在，正在删除..." -ForegroundColor Yellow
        docker rm -f $ContainerName | Out-Null
    }
    
    # 检查端口是否被占用
    $portCheck = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if ($portCheck) {
        Write-Error-Custom "端口 $Port 已被占用"
        Write-Host "使用以下命令查看占用进程:" -ForegroundColor Yellow
        Write-Host "  Get-Process -Id (Get-NetTCPConnection -LocalPort $Port).OwningProcess"
        exit 1
    }
    
    docker run -d `
        --name $ContainerName `
        -p "${Port}:${Port}" `
        -e "PORT=$Port" `
        -e "MOLTBOT_PUBLIC_PORT=$Port" `
        $ImageName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "容器已启动"
        Write-Host "容器名称: $ContainerName" -ForegroundColor Gray
        Write-Host "访问地址: http://localhost:$Port" -ForegroundColor Gray
    } else {
        Write-Error-Custom "容器启动失败"
        exit 1
    }
}

function Stop-Container {
    Write-Step "停止容器..."
    docker stop $ContainerName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "容器已停止"
    } else {
        Write-Host "容器未运行或不存在" -ForegroundColor Yellow
    }
}

function Show-Logs {
    Write-Step "查看容器日志..."
    if ($Follow) {
        docker logs -f $ContainerName
    } else {
        docker logs --tail 50 $ContainerName
    }
}

function Test-HealthCheck {
    Write-Step "测试健康检查端点..."
    
    # 检查容器是否运行
    $running = docker ps --filter "name=$ContainerName" --format "{{.Names}}"
    if ($running -ne $ContainerName) {
        Write-Error-Custom "容器未运行"
        exit 1
    }
    
    Write-Host "等待服务启动..." -ForegroundColor Yellow
    $maxAttempts = 60
    $attempt = 0
    $success = $false
    
    while ($attempt -lt $maxAttempts) {
        $attempt++
        Write-Host "." -NoNewline
        
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port/setup/healthz" -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                $success = $true
                break
            }
        } catch {
            # 继续等待
        }
        
        Start-Sleep -Seconds 5
    }
    
    Write-Host ""
    
    if ($success) {
        Write-Success "健康检查通过！"
        Write-Host ""
        Write-Host "测试访问主页:" -ForegroundColor Cyan
        try {
            $homeResponse = Invoke-WebRequest -Uri "http://localhost:$Port" -UseBasicParsing
            Write-Success "主页访问成功 (HTTP $($homeResponse.StatusCode))"
        } catch {
            Write-Error-Custom "主页访问失败: $_"
        }
    } else {
        Write-Error-Custom "健康检查失败（超时）"
        Write-Host "`n查看日志以了解详情:" -ForegroundColor Yellow
        docker logs --tail 20 $ContainerName
        exit 1
    }
}

function Clean-All {
    Write-Step "清理容器和镜像..."
    
    docker rm -f $ContainerName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "容器已删除"
    }
    
    docker rmi $ImageName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "镜像已删除"
    }
    
    Write-Success "清理完成"
}

function Run-FullTest {
    Write-Host @"
╔══════════════════════════════════════════════════════╗
║     Railway 本地部署测试 - 完整流程                 ║
╚══════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    Build-Image
    Start-Container
    Test-HealthCheck
    
    Write-Host @"

╔══════════════════════════════════════════════════════╗
║                  测试完成！                          ║
╚══════════════════════════════════════════════════════╝

下一步:
  • 在浏览器中访问: http://localhost:$Port
  • 查看实时日志: .\scripts\test-local.ps1 logs -Follow
  • 停止容器: .\scripts\test-local.ps1 stop
  • 清理资源: .\scripts\test-local.ps1 clean

"@ -ForegroundColor Green
}

# 主逻辑
if ($Help) {
    Show-Help
    exit 0
}

# 检查 Docker 是否安装
try {
    docker --version | Out-Null
} catch {
    Write-Error-Custom "Docker 未安装或未运行"
    Write-Host "请先安装 Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

switch ($Action) {
    'build' { Build-Image }
    'start' { Start-Container }
    'stop' { Stop-Container }
    'logs' { Show-Logs }
    'test' { Test-HealthCheck }
    'clean' { Clean-All }
    'full' { Run-FullTest }
}
