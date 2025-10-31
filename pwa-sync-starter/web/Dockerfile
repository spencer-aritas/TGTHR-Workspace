
# Build stage
FROM node:18 AS builder
WORKDIR /usr/src/app

# Set env vars to skip problematic optional dependencies
ENV ROLLUP_SKIP_NODEJS_NATIVE=true
ENV DISABLE_OPTIONAL=true
# Don't set NODE_ENV=production yet - we need devDependencies for build

# Install dependencies with cached package layers
COPY web/package.json web/package-lock.json ./

# Clean install without optional deps and platform-specific packages
RUN npm ci --no-audit --no-fund --include=dev --no-optional \
    && npm config set optional false \
    && npm config set platform linux \
    && npm config set arch x64

# Copy application source
COPY web/ .
# Provide shared contracts for TS path aliases (../shared)
COPY shared ../shared

# Set production env for build optimization
ENV NODE_ENV=production

# Build the app
RUN npm run build

# Production stage - using nginx for static file serving
FROM nginx:stable-alpine
WORKDIR /usr/share/nginx/html

# Copy the built files from builder stage
COPY --from=builder /usr/src/app/dist .

# Copy our custom nginx config
COPY web/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 5173

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
