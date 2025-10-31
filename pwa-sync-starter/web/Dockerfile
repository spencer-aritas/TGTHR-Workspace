
# Build stage
FROM node:20 AS builder
WORKDIR /usr/src/app

# Install dependencies with cached package layers
COPY web/package.json web/package-lock.json ./

# Use JS implementation of Rollup instead of native
ENV ROLLUP_SKIP_NODEJS_NATIVE=1
RUN npm ci

# Copy application source
COPY web/ .
# Provide shared contracts for TS path aliases (../shared)
COPY shared ../shared

# Build the app in production mode
ENV NODE_ENV=production
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
