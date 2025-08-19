# USB Token Private Key Export Script
# Exports certificate with private key from USB token for Laravel ETA integration

param(
    [string]$OutputPath = ".\exported-certificate.pfx",
    [string]$Password = "",
    [switch]$ListCertificates = $false
)

Write-Host "🔐 USB Token Private Key Export Script" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

if ($ListCertificates) {
    Write-Host "📋 Available certificates with private keys:" -ForegroundColor Yellow
    
    # List certificates with private keys
    $certs = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.HasPrivateKey -eq $true }
    
    if ($certs.Count -eq 0) {
        Write-Host "❌ No certificates with private keys found" -ForegroundColor Red
        Write-Host "💡 Make sure your USB token is connected and certificates are installed" -ForegroundColor Yellow
        exit 1
    }
    
    for ($i = 0; $i -lt $certs.Count; $i++) {
        $cert = $certs[$i]
        Write-Host "[$i] Subject: $($cert.Subject)" -ForegroundColor Cyan
        Write-Host "    Issuer: $($cert.Issuer)" -ForegroundColor Gray
        Write-Host "    Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
        Write-Host "    Valid: $($cert.NotBefore) to $($cert.NotAfter)" -ForegroundColor Gray
        Write-Host "    Has Private Key: $($cert.HasPrivateKey)" -ForegroundColor Green
        Write-Host ""
    }
    
    Write-Host "💡 To export a certificate, run:" -ForegroundColor Yellow
    Write-Host "   .\export-private-key.ps1 -OutputPath 'my-certificate.pfx'" -ForegroundColor White
    exit 0
}

# Get password if not provided
if ([string]::IsNullOrEmpty($Password)) {
    $SecurePassword = Read-Host "Enter password for PFX file" -AsSecureString
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword))
}

Write-Host "🔍 Searching for certificates with private keys..." -ForegroundColor Yellow

# Find certificates with private keys
$certificates = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.HasPrivateKey -eq $true }

if ($certificates.Count -eq 0) {
    Write-Host "❌ No certificates with private keys found" -ForegroundColor Red
    Write-Host "💡 Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "   1. Ensure USB token is connected" -ForegroundColor White
    Write-Host "   2. Install USB token software/drivers" -ForegroundColor White
    Write-Host "   3. Import certificate to Windows certificate store" -ForegroundColor White
    Write-Host "   4. Run: .\export-private-key.ps1 -ListCertificates" -ForegroundColor White
    exit 1
}

Write-Host "✅ Found $($certificates.Count) certificate(s) with private keys" -ForegroundColor Green

# If multiple certificates, let user choose
if ($certificates.Count -gt 1) {
    Write-Host "📋 Multiple certificates found:" -ForegroundColor Yellow
    
    for ($i = 0; $i -lt $certificates.Count; $i++) {
        $cert = $certificates[$i]
        Write-Host "[$i] $($cert.Subject)" -ForegroundColor Cyan
    }
    
    do {
        $selection = Read-Host "Enter certificate number to export [0-$($certificates.Count - 1)]"
        $selectedIndex = [int]$selection
    } while ($selectedIndex -lt 0 -or $selectedIndex -ge $certificates.Count)
    
    $selectedCert = $certificates[$selectedIndex]
} else {
    $selectedCert = $certificates[0]
}

Write-Host "🎯 Selected certificate:" -ForegroundColor Green
Write-Host "   Subject: $($selectedCert.Subject)" -ForegroundColor White
Write-Host "   Issuer: $($selectedCert.Issuer)" -ForegroundColor White
Write-Host "   Thumbprint: $($selectedCert.Thumbprint)" -ForegroundColor White

try {
    Write-Host "📦 Exporting certificate with private key..." -ForegroundColor Yellow
    
    # Convert password to secure string
    $SecurePassword = ConvertTo-SecureString -String $Password -Force -AsPlainText
    
    # Export certificate with private key
    Export-PfxCertificate -Cert $selectedCert -FilePath $OutputPath -Password $SecurePassword -Force | Out-Null
    
    if (Test-Path $OutputPath) {
        Write-Host "✅ Certificate exported successfully!" -ForegroundColor Green
        Write-Host "📁 File: $OutputPath" -ForegroundColor White
        Write-Host "🔐 Password: [Protected]" -ForegroundColor White
        
        # Get file size
        $fileSize = (Get-Item $OutputPath).Length
        Write-Host "📊 Size: $fileSize bytes" -ForegroundColor White
        
        Write-Host ""
        Write-Host "🚀 Next steps for Laravel integration:" -ForegroundColor Yellow
        Write-Host "   1. Copy the PFX file to your Laravel server" -ForegroundColor White
        Write-Host "   2. Import using Laravel command:" -ForegroundColor White
        Write-Host "      php artisan eta:import-certificate '$OutputPath' my-eta-cert --type=taxpayer --configure" -ForegroundColor Cyan
        Write-Host "   3. Use the password you set when prompted" -ForegroundColor White
        
        Write-Host ""
        Write-Host "💡 Alternative: Convert to separate CER + KEY files:" -ForegroundColor Yellow
        Write-Host "   openssl pkcs12 -in '$OutputPath' -clcerts -nokeys -out certificate.cer" -ForegroundColor Gray
        Write-Host "   openssl pkcs12 -in '$OutputPath' -nocerts -nodes -out private.key" -ForegroundColor Gray
        
    } else {
        Write-Host "❌ Export failed - file not created" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "❌ Export failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Common issues:" -ForegroundColor Yellow
    Write-Host "   • USB token not connected or accessible" -ForegroundColor White
    Write-Host "   • Certificate doesn't have exportable private key" -ForegroundColor White
    Write-Host "   • Insufficient permissions" -ForegroundColor White
    Write-Host "   • USB token PIN not entered" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "🔒 Security Notes:" -ForegroundColor Yellow
Write-Host "   • Keep the PFX file secure" -ForegroundColor White
Write-Host "   • Use a strong password" -ForegroundColor White
Write-Host "   • Delete the file after importing to Laravel" -ForegroundColor White
Write-Host "   • Never share the private key" -ForegroundColor White
