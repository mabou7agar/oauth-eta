# USB Token Server - Windows Native Startup Script
# ================================================

Write-Host "Starting USB Token Server (Windows Native Version)..." -ForegroundColor Green
Write-Host "This version bypasses PKCS#11 tool issues and uses Windows native APIs" -ForegroundColor Cyan
Write-Host ""

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Host "Node.js version: $nodeVersion" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: Node.js is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Node.js from https://nodejs.org/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if npm dependencies are installed
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing Node.js dependencies..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to install dependencies" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# Set environment variables for Windows
$env:NODE_ENV = "development"
$env:PORT = "3000"
$env:CORS_ORIGIN = "*"
$env:LOG_LEVEL = "info"

# Create directories if they don't exist
if (-not (Test-Path "temp")) { New-Item -ItemType Directory -Path "temp" }
if (-not (Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" }

Write-Host ""
Write-Host "USB Token Server Configuration (Windows Native):" -ForegroundColor Cyan
Write-Host "- Port: $($env:PORT)"
Write-Host "- Environment: $($env:NODE_ENV)"
Write-Host "- CORS Origin: $($env:CORS_ORIGIN)"
Write-Host "- Method: Windows Native APIs + PKCS#11 fallback"
Write-Host ""

# Check for smart card readers
Write-Host "Checking for smart card readers..." -ForegroundColor Yellow
try {
    $scInfo = certutil -scinfo 2>&1
    if ($scInfo -match "Smart Card Reader") {
        Write-Host "✅ Smart card readers detected!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  No smart card readers detected" -ForegroundColor Yellow
        Write-Host "   Make sure your USB token is connected" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠️  Could not check smart card status" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Starting Windows Native USB Token Server..." -ForegroundColor Green
Write-Host "Server will be available at: http://localhost:$($env:PORT)" -ForegroundColor Cyan
Write-Host "Health check: http://localhost:$($env:PORT)/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "This version uses:" -ForegroundColor Yellow
Write-Host "- Windows Certificate Store (certutil)" -ForegroundColor Gray
Write-Host "- Smart Card detection (certutil -scinfo)" -ForegroundColor Gray
Write-Host "- PKCS#11 fallback (if available)" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

try {
    node server-windows-native.js
} catch {
    Write-Host "Server stopped" -ForegroundColor Red
} finally {
    Write-Host ""
    Read-Host "Press Enter to exit"
}
