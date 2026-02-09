import sherpa_onnx
import soundfile as sf
import time

def main():
    model_path = "sherpa_models/en_US-amy-medium.onnx"
    tokens_path = "sherpa_models/tokens.txt"
    data_dir = "sherpa_models/espeak-ng-data"
    
    print("Initialize config...")
    config = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                model=model_path,
                tokens=tokens_path,
                data_dir=data_dir,
            ),
            provider="cpu", # Start with CPU to be safe
            num_threads=2,
            debug=True,
        )
    )
    
    print("Initialize Loading model...")
    start_load = time.time()
    app = sherpa_onnx.OfflineTts(config)
    print(f"Model loaded in {time.time() - start_load:.4f}s")
    
    text = "This is a test of the emergency broadcast system."
    print("Generating...")
    start_gen = time.time()
    audio = app.generate(text, sid=0, speed=1.0)
    print(f"Generated {len(audio.samples)/audio.sample_rate:.2f}s audio in {time.time() - start_gen:.4f}s")
    
    sf.write("test_sherpa.wav", audio.samples, audio.sample_rate)
    print("Saved test_sherpa.wav")

if __name__ == "__main__":
    main()
