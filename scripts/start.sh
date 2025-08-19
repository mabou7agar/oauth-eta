#!/bin/bash
# USB Token Server - Start Script

set -e

echo "🚀 Starting ETA USB Token Server..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Create necessary directories
mkdir -p logs temp monitoring

# Copy environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "📋 Creating environment file..."
    cp .env.docker .env
    echo "✅ Created .env file. Please review and customize it."
fi

# Parse command line arguments
PROFILE=""
DETACHED="-d"
REBUILD=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dev|--development)
            echo "🔧 Starting in development mode..."
            COMPOSE_FILES="-f docker-compose.yml -f docker-compose.override.yml"
            shift
            ;;
        --proxy)
            echo "🔀 Starting with proxy..."
            PROFILE="--profile proxy"
            shift
            ;;
        --monitoring)
            echo "📊 Starting with monitoring..."
            PROFILE="--profile monitoring"
            shift
            ;;
        --full)
            echo "🎯 Starting full stack..."
            PROFILE="--profile proxy --profile monitoring"
            shift
            ;;
        --foreground|-f)
            echo "📺 Running in foreground..."
            DETACHED=""
            shift
            ;;
        --rebuild)
            echo "🔨 Rebuilding images..."
            REBUILD="--build"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dev, --development    Start in development mode with hot reload"
            echo "  --proxy                 Start with nginx reverse proxy"
            echo "  --monitoring           Start with Prometheus monitoring"
            echo "  --full                 Start with proxy and monitoring"
            echo "  --foreground, -f       Run in foreground (don't detach)"
            echo "  --rebuild              Rebuild Docker images"
            echo "  --help, -h             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                     # Basic USB token server"
            echo "  $0 --dev               # Development mode"
            echo "  $0 --full              # Full stack with proxy and monitoring"
            echo "  $0 --proxy --foreground # Proxy mode in foreground"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Build and start services
echo "🏗️  Building and starting services..."
if [ -n "$COMPOSE_FILES" ]; then
    docker-compose $COMPOSE_FILES up $DETACHED $REBUILD $PROFILE
else
    docker-compose up $DETACHED $REBUILD $PROFILE
fi

if [ -n "$DETACHED" ]; then
    echo ""
    echo "✅ USB Token Server started successfully!"
    echo ""
    echo "🔗 Service URLs:"
    echo "   USB Token Server: http://localhost:3000"
    echo "   Health Check:     http://localhost:3000/health"
    
    if [[ "$PROFILE" == *"proxy"* ]]; then
        echo "   Proxy:            http://localhost:2345"
    fi
    
    if [[ "$PROFILE" == *"monitoring"* ]]; then
        echo "   Prometheus:       http://localhost:9090"
    fi
    
    echo ""
    echo "📋 Useful commands:"
    echo "   View logs:        docker-compose logs -f usb-token-server"
    echo "   Stop services:    docker-compose down"
    echo "   Restart:          docker-compose restart usb-token-server"
    echo ""
fi
