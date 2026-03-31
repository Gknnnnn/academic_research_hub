import os
import requests
import glob
from pathlib import Path

# Configuration
ZOTERO_STORAGE = "/Users/mehmetgokhanozdemir/Zotero/storage"
LIGHTRAG_API_URL = "http://localhost:8000/insert"

def sync_zotero_to_lightrag():
    print(f"Scanning Zotero storage: {ZOTERO_STORAGE}")
    
    # Zotero storage structure: storage/[KEY]/[FILENAME].pdf
    pdf_files = glob.glob(os.path.join(ZOTERO_STORAGE, "**/*.pdf"), recursive=True)
    
    print(f"Found {len(pdf_files)} PDF files.")
    
    for pdf_path in pdf_files:
        filename = os.path.basename(pdf_path)
        print(f"Processing: {filename}")
        
        # Simple check: has this been indexed? 
        # For a more robust solution, we'd maintain a local DB or check LightRAG metadata.
        # For now, we'll try to insert (LightRAG usually handles duplicates if implemented correctly).
        
        try:
            with open(pdf_path, 'rb') as f:
                # Assuming LightRAG /insert endpoint takes multipart/form-data with 'file'
                response = requests.post(LIGHTRAG_API_URL, files={'file': f})
                if response.status_code == 200:
                    print(f"Successfully indexed: {filename}")
                else:
                    print(f"Failed to index {filename}: {response.text}")
        except Exception as e:
            print(f"Error processing {filename}: {str(e)}")

if __name__ == "__main__":
    sync_zotero_to_lightrag()
