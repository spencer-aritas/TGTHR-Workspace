# ---- Build stage ----
FROM node:20-bookworm AS web-builder
WORKDIR /usr/src/app

# Fix npm optional-deps bug that breaks Rollup platform binaries
RUN npm i -g npm@11.6.2

# Install deps (include dev so tsc/vite are present)
COPY web/package*.json ./
RUN npm ci --include=dev

# Copy source
COPY web/ ./
# If you rely on shared TS path aliases:
# (make sure build context includes the "shared" folder)
COPY shared ../shared

# Defensive: if npm still missed the Rollup arm64 binary, install it
# (Use -musl if you build on Alpine in the BUILDER stage; here we are on Debian/glibc)
RUN node -e "try{require.resolve('@rollup/rollup-linux-arm64-gnu');process.exit(0)}catch(e){process.exit(1)}" \
  || npm i --no-save @rollup/rollup-linux-arm64-gnu

# Build
RUN npm run build

# ---- Runtime stage ----
FROM nginx:stable-alpine AS web-runtime
WORKDIR /usr/share/nginx/html

# Copy built assets
COPY --from=web-builder /usr/src/app/dist ./

# SPA routing? Provide your nginx config if needed
# (assumes web/nginx.conf exists in build context)
COPY web/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
