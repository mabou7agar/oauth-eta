# ePass2003 PKCS#11 Library Fix Script
# Resolves LoadLibrary/GetProcAddress errors for ePass2003 tokens

Write-Host "ePass2003 PKCS#11 Library Fix Script" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green

# Common ePass2003 PKCS#11 library locations
$ePassLibraries = @(
    "C:\Windows\System32\ePass2003CSP.dll",
    "C:\Windows\SysWOW64\ePass2003CSP.dll",
    "C:\Program Files\ePass2003\ePass2003CSP.dll",
    "C:\Program Files (x86)\ePass2003\ePass2003CSP.dll",
    "C:\Program Files\Feitian\ePass2003\ePass2003CSP.dll",
    "C:\Program Files (x86)\Feitian\ePass2003\ePass2003CSP.dll",
    "C:\Windows\System32\ep2003csp11.dll",
    "C:\Windows\SysWOW64\ep2003csp11.dll"
)

Write-Host "1. Searching for ePass2003 PKCS#11 libraries..." -ForegroundColor Yellow

$foundLibraries = @()
foreach ($lib in $ePassLibraries) {
    if (Test-Path $lib) {
        Write-Host "   Found: $lib" -ForegroundColor Green
        
        # Get file details
        $file = Get-Item $lib
        $version = $file.VersionInfo.FileVersion
        $size = $file.Length
        $arch = if ($lib -match "SysWOW64|x86") { "32-bit" } else { "64-bit" }
        
        Write-Host "     Version: $version" -ForegroundColor White
        Write-Host "     Size: $size bytes" -ForegroundColor White
        Write-Host "     Architecture: $arch" -ForegroundColor White
        
        $foundLibraries += @{
            Path = $lib
            Version = $version
            Size = $size
            Architecture = $arch
        }
    }
}

if ($foundLibraries.Count -eq 0) {
    Write-Host "   No ePass2003 PKCS#11 libraries found!" -ForegroundColor Red
    Write-Host "   Please install ePass2003 PKI Client from Feitian Technology" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n2. Testing library compatibility..." -ForegroundColor Yellow

# Determine Node.js architecture
$nodeArch = node -e "console.log(process.arch)"
Write-Host "   Node.js architecture: $nodeArch" -ForegroundColor White

# Select appropriate library
$recommendedLib = $null
if ($nodeArch -eq "x64") {
    # Prefer 64-bit libraries for 64-bit Node.js
    $recommendedLib = $foundLibraries | Where-Object { $_.Architecture -eq "64-bit" } | Select-Object -First 1
    if (-not $recommendedLib) {
        $recommendedLib = $foundLibraries[0]
        Write-Host "   Warning: No 64-bit library found, using: $($recommendedLib.Path)" -ForegroundColor Yellow
    }
} else {
    # Prefer 32-bit libraries for 32-bit Node.js
    $recommendedLib = $foundLibraries | Where-Object { $_.Architecture -eq "32-bit" } | Select-Object -First 1
    if (-not $recommendedLib) {
        $recommendedLib = $foundLibraries[0]
        Write-Host "   Warning: No 32-bit library found, using: $($recommendedLib.Path)" -ForegroundColor Yellow
    }
}

Write-Host "   Recommended library: $($recommendedLib.Path)" -ForegroundColor Green

Write-Host "`n3. Testing library loading..." -ForegroundColor Yellow

# Test if library can be loaded
try {
    $testResult = Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class PKCS11Test {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr LoadLibrary(string lpFileName);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FreeLibrary(IntPtr hModule);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);
}
"@ -PassThru

    $handle = [PKCS11Test]::LoadLibrary($recommendedLib.Path)
    if ($handle -ne [IntPtr]::Zero) {
        Write-Host "   Library loads successfully" -ForegroundColor Green
        
        # Test for PKCS#11 functions
        $c_GetFunctionList = [PKCS11Test]::GetProcAddress($handle, "C_GetFunctionList")
        if ($c_GetFunctionList -ne [IntPtr]::Zero) {
            Write-Host "   PKCS#11 functions found" -ForegroundColor Green
        } else {
            Write-Host "   Warning: PKCS#11 functions not found" -ForegroundColor Yellow
        }
        
        [PKCS11Test]::FreeLibrary($handle) | Out-Null
    } else {
        Write-Host "   Failed to load library" -ForegroundColor Red
        $error = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host "   Error code: $error" -ForegroundColor Red
    }
} catch {
    Write-Host "   Library test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n4. Checking dependencies..." -ForegroundColor Yellow

# Check for common dependencies
$dependencies = @(
    "C:\Windows\System32\msvcr120.dll",
    "C:\Windows\System32\msvcp120.dll",
    "C:\Windows\System32\vcruntime140.dll"
)

foreach ($dep in $dependencies) {
    if (Test-Path $dep) {
        Write-Host "   Found: $(Split-Path $dep -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "   Missing: $(Split-Path $dep -Leaf)" -ForegroundColor Red
    }
}

Write-Host "`n5. Generating configuration..." -ForegroundColor Yellow

# Create environment configuration
$envConfig = @"
# ePass2003 PKCS#11 Configuration
# Add these to your .env file or environment variables

# PKCS#11 library path (use the recommended library)
PKCS11_MODULE=$($recommendedLib.Path)

# For USB token server
ETA_USB_TOKEN_PKCS11_LIB=$($recommendedLib.Path)
ETA_USE_USB_TOKEN=true
ETA_USB_TOKEN_PIN=your_epass2003_pin

# Alternative paths to try if the above fails:
"@

foreach ($lib in $foundLibraries) {
    $envConfig += "`n# $($lib.Path) ($($lib.Architecture))"
}

Write-Host $envConfig -ForegroundColor Cyan

# Save to file
$configFile = "epass2003-config.env"
$envConfig | Out-File -FilePath $configFile -Encoding UTF8
Write-Host "`n   Configuration saved to: $configFile" -ForegroundColor Green

Write-Host "`n6. Next steps:" -ForegroundColor Yellow
Write-Host "   1. Update your USB token server configuration:" -ForegroundColor White
Write-Host "      Set PKCS11_MODULE=$($recommendedLib.Path)" -ForegroundColor Cyan
Write-Host "   2. Restart the USB token server" -ForegroundColor White
Write-Host "   3. Test with: curl -X POST http://localhost:3000/api/usb-token/test" -ForegroundColor White
Write-Host "   4. If still failing, try other library paths from the list above" -ForegroundColor White

Write-Host "`n   Common solutions for LoadLibrary errors:" -ForegroundColor Yellow
Write-Host "   • Install Visual C++ Redistributable 2015-2019" -ForegroundColor White
Write-Host "   • Install ePass2003 PKI Client from Feitian" -ForegroundColor White
Write-Host "   • Use 64-bit library with 64-bit Node.js" -ForegroundColor White
Write-Host "   • Run as Administrator if permission issues" -ForegroundColor White

Write-Host "`nFix script complete!" -ForegroundColor Green
