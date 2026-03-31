# Dual Workspace Protocol

Bu vault tek katmanlı değil, iki farklı çalışma mantığını birlikte taşır:

- `Legacy ayrımlar`: araştırmayı klasör bazlı düşünme ve okuma düzeni
- `ROC ayrımları`: otomasyon, veri akışı, proje yönetimi ve üretim hattı

Karar:

- Legacy klasörler korunur.
- ROC klasörleri aktif üretim omurgası olarak kullanılır.
- Aynı içerik iki kez çoğaltılmaz; legacy klasörler referans ve zihinsel harita olarak yaşar.

## Neden İki Katman?

Legacy yapı şu soruya iyi cevap veriyor:

- "Şu an ne tür bir iş yapıyorum?"

ROC yapı şu soruya iyi cevap veriyor:

- "Bu iş üretim hattında nereye oturuyor?"

Bu yüzden:

- `01_Literature_Review` gibi klasörler düşünme biçimini temsil eder
- `100-Literature` gibi klasörler sistemik bilgi tabanını temsil eder

## Kullanım Kuralı

### Legacy klasörler

Amaç:

- okuma alışkanlığını korumak
- eski çalışma reflekslerini kaybetmemek
- zihinsel oryantasyon sağlamak

İşlev:

- yönlendirme
- referans
- hafıza

### ROC klasörleri

Amaç:

- yeni not üretmek
- veri akışını sürdürmek
- proje, yöntem ve çıktı yönetmek

İşlev:

- aktif yazım
- otomasyon
- entegrasyon

## Brainstorming Katmanı

AI ile düşünme ve fikir geliştirme için ayrı alanlar:

- `200-Concepts/240-Brainstorming-Lab`
- `300-Projects/340-Idea-Incubator`

İlke:

- ham fikir önce brainstorming alanına düşer
- olgunlaşan fikir proje klasörüne taşınır
- doğrulanan fikir veri ve yöntem katmanına bağlanır

## Çalışma Ritimleri

### 1. Exploratory mode

- soru üret
- kavram haritası kur
- karşı argüman çıkar
- yöntem seçenekleri listele

Konum:

- `240-Brainstorming-Lab`

### 2. Structured research mode

- kaynak seç
- paper note üret
- method map güncelle
- equation library bağla

Konum:

- `100-Literature`
- `500-Methods`

### 3. Production mode

- proje dosyası aç
- veri bağla
- analiz çalıştır
- makale taslağı yaz

Konum:

- `300-Projects`
- `400-Data`
- `700-Analysis-Output`

## AI İle Çalışma Kuralı

AI sadece yazan bir asistan değil, düşünme ortağı olarak kullanılmalıdır.

AI kullanım kipleri:

- `brainstorming`
- `socratic challenge`
- `literature compression`
- `method comparison`
- `equation reconstruction`
- `draft critique`

Her kip için çıktıların yeri farklıdır:

- brainstorming -> `240-Brainstorming-Lab`
- literature compression -> `140-Paper-Notes`
- method comparison -> `150-Method-Maps`
- equation reconstruction -> `540-Equation-Library`
- draft critique -> ilgili proje klasörü
