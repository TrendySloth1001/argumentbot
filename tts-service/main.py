from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import subprocess
import io
import os
import wave
from pathlib import Path

app = FastAPI(title="ArgumentBot TTS Service", version="1.0.0")

# CORS for backend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

VOICES_DIR = Path("/app/voices")
DEFAULT_VOICE = "en_US-lessac-medium"

class SynthesizeRequest(BaseModel):
    text: str
    voice: str | None = None

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "tts"}

@app.get("/voices")
async def list_voices():
    """List available voice models"""
    voices = []
    if VOICES_DIR.exists():
        for onnx_file in VOICES_DIR.glob("*.onnx"):
            voice_name = onnx_file.stem
            voices.append({
                "id": voice_name,
                "name": voice_name.replace("-", " ").replace("_", " ").title(),
                "language": voice_name.split("-")[0] if "-" in voice_name else "unknown"
            })
    return {"voices": voices}

@app.post("/synthesize")
async def synthesize(request: SynthesizeRequest):
    """Convert text to speech and return audio"""
    voice = request.voice or DEFAULT_VOICE
    voice_path = VOICES_DIR / f"{voice}.onnx"
    
    if not voice_path.exists():
        # Try to find any available voice
        available_voices = list(VOICES_DIR.glob("*.onnx"))
        if not available_voices:
            raise HTTPException(status_code=404, detail="No voice models found. Please download a voice first.")
        voice_path = available_voices[0]
    
    try:
        # Run piper to synthesize audio
        process = subprocess.Popen(
            ["piper", "--model", str(voice_path), "--output_raw"],
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
