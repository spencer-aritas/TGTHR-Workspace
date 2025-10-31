
# Build stage
FROM node:18 AS builder
WORKDIR /usr/src/app

# Set env var to skip native modules before any npm commands
ENV ROLLUP_SKIP_NODEJS_NATIVE=true
# Don't set NODE_ENV=production yet - we need devDependencies for build

# Install dependencies with cached package layers
COPY web/package.json web/package-lock.json ./

# Install ALL dependencies (including devDependencies) for build
RUN npm ci --no-audit --no-fund --include=dev

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
