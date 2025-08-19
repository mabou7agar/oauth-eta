/**
 * USB Token Server for Client-Side Signing
 * 
 * This Node.js server provides HTTP endpoints for USB Token operations,
 * allowing JavaScript clients to request signing operations while keeping
 * private keys secure on the server with the USB Token.
 */

const express = require('express');
const cors = require('cors');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Configuration
const config = {
    pkcs11Module: process.env.PKCS11_MODULE || '/usr/lib/opensc-pkcs11.so',
    tempDir: path.join(__dirname, 'temp'),
    logLevel: process.env.LOG_LEVEL || 'info'
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
 * Execute shell command with promise
 */
function execCommand(command, options = {}) {
    return new Promise((resolve, reject) => {
        exec(command, { timeout: 30000, ...options }, (error, stdout, stderr) => {
            if (error) {
                log('error', `Command failed: ${command}`, { error: error.message, stderr });
                reject(new Error(`Command failed: ${error.message}`));
            } else {
                log('debug', `Command successful: ${command}`);
                resolve({ stdout, stderr });
            }
        });
    });
}

/**
 * Generate unique filename for temporary files
 */
function generateTempFilename(extension = '.tmp') {
    return path.join(config.tempDir, `usb_token_${Date.now()}_${Math.random().toString(36).substr(2, 9)}${extension}`);
}

/**
 * Clean up temporary files
 */
function cleanupTempFile(filepath) {
    try {
        if (fs.existsSync(filepath)) {
            fs.unlinkSync(filepath);
            log('debug', `Cleaned up temp file: ${filepath}`);
        }
    } catch (error) {
        log('warn', `Failed to cleanup temp file: ${filepath}`, error);
    }
}

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        server: 'USB Token Server',
        version: '1.0.0'
    });
});

/**
 * Test USB Token connection
 */
app.post('/api/usb-token/test', async (req, res) => {
    try {
        const { pin } = req.body;
        
        if (!pin) {
            return res.status(400).json({
                success: false,
                message: 'PIN is required'
            });
        }

        log('info', 'Testing USB Token connection');

        // Test token connection
        const command = `pkcs11-tool --module ${config.pkcs11Module} --list-slots`;
        const result = await execCommand(command);

        if (!result.stdout.includes('token present')) {
            return res.status(404).json({
                success: false,
                message: 'No USB Token detected'
            });
        }

        // Test PIN
        const pinTestCommand = `pkcs11-tool --module ${config.pkcs11Module} --login --pin ${pin} --list-objects --type cert`;
        await execCommand(pinTestCommand);

        log('info', 'USB Token test successful');

        res.json({
            success: true,
            message: 'USB Token is connected and PIN is correct',
            data: {
                token_present: true,
                pin_verified: true,
                timestamp: new Date().toISOString()
            }
        });

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
 * Get USB Token certificates
 */
app.post('/api/usb-token/certificates', async (req, res) => {
    try {
        const { pin } = req.body;
        
        if (!pin) {
            return res.status(400).json({
                success: false,
                message: 'PIN is required'
            });
        }

        log('info', 'Retrieving USB Token certificates');

        const command = `pkcs11-tool --module ${config.pkcs11Module} --login --pin ${pin} --list-objects --type cert`;
        const result = await execCommand(command);

        // Parse certificate information
        const certificates = [];
        const lines = result.stdout.split('\n');
        let currentCert = {};

        for (const line of lines) {
            if (line.includes('Certificate Object')) {
                if (Object.keys(currentCert).length > 0) {
                    certificates.push(currentCert);
                }
                currentCert = {};
            } else if (line.includes('label:')) {
                currentCert.label = line.split('label:')[1].trim();
            } else if (line.includes('subject:')) {
                currentCert.subject = line.split('subject:')[1].trim();
            } else if (line.includes('ID:')) {
                currentCert.id = line.split('ID:')[1].trim();
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
            count: certificates.length
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
 * Sign data using USB Token
 */
app.post('/api/usb-token/sign', async (req, res) => {
    let tempDataFile = null;
    let tempSigFile = null;

    try {
        const { data, pin, submission_type = 'taxpayer' } = req.body;
        
        if (!data || !pin) {
            return res.status(400).json({
                success: false,
                message: 'Data and PIN are required'
            });
        }

        log('info', `Signing data for ${submission_type} submission`);

        // Create temporary file for data to sign
        tempDataFile = generateTempFilename('.json');
        fs.writeFileSync(tempDataFile, JSON.stringify(data, null, 2));

        const signatures = [];

        // Generate taxpayer signature (always required)
        log('info', 'Generating taxpayer signature');
        tempSigFile = generateTempFilename('.sig');
        
        const signCommand = `pkcs11-tool --module ${config.pkcs11Module} --login --pin ${pin} --sign --mechanism RSA-PKCS --input-file ${tempDataFile} --output-file ${tempSigFile}`;
        await execCommand(signCommand);

        if (fs.existsSync(tempSigFile)) {
            const signatureData = fs.readFileSync(tempSigFile, 'base64');
            signatures.push({
                type: 'taxpayer',
                algorithm: 'RSA-PKCS',
                signature: signatureData,
                timestamp: new Date().toISOString()
            });
            cleanupTempFile(tempSigFile);
        }

        // Generate intermediary signature if needed
        if (submission_type === 'intermediary') {
            log('info', 'Generating intermediary signature');
            tempSigFile = generateTempFilename('.sig');
            
            // For intermediary, we might use a different certificate or mechanism
            await execCommand(signCommand.replace(tempSigFile, tempSigFile));
            
            if (fs.existsSync(tempSigFile)) {
                const signatureData = fs.readFileSync(tempSigFile, 'base64');
                signatures.push({
                    type: 'intermediary',
                    algorithm: 'RSA-PKCS',
                    signature: signatureData,
                    timestamp: new Date().toISOString()
                });
                cleanupTempFile(tempSigFile);
            }
        }

        cleanupTempFile(tempDataFile);

        log('info', `Generated ${signatures.length} signatures successfully`);

        res.json({
            success: true,
            message: `Generated ${signatures.length} signatures`,
            signatures: signatures,
            submission_type: submission_type,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        log('error', 'Signing operation failed', error);
        
        // Cleanup temp files
        if (tempDataFile) cleanupTempFile(tempDataFile);
        if (tempSigFile) cleanupTempFile(tempSigFile);

        res.status(500).json({
            success: false,
            message: 'Signing operation failed',
            error: error.message
        });
    }
});

/**
 * Get USB Token information
 */
app.post('/api/usb-token/info', async (req, res) => {
    try {
        const { pin } = req.body;
        
        if (!pin) {
            return res.status(400).json({
                success: false,
                message: 'PIN is required'
            });
        }

        log('info', 'Getting USB Token information');

        // Get token slots
        const slotsCommand = `pkcs11-tool --module ${config.pkcs11Module} --list-slots`;
        const slotsResult = await execCommand(slotsCommand);

        // Get token info
        const infoCommand = `pkcs11-tool --module ${config.pkcs11Module} --login --pin ${pin} --list-token-slots`;
        const infoResult = await execCommand(infoCommand);

        res.json({
            success: true,
            message: 'USB Token information retrieved',
            data: {
                slots: slotsResult.stdout,
                token_info: infoResult.stdout,
                module: config.pkcs11Module,
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
 * Graceful shutdown
 */
process.on('SIGTERM', () => {
    log('info', 'Received SIGTERM, shutting down gracefully');
    
    // Cleanup temp directory
    try {
        const files = fs.readdirSync(config.tempDir);
        files.forEach(file => {
            cleanupTempFile(path.join(config.tempDir, file));
        });
    } catch (error) {
        log('warn', 'Error during cleanup', error);
    }
    
    process.exit(0);
});

/**
 * Start server
 */
app.listen(PORT, () => {
    log('info', `USB Token Server started on port ${PORT}`);
    log('info', `PKCS#11 Module: ${config.pkcs11Module}`);
    log('info', `Temp Directory: ${config.tempDir}`);
    log('info', 'Available endpoints:');
    log('info', '  GET  /health - Health check');
    log('info', '  POST /api/usb-token/test - Test USB Token');
    log('info', '  POST /api/usb-token/certificates - Get certificates');
    log('info', '  POST /api/usb-token/sign - Sign data');
    log('info', '  POST /api/usb-token/info - Get token info');
});

module.exports = app;
