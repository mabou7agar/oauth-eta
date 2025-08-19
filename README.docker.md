# USB Token Server - Docker Setup

This directory contains Docker configuration for the ETA USB Token Server, which provides **local network access** to USB hardware security tokens for client-side digital signing.

## 🔗 Odoo ERP Integration

This server is optimized for **Odoo ERP integration**, allowing Odoo modules to perform digital signing operations using USB hardware tokens directly from the web interface.

## 🚀 Quick Start

### Basic Setup (Recommended for Odoo Integration)
```bash
# Build and start the USB token server
docker-compose up -d usb-token-server

# Check logs
docker-compose logs -f usb-token-server

# Check health (accessible from Odoo)
curl http://localhost:3000/health
# Or from Odoo server:
curl http://YOUR_USB_SERVER_IP:3000/health
```

### Full Setup (With Caching & Monitoring)
```bash
# Start with Redis cache and monitoring
docker-compose --profile monitoring up -d

# Note: Proxy is disabled for local network deployment
# The server is directly accessible at port 3000
```

### Development Mode
```bash
# Start in development mode with hot reload
docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d
```

## 📋 Available Services

### Core Services
- **usb-token-server** - Main USB token server (Port: 3000)
- **redis-cache** - Redis cache for token operations (Port: 6379)

### Optional Services (Profiles)
- **prometheus** - Monitoring and metrics (Port: 9090)
  ```bash
  docker-compose --profile monitoring up -d
  ```

**Note**: Nginx proxy is disabled for local network deployments as the server is directly accessible.

## 🔧 Configuration

### Environment Variables
Copy and customize the environment file:
```bash
cp .env.docker .env
# Edit .env with your specific configuration
```

### Key Configuration Options
- `CORS_ORIGIN` - Allowed origins for CORS (pre-configured for Odoo ports 8069, 8080)
- `USB_TOKEN_TIMEOUT` - Timeout for USB operations (ms)
- `MAX_CONCURRENT_OPERATIONS` - Max concurrent signing operations
- `REDIS_PASSWORD` - Redis cache password

### Odoo Integration Settings
- **Default Odoo Port**: 8069 (included in CORS configuration)
- **Alternative Port**: 8080 (for custom Odoo setups)
- **API Endpoint**: `http://USB_SERVER_IP:3000/api/sign`

## 🔧 Odoo Module Integration

### JavaScript Integration in Odoo
```javascript
// In your Odoo web module
const usbTokenUrl = 'http://USB_SERVER_IP:3000';

// Sign document function
async function signDocument(documentData) {
    try {
        const response = await fetch(`${usbTokenUrl}/api/sign`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                data: documentData,
                certificate_id: 'your_cert_id'
            })
        });
        
        const result = await response.json();
        return result.signature;
    } catch (error) {
        console.error('USB Token signing failed:', error);
        throw error;
    }
}
```

### Python Integration in Odoo Backend
```python
# In your Odoo model
import requests
import json

class YourModel(models.Model):
    _name = 'your.model'
    
    def sign_document_with_usb_token(self, document_data):
        usb_token_url = 'http://USB_SERVER_IP:3000'
        
        try:
            response = requests.post(
                f'{usb_token_url}/api/sign',
                json={
                    'data': document_data,
                    'certificate_id': 'your_cert_id'
                },
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()['signature']
            else:
                raise Exception(f'Signing failed: {response.text}')
                
        except Exception as e:
            _logger.error(f'USB Token signing error: {e}')
            raise
```

## 🔌 USB Device Access

### Linux
USB devices are automatically mounted via:
```yaml
volumes:
  - /dev/bus/usb:/dev/bus/usb:rw
devices:
  - /dev/bus/usb
```

### macOS/Windows
USB passthrough requires additional Docker Desktop configuration or VM setup.

## 📊 Monitoring & Health Checks

### Health Check Endpoints
- `GET /health` - Basic health check
- `GET /health/detailed` - Detailed system status
- `GET /metrics` - Prometheus metrics (if enabled)

### Logs
```bash
# View logs
docker-compose logs -f usb-token-server

# View specific service logs
docker-compose logs redis-cache
```

## 🛠️ Development

### Hot Reload Development
```bash
# Start with development overrides
docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d

# Attach debugger (if needed)
# Connect to localhost:9229 in your IDE
```

### Building Custom Images
```bash
# Build only the USB token server
docker-compose build usb-token-server

# Build with no cache
docker-compose build --no-cache usb-token-server
```

## 🔐 Security Considerations

### Production Deployment
1. **Enable API Key Authentication**:
   ```bash
   API_KEY_REQUIRED=true
   ```

2. **Use Strong Redis Password**:
   ```bash
   REDIS_PASSWORD=your_strong_password_here
   ```

3. **Limit CORS Origins**:
   ```bash
   CORS_ORIGIN=https://your-domain.com
   ```

4. **Network Security**:
   - Server runs directly on port 3000 for local network access
   - Configure firewall rules to restrict access to trusted local IPs only

## 🚨 Troubleshooting

### Common Issues

**USB Device Not Found**:
```bash
# Check USB devices in container
docker-compose exec usb-token-server lsusb

# Check container privileges
docker-compose exec usb-token-server ls -la /dev/bus/usb
```

**Connection Refused**:
```bash
# Check if service is running
docker-compose ps

# Check port binding
docker-compose port usb-token-server 3000
```

**High Memory Usage**:
```bash
# Check container stats
docker stats eta-usb-token-server

# Restart services
docker-compose restart usb-token-server
```

### Debugging
```bash
# Enter container shell
docker-compose exec usb-token-server sh

# Check Node.js processes
docker-compose exec usb-token-server ps aux

# View detailed logs
docker-compose logs --details usb-token-server
```

## 📈 Scaling

### Multiple Token Servers
```yaml
# Add to docker-compose.yml
usb-token-server-2:
  extends: usb-token-server
  container_name: eta-usb-token-server-2
  ports:
    - "3001:3000"
```

### Load Balancing
For local network deployment, load balancing is typically not needed.
If required, you can run multiple instances on different ports:
```bash
# Run additional instance on port 3001
docker run -d -p 3001:3000 --name eta-usb-token-server-2 your-image
```

## 🔄 Backup & Recovery

### Data Volumes
- `redis_data` - Redis cache data
- `prometheus_data` - Monitoring data
- `./logs` - Application logs
- `./temp` - Temporary signing files

### Backup Commands
```bash
# Backup Redis data
docker-compose exec redis-cache redis-cli BGSAVE

# Export container logs
docker-compose logs usb-token-server > usb-token-server.log
```

## 🛑 Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Stop specific service
docker-compose stop usb-token-server
```
