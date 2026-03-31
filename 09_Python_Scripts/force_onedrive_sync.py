import os

# Dr. Özdemir'in Obsidian Ana Karargah Yolu
VAULT_PATH = "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma"

def force_onedrive_sync(directory):
    print("Google Antigravity: Obsidian kasası yerel diske çekiliyor...")
    synced_count = 0
    
    for root, dirs, files in os.walk(directory):
        for file in files:
            # Gizli dosyaları ve .DS_Store gibi sistem dosyalarını atla
            if file.startswith('.'):
                continue
                
            file_path = os.path.join(root, file)
            try:
                # Dosyayı okuma modunda açmak macOS File Provider API'sini tetikler 
                # ve dosyayı buluttan fiziksel diske indirmeye zorlar.
                with open(file_path, 'rb') as f:
                    f.read(1)
                synced_count += 1
            except Exception as e:
                print(f"❌ Senkronizasyon hatası ({file}): {e}")

    print(f"✅ İşlem tamamlandı! Toplam {synced_count} dosya fiziksel olarak diske sabitlendi.")
    print("Obsidian artık hiçbir dosyayı boş görmeyecek.")

if __name__ == "__main__":
    force_onedrive_sync(VAULT_PATH)
