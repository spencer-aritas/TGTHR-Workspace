
FROM python:3.11-slim
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

# Create necessary directories
RUN mkdir -p /app/data

# Copy application code
COPY app ./app

# Create a directory for the JWT key and set proper permissions
RUN mkdir -p /app/keys && \
    chmod 700 /app/keys

# Set JWT key path environment variable
ENV SF_BENEFITS_JWT_PRIVATE_KEY_PATH=/app/keys/jwt_private.key

EXPOSE 8000

# Command to run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
