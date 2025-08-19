# USB Token Server - Windows PowerShell Startup Script
# ===================================================

Write-Host "Starting USB Token Server on Windows..." -ForegroundColor Green
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

# Try to find PKCS#11 library in common Windows locations
$pkcs11Paths = @(
    "C:\Windows\System32\opensc-pkcs11.dll",
    "C:\Program Files\OpenSC Project\OpenSC\pkcs11\opensc-pkcs11.dll",
    "C:\Program Files (x86)\OpenSC Project\OpenSC\pkcs11\opensc-pkcs11.dll"
)

$pkcs11Found = $false
foreach ($path in $pkcs11Paths) {
    if (Test-Path $path) {
        $env:PKCS11_MODULE = $path
        $pkcs11Found = $true
        Write-Host "Found PKCS#11 library: $path" -ForegroundColor Green
        break
    }
}

if (-not $pkcs11Found) {
    Write-Host "WARNING: PKCS#11 library not found in standard locations" -ForegroundColor Yellow
    Write-Host "Please install OpenSC or configure PKCS11_MODULE environment variable" -ForegroundColor Yellow
    $env:PKCS11_MODULE = "opensc-pkcs11.dll"
}

# Create directories if they don't exist
if (-not (Test-Path "temp")) { New-Item -ItemType Directory -Path "temp" }
if (-not (Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" }

Write-Host ""
Write-Host "USB Token Server Configuration:" -ForegroundColor Cyan
Write-Host "- Port: $($env:PORT)"
Write-Host "- PKCS11 Module: $($env:PKCS11_MODULE)"
Write-Host "- Environment: $($env:NODE_ENV)"
Write-Host "- CORS Origin: $($env:CORS_ORIGIN)"
Write-Host ""

# Start the server
Write-Host "Starting server..." -ForegroundColor Green
Write-Host "Server will be available at: http://localhost:$($env:PORT)" -ForegroundColor Cyan
Write-Host "Health check: http://localhost:$($env:PORT)/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

try {
    node server.js
} catch {
    Write-Host "Server stopped" -ForegroundColor Red
} finally {
    Write-Host ""
    Read-Host "Press Enter to exit"
}
