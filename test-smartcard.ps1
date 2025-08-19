# Smart Card Testing Script
# ========================

Write-Host "Smart Card Detection and Testing" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Basic smart card reader detection
Write-Host "1. Testing smart card reader detection..." -ForegroundColor Yellow
try {
    $readers = certutil -scinfo 2>&1
    Write-Host "✅ certutil -scinfo output:" -ForegroundColor Green
    Write-Host $readers -ForegroundColor Gray
} catch {
    Write-Host "❌ certutil -scinfo failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "2. Testing alternative smart card detection..." -ForegroundColor Yellow

# Test 2: Try different certutil commands
$commands = @(
    "certutil -scinfo",
    "certutil -csp",
    "certutil -store -user My",
    "certutil -store Root"
)

foreach ($cmd in $commands) {
    Write-Host "   Testing: $cmd" -ForegroundColor Cyan
    try {
        $result = Invoke-Expression $cmd 2>&1
        if ($result -match "Smart Card|Certificate|Provider") {
            Write-Host "   ✅ Success - Found relevant info" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  No relevant info found" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ❌ Failed: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 3: Check Windows Certificate Store
Write-Host "3. Checking Windows Certificate Store..." -ForegroundColor Yellow
try {
    $certs = Get-ChildItem -Path Cert:\CurrentUser\My 2>&1
    if ($certs.Count -gt 0) {
        Write-Host "   ✅ Found $($certs.Count) certificates in user store" -ForegroundColor Green
        foreach ($cert in $certs) {
            Write-Host "   - Subject: $($cert.Subject)" -ForegroundColor Gray
            Write-Host "     Issuer: $($cert.Issuer)" -ForegroundColor Gray
            Write-Host "     Valid: $($cert.NotBefore) to $($cert.NotAfter)" -ForegroundColor Gray
            Write-Host ""
        }
    } else {
        Write-Host "   ⚠️  No certificates found in user store" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Failed to access certificate store: $_" -ForegroundColor Red
}

# Test 4: Check for CSP (Cryptographic Service Providers)
Write-Host "4. Checking Cryptographic Service Providers..." -ForegroundColor Yellow
try {
    $cspResult = certutil -csp 2>&1
    if ($cspResult -match "Provider") {
        Write-Host "   ✅ CSP information available" -ForegroundColor Green
        Write-Host $cspResult -ForegroundColor Gray
    } else {
        Write-Host "   ⚠️  No CSP information found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ CSP check failed: $_" -ForegroundColor Red
}

# Test 5: Try PowerShell smart card detection
Write-Host ""
Write-Host "5. PowerShell smart card detection..." -ForegroundColor Yellow
try {
    # Try to get smart card readers using .NET
    Add-Type -AssemblyName System.Security
    $readers = [System.Security.Cryptography.X509Certificates.X509Certificate2UI]::SelectFromCollection(
        (Get-ChildItem Cert:\CurrentUser\My),
        "Select Certificate",
        "Choose a certificate",
        0
    )
    Write-Host "   ✅ PowerShell certificate selection available" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  PowerShell certificate UI not available: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "6. Recommendations based on results:" -ForegroundColor Cyan

# Provide recommendations
Write-Host "   📋 Next steps:" -ForegroundColor Yellow
Write-Host "   1. If you see 'Smart Card Reader' above, your token is detected" -ForegroundColor Gray
Write-Host "   2. If you see certificates, they might be on the smart card" -ForegroundColor Gray
Write-Host "   3. Try running the USB Token Server with these findings" -ForegroundColor Gray
Write-Host "   4. The error 'cannot perform requested operation' might be resolved with proper PIN" -ForegroundColor Gray

Write-Host ""
Write-Host "Testing complete!" -ForegroundColor Green
Read-Host "Press Enter to exit"
