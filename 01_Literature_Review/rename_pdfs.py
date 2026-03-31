import os
import re
import requests
from pdfminer.high_level import extract_text

PDF_DIR = "."

def find_doi(text):
    pattern = r'10\.\d{4,9}/[-._;()/:A-Z0-9]+'
    match = re.search(pattern, text, re.IGNORECASE)
    if match:
        return match.group(0).rstrip('./')
    return None

def get_metadata(doi):
    try:
        url = f"https://api.crossref.org/works/{doi}"
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            data = response.json()['message']
            
            author = data['author'][0].get('family', 'Unknown') if 'author' in data and len(data['author']) > 0 else "Unknown"
            
            year = "Year"
            if 'published-print' in data:
                year = data['published-print']['date-parts'][0][0]
            elif 'published-online' in data:
                year = data['published-online']['date-parts'][0][0]

            title = data['title'][0] if 'title' in data and len(data['title']) > 0 else "Title"
            clean_title = re.sub(r'[\\/*?:"<>|]', "", title)[:50].strip()
            
            return f"{year} - {author} - {clean_title}.pdf"
    except Exception:
        pass
    return None

print("🔍 PDF isimlendirme operasyonu başlıyor...\n")

for filename in os.listdir(PDF_DIR):
    if filename.endswith(".pdf") and not re.match(r'^(19|20)\d{2}\s-', filename):
        filepath = os.path.join(PDF_DIR, filename)
        print(f"İnceleniyor: {filename}")
        
        try:
            text = extract_text(filepath, maxpages=2)
            doi = find_doi(text)
            
            if doi:
                new_name = get_metadata(doi)
                if new_name:
                    new_filepath = os.path.join(PDF_DIR, new_name)
                    os.rename(filepath, new_filepath)
                    print(f"✅ Başarılı: {new_name}")
                else:
                    print(f"❌ (DOI: {doi}) Crossref'ten veri alınamadı.")
            else:
                print("❌ DOI bulunamadı.")
        except Exception as e:
            print(f"⚠️ Hata: {e}")

