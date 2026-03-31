import os
import requests
import glob

ZOTERO_STORAGE = "/Users/mehmetgokhanozdemir/Zotero/storage"
LIGHTRAG_API = "http://localhost:8000/index_pdf"

def sync_zotero_to_lightrag():
    print("🔍 Zotero kütüphanesi taranıyor...")
    pdf_files = glob.glob(os.path.join(ZOTERO_STORAGE, "**/*.pdf"), recursive=True)
    print(f"📦 Toplam {len(pdf_files)} PDF dosyası bulundu.")

    for pdf_path in pdf_files:
        try:
            with open(pdf_path, 'rb') as f:
                files = {'file': f}
                response = requests.post(LIGHTRAG_API, files=files)
                if response.status_code == 200:
                    print(f"✅ İndekslendi: {os.path.basename(pdf_path)}")
                else:
                    print(f"❌ Hata: {os.path.basename(pdf_path)} (Kod: {response.status_code})")
        except Exception as e:
            print(f"⚠️ Kritik Hata: {e}")

if __name__ == "__main__":
    sync_zotero_to_lightrag()
