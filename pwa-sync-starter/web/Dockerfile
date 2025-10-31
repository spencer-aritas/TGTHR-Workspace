
# Build stage
FROM node:20 AS builder
WORKDIR /usr/src/app

# Clean npm cache first
RUN npm cache clean --force

# Copy only package files first
COPY web/package.json web/package-lock.json ./

# Install dependencies with clean environment
RUN npm ci --production=false && \
    rm -rf /root/.npm/_cacache

# Copy only necessary source files
COPY web/ .
COPY shared ../shared

# Build the app in production mode
ENV NODE_ENV=production
RUN npm run build && \
    rm -rf node_modules

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
