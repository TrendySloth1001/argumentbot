"""
Native TTS Service using sherpa-onnx for local M1/M2/M3 execution.
Provides significantly better performance than Docker-based Piper.
"""
import os
import io
import json
import time
from pathlib import Path
from typing import Optional

import sherpa_onnx
import numpy as np
from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="TTS Service (Native)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Configuration ---
SHERPA_MODELS_DIR = Path("sherpa_models")
VOICES_DIR = Path("voices")

# Voice registry: voice_id -> sherpa model config
VOICE_REGISTRY = {
    "en_US-amy-medium": {
        "model": SHERPA_MODELS_DIR / "en_US-amy-medium.onnx",
        "tokens": SHERPA_MODELS_DIR / "tokens.txt",
        "data_dir": SHERPA_MODELS_DIR / "espeak-ng-data",
        "name": "Amy",
        "gender": "female",
        "accent": "American",
        "quality": "medium",
        "description": "Natural American female voice",
        "engine": "piper-native",
    }
}

# Lazy-loaded TTS engines
_tts_engines = {}

def get_tts_engine(voice_id: str):
    """Lazily load and cache TTS engines."""
    if voice_id in _tts_engines:
        return _tts_engines[voice_id]
    
    if voice_id not in VOICE_REGISTRY:
        raise ValueError(f"Unknown voice: {voice_id}")
    
    cfg = VOICE_REGISTRY[voice_id]
    print(f"[TTS] Loading voice: {voice_id}...")
    start = time.time()
    
    config = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                model=str(cfg["model"]),
                tokens=str(cfg["tokens"]),
                data_dir=str(cfg["data_dir"]),
            ),
            provider="cpu",
            num_threads=4,  # Utilize multiple cores
            debug=False,
        )
    )
    
    engine = sherpa_onnx.OfflineTts(config)
    _tts_engines[voice_id] = engine
    print(f"[TTS] Voice '{voice_id}' loaded in {time.time() - start:.2f}s")
    return engine


class SynthesizeRequest(BaseModel):
    text: str
    voice: Optional[str] = "en_US-amy-medium"
    speed: float = 1.0


@app.get("/health")
def health():
    return {"status": "healthy", "engine": "sherpa-onnx", "native": True}


@app.get("/voices")
def list_voices():
    return [
        {
            "id": voice_id,
            "name": cfg["name"],
            "gender": cfg["gender"],
            "accent": cfg["accent"],
            "quality": cfg["quality"],
            "description": cfg["description"],
            "engine": cfg["engine"],
        }
        for voice_id, cfg in VOICE_REGISTRY.items()
    ]


@app.post("/synthesize")
def synthesize(request: SynthesizeRequest):
    voice_id = request.voice or "en_US-amy-medium"
    
    try:
        engine = get_tts_engine(voice_id)
    except ValueError as e:
        return Response(content=str(e), status_code=400)
    
    start = time.time()
    audio = engine.generate(request.text, sid=0, speed=request.speed)
    gen_time = time.time() - start
    audio_duration = len(audio.samples) / audio.sample_rate
    
    print(f"[TTS] Generated {audio_duration:.2f}s in {gen_time:.3f}s ({audio_duration/gen_time:.1f}x realtime)")
    
    # Convert to WAV bytes
    import wave
    buffer = io.BytesIO()
    with wave.open(buffer, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(audio.sample_rate)
        # Convert float32 to int16
        audio_int16 = (np.array(audio.samples) * 32767).astype(np.int16)
        wf.writeframes(audio_int16.tobytes())
    
    buffer.seek(0)
    return Response(content=buffer.read(), media_type="audio/wav")


@app.post("/synthesize_stream")
async def synthesize_stream(request: SynthesizeRequest):
    """Streaming synthesis endpoint - for compatibility with backend."""
    voice_id = request.voice or "en_US-amy-medium"
    
    try:
        engine = get_tts_engine(voice_id)
    except ValueError as e:
        return Response(content=str(e), status_code=400)
    
    start = time.time()
    audio = engine.generate(request.text, sid=0, speed=request.speed)
    gen_time = time.time() - start
    audio_duration = len(audio.samples) / audio.sample_rate
    
    print(f"[TTS-Stream] Generated {audio_duration:.2f}s in {gen_time:.3f}s ({audio_duration/gen_time:.1f}x realtime)")
    
    # Convert to raw PCM bytes (16-bit signed, mono)
    audio_int16 = (np.array(audio.samples) * 32767).astype(np.int16)
    
    # Return raw PCM audio for streaming
    return Response(
        content=audio_int16.tobytes(),
        media_type="audio/raw",
        headers={
            "X-Sample-Rate": str(audio.sample_rate),
            "X-Channels": "1",
            "X-Sample-Width": "2",
        }
    )


if __name__ == "__main__":
    import uvicorn
    # Pre-load default voice
    get_tts_engine("en_US-amy-medium")
    uvicorn.run(app, host="0.0.0.0", port=5500)
