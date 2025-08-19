/**
 * Generic PKCS#11 Test for ePass2003 without official drivers
 * Attempts to use alternative PKCS#11 libraries
 */

const fs = require('fs');
const path = require('path');

// Alternative PKCS#11 libraries to try
const alternativeLibraries = [
    process.env.ETA_USB_TOKEN_PKCS11_LIB,        // User-specified library
    'eps2003cps11.dll',                          // ePass2003 PKCS#11 (found!)
    'C:\\Windows\\System32\\eps2003cps11.dll',   // ePass2003 system location
    'C:\\Program Files\\ePass2003\\eps2003cps11.dll', // ePass2003 program files
    'C:\\Windows\\System32\\opensc-pkcs11.dll',  // OpenSC (open source)
    'C:\\Program Files\\OpenSC Project\\OpenSC\\pkcs11\\opensc-pkcs11.dll',
    'C:\\Windows\\System32\\msclmd.dll',         // Microsoft Smart Card Base CSP
    'C:\\Windows\\System32\\basecsp.dll',        // Windows Base CSP
    'C:\\Windows\\SysWOW64\\opensc-pkcs11.dll'   // 32-bit OpenSC
].filter(Boolean); // Remove undefined values

console.log('🔍 Generic PKCS#11 Test for ePass2003');
console.log('=====================================');

// Check for alternative PKCS#11 libraries
console.log('\n1. Checking for alternative PKCS#11 libraries:');
let foundLibrary = null;

for (const lib of alternativeLibraries) {
    if (fs.existsSync(lib)) {
        console.log(`   ✅ Found: ${lib}`);
        if (!foundLibrary) foundLibrary = lib;
    } else {
        console.log(`   ❌ Not found: ${lib}`);
    }
}

if (!foundLibrary) {
    console.log('\n❌ No PKCS#11 libraries found');
    console.log('💡 Solutions:');
    console.log('   1. Install ePass2003 PKI Client from Feitian Technology');
    console.log('   2. Install OpenSC (open source smart card library)');
    console.log('   3. Download from: https://github.com/OpenSC/OpenSC/releases');
    process.exit(1);
}

console.log(`\n2. Testing with: ${foundLibrary}`);

// Test basic PKCS#11 functionality
try {
    // Try to load pkcs11js (if available)
    let pkcs11;
    try {
        pkcs11 = require('pkcs11js');
    } catch (e) {
        console.log('❌ pkcs11js module not available');
        console.log('💡 Install with: npm install pkcs11js');
        
        // Alternative: Test with basic Node.js
        console.log('\n3. Testing basic library loading:');
        const { execSync } = require('child_process');
        
        try {
            // Test if library can be loaded by system
            execSync(`powershell "Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class Test { [DllImport(\\"kernel32.dll\\")] public static extern IntPtr LoadLibrary(string path); }'; [Test]::LoadLibrary('${foundLibrary}')"`);
            console.log('   ✅ Library can be loaded by system');
        } catch (e) {
            console.log('   ❌ Library load failed');
        }
        
        return;
    }

    // Initialize PKCS#11
    pkcs11.load(foundLibrary);
    pkcs11.C_Initialize();

    // Get slots
    const slots = pkcs11.C_GetSlotList(true);
    console.log(`   Found ${slots.length} slot(s) with tokens`);

    if (slots.length === 0) {
        console.log('   ❌ No tokens found');
        console.log('   💡 Make sure ePass2003 token is inserted');
    } else {
        console.log('   ✅ Token(s) detected!');
        
        // Get slot info
        for (const slot of slots) {
            try {
                const slotInfo = pkcs11.C_GetSlotInfo(slot);
                console.log(`   Slot ${slot}: ${slotInfo.slotDescription.trim()}`);
                
                const tokenInfo = pkcs11.C_GetTokenInfo(slot);
                console.log(`     Token: ${tokenInfo.label.trim()}`);
                console.log(`     Manufacturer: ${tokenInfo.manufacturerID.trim()}`);
            } catch (e) {
                console.log(`   Slot ${slot}: Error getting info - ${e.message}`);
            }
        }
    }

    // Cleanup
    pkcs11.C_Finalize();

} catch (error) {
    console.log(`❌ PKCS#11 test failed: ${error.message}`);
    
    if (error.message.includes('cannot open shared object file')) {
        console.log('💡 Library dependencies missing');
    } else if (error.message.includes('invalid ELF header')) {
        console.log('💡 Architecture mismatch (32-bit vs 64-bit)');
    }
}

console.log('\n4. Recommendations:');
console.log('   For best ePass2003 support:');
console.log('   1. Install official ePass2003 PKI Client from Feitian');
console.log('   2. Restart Windows after installation');
console.log('   3. Test with: certutil -scinfo');
console.log('   4. Configure Laravel with proper PKCS#11 path');

console.log('\n   Alternative (if official software unavailable):');
console.log('   1. Install OpenSC: https://github.com/OpenSC/OpenSC/releases');
console.log('   2. Use OpenSC PKCS#11 library instead');
console.log('   3. May have limited ePass2003 functionality');
