# MCP Profile Recommendations

Bu depo için önerilen profil seti:

## 1) `academic-research`

Kullanım:
- literatür notları
- dosya tarama
- kaynak ve klasör keşfi
- taslak hazırlığı

Önerilen server türleri:
- filesystem erişimi, ama yalnızca bu depo köküyle sınırlı
- git/repo araçları
- read-only doküman tarayıcıları

Bu depo için somut profil:
- `economic-research`
- aktif MCP seti: `research_nexus`, `fetch`, `filesystem`, `time`
- özellikle ekonomi, politika, yöntem ve literatür sentezi için uygun

## 2) `manuscript`

Kullanım:
- bölüm revizyonları
- referans denetimi
- biçim ve tutarlılık kontrolü

Önerilen server türleri:
- dosya okuma/yazma yetkisi olan ama dar kapsamlı araçlar
- doküman üretim araçları

Bu depo için somut profil:
- `paper-writing`
- aktif MCP seti: `research_nexus`, `filesystem`, `time`
- gerekirse görev bazlı `fetch`
- draft, revision memo ve submission package odaklı

## 3) `ops`

Kullanım:
- veri akışı
- otomasyon
- script çalıştırma

Önerilen server türleri:
- shell/command çalıştırıcıları
- sınırlı görev otomasyonu
- yalnızca gerekli klasörlere erişen dosya araçları

## Güvenlik önceliği

- depoyu tam genişlikte mount etmeyin
- gizli anahtarları MCP araçlarına vermeyin
- yazma yetkisini sadece gerekli profil ve görevlerde açın
- veri klasörlerini varsayılan olarak salt okunur tutun

## Bu depo için önerilen varsayılan

1. Günlük keşif ve literatür işleri için `economic-research`
2. Taslak ve gönderim işleri için `paper-writing`
3. Shell veya geniş yazma yetkisini yalnızca ayrı `ops` oturumlarında açın
