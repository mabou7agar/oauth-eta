# USB Token Server - Windows Diagnostic Script
# =============================================

Write-Host "USB Token Server - Windows Diagnostics" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Check Node.js installation
Write-Host "1. Checking Node.js installation..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version
    Write-Host "   ✅ Node.js version: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Node.js not found - Please install from https://nodejs.org/" -ForegroundColor Red
    exit 1
}

# Check OpenSC installation
Write-Host ""
Write-Host "2. Checking OpenSC installation..." -ForegroundColor Yellow

# Check for pkcs11-tool
try {
    $pkcs11ToolVersion = pkcs11-tool --version 2>&1
    Write-Host "   ✅ pkcs11-tool found" -ForegroundColor Green
} catch {
    Write-Host "   ❌ pkcs11-tool not found in PATH" -ForegroundColor Red
}

# Search for PKCS#11 libraries
Write-Host ""
Write-Host "3. Searching for PKCS#11 libraries..." -ForegroundColor Yellow

$pkcs11Paths = @(
    "C:\Program Files\OpenSC Project\OpenSC\pkcs11\opensc-pkcs11.dll",
    "C:\Program Files (x86)\OpenSC Project\OpenSC\pkcs11\opensc-pkcs11.dll",
    "C:\Windows\System32\opensc-pkcs11.dll",
    "C:\Program Files\OpenSC Project\OpenSC\pkcs11\onepin-opensc-pkcs11.dll",
    "C:\Program Files (x86)\OpenSC Project\OpenSC\pkcs11\onepin-opensc-pkcs11.dll"
)

$foundLibraries = @()
foreach ($path in $pkcs11Paths) {
    if (Test-Path $path) {
        $foundLibraries += $path
        Write-Host "   ✅ Found: $path" -ForegroundColor Green
        
        # Get file info
        $fileInfo = Get-Item $path
        Write-Host "      Size: $($fileInfo.Length) bytes, Modified: $($fileInfo.LastWriteTime)" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ Not found: $path" -ForegroundColor Red
    }
}

if ($foundLibraries.Count -eq 0) {
    Write-Host "   ⚠️  No PKCS#11 libraries found!" -ForegroundColor Yellow
    Write-Host "   Please install OpenSC from: https://github.com/OpenSC/OpenSC/releases" -ForegroundColor Yellow
} else {
    Write-Host "   📊 Found $($foundLibraries.Count) PKCS#11 library(ies)" -ForegroundColor Cyan
}

# Check USB token detection
Write-Host ""
Write-Host "4. Testing USB token detection..." -ForegroundColor Yellow

if ($foundLibraries.Count -gt 0) {
    $testLibrary = $foundLibraries[0]
    Write-Host "   Using library: $testLibrary" -ForegroundColor Cyan
    
    try {
        # Test with pkcs11-tool if available
        $slotsOutput = pkcs11-tool --module "$testLibrary" --list-slots 2>&1
        
        if ($slotsOutput -match "Available slots") {
            Write-Host "   ✅ PKCS#11 library loaded successfully" -ForegroundColor Green
            
            if ($slotsOutput -match "token present") {
                Write-Host "   ✅ USB token detected!" -ForegroundColor Green
                Write-Host "   $slotsOutput" -ForegroundColor Gray
            } else {
                Write-Host "   ⚠️  No USB token detected (no token present)" -ForegroundColor Yellow
                Write-Host "   Make sure your USB token is connected and drivers are installed" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ❌ Failed to load PKCS#11 library" -ForegroundColor Red
            Write-Host "   Error: $slotsOutput" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Error testing PKCS#11 library: $_" -ForegroundColor Red
    }
} else {
    Write-Host "   ⚠️  Cannot test - no PKCS#11 libraries found" -ForegroundColor Yellow
}

# Check Windows architecture
Write-Host ""
Write-Host "5. System Information..." -ForegroundColor Yellow
$arch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
Write-Host "   Windows Architecture: $arch" -ForegroundColor Cyan

if ($arch -eq "64-bit") {
    Write-Host "   💡 Tip: Use 64-bit OpenSC version for best compatibility" -ForegroundColor Cyan
} else {
    Write-Host "   💡 Tip: Use 32-bit OpenSC version for your system" -ForegroundColor Cyan
}

# Recommendations
Write-Host ""
Write-Host "6. Recommendations..." -ForegroundColor Yellow

if ($foundLibraries.Count -eq 0) {
    Write-Host "   📥 Install OpenSC:" -ForegroundColor Yellow
    Write-Host "      1. Download from: https://github.com/OpenSC/OpenSC/releases" -ForegroundColor Gray
    Write-Host "      2. Choose the appropriate version for your Windows architecture" -ForegroundColor Gray
    Write-Host "      3. Run as Administrator and install with 'Complete' option" -ForegroundColor Gray
} else {
    Write-Host "   🚀 Ready to run USB Token Server:" -ForegroundColor Green
    Write-Host "      Recommended PKCS#11 library: $($foundLibraries[0])" -ForegroundColor Gray
    Write-Host "      Run: .\start-windows.ps1" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Diagnostics complete!" -ForegroundColor Cyan
Read-Host "Press Enter to exit"
