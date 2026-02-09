import json
import os
from pathlib import Path

def convert_json_to_tokens(json_path):
    print(f"Processing {json_path}")
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    phoneme_id_map = data.get("phoneme_id_map", {})
    if not phoneme_id_map:
        print("No phoneme_id_map found.")
        return

    tokens_path = json_path.with_name(json_path.stem + ".tokens.txt")
    
    with open(tokens_path, 'w', encoding='utf-8') as f:
        # Sort by ID to be safe, though format is 'token id'
        # Invert map: ID -> list of tokens
        id_to_tokens = {}
        for token, ids in phoneme_id_map.items():
            for i in ids:
                id_to_tokens[i] = token
        
        # Write in order
        for i in sorted(id_to_tokens.keys()):
            token = id_to_tokens[i]
            # Handle space
            if token == " ":
                token = " " # Space is space
            f.write(f"{token} {i}\n")
            
    print(f"Wrote {tokens_path}")

def main():
    voices_dir = Path("voices")
    for json_file in voices_dir.glob("*.json"):
        convert_json_to_tokens(json_file)

if __name__ == "__main__":
    main()
