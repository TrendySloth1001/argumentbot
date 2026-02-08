import io
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from faster_whisper import WhisperModel
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("stt-service")

app = FastAPI()

# Load model
# 'tiny' or 'base' is good for CPU. 'int8' quantization for speed.
model = WhisperModel("base", device="cpu", compute_type="int8")
logger.info("Model loaded")

import numpy as np

# ...

@app.websocket("/listen")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    logger.info("Client connected")
    
    audio_buffer = bytearray()
    
    try:
        while True:
            # Receive binary data (audio chunk)
            data = await websocket.receive_bytes()
            audio_buffer.extend(data)
            
            # 16kHz * 2 bytes/sample = 32000 bytes/sec
            # Process every ~1 second of accumulated audio
            if len(audio_buffer) < 32000: 
                continue

            try:
                # Convert buffer to numpy float32
                audio_array = np.frombuffer(audio_buffer, dtype=np.int16).astype(np.float32) / 32768.0
                
                # Transcribe with VAD to filter silence, force English
                segments, info = model.transcribe(audio_array, beam_size=5, vad_filter=True, language="en")
                
                text = " ".join([segment.text for segment in segments])
                
                if text.strip():
                    await websocket.send_json({
                        "text": text.strip(),
                        "language": info.language,
                        "probability": info.language_probability
                    })
                    
                # Creating a rolling window? 
                # For now, let's keep the buffer growing to refine previous context.
                # Ideally, we should detect silence or commit text, but indefinite growth is okay for short turns (<1min).
                
            except Exception as e:
                logger.error(f"Transcription error: {e}")
                
    except WebSocketDisconnect:
        logger.info("Client disconnected")
    except Exception as e:
        logger.error(f"Error processing audio: {e}")
