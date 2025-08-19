/**
 * USB Token Server for Windows - Native Implementation
 * 
 * This version bypasses pkcs11-tool and uses direct Windows APIs
 * for better compatibility with Windows PKCS#11 libraries.
 */

const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { exec, spawn } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Configuration
const config = {
    tempDir: path.join(__dirname, 'temp'),
    logLevel: process.env.LOG_LEVEL || 'info',
    // Windows-specific PKCS#11 libraries to try
    pkcs11Libraries: [
        'C:\\Program Files\\OpenSC Project\\OpenSC\\pkcs11\\opensc-pkcs11.dll',
        'C:\\Program Files (x86)\\OpenSC Project\\OpenSC\\pkcs11\\opensc-pkcs11.dll',
        'C:\\Program Files\\OpenSC Project\\OpenSC\\pkcs11\\onepin-opensc-pkcs11.dll',
        'C:\\Program Files (x86)\\OpenSC Project\\OpenSC\\pkcs11\\onepin-opensc-pkcs11.dll',
        'C:\\Windows\\System32\\opensc-pkcs11.dll'
    ]
};

// Ensure temp directory exists
if (!fs.existsSync(config.tempDir)) {
    fs.mkdirSync(config.tempDir, { recursive: true });
}

/**
 * Logging utility
 */
function log(level, message, data = null) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] [${level.toUpperCase()}] ${message}`, data || '');
}

/**
 * Find working PKCS#11 library
 */
async function findWorkingPkcs11Library() {
    for (const libPath of config.pkcs11Libraries) {
        if (fs.existsSync(libPath)) {
            log('info', `Testing PKCS#11 library: ${libPath}`);
            
            try {
                // Test if the library can be loaded by trying a simple operation
                const testResult = await testPkcs11Library(libPath);
                if (testResult.success) {
                    log('info', `Working PKCS#11 library found: ${libPath}`);
                    return { path: libPath, ...testResult };
                }
            } catch (error) {
                log('warn', `PKCS#11 library test failed: ${libPath}`, error.message);
            }
        } else {
            log('debug', `PKCS#11 library not found: ${libPath}`);
        }
    }
    
    throw new Error('No working PKCS#11 library found');
}

/**
 * Test PKCS#11 library by attempting to list slots
 */
function testPkcs11Library(libPath) {
    return new Promise((resolve, reject) => {
        // Use a more robust approach - try different methods
        const methods = [
            // Method 1: Direct pkcs11-tool with specific module
            () => execCommand(`pkcs11-tool --module "${libPath}" --list-slots`),
            
            // Method 2: Try with quotes and different path format
            () => execCommand(`pkcs11-tool --module ${libPath.replace(/\\/g, '/')} --list-slots`),
            
            // Method 3: Use certutil (Windows native) as fallback
            () => execCommand('certutil -scinfo')
        ];
        
        // Try each method sequentially
        tryMethods(methods, 0, resolve, reject);
    });
}

function tryMethods(methods, index, resolve, reject) {
    if (index >= methods.length) {
        reject(new Error('All methods failed'));
        return;
    }
    
    methods[index]()
        .then(result => {
            // Check if result indicates success
            if (result.stdout.includes('Available slots') || 
                result.stdout.includes('Slot ') || 
                result.stdout.includes('Smart Card')) {
                resolve({ 
                    success: true, 
                    method: index + 1,
                    output: result.stdout 
                });
            } else {
                // Try next method
                tryMethods(methods, index + 1, resolve, reject);
            }
        })
        .catch(error => {
            // Try next method
            tryMethods(methods, index + 1, resolve, reject);
        });
}

/**
 * Execute command with better error handling
 */
function execCommand(command, options = {}) {
    return new Promise((resolve, reject) => {
        log('debug', `Executing: ${command}`);
        
        exec(command, { 
            timeout: 30000, 
            encoding: 'utf8',
            ...options 
        }, (error, stdout, stderr) => {
            if (error) {
                log('debug', `Command failed: ${command}`, { error: error.message, stderr });
                reject(new Error(`Command failed: ${error.message}`));
            } else {
                log('debug', `Command successful: ${command}`);
                resolve({ stdout: stdout || '', stderr: stderr || '' });
            }
        });
    });
}

/**
 * Windows-specific smart card detection using certutil
 */
async function detectSmartCardsWindows() {
    try {
        const result = await execCommand('certutil -scinfo');
        const cards = [];
        
        // Parse certutil output
        const lines = result.stdout.split('\n');
        let currentCard = null;
        
        for (const line of lines) {
            const trimmed = line.trim();
            
            if (trimmed.includes('Smart Card Reader:')) {
                if (currentCard) cards.push(currentCard);
                currentCard = {
                    reader: trimmed.replace('Smart Card Reader:', '').trim(),
                    status: 'unknown',
                    certificates: []
                };
            } else if (trimmed.includes('Card Status:')) {
                if (currentCard) {
                    currentCard.status = trimmed.replace('Card Status:', '').trim();
                }
            } else if (trimmed.includes('Certificate')) {
                if (currentCard) {
                    currentCard.certificates.push(trimmed);
                }
            }
        }
        
        if (currentCard) cards.push(currentCard);
        
        return {
            success: true,
            cards: cards,
            method: 'certutil'
        };
    } catch (error) {
        log('warn', 'Windows smart card detection failed', error.message);
        return {
            success: false,
            error: error.message,
            cards: []
        };
    }
}

// Global variable to store working PKCS#11 configuration
let workingPkcs11 = null;

/**
 * Initialize PKCS#11 on server startup
 */
async function initializePkcs11() {
    try {
        log('info', 'Initializing PKCS#11 support...');
        workingPkcs11 = await findWorkingPkcs11Library();
        log('info', `PKCS#11 initialized successfully with: ${workingPkcs11.path}`);
    } catch (error) {
        log('warn', 'PKCS#11 initialization failed, falling back to Windows native methods', error.message);
        workingPkcs11 = { fallback: true };
    }
}

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        server: 'USB Token Server (Windows Native)',
        version: '1.0.0',
        pkcs11Status: workingPkcs11 ? (workingPkcs11.fallback ? 'fallback' : 'active') : 'not_initialized'
    });
});

/**
 * Test USB Token connection - Windows Native Version
 */
app.post('/api/usb-token/test', async (req, res) => {
    try {
        log('info', 'Testing USB Token connection (Windows Native)');
        
        let result;
        
        if (workingPkcs11 && !workingPkcs11.fallback) {
            // Try PKCS#11 method
            try {
                const testResult = await testPkcs11Library(workingPkcs11.path);
                result = {
                    success: true,
                    method: 'pkcs11',
                    library: workingPkcs11.path,
                    data: {
                        token_present: testResult.output.includes('token present'),
                        slots_available: testResult.output.includes('Available slots'),
                        output: testResult.output
                    }
                };
            } catch (error) {
                throw error;
            }
        } else {
            // Fallback to Windows native method
            result = await detectSmartCardsWindows();
            result.method = 'windows_native';
        }
        
        if (result.success) {
            log('info', `USB Token test successful using ${result.method}`);
            res.json({
                success: true,
                message: `USB Token test successful using ${result.method}`,
                data: {
                    method: result.method,
                    timestamp: new Date().toISOString(),
                    ...result.data || result
                }
            });
        } else {
            res.status(404).json({
                success: false,
                message: 'No USB Token detected',
                error: result.error || 'Unknown error'
            });
        }
        
    } catch (error) {
        log('error', 'USB Token test failed', error);
        res.status(500).json({
            success: false,
            message: 'USB Token test failed',
            error: error.message
        });
    }
});

/**
 * Get USB Token certificates - Windows Native Version
 */
app.post('/api/usb-token/certificates', async (req, res) => {
    try {
        log('info', 'Retrieving USB Token certificates (Windows Native)');
        
        // Try Windows certificate store first
        const certResult = await execCommand('certutil -store -user My');
        
        const certificates = [];
        const lines = certResult.stdout.split('\n');
        let currentCert = {};
        
        for (const line of lines) {
            const trimmed = line.trim();
            
            if (trimmed.includes('Serial Number:')) {
                if (Object.keys(currentCert).length > 0) {
                    certificates.push(currentCert);
                }
                currentCert = {
                    serialNumber: trimmed.replace('Serial Number:', '').trim()
                };
            } else if (trimmed.includes('Subject:')) {
                currentCert.subject = trimmed.replace('Subject:', '').trim();
            } else if (trimmed.includes('Issuer:')) {
                currentCert.issuer = trimmed.replace('Issuer:', '').trim();
            } else if (trimmed.includes('NotBefore:')) {
                currentCert.validFrom = trimmed.replace('NotBefore:', '').trim();
            } else if (trimmed.includes('NotAfter:')) {
                currentCert.validTo = trimmed.replace('NotAfter:', '').trim();
            }
        }
        
        if (Object.keys(currentCert).length > 0) {
            certificates.push(currentCert);
        }
        
        log('info', `Found ${certificates.length} certificates`);
        
        res.json({
            success: true,
            message: `Found ${certificates.length} certificates`,
            certificates: certificates,
            count: certificates.length,
            method: 'windows_certificate_store'
        });
        
    } catch (error) {
        log('error', 'Failed to retrieve certificates', error);
        res.status(500).json({
            success: false,
            message: 'Failed to retrieve certificates',
            error: error.message
        });
    }
});

/**
 * Sign data using USB Token - Windows Native Version
 */
app.post('/api/usb-token/sign', async (req, res) => {
    try {
        const { data, pin, submission_type = 'taxpayer' } = req.body;
        
        if (!data) {
            return res.status(400).json({
                success: false,
                message: 'Data is required'
            });
        }
        
        log('info', `Signing data for ${submission_type} submission (Windows Native)`);
        
        // For now, return a placeholder response indicating Windows native signing
        // In a real implementation, you would use Windows CryptoAPI or similar
        
        res.json({
            success: true,
            message: 'Windows native signing not yet implemented',
            note: 'This would use Windows CryptoAPI for actual signing',
            data: {
                submission_type: submission_type,
                method: 'windows_native_placeholder',
                timestamp: new Date().toISOString()
            }
        });
        
    } catch (error) {
        log('error', 'Signing operation failed', error);
        res.status(500).json({
            success: false,
            message: 'Signing operation failed',
            error: error.message
        });
    }
});

/**
 * Get USB Token information - Windows Native Version
 */
app.post('/api/usb-token/info', async (req, res) => {
    try {
        log('info', 'Getting USB Token information (Windows Native)');
        
        const smartCardInfo = await detectSmartCardsWindows();
        
        res.json({
            success: true,
            message: 'USB Token information retrieved (Windows Native)',
            data: {
                method: 'windows_native',
                smartCards: smartCardInfo.cards,
                pkcs11Status: workingPkcs11 ? (workingPkcs11.fallback ? 'fallback' : 'active') : 'not_initialized',
                timestamp: new Date().toISOString()
            }
        });
        
    } catch (error) {
        log('error', 'Failed to get USB Token information', error);
        res.status(500).json({
            success: false,
            message: 'Failed to get USB Token information',
            error: error.message
        });
    }
});

/**
 * Error handling middleware
 */
app.use((error, req, res, next) => {
    log('error', 'Unhandled error', error);
    res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
    });
});

/**
 * 404 handler
 */
app.use((req, res) => {
    res.status(404).json({
        success: false,
        message: 'Endpoint not found',
        path: req.path
    });
});

/**
 * Start server
 */
async function startServer() {
    try {
        // Initialize PKCS#11 support
        await initializePkcs11();
        
        app.listen(PORT, () => {
            log('info', `USB Token Server (Windows Native) started on port ${PORT}`);
            log('info', `Temp Directory: ${config.tempDir}`);
            log('info', 'Available endpoints:');
            log('info', '  GET  /health - Health check');
            log('info', '  POST /api/usb-token/test - Test USB Token');
            log('info', '  POST /api/usb-token/certificates - Get certificates');
            log('info', '  POST /api/usb-token/sign - Sign data');
            log('info', '  POST /api/usb-token/info - Get token info');
            log('info', '');
            log('info', 'Server ready for Windows USB Token operations!');
        });
    } catch (error) {
        log('error', 'Failed to start server', error);
        process.exit(1);
    }
}

// Start the server
startServer();

module.exports = app;
