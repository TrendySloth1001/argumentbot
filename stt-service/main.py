import io
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from faster_whisper import WhisperModel
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("stt-service")

app = FastAPI()

import torch

# Load model
# 'base.en' is more accurate than tiny.en, still fast on M1 CPU
model = WhisperModel("base.en", device="cpu", compute_type="float32", cpu_threads=4)
# Load Silero VAD
vad_model, utils = torch.hub.load(repo_or_dir='snakers4/silero-vad',
                                  model='silero_vad',
                                  force_reload=False,
                                  onnx=False)
(get_speech_timestamps, save_audio, read_audio, VADIterator, collect_chunks) = utils
logger.info("Models loaded")


@app.get("/health")
def health():
    return {"status": "healthy", "service": "stt"}

import numpy as np

@app.websocket("/listen")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    logger.info("Client connected")
    
    audio_buffer = bytearray()
    speech_buffer = bytearray()
    vad_iterator = VADIterator(vad_model)
    is_speaking = False
    
    # 32ms chunk size for VAD (512 samples @ 16kHz)
    VAD_CHUNK_SIZE = 1024 
    
    try:
        while True:
            data = await websocket.receive_bytes()
            audio_buffer.extend(data)
            
            while len(audio_buffer) >= VAD_CHUNK_SIZE:
                chunk_bytes = audio_buffer[:VAD_CHUNK_SIZE]
                audio_buffer = audio_buffer[VAD_CHUNK_SIZE:]
                
                # VAD Input
                audio_float32 = np.frombuffer(chunk_bytes, dtype=np.int16).astype(np.float32) / 32768.0
                tensor_chunk = torch.from_numpy(audio_float32)
                
                # Check for speech
                speech_dict = vad_iterator(tensor_chunk, return_seconds=True)
                
                # Update speaking state
                if speech_dict:
                    if 'start' in speech_dict:
                        logger.info("VAD: Speech started")
                        is_speaking = True
                    if 'end' in speech_dict:
                        logger.info("VAD: Speech ended")
                        is_speaking = False
                        
                        # End of phrase: Add last chunk and transribe
                        speech_buffer.extend(chunk_bytes)
                        
                        if len(speech_buffer) > 16000: # Min 1 sec of speech
                            audio_array = np.frombuffer(speech_buffer, dtype=np.int16).astype(np.float32) / 32768.0
                            segments, info = model.transcribe(audio_array, beam_size=1, language="en", condition_on_previous_text=False)
                            text = " ".join([segment.text for segment in segments])
                            if text.strip():
                                await websocket.send_json({"text": text.strip(), "is_final": True})
                        
                        speech_buffer = bytearray()
                        vad_iterator.reset_states()
                        continue # Skip appending this chunk again to avoided double add

                # If speaking, accumulate audio
                if is_speaking:
                    speech_buffer.extend(chunk_bytes)
                    
                # Safety: Limit buffer size (e.g. 30 seconds)
                if len(speech_buffer) > 32000 * 30:
                     speech_buffer = speech_buffer[-32000*30:]

    except WebSocketDisconnect:
        logger.info("Client disconnected")
    except Exception as e:
        logger.error(f"Error processing audio: {e}")
