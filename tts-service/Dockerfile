FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -u -y \
    curl \
    tar \
    gzip \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies (FastAPI, Uvicorn)
COPY requirements.txt .
# Remove piper-tts from requirements to avoid conflict/double install
RUN sed -i '/piper-tts/d' requirements.txt && \
    pip install --no-cache-dir -r requirements.txt

# Install Piper Binary (Native)
# Detect architecture and download appropriate binary
ARG TARGETARCH
RUN echo "Target Architecture: $TARGETARCH" && \
    if [ "$TARGETARCH" = "arm64" ]; then \
    curl -L -o piper.tar.gz "https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_arm64.tar.gz"; \
    else \
    curl -L -o piper.tar.gz "https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_amd64.tar.gz"; \
    fi && \
    tar -xzf piper.tar.gz && \
    rm piper.tar.gz && \
    mv piper /app/piper_bin

# Add piper to PATH
ENV PATH="/app/piper_bin:$PATH"

# Create voices directory
RUN mkdir -p /app/voices

# Download voice models (Keep existing downloads)
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

# Southern English Female - GB (Low)
RUN python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/southern_english_female/low/en_GB-southern_english_female-low.onnx', '/app/voices/en_GB-southern_english_female-low.onnx')" && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/southern_english_female/low/en_GB-southern_english_female-low.onnx.json', '/app/voices/en_GB-southern_english_female-low.onnx.json')"

# Jenny Dioco - GB Female (Medium)
RUN python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx', '/app/voices/en_GB-jenny_dioco-medium.onnx')" && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx.json', '/app/voices/en_GB-jenny_dioco-medium.onnx.json')"

# Indian English - Female (Medium) - Community Model
RUN python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/navgurukul-ai-labs/text-to-speech-en-IN-piper/resolve/main/en_IN-dataset%3Dspicor-english-base%3Dljspeech-epochs%3D1089.onnx', '/app/voices/en_IN-spicor-medium.onnx')" && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://huggingface.co/navgurukul-ai-labs/text-to-speech-en-IN-piper/resolve/main/en_IN-dataset%3Dspicor-english-base%3Dljspeech-epochs%3D1089.onnx.json', '/app/voices/en_IN-spicor-medium.onnx.json')"

# Copy application code
COPY main.py .

# Expose port
EXPOSE 5500

# Run the service
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5500"]
