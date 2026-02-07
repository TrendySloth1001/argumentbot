FROM python:3.11-slim

WORKDIR /app

# Install Python dependencies first
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create voices directory
RUN mkdir -p /app/voices

# Download multiple high-quality English voice models
# Amy - US Female (Natural)
RUN python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx', '/app/voices/en_US-amy-medium.onnx')" && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx.json', '/app/voices/en_US-amy-medium.onnx.json')"

# Ryan - US Male (High Quality)
RUN python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx', '/app/voices/en_US-ryan-high.onnx')" && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx.json', '/app/voices/en_US-ryan-high.onnx.json')"

# Alba - British Female
RUN python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/alba/medium/en_GB-alba-medium.onnx', '/app/voices/en_GB-alba-medium.onnx')" && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/alba/medium/en_GB-alba-medium.onnx.json', '/app/voices/en_GB-alba-medium.onnx.json')"

# Joe - US Male 
RUN python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/joe/medium/en_US-joe-medium.onnx', '/app/voices/en_US-joe-medium.onnx')" && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/joe/medium/en_US-joe-medium.onnx.json', '/app/voices/en_US-joe-medium.onnx.json')"

# Lessac - US Female (High Quality)
RUN python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/high/en_US-lessac-high.onnx', '/app/voices/en_US-lessac-high.onnx')" && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/high/en_US-lessac-high.onnx.json', '/app/voices/en_US-lessac-high.onnx.json')"

# Danny - US Male (Low, fast)
RUN python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/danny/low/en_US-danny-low.onnx', '/app/voices/en_US-danny-low.onnx')" && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/danny/low/en_US-danny-low.onnx.json', '/app/voices/en_US-danny-low.onnx.json')"

# Copy application code
COPY main.py .

# Expose port
EXPOSE 5500

# Run the service
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5500"]
