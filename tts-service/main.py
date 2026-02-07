from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import subprocess
import io
import os
import wave
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
            "piper", 
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5500)
