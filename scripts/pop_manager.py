import os
import time
import requests
import bibtexparser
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Configuration
WATCH_DIR = "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/99_Exports"
LIGHTRAG_API = "http://localhost:8000/index_pdf"

class BibHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory and event.src_path.endswith('.bib'):
            print(f"📦 Yeni BibTeX dosyası algılandı: {event.src_path}")
            self.process_bib(event.src_path)

    def process_bib(self, file_path):
        try:
            with open(file_path, encoding='utf-8') as bibtex_file:
                bib_database = bibtexparser.load(bibtex_file)
                
            for entry in bib_database.entries:
                # Her bir girişi LightRAG'e metin olarak gönderiyoruz
                # Gelecekte burada Zotero API entegrasyonu da olacak
                summary = f"Title: {entry.get('title', 'N/A')}\n"
                summary += f"Authors: {entry.get('author', 'N/A')}\n"
                summary += f"Year: {entry.get('year', 'N/A')}\n"
                summary += f"Abstract: {entry.get('abstract', 'N/A')}\n"
                summary += f"DOI: {entry.get('doi', 'N/A')}\n"
                
                # Mock sending as text to /index_pdf (server.py needs to handle text too)
                requests.post(LIGHTRAG_API, files={'file': ('metadata.txt', summary)})
                print(f"✅ İndekslendi: {entry.get('title')[:50]}...")
                
        except Exception as e:
            print(f"❌ BibTeX işleme hatası: {e}")

if __name__ == "__main__":
    if not os.path.exists(WATCH_DIR):
        os.makedirs(WATCH_DIR)
        
    event_handler = BibHandler()
    observer = Observer()
    observer.schedule(event_handler, WATCH_DIR, recursive=False)
    
    print(f"🔭 {WATCH_DIR} klasörü izleniyor (Publish or Perish / Scopus çıktıları için)...")
    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
