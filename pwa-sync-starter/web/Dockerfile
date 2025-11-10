# ---- Build stage ----
FROM public.ecr.aws/docker/library/node:20-bookworm AS web-builder
WORKDIR /usr/src/app

# Fix npm optional-deps bug that breaks Rollup platform binaries
RUN npm i -g npm@11.6.2

# Copy entire monorepo structure (root + web + shared)
COPY package*.json ./
COPY web/package*.json ./web/
COPY shared/contracts/package.json ./shared/contracts/

# Install all workspace dependencies at root level
# This ensures npm recognizes and links the workspace packages
RUN npm ci --include=dev

# Copy source files
COPY web/ ./web/
COPY shared/ ../shared/

# Build from web directory
WORKDIR /usr/src/app/web

# Defensive: if npm still missed the Rollup arm64 binary, install it
# (Use -musl if you build on Alpine in the BUILDER stage; here we are on Debian/glibc)
RUN node -e "try{require.resolve('@rollup/rollup-linux-arm64-gnu');process.exit(0)}catch(e){process.exit(1)}" \
  || npm i --no-save @rollup/rollup-linux-arm64-gnu

# Build (run from web directory)
RUN npm run build

# ---- Runtime stage ----
FROM public.ecr.aws/docker/library/nginx:stable-alpine AS web-runtime
WORKDIR /usr/share/nginx/html

# Copy built assets from web directory
COPY --from=web-builder /usr/src/app/web/dist ./

# SPA routing? Provide your nginx config if needed
# (assumes web/nginx.conf exists in build context)
COPY web/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
