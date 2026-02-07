from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import subprocess
import io
import os
import wave
import time
from pathlib import Path

app = FastAPI(title="ArgumentBot TTS Service", version="2.0.0")

# CORS for backend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

VOICES_DIR = Path("/app/voices")
DEFAULT_VOICE = "en_US-amy-medium"

# Voice metadata for UI display
VOICE_METADATA = {
    "en_US-amy-medium": {
        "name": "Amy",
        "gender": "female",
        "accent": "American",
        "quality": "medium",
        "description": "Natural female voice, warm tone"
    },
    "en_US-ryan-high": {
        "name": "Ryan",
        "gender": "male",
        "accent": "American",
        "quality": "high",
        "description": "Professional male voice, clear and authoritative"
    },
    "en_GB-alba-medium": {
        "name": "Alba",
        "gender": "female",
        "accent": "British",
        "quality": "medium",
        "description": "British female voice, elegant"
    },
    "en_US-joe-medium": {
        "name": "Joe",
        "gender": "male",
        "accent": "American",
        "quality": "medium",
        "description": "Casual male voice, friendly"
    },
    "en_US-lessac-high": {
        "name": "Lessac",
        "gender": "female",
        "accent": "American",
        "quality": "high",
        "description": "High-quality female voice, expressive"
    },
    "en_US-danny-low": {
        "name": "Danny",
        "gender": "male",
        "accent": "American",
        "quality": "low",
        "description": "Fast male voice, quick responses"
    }
}

class SynthesizeRequest(BaseModel):
    text: str
    voice: str | None = None
    speed: float = 0.95  # Slightly faster by default
    sentence_silence: float = 0.1 # Reduced silence for better flow

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "tts"}

@app.get("/voices")
async def list_voices():
    """List available voice models with metadata"""
    voices = []
    if VOICES_DIR.exists():
        for onnx_file in VOICES_DIR.glob("*.onnx"):
            voice_id = onnx_file.stem
            metadata = VOICE_METADATA.get(voice_id, {})
            voices.append({
                "id": voice_id,
                "name": metadata.get("name", voice_id),
                "gender": metadata.get("gender", "unknown"),
                "accent": metadata.get("accent", "unknown"),
                "quality": metadata.get("quality", "medium"),
                "description": metadata.get("description", ""),
            })
    # Sort by quality (high first) then name
    quality_order = {"high": 0, "medium": 1, "low": 2}
    voices.sort(key=lambda v: (quality_order.get(v["quality"], 1), v["name"]))
    return {"voices": voices, "default": DEFAULT_VOICE}

@app.post("/synthesize")
async def synthesize(request: SynthesizeRequest):
    """Convert text to speech and return audio"""
    voice = request.voice or DEFAULT_VOICE
    voice_path = VOICES_DIR / f"{voice}.onnx"
    
    if not voice_path.exists():
        # Try to find any available voice
        available_voices = list(VOICES_DIR.glob("*.onnx"))
        if not available_voices:
            raise HTTPException(status_code=404, detail="No voice models found.")
        voice_path = available_voices[0]
    
    try:
        # Run piper to synthesize audio
        # Optimized parameters for speed and human-like prosody
        cmd = [
            "/app/piper_bin/piper", 
            "--model", str(voice_path), 
            "--output_raw",
            "--length_scale", str(request.speed),
            "--sentence_silence", str(request.sentence_silence),
            "--noise_scale", "0.667", # Default var
            "--noise_w", "0.8"        # Default pronunciation var
        ]

        process = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        audio_data, stderr = process.communicate(input=request.text.encode())
        
        if process.returncode != 0:
            raise HTTPException(status_code=500, detail=f"TTS failed: {stderr.decode()}")
        
        # Convert raw audio to WAV
        wav_buffer = io.BytesIO()
        with wave.open(wav_buffer, 'wb') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)  # 16-bit
            wav_file.setframerate(22050)  # Piper default sample rate
            wav_file.writeframes(audio_data)
        
        wav_buffer.seek(0)
        
        return StreamingResponse(
            wav_buffer,
            media_type="audio/wav",
            headers={"Content-Disposition": "attachment; filename=speech.wav"}
        )
        
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="Piper TTS not installed")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/synthesize_stream")
async def synthesize_stream(request: SynthesizeRequest):
    """Stream audio as it is generated (low latency)"""
    voice_file = VOICES_DIR / f"{request.voice}.onnx"
    if not voice_file.exists():
        # Fallback to default if not found
        voice_file = VOICES_DIR / "en_US-amy-medium.onnx"
    
    print(f"[{time.time()}] Received synthesize_stream request for: {request.text[:20]}...", flush=True)

    cmd = [
        "/app/piper_bin/piper",
        "--model", str(voice_file),
        "--output_raw",
        "--length_scale", "0.95",
        "--sentence_silence", "0.1",
        "--noise_scale", "0.667",
        "--noise_w", "0.8"
    ]
    
    # Verify Piper exists (check PATH)
    import shutil
    if shutil.which("piper") is None:
        print(f"[{time.time()}] HEADER ERROR: Piper binary not found in PATH", flush=True)

    def audio_generator():
        print(f"[{time.time()}] Audio generator started", flush=True)
        try:
            print(f"[{time.time()}] Spawning subprocess: {cmd}", flush=True)
            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                bufsize=0 # Unbuffered
            )
            print(f"[{time.time()}] Subprocess spawned, PID: {process.pid}", flush=True)
            
            # Feed text to stdin
            if process.stdin:
                try:
                    print(f"[{time.time()}] Writing to stdin...", flush=True)
                    process.stdin.write(request.text.encode())
                    process.stdin.close()
                    print(f"[{time.time()}] Stdin closed", flush=True)
                except Exception as e:
                    print(f"Error writing to piper stdin: {e}", flush=True)
                    return

            # 1. Yield WAV Header (44 bytes)
            # RIFF header
            header = b'RIFF'
            # header += (0).to_bytes(4, 'little') # File size (0 for stream)
            header += (0x7fffffff).to_bytes(4, 'little') # Fake max file size
            header += b'WAVE'
            
            # fmt chunk
            header += b'fmt '
            header += (16).to_bytes(4, 'little') # Subchunk1Size
            header += (1).to_bytes(2, 'little')  # AudioFormat (PCM)
            header += (1).to_bytes(2, 'little')  # NumChannels (1)
            header += (22050).to_bytes(4, 'little') # SampleRate
            header += (22050 * 1 * 2).to_bytes(4, 'little') # ByteRate
            header += (1 * 2).to_bytes(2, 'little') # BlockAlign
            header += (16).to_bytes(2, 'little') # BitsPerSample
            
            # data chunk
            header += b'data'
            # header += (0).to_bytes(4, 'little') # Subchunk2Size
            header += (0x7fffffff).to_bytes(4, 'little') # Fake max data size
            
            print(f"[{time.time()}] Yielding WAV header", flush=True)
            yield header

            # 2. Yield raw PCM chunks from Piper
            first_chunk = True
            chunk_count = 0
            if process.stdout:
                print(f"[{time.time()}] Reading from stdout...", flush=True)
                while True:
                    chunk = process.stdout.read(4096)
                    if not chunk:
                        print(f"[{time.time()}] Stdout closed (no more chunks)", flush=True)
                        break
                    
                    if first_chunk:
                        print(f"[{time.time()}] Yielding first PCM chunk", flush=True)
                        first_chunk = False
                    
                    yield chunk
                    chunk_count += 1
            
            print(f"[{time.time()}] Finished yielding {chunk_count} chunks", flush=True)

            if process.stderr:
                err = process.stderr.read()
                if err:
                    print(f"Piper stderr: {err.decode()}", flush=True)
            
            process.wait()

        except Exception as e:
            print(f"Error in audio generator: {e}", flush=True)

    return StreamingResponse(audio_generator(), media_type="audio/wav")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5500)
