
FROM node:20-alpine
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

# Build the app
RUN npm run build

EXPOSE 5173 4173
CMD [ "npm", "run", "dev", "--", "--host", "0.0.0.0" ]
