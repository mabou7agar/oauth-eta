/**
 * ePass2003 PKCS#11 Test for Windows
 * Tests the found eps2003csp11.dll library
 */

const fs = require('fs');
const path = require('path');

// Your found ePass2003 PKCS#11 library
const epass2003Library = 'C:\\Windows\\System32\\eps2003csp11.dll';

console.log('🔍 ePass2003 PKCS#11 Test');
console.log('=========================');
console.log(`Testing library: ${epass2003Library}`);

// Check if library exists
if (!fs.existsSync(epass2003Library)) {
    console.log('❌ Library not found!');
    console.log('💡 Make sure you are running this on Windows where eps2003csp11.dll exists');
    process.exit(1);
}

console.log('✅ Library found!');

// Test basic library loading
try {
    // Try to load pkcs11js
    let pkcs11;
    try {
        pkcs11 = require('pkcs11js');
        console.log('✅ pkcs11js module available');
    } catch (e) {
        console.log('❌ pkcs11js module not available');
        console.log('💡 Install with: npm install pkcs11js');
        
        // Alternative: Test basic library properties
        console.log('\n📋 Library Information:');
        const stats = fs.statSync(epass2003Library);
        console.log(`   Size: ${stats.size} bytes`);
        console.log(`   Modified: ${stats.mtime}`);
        
        console.log('\n🚀 Next Steps:');
        console.log('1. Install pkcs11js: npm install pkcs11js');
        console.log('2. Run this script again');
        console.log('3. Insert your ePass2003 token');
        console.log('4. Test with PIN');
        
        return;
    }

    console.log('\n🔧 Testing PKCS#11 Operations:');
    
    // Initialize PKCS#11
    console.log('1. Loading PKCS#11 library...');
    pkcs11.load(epass2003Library);
    
    console.log('2. Initializing PKCS#11...');
    pkcs11.C_Initialize();

    console.log('3. Getting slot list...');
    const slots = pkcs11.C_GetSlotList(true);
    console.log(`   Found ${slots.length} slot(s) with tokens`);

    if (slots.length === 0) {
        console.log('   ❌ No tokens found');
        console.log('   💡 Make sure your ePass2003 token is inserted');
    } else {
        console.log('   ✅ Token(s) detected!');
        
        // Get detailed slot information
        for (let i = 0; i < slots.length; i++) {
            const slot = slots[i];
            console.log(`\n📱 Slot ${slot}:`);
            
            try {
                const slotInfo = pkcs11.C_GetSlotInfo(slot);
                console.log(`   Description: ${slotInfo.slotDescription.trim()}`);
                console.log(`   Manufacturer: ${slotInfo.manufacturerID.trim()}`);
                console.log(`   Hardware Version: ${slotInfo.hardwareVersion.major}.${slotInfo.hardwareVersion.minor}`);
                
                const tokenInfo = pkcs11.C_GetTokenInfo(slot);
                console.log(`   Token Label: ${tokenInfo.label.trim()}`);
                console.log(`   Token Manufacturer: ${tokenInfo.manufacturerID.trim()}`);
                console.log(`   Token Model: ${tokenInfo.model.trim()}`);
                console.log(`   Serial Number: ${tokenInfo.serialNumber.trim()}`);
                console.log(`   Max PIN Length: ${tokenInfo.ulMaxPinLen}`);
                console.log(`   Min PIN Length: ${tokenInfo.ulMinPinLen}`);
                
                // Test PIN if provided
                const pin = process.env.ETA_USB_TOKEN_PIN;
                if (pin) {
                    console.log('\n🔐 Testing PIN...');
                    try {
                        const session = pkcs11.C_OpenSession(slot, pkcs11.CKF_SERIAL_SESSION | pkcs11.CKF_RW_SESSION);
                        pkcs11.C_Login(session, pkcs11.CKU_USER, pin);
                        console.log('   ✅ PIN verified successfully!');
                        
                        // List certificates
                        console.log('\n📜 Listing certificates...');
                        const objects = pkcs11.C_FindObjectsInit(session, [{type: pkcs11.CKA_CLASS, value: pkcs11.CKO_CERTIFICATE}]);
                        const certs = pkcs11.C_FindObjects(session);
                        console.log(`   Found ${certs.length} certificate(s)`);
                        
                        for (let j = 0; j < certs.length; j++) {
                            try {
                                const cert = certs[j];
                                const label = pkcs11.C_GetAttributeValue(session, cert, [{type: pkcs11.CKA_LABEL}]);
                                const id = pkcs11.C_GetAttributeValue(session, cert, [{type: pkcs11.CKA_ID}]);
                                console.log(`   Certificate ${j + 1}: ${label[0].value ? Buffer.from(label[0].value).toString() : 'No label'}`);
                                console.log(`     ID: ${id[0].value ? Buffer.from(id[0].value).toString('hex') : 'No ID'}`);
                            } catch (e) {
                                console.log(`   Certificate ${j + 1}: Error reading attributes`);
                            }
                        }
                        
                        pkcs11.C_FindObjectsFinal(session);
                        pkcs11.C_Logout(session);
                        pkcs11.C_CloseSession(session);
                        
                    } catch (e) {
                        console.log(`   ❌ PIN test failed: ${e.message}`);
                        if (e.message.includes('CKR_PIN_INCORRECT')) {
                            console.log('   💡 Check your PIN and try again');
                        }
                    }
                } else {
                    console.log('\n💡 Set ETA_USB_TOKEN_PIN environment variable to test PIN');
                }
                
            } catch (e) {
                console.log(`   ❌ Error getting slot info: ${e.message}`);
            }
        }
    }

    // Cleanup
    pkcs11.C_Finalize();
    console.log('\n✅ PKCS#11 test completed successfully!');

} catch (error) {
    console.log(`❌ PKCS#11 test failed: ${error.message}`);
    
    if (error.message.includes('cannot open shared object file')) {
        console.log('💡 Library dependencies missing');
    } else if (error.message.includes('invalid ELF header')) {
        console.log('💡 Architecture mismatch (32-bit vs 64-bit)');
    } else if (error.message.includes('The specified module could not be found')) {
        console.log('💡 Library or its dependencies not found');
    }
    
    console.log('\n🔧 Troubleshooting:');
    console.log('1. Make sure ePass2003 software is properly installed');
    console.log('2. Check if all ePass2003 dependencies are available');
    console.log('3. Try running as Administrator');
    console.log('4. Ensure Node.js architecture matches library (32/64-bit)');
}

console.log('\n📋 Configuration for Laravel:');
console.log('Add to your .env file:');
console.log('ETA_USE_REAL_CERTIFICATES=true');
console.log('ETA_USE_USB_TOKEN=true');
console.log('ETA_USB_TOKEN_TYPE=epass2003');
console.log(`ETA_USB_TOKEN_PKCS11_LIB=${epass2003Library}`);
console.log('ETA_USB_TOKEN_PIN=your_pin_here');
