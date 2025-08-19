# USB Token Server Dockerfile
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Install system dependencies for USB Token support
RUN apk add --no-cache \
    opensc \
    pcsc-lite \
    pcsc-lite-dev \
    openssl-dev \
    build-base \
    python3 \
    make \
    g++

# Copy package files
COPY package*.json ./

# Install Node.js dependencies (including dev dependencies for nodemon)
RUN npm ci

# Copy application files
COPY . .

# Create temp directory for signing operations
RUN mkdir -p temp && chmod 755 temp

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership of app directory
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start the application
CMD ["npm", "start"]
