
FROM public.ecr.aws/docker/library/python:3.11-slim
WORKDIR /app

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app
ENV DB_PATH=/app/data/app.duckdb
ENV SQLITE_DB_PATH=/app/data/server.db

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Python dependencies
RUN pip install --upgrade pip
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create necessary directories and set permissions
RUN mkdir -p /app/data /app/keys && \
    # Create user with specific UID/GID for volume ownership
    groupadd -g 1000 appuser && \
    useradd -u 1000 -g appuser -s /bin/bash -m appuser && \
    # Set correct ownership and permissions
    chown -R 1000:1000 /app/data /app/keys && \
    chmod 700 /app/keys && \
    chmod 755 /app/data

# Copy application code
COPY app ./app
RUN chown -R 1000:1000 /app/app

# Set environment for JWT and data paths
ENV SF_BENEFITS_JWT_PRIVATE_KEY_PATH=/app/keys/jwt_private.key
ENV DB_PATH=/app/data/app.duckdb
ENV SQLITE_DB_PATH=/app/data/server.db

# Switch to non-root user for better security
USER 1000:1000

EXPOSE 8000

# Command to run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
