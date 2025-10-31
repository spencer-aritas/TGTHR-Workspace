
# Build stage
FROM node:20-alpine AS builder
WORKDIR /usr/src/app

# Install dependencies with cached package layers
COPY web/package.json web/package-lock.json ./

# Install architecture-specific Rollup binaries
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
      echo "Installing ARM64 dependencies" && \
      npm install --no-save @rollup/rollup-linux-arm64-musl@4.50.0; \
    else \
      echo "Installing x64 dependencies" && \
      npm install --no-save @rollup/rollup-linux-x64-musl@4.50.0; \
    fi && \
    npm install

# Copy application source
COPY web/ .
# Provide shared contracts for TS path aliases (../shared)
COPY shared ../shared

# Build the app in production mode
ENV NODE_ENV=production
RUN npm run build

# Production stage - using nginx for static file serving
FROM nginx:alpine
WORKDIR /usr/share/nginx/html

# Copy the built files from builder stage
COPY --from=builder /usr/src/app/dist .

# Copy our custom nginx config
COPY web/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 5173

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
