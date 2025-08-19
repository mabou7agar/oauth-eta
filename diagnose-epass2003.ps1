# ePass2003 USB Token Diagnostic Script
# Specifically designed for ePass2003 tokens and "cannot perform requested operation" errors

Write-Host "ePass2003 USB Token Diagnostic Script" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

Write-Host "Checking ePass2003 token status..." -ForegroundColor Yellow

# Check 1: ePass2003 Software Installation
Write-Host "`n1. Checking ePass2003 Software Installation:" -ForegroundColor Cyan

$ePassPaths = @(
    "C:\Program Files\ePass2003\ePass2003CSP.dll",
    "C:\Windows\System32\ePass2003CSP.dll",
    "C:\Program Files (x86)\ePass2003\ePass2003CSP.dll"
)

$ePassFound = $false
foreach ($path in $ePassPaths) {
    if (Test-Path $path) {
        Write-Host "   Found: $path" -ForegroundColor Green
        $ePassFound = $true
        
        # Get file version
        $version = (Get-Item $path).VersionInfo.FileVersion
        Write-Host "   Version: $version" -ForegroundColor White
    }
}

if (-not $ePassFound) {
    Write-Host "   ePass2003 software not found!" -ForegroundColor Red
    Write-Host "   Download from: Feitian Technology website" -ForegroundColor Yellow
    Write-Host "   Install ePass2003 PKI Client" -ForegroundColor Yellow
}

# Check 2: Smart Card Service
Write-Host "`n2. Checking Smart Card Service:" -ForegroundColor Cyan

$scService = Get-Service -Name "SCardSvr" -ErrorAction SilentlyContinue
if ($scService) {
    Write-Host "   Smart Card Service: $($scService.Status)" -ForegroundColor $(if ($scService.Status -eq "Running") { "Green" } else { "Red" })
    
    if ($scService.Status -ne "Running") {
        Write-Host "   Starting Smart Card Service..." -ForegroundColor Yellow
        try {
            Start-Service -Name "SCardSvr"
            Write-Host "   Smart Card Service started" -ForegroundColor Green
        } catch {
            Write-Host "   Failed to start Smart Card Service: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "   Smart Card Service not found" -ForegroundColor Red
}

# Check 3: ePass2003 Token Detection
Write-Host "`n3. Checking ePass2003 Token Detection:" -ForegroundColor Cyan

try {
    # Check smart card readers
    $readers = certutil -scinfo 2>&1
    if ($readers -match "ePass2003" -or $readers -match "Feitian") {
        Write-Host "   ePass2003 token detected!" -ForegroundColor Green
    } else {
        Write-Host "   ePass2003 token not detected" -ForegroundColor Red
        Write-Host "   Make sure token is inserted and drivers are installed" -ForegroundColor Yellow
    }
    
    # Show reader info
    Write-Host "   Smart card readers:" -ForegroundColor White
    $readers | ForEach-Object { 
        if ($_ -match "Reader|Card|ePass|Feitian") {
            Write-Host "     $_" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "   Failed to check smart card info: $($_.Exception.Message)" -ForegroundColor Red
}

# Check 4: Certificate Store
Write-Host "`n4. Checking Certificate Store:" -ForegroundColor Cyan

try {
    # Check for certificates in personal store
    $certs = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -match "ePass|Feitian" -or $_.Issuer -match "ePass|Feitian" }
    
    if ($certs.Count -gt 0) {
        Write-Host "   Found $($certs.Count) ePass2003 certificate(s)" -ForegroundColor Green
        foreach ($cert in $certs) {
            Write-Host "     Subject: $($cert.Subject)" -ForegroundColor White
            Write-Host "     Has Private Key: $($cert.HasPrivateKey)" -ForegroundColor $(if ($cert.HasPrivateKey) { "Green" } else { "Red" })
        }
    } else {
        Write-Host "   No ePass2003 certificates found in personal store" -ForegroundColor Red
        Write-Host "   Try importing certificate using ePass2003 PKI Client" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Failed to check certificate store: $($_.Exception.Message)" -ForegroundColor Red
}

# Check 5: PKCS#11 Library Test
Write-Host "`n5. Testing PKCS#11 Library:" -ForegroundColor Cyan

$pkcs11Paths = @(
    "C:\Program Files\ePass2003\ePass2003CSP.dll",
    "C:\Windows\System32\ePass2003CSP.dll"
)

foreach ($path in $pkcs11Paths) {
    if (Test-Path $path) {
        Write-Host "   Testing: $path" -ForegroundColor White
        
        # Try to load the library (basic test)
        try {
            $lib = [System.Reflection.Assembly]::LoadFile($path)
            Write-Host "     Library can be loaded" -ForegroundColor Green
        } catch {
            Write-Host "     Library load test failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Check 6: Registry Settings
Write-Host "`n6. Checking Registry Settings:" -ForegroundColor Cyan

$regPaths = @(
    "HKLM:\SOFTWARE\Feitian",
    "HKLM:\SOFTWARE\WOW6432Node\Feitian",
    "HKCU:\SOFTWARE\Feitian"
)

$regFound = $false
foreach ($regPath in $regPaths) {
    if (Test-Path $regPath) {
        Write-Host "   Found: $regPath" -ForegroundColor Green
        $regFound = $true
    }
}

if (-not $regFound) {
    Write-Host "   No Feitian registry entries found" -ForegroundColor Red
    Write-Host "   ePass2003 software may not be properly installed" -ForegroundColor Yellow
}

# Recommendations
Write-Host "`n7. Recommendations:" -ForegroundColor Cyan

Write-Host "   For 'cannot perform requested operation' error:" -ForegroundColor Yellow
Write-Host "     1. Install ePass2003 PKI Client from Feitian Technology" -ForegroundColor White
Write-Host "     2. Restart Windows after installation" -ForegroundColor White
Write-Host "     3. Insert ePass2003 token and enter PIN in PKI Client" -ForegroundColor White
Write-Host "     4. Import certificate to Windows certificate store" -ForegroundColor White
Write-Host "     5. Test with: certutil -scinfo" -ForegroundColor White

Write-Host "`n   For Laravel ETA integration:" -ForegroundColor Yellow
Write-Host "     1. Use USB token mode instead of certificate export" -ForegroundColor White
Write-Host "     2. Configure: ETA_USE_USB_TOKEN=true" -ForegroundColor White
Write-Host "     3. Set: ETA_USB_TOKEN_PIN=your_pin" -ForegroundColor White
Write-Host "     4. Start: .\start-windows-native.ps1" -ForegroundColor White

Write-Host "`n   Next steps:" -ForegroundColor Yellow
Write-Host "     1. Fix any issues found above" -ForegroundColor White
Write-Host "     2. Test with: .\test-epass2003.ps1" -ForegroundColor White
Write-Host "     3. Configure Laravel environment" -ForegroundColor White
Write-Host "     4. Test ETA integration" -ForegroundColor White

Write-Host "`nDiagnostic complete!" -ForegroundColor Green
