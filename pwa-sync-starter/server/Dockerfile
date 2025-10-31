
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
    chown -R nobody:nogroup /app/data /app/keys && \
    chmod 700 /app/keys && \
    chmod 755 /app/data

# Copy application code
COPY app ./app

# Set environment for JWT and data paths
ENV SF_BENEFITS_JWT_PRIVATE_KEY_PATH=/app/keys/jwt_private.key
ENV DB_PATH=/app/data/app.duckdb
ENV SQLITE_DB_PATH=/app/data/server.db

# Switch to non-root user for better security
USER nobody

EXPOSE 8000

# Command to run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
