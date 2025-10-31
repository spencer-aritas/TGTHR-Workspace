
# Build stage
FROM node:20-alpine AS builder
WORKDIR /usr/src/app

# Install dependencies with cached package layers
COPY web/package.json web/package-lock.json ./
RUN npm install && \
    ARCH=$(node -p "process.arch") && \
    if [ "$ARCH" = "arm64" ]; then \
      npm install --no-save @rollup/rollup-linux-arm64-musl@4.50.0; \
    elif [ "$ARCH" = "x64" ]; then \
      npm install --no-save @rollup/rollup-linux-x64-musl@4.50.0; \
    fi

# Copy application source
COPY web/ .
# Provide shared contracts for TS path aliases (../shared)
COPY shared ../shared

# Build the app in production mode
ENV NODE_ENV=production
RUN npm run build

# Production stage
FROM node:20-alpine
WORKDIR /usr/src/app

# Copy only the built files and necessary runtime dependencies
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/package.json ./
COPY --from=builder /usr/src/app/package-lock.json ./
COPY --from=builder /usr/src/app/vite.config.ts ./

# Install dependencies including Vite (not just production deps)
RUN npm install

EXPOSE 5173

# Run in production mode
ENV NODE_ENV=production
CMD [ "npm", "run", "preview", "--", "--host", "0.0.0.0" ]
