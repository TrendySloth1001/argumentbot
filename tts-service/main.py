from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import subprocess
import io
import os
import wave
import time
import shutil
from pathlib import Path

# Coqui TTS Import
try:
    from TTS.api import TTS
    COQUI_AVAILABLE = True
except ImportError:
    COQUI_AVAILABLE = False
    print("Coqui TTS not available")

app = FastAPI(title="ArgumentBot TTS Service", version="2.1.0")

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

# Initialize Coqui TTS (Lazy loading or load on startup)
# VCTK VITS is a multi-speaker model
COQUI_MODEL_NAME = "tts_models/en/vctk/vits"
coqui_tts = None

if COQUI_AVAILABLE:
    try:
        print("Initializing Coqui TTS...", flush=True)
        # Check if we agree to TOS (set in Dockerfile)
        os.environ["COQUI_TOS_AGREED"] = "1"
        coqui_tts = TTS(model_name=COQUI_MODEL_NAME, progress_bar=False, gpu=False)
        print("Coqui TTS Initialized", flush=True)
    except Exception as e:
        print(f"Failed to initialize Coqui TTS: {e}", flush=True)
        COQUI_AVAILABLE = False

# Voice metadata for UI display
VOICE_METADATA = {
    # Piper Voices
    "en_US-amy-medium": {
        "name": "Amy",
        "gender": "female",
        "accent": "American",
        "quality": "medium",
        "engine": "piper",
        "description": "Natural female voice, warm tone"
    },
    "en_US-ryan-high": {
        "name": "Ryan",
        "gender": "male",
        "accent": "American",
        "quality": "high",
        "engine": "piper",
        "description": "Professional male voice, clear and authoritative"
    },
    "en_GB-alba-medium": {
        "name": "Alba",
        "gender": "female",
        "accent": "British",
        "quality": "medium",
        "engine": "piper",
        "description": "British female voice, elegant"
    },
    "en_US-joe-medium": {
        "name": "Joe",
        "gender": "male",
        "accent": "American",
        "quality": "medium",
        "engine": "piper",
        "description": "Casual male voice, friendly"
    },
    "en_US-lessac-high": {
        "name": "Lessac",
        "gender": "female",
        "accent": "American",
        "quality": "high",
        "engine": "piper",
        "description": "High-quality female voice, expressive"
    },
    "en_US-danny-low": {
        "name": "Danny",
        "gender": "male",
        "accent": "American",
        "quality": "low",
        "engine": "piper",
        "description": "Fast male voice, quick responses"
    },
    "en_GB-southern_english_female-low": {
        "name": "Sophie",
        "gender": "female",
        "accent": "British",
        "quality": "low",
        "engine": "piper",
        "description": "Southern English female voice"
    },
    "en_GB-jenny_dioco-medium": {
        "name": "Jenny",
        "gender": "female",
        "accent": "British",
        "quality": "medium",
        "engine": "piper",
        "description": "Clear British female voice"
    },
    "en_IN-spicor-medium": {
        "name": "Piya",
        "gender": "female",
        "accent": "Indian",
        "quality": "medium",
        "engine": "piper",
        "description": "Indian English female voice"
    },
    # Coqui Voices (VCTK Speakers mapping)
    # VCTK has hundreds, we'll expose a few good ones
    "coqui-vctk-p226": { # Young male
        "name": "Coqui: Alex",
        "gender": "male",
        "accent": "British",
        "quality": "neuro",
        "engine": "coqui",
        "speaker_id": "p226",
        "description": "Neural VCTK Voice (Male)"
    },
    "coqui-vctk-p225": { # Young female
        "name": "Coqui: Sarah",
        "gender": "female",
        "accent": "British",
        "quality": "neuro",
        "engine": "coqui",
        "speaker_id": "p225",
        "description": "Neural VCTK Voice (Female)"
    },
     "coqui-vctk-p232": { # American Male
        "name": "Coqui: Chris",
        "gender": "male",
        "accent": "American",
        "quality": "neuro",
        "engine": "coqui",
        "speaker_id": "p232",
        "description": "Neural VCTK Voice (American Male)"
    },
}

class SynthesizeRequest(BaseModel):
    text: str
    voice: str | None = None
    speed: float = 0.95 
    sentence_silence: float = 0.1 

@app.get("/health")
async def health():
    return {
        "status": "healthy", 
        "service": "tts", 
        "coqui_available": COQUI_AVAILABLE
    }

@app.get("/voices")
async def list_voices():
    """List available voice models with metadata"""
    voices = []
    
    # 1. Add Piper Voices
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
                "engine": metadata.get("engine", "piper"),
                "description": metadata.get("description", ""),
            })

    # 2. Add Coqui Voices (if enabled)
    if COQUI_AVAILABLE and coqui_tts:
        # Add manually defined Coqui voices first
        manual_coqui_ids = set()
        for vid, meta in VOICE_METADATA.items():
            if meta.get("engine") == "coqui":
                manual_coqui_ids.add(meta.get("speaker_id"))
                voices.append({
                    "id": vid,
                    "name": meta["name"],
                    "gender": meta["gender"],
                    "accent": meta["accent"],
                    "quality": meta["quality"],
                    "engine": "coqui",
                    "description": meta["description"],
                })

        # Dynamic VCTK Speakers
        if coqui_tts.is_multi_speaker:
            import random
            
            # List of names to assign to VCTK speakers (mixed gender)
            # We use a fixed seed so names are consistent across restarts
            # (or better, map specific IDs if we knew genders, but here we just randomize consistently)
            names_pool = [
                "Alex", "Alice", "Aliah", "Amara", "Arjun", "Arthur", "Astrid", "Ava", "Ben", "Bella",
                "Blake", "Brooke", "Caleb", "Chloe", "Connor", "Daisy", "Daniel", "David", "Elena", "Elias",
                "Ella", "Emily", "Emma", "Ethan", "Eva", "Felix", "Finn", "Fiona", "Gabriel", "Grace",
                "Hannah", "Harper", "Hazel", "Henry", "Hugo", "Iris", "Isaac", "Isabella", "Jack", "Jacob",
                "James", "Jasmine", "Jayden", "Jessica", "John", "Joseph", "Julian", "Kai", "Kate", "Liam",
                "Lila", "Lily", "Logan", "Lucas", "Lucy", "Luke", "Luna", "Maddie", "Mason", "Mateo",
                "Maya", "Mia", "Michael", "Mila", "Miles", "Nathan", "Noah", "Nora", "Oliver", "Olivia",
                "Oscar", "Owen", "Parker", "Penelope", "Quinn", "Rachel", "Riley", "Rose", "Ruby", "Ryan",
                "Sam", "Samuel", "Sarah", "Scarlett", "Sebastian", "Silas", "Sofia", "Sophia", "Stella", "Theo",
                "Thomas", "Tyler", "Victoria", "Violet", "William", "Wyatt", "Xavier", "Zara", "Zoe", "Zach",
                "Aaron", "Adam", "Adrian", "Aidan", "Andrew", "Anthony", "Asher", "Austin", "Brandie", "Brian",
                "Cameron", "Charles", "Christian", "Christopher", "Cole", "Colin", "Cooper", "Dominic", "Dylan", "Easton",
                "Eli", "Elijah", "Elliot", "Eric", "Evan", "Ezra", "Gavin", "George", "Grayson", "Harrison",
                "Hayden", "Hudson", "Hunter", "Ian", "Isaiah", "Jace", "Jackson", "Jason", "Jeremiah", "Jonathan",
                "Jordan", "Joshua", "Josiah", "Justin", "Kevin", "Landon", "Leo", "Levi", "Lincoln", "Luis"
            ]
            
            # Sort speakers to ensure deterministic assignment
            sorted_speakers = sorted(coqui_tts.speakers)
            
            for i, speaker_id in enumerate(sorted_speakers):
                if speaker_id in manual_coqui_ids:
                    continue  # Already added manually
                
                # Check for clean IDs
                clean_id = speaker_id.strip()
                if not clean_id:
                    continue
                
                # Pick a name deterministically based on index or hash
                # Using index is simplest since we sorted the list
                name_idx = i % len(names_pool)
                human_name = names_pool[name_idx]
                
                # Add a suffix if we run out of names? Or just standard rotation.
                # To avoid duplicates if potential > 100, let's append ID if needed, 
                # but user wants "random names". 
                # Let's just use the name plus a letter if needed? 
                # Actually, VCTK has ~109 speakers. Our list has ~130 names. Should be unique enough.

                voices.append({
                    "id": f"coqui-vctk-{clean_id}",
                    "name": f"Coqui: {human_name}",
                    "gender": "unknown", # Without VCTK metadata table, we can't know for sure
                    "accent": "VCTK",
                    "quality": "neuro",
                    "engine": "coqui",
                    "description": f"VCTK Speaker {clean_id}",
                })

    # Sort: Piper first, then Coqui (alphanumeric)
    # voices.sort(key=lambda v: (v["engine"], v["name"]))
    return {"voices": voices, "default": DEFAULT_VOICE}

@app.post("/synthesize")
async def synthesize(request: SynthesizeRequest):
    """Convert text to speech and return audio"""
    voice = request.voice or DEFAULT_VOICE
    
    metadata = VOICE_METADATA.get(voice)
    
    # Determine engine and params
    engine = "piper"
    speaker_id = None
    
    if metadata:
        engine = metadata.get("engine", "piper")
        speaker_id = metadata.get("speaker_id")
    elif voice.startswith("coqui-vctk-"):
        engine = "coqui"
        speaker_id = voice.replace("coqui-vctk-", "")
    
    if engine == "coqui" and COQUI_AVAILABLE and coqui_tts:
        return await synthesize_coqui(request, speaker_id)
    else:
        return await synthesize_piper(request)

async def synthesize_coqui(request: SynthesizeRequest, speaker_id: str | None):
    try:
        # Default to first speaker if none provided
        if not speaker_id and coqui_tts.is_multi_speaker:
            speaker_id = coqui_tts.speakers[0]
            
        wav_buffer = io.BytesIO()
        
        # Coqui generation
        wav_data = coqui_tts.tts(text=request.text, speaker=speaker_id)
        
        # Convert list of floats to wav bytes
        import numpy as np
        # VITS VCTK usually is 22050Hz
        sample_rate = 22050 
        
        # Normalize/Scale if needed (usually coqui output is between -1 and 1)
        audio_array = np.array(wav_data, dtype=np.float32)
        
        # Convert to 16-bit PCM
        audio_int16 = (audio_array * 32767).astype(np.int16)
        
        with wave.open(wav_buffer, 'wb') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(sample_rate)
            wav_file.writeframes(audio_int16.tobytes())
            
        wav_buffer.seek(0)
        return StreamingResponse(
            wav_buffer,
            media_type="audio/wav",
            headers={"Content-Disposition": "attachment; filename=speech.wav"}
        )
    except Exception as e:
        print(f"Coqui Error: {e}")
        raise HTTPException(status_code=500, detail=f"Coqui TTS failed: {str(e)}")

async def synthesize_piper(request: SynthesizeRequest):
    voice = request.voice or DEFAULT_VOICE
    voice_path = VOICES_DIR / f"{voice}.onnx"
    
    if not voice_path.exists():
        available_voices = list(VOICES_DIR.glob("*.onnx"))
        if not available_voices:
            raise HTTPException(status_code=404, detail="No voice models found.")
        voice_path = available_voices[0]
    
    try:
        cmd = [
            "/app/piper_bin/piper", 
            "--model", str(voice_path), 
            "--output_raw",
            "--length_scale", str(request.speed),
            "--sentence_silence", str(request.sentence_silence),
            "--noise_scale", "0.667",
            "--noise_w", "0.8"
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
        
        wav_buffer = io.BytesIO()
        with wave.open(wav_buffer, 'wb') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(22050)
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
    # NOTE: Coqui VITS doesn't support true streaming in the same way Piper does via CLI
    # For now, if Coqui is selected, we might just fallback to full synthesis or standard piper
    
    voice = request.voice or DEFAULT_VOICE
    
    metadata = VOICE_METADATA.get(voice)
    
    # Determine engine and params
    engine = "piper"
    
    if metadata:
        engine = metadata.get("engine", "piper")
    elif voice.startswith("coqui-vctk-"):
        engine = "coqui"
    
    if engine == "coqui":
        # Coqui doesn't stream nicely yet in this simple implementation
        # For better UX, we could use Piper for streaming/previews, OR implement chunked coqui if possible
        # But let's just use the non-streaming synthesize for coqui but wrapped in a stream response
        # It won't be "live" streaming, but it will work.
        print(f"Streaming not supported for Coqui ({voice}), falling back to full synthesis")
        return await synthesize(request)

    # Piper Streaming Logic
    voice_file = VOICES_DIR / f"{voice}.onnx"
    if not voice_file.exists():
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
    
    import shutil
    if shutil.which("piper") is None:
        print(f"[{time.time()}] HEADER ERROR: Piper binary not found in PATH", flush=True)

    def audio_generator():
        # ... (Same as before) ...
        try:
            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                bufsize=0 
            )
            
            if process.stdin:
                try:
                    process.stdin.write(request.text.encode())
                    process.stdin.close()
                except Exception as e:
                    print(f"Error writing to piper stdin: {e}", flush=True)
                    return

            # Yield WAV Header
            header = b'RIFF'
            header += (0x7fffffff).to_bytes(4, 'little')
            header += b'WAVE'
            header += b'fmt '
            header += (16).to_bytes(4, 'little')
            header += (1).to_bytes(2, 'little') # PCM
            header += (1).to_bytes(2, 'little') # Channels
            header += (22050).to_bytes(4, 'little') # SampleRate
            header += (22050 * 1 * 2).to_bytes(4, 'little') # ByteRate
            header += (1 * 2).to_bytes(2, 'little') # BlockAlign
            header += (16).to_bytes(2, 'little') # BitsPerSample
            header += b'data'
            header += (0x7fffffff).to_bytes(4, 'little')
            
            yield header

            # Yield raw PCM chunks
            if process.stdout:
                while True:
                    chunk = process.stdout.read(4096)
                    if not chunk:
                        break
                    yield chunk
            
            process.wait()

        except Exception as e:
            print(f"Error in audio generator: {e}", flush=True)

    return StreamingResponse(audio_generator(), media_type="audio/wav")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5500)
