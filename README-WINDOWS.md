# USB Token Server - Windows Setup Guide

## 🚨 Important: Docker Limitation on Windows

**Docker Desktop on Windows cannot access physical USB devices directly.** To use USB tokens with this server, you need to run it **natively on Windows** rather than in Docker.

## 🔧 Windows Native Setup

### Prerequisites

1. **Install Node.js**
   - Download from: https://nodejs.org/
   - Choose the LTS version
   - Verify installation: `node --version`

2. **Install OpenSC (for PKCS#11 support)**
   - Download from: https://github.com/OpenSC/OpenSC/releases
   - Install the Windows MSI package
   - This provides the PKCS#11 library needed for USB token access

3. **Install USB Token Drivers**
   - Install the specific drivers for your USB token/smart card
   - Ensure Windows recognizes your USB token

### 🚀 Quick Start

#### Option 1: Using PowerShell (Recommended)
```powershell
# Navigate to the USB token server directory
cd usb-token-server

# Run the PowerShell startup script
.\start-windows.ps1
```

#### Option 2: Using Command Prompt
```cmd
# Navigate to the USB token server directory
cd usb-token-server

# Run the batch startup script
start-windows.bat
```

#### Option 3: Manual Setup
```cmd
# Install dependencies
npm install

# Set environment variables
set NODE_ENV=development
set PORT=3000
set CORS_ORIGIN=*
set PKCS11_MODULE=C:\Windows\System32\opensc-pkcs11.dll

# Start the server
node server.js
```

## 🔍 Troubleshooting

### USB Token Not Detected

1. **Check USB Token Connection**
   ```cmd
   # List available PKCS#11 slots
   pkcs11-tool --list-slots
   ```

2. **Verify PKCS#11 Library**
   - Check if OpenSC is installed
   - Common locations:
     - `C:\Windows\System32\opensc-pkcs11.dll`
     - `C:\Program Files\OpenSC Project\OpenSC\pkcs11\opensc-pkcs11.dll`

3. **Test USB Token Access**
   ```cmd
   # Test with pkcs11-tool (if available)
   pkcs11-tool --list-token-slots
   ```

### Common Issues

**"PKCS#11 library not found"**
- Install OpenSC from the official website
- Set the correct path in `PKCS11_MODULE` environment variable

**"No slots available"**
- Ensure USB token is properly connected
- Install correct drivers for your USB token
- Try unplugging and reconnecting the USB token

**"Access denied"**
- Run Command Prompt or PowerShell as Administrator
- Check if another application is using the USB token

## 📊 Testing the Server

Once the server is running:

```bash
# Test health endpoint
curl http://localhost:3000/health

# Test USB token detection
curl -X POST http://localhost:3000/api/usb-token/test -H "Content-Type: application/json" -d "{\"pin\":\"YOUR_PIN\"}"

# List certificates
curl -X POST http://localhost:3000/api/usb-token/certificates -H "Content-Type: application/json" -d "{\"pin\":\"YOUR_PIN\"}"
```

## 🔐 Security Notes

- Replace `YOUR_PIN` with your actual USB token PIN
- The server runs on `http://localhost:3000` by default
- CORS is set to allow all origins (`*`) for development - restrict this in production

## 🐳 Why Not Docker?

Docker Desktop on Windows uses a Linux VM and cannot pass through USB devices to containers. The USB devices visible in Docker are virtual USB/IP controllers, not your physical USB token.

**Solutions:**
1. ✅ **Run natively on Windows** (this guide)
2. ❌ Docker with USB passthrough (not supported on Windows)
3. ⚠️ WSL2 with USB/IP forwarding (complex setup, not recommended)

## 📞 Support

If you encounter issues:
1. Ensure your USB token works with other Windows applications
2. Verify OpenSC installation and PKCS#11 library location
3. Check Windows Device Manager for USB token recognition
4. Test with manufacturer-provided tools first

---

**Note**: This server is designed for development and testing. For production use, implement proper authentication, HTTPS, and security measures.
