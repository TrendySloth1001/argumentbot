  
import onnx
import json
import sys
from pathlib import Path

def patch_model(onnx_path):
    print(f"Loading {onnx_path}...")
    model = onnx.load(onnx_path)
    
    json_path = onnx_path.with_name(onnx_path.stem + ".onnx.json") # e.g. .onnx.json
    if not json_path.exists():
        # Try just .json
        json_path = onnx_path.with_name(onnx_path.stem + ".json")
        
    if not json_path.exists():
        print(f"JSON config not found for {onnx_path}")
        return

    print(f"Loading config from {json_path}...")
    with open(json_path, 'r', encoding='utf-8') as f:
        config = json.load(f)

    # Extract metadata
    # Piper JSON structure:
    # "audio": { "sample_rate": 22050 }
    # "num_speakers": 1
    # "speaker_id_map": {}
    
    meta_dict = {}
    
    # 1. sample_rate
    if "audio" in config and "sample_rate" in config["audio"]:
        meta_dict["sample_rate"] = str(config["audio"]["sample_rate"])
    
    # 2. n_speakers (sherpa-onnx expects this key name)
    if "num_speakers" in config:
        meta_dict["n_speakers"] = str(config["num_speakers"])
    
    # 3. speaker_ids (if any)
    # Sherpa expects "speaker_ids" as string if multi-speaker
    # But for single speaker, maybe not needed.
    
    # 4. language
    if "language" in config and "code" in config["language"]:
         meta_dict["language"] = config["language"]["code"]
         
    # 5. type
    meta_dict["type"] = "vits" # Explicitly mark as VITS
    meta_dict["comment"] = "Patched for sherpa-onnx"

    print("Injecting metadata:", meta_dict)
    
    # Add to model.metadata_props
    for key, value in meta_dict.items():
        meta = model.metadata_props.add()
        meta.key = key
        meta.value = value
        
    output_path = onnx_path # Overwrite? Or create new? Let's overwrite.
    print(f"Saving to {output_path}...")
    onnx.save(model, output_path)
    print("Done.")

if __name__ == "__main__":
    voices_dir = Path("voices")
    for onnx_file in voices_dir.glob("*.onnx"):
        patch_model(onnx_file)
