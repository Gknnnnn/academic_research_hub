import os
import re
import requests
from pdfminer.high_level import extract_text

PDF_DIR = "." # Script zaten bu klasörün içinde çalışacak

def find_doi(text):
    # DOI formatını yakalayan Regex kalıbı
    pattern = r'10.\d{4,9}/[-._;()/:A-Z0-9]+'
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
            
            # Yazar (İlk yazarın soyadı)
            author = "Unknown"
            if 'author' in data and len(data['author']) > 0:
                author = data['author'][0].get('family', 'Unknown')
            
            # Yıl
            year = "Year"
            if 'published-print' in data:
                year = data['published-print']['date-parts'][0][0]
            elif 'published-online' in data:
                year = data['published-online']['date-parts'][0][0]

            # Başlık (İlk 50 karakter ve geçersiz karakterleri temizle)
            title = "Title"
            if 'title' in data and len(data['title']) > 0:
                title = data['title'][0]
            
            clean_title = re.sub(r'[\\/*?:"<>|]', "", title)[:50].strip()
            
            return f"{year} - {author} - {clean_title}.pdf"
    except Exception as e:
        pass
    return None

print(f"Hedef klasör taranıyor: {os.getcwd()}")

for filename in os.listdir(PDF_DIR):
    # Sadece .pdf uzantılı ve daha önce isimlendirilmemiş (202 ile başlamayan vb.) dosyaları işle
    if filename.endswith(".pdf") and not re.match(r'^(19|20)\d{2}\s-', filename):
        filepath = os.path.join(PDF_DIR, filename)
        print(f"\nİnceleniyor: {filename}")
        
        try:
            # Sadece ilk 2 sayfayı oku (DOI genelde kapaktadır)
            text = extract_text(filepath, maxpages=2)
            doi = find_doi(text)
            
            if doi:
                print(f"🔍 DOI Bulundu: {doi}")
                new_name = get_metadata(doi)
                
                if new_name:
                    new_filepath = os.path.join(PDF_DIR, new_name)
                    os.rename(filepath, new_filepath)
                    print(f"✅ Yeniden adlandırıldı: {new_name}")
                else:
                    print("❌ Crossref API'den metaveri alınamadı.")
            else:
                print("❌ Metin içinde DOI bulunamadı.")
        except Exception as e:
            print(f"⚠️ Dosya okunamadı: {e}")

print("\n🚀 Operasyon tamamlandı!")
