FROM python:3.11-slim

WORKDIR /app

# Install Python dependencies first
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Download a default English voice model using Python
RUN mkdir -p /app/voices && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx', '/app/voices/en_US-lessac-medium.onnx')" && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json', '/app/voices/en_US-lessac-medium.onnx.json')"

# Copy application code
COPY main.py .

# Expose port
EXPOSE 5500

# Run the service
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5500"]
