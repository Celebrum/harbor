# Harbor and Harpoon Deployment Script for Windows
# This script helps deploy Harbor with Harpoon on Windows using Docker Desktop and Kind

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Harbor + Harpoon Deployment Script for Windows" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Define variables
$HarborPath = $PSScriptRoot
$KindClusterName = "securedme-cluster"

# Check if we have admin privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Check-Prerequisites {
    Write-Host "[1] Checking prerequisites..." -ForegroundColor Green
    
    # Check if Docker is running
    try {
        docker info | Out-Null
        Write-Host "✓ Docker is running" -ForegroundColor Green
    } catch {
        Write-Host "✗ Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
        exit 1
    }
    
    # Check for WSL
    try {
        wsl --status | Out-Null
        Write-Host "✓ WSL is available" -ForegroundColor Green
    } catch {
        Write-Host "✗ WSL is not available. This script requires WSL." -ForegroundColor Red
        exit 1
    }
}

function Update-HostsFile {
    Write-Host "[2] Updating hosts file..." -ForegroundColor Green
    
    if (-not $isAdmin) {
        Write-Host "⚠ Not running as admin, cannot modify hosts file automatically" -ForegroundColor Yellow
        Write-Host "Please manually add the following entry to your hosts file (C:\Windows\System32\drivers\etc\hosts):" -ForegroundColor Yellow
        Write-Host "127.0.0.1 harbor.localhost" -ForegroundColor Cyan
        return
    }
    
    $hostsFile = "$env:windir\System32\drivers\etc\hosts"
    $hostsContent = Get-Content $hostsFile
    
    if ($hostsContent -match "harbor.localhost") {
        Write-Host "✓ hosts file already contains harbor.localhost entry" -ForegroundColor Green
    } else {
        Write-Host "Adding harbor.localhost to hosts file..." -ForegroundColor Yellow
        Add-Content -Path $hostsFile -Value "`r`n127.0.0.1 harbor.localhost"
        Write-Host "✓ hosts file updated" -ForegroundColor Green
    }
}

function Prepare-Harbor {
    Write-Host "[3] Preparing Harbor with Harpoon..." -ForegroundColor Green
    
    # Check if harbor.yml exists
    if (-not (Test-Path "$HarborPath\harbor.yml")) {
        Write-Host "✗ $HarborPath\harbor.yml not found" -ForegroundColor Red
        exit 1
    }
    
    # Convert Windows path to WSL path using wslpath directly
    $wslHarborPath = (wsl wslpath -u "`"$HarborPath`"").Trim()
    Write-Host "WSL path: $wslHarborPath" -ForegroundColor Yellow
    
    # Verify the path exists in WSL
    $pathExists = (wsl test -d "$wslHarborPath" && echo "true" || echo "false").Trim()
    if ($pathExists -eq "false") {
        Write-Host "✗ Path does not exist in WSL: $wslHarborPath" -ForegroundColor Red
        
        # Let's check if the parent directory exists
        $parentPath = (wsl dirname "$wslHarborPath").Trim()
        $parentExists = (wsl test -d "$parentPath" && echo "true" || echo "false").Trim()
        Write-Host "Parent directory ($parentPath) exists: $parentExists" -ForegroundColor Yellow
        
        # List the contents of the parent directory to help troubleshoot
        Write-Host "Contents of parent directory:" -ForegroundColor Yellow
        wsl ls -la "$parentPath"
        
        exit 1
    }
    
    # Check if make/prepare exists
    $prepareScriptExists = (wsl test -f "$wslHarborPath/make/prepare" && echo "true" || echo "false").Trim()
    if ($prepareScriptExists -eq "false") {
        Write-Host "✗ Prepare script not found at $wslHarborPath/make/prepare" -ForegroundColor Red
        
        # List contents of the make directory if it exists
        $makeDirExists = (wsl test -d "$wslHarborPath/make" && echo "true" || echo "false").Trim()
        if ($makeDirExists -eq "true") {
            Write-Host "Contents of make directory:" -ForegroundColor Yellow
            wsl ls -la "$wslHarborPath/make"
        } else {
            Write-Host "  make directory not found!" -ForegroundColor Red
        }
        
        exit 1
    }
    
    # Make the prepare script executable
    wsl chmod +x "$wslHarborPath/make/prepare"
    
    # Run the prepare script
    Write-Host "Running prepare script with bash -c 'cd $wslHarborPath && bash make/prepare'" -ForegroundColor Yellow
    wsl bash -c "cd '$wslHarborPath' && bash make/prepare"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Harbor prepare script failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Harbor prepared successfully" -ForegroundColor Green
}

function Deploy-HarborToDocker {
    Write-Host "[4] Deploying Harbor with Docker Compose..." -ForegroundColor Green
    
    # Check if docker-compose.yml exists
    if (-not (Test-Path "$HarborPath\docker-compose.yml")) {
        Write-Host "✗ $HarborPath\docker-compose.yml not found" -ForegroundColor Red
        Write-Host "Make sure the prepare script ran successfully" -ForegroundColor Yellow
        exit 1
    }
    
    # Convert Windows path to WSL path
    $wslHarborPath = (wsl wslpath -u "`"$HarborPath`"").Trim()
    
    # Run docker-compose up
    Write-Host "Starting Harbor containers..." -ForegroundColor Yellow
    wsl bash -c "cd '$wslHarborPath' && docker-compose up -d"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to start Harbor containers" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Harbor containers started successfully" -ForegroundColor Green
}

function Show-HarborInfo {
    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host "Harbor + Harpoon Deployment Complete!" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "Access Harbor at: http://harbor.localhost" -ForegroundColor Green
    Write-Host "Username: admin" -ForegroundColor Green
    Write-Host "Password: Harbor12345" -ForegroundColor Green
    Write-Host "`nTo use Harbor with Docker:" -ForegroundColor Yellow
    Write-Host "1. docker login harbor.localhost" -ForegroundColor Yellow
    Write-Host "2. docker tag IMAGE_NAME harbor.localhost/PROJECT_NAME/IMAGE_NAME" -ForegroundColor Yellow
    Write-Host "3. docker push harbor.localhost/PROJECT_NAME/IMAGE_NAME" -ForegroundColor Yellow
    Write-Host "`nTo stop Harbor:" -ForegroundColor Yellow
    Write-Host "cd $HarborPath && docker-compose down" -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Cyan
}

# Main execution
try {
    Check-Prerequisites
    Update-HostsFile
    Prepare-Harbor
    Deploy-HarborToDocker
    Show-HarborInfo
} catch {
    Write-Host "An error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}