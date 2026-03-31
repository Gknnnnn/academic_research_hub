import os
import requests
from datetime import datetime

# Configuration
OBSIDIAN_BASE = "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma"
LIGHTRAG_API = "http://localhost:8000/query"

def get_research_directions():
    prompt = """
    Analiz ettiğin son makaleler ve ekonomi literatürü ışığında, 
    Dr. Mehmet Gökhan Özdemir için 3 adet 'Q1 Yayın Potansiyeli Olan Seviyede' 
    yeni araştırma sorusu ve bir 'Gelecek Çalışma Planı' (Future Work) taslağı oluştur.
    Lütfen Markdown formatında ve akademik bir dille (İngilizce/Türkçe karışık) yaz.
    Daha önce sorulmamış, ekonometrik olarak test edilebilir olsun.
    """
    
    try:
        response = requests.post(LIGHTRAG_API, json={"query": prompt, "mode": "global"})
        if response.status_code == 200:
            return response.json().get('response', "Yapay zeka henüz veri toplayamadı.")
        return "Sunucu hatası: Yanıt alınamadı."
    except Exception as e:
        return f"Hata: {e}"

def inject_to_obsidian():
    print("🧠 AI Araştırma Soruları oluşturuluyor...")
    directions = get_research_directions()
    
    # Hedef dosya: Teoretik Çerçeve klasörü içindeki AI günlüğü
    target_dir = os.path.join(OBSIDIAN_BASE, "02_Theoretical_Framework")
    if not os.path.exists(target_dir):
        os.makedirs(target_dir)
        
    target_file = os.path.join(target_dir, "AI_Research_Directions.md")
    
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    header = f"\n\n## 🚀 AI-Generated Research Update ({timestamp})\n"
    
    with open(target_file, "a", encoding="utf-8") as f:
        f.write(header)
        f.write(directions)
        
    print(f"✅ Obsidian kasanız güncellendi: {target_file}")

if __name__ == "__main__":
    inject_to_obsidian()
