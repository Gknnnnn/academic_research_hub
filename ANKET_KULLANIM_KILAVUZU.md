# Akademik Danışmanlık Memnuniyet Anketi – Kullanım Kılavuzu
**STAR Akreditasyonu | PUKO Döngüsü | 2024-2025 Bahar Yarıyılı**
Dr. M. Gökhan Özdemir – KKÜ İİBF İktisat Bölümü

---

## 📋 Anket Yapısı (17 Soru)

| Bölüm | Sorular | İçerik | PUKO Boyutu |
|-------|---------|--------|-------------|
| A | S1–S3 | Toplantı katılımı + KVKK nedenini öğrenme | Kontrol |
| B | S4–S6 | Ders kayıt durumu ve gerekçe | Önlem Al |
| C | S7–S15 | Danışmanlık kalitesi (Madde 5/1-12) | Tüm boyutlar |
| D | S16–S17 | Genel memnuniyet + açık uçlu öneri | Önlem Al |

**Zorunlu sorular:** S1, S4, S7–S16 (10 soru)
**Koşullu/isteğe bağlı:** S2, S3, S5, S6, S17

---

## 🚀 ADIM 1 – Formu Oluşturma (Apps Script)

1. Chrome'da **https://script.google.com** adresine gidin
2. **"Yeni proje"** (New project) butonuna tıklayın
3. Sol taraftaki editörde `Code.gs` dosyasını açın; içeriği **tamamen silin**
4. `akademik_danisman_anket.gs` dosyasının içeriğini **yapıştırın**
5. Üstteki fonksiyon seçiciden **`createAdvisorSurvey`** seçili olduğundan emin olun
6. ▶️ **Çalıştır** butonuna tıklayın
7. İlk çalıştırmada Google hesabı izni isteyecektir → **İzin Ver**
8. Sol alttaki **Execution Log** bölümünde şunları göreceksiniz:
   - `📝 Düzenleme URL'si` → Formu kendiniz düzenleyebilirsiniz
   - `🔗 Yanıt URL'si` → Öğrencilere göndereceğiniz link

---

## 📧 ADIM 2 – Öğrencilere Duyuru (KVKK Uyumlu)

> ⚠️ **KVKK Uyarısı:** Öğrencilerin e-posta adreslerini toplu CC/To alanına **YAZMAYINIZ**.
> Mutlaka **BCC (Gizli Alıcı)** kullanın. Böylece öğrenciler birbirlerinin e-posta
> adresini görmez.

### E-posta Şablonu (KKÜ kurumsal e-posta ile gönderin)

**Konu:** Akademik Danışmanlık Memnuniyet Anketi – Lütfen Katılın (2 dk.)

---

Sayın Öğrencim,

Kırıkkale Üniversitesi STAR Akreditasyonu kapsamında yürütülen kalite çalışmaları çerçevesinde, akademik danışmanlık hizmetlerini değerlendirmenizi ve geliştirmemize katkıda bulunmanızı talep ediyorum.

Anket tamamen **anonim** olup yanıtlarınız yalnızca hizmet kalitesinin iyileştirilmesinde kullanılacaktır. Doldurmak yaklaşık **2-3 dakika** sürmektedir.

**👉 Anket Linki:** [BURAYA URL YAZILAÇAK]

**Son katılım tarihi:** [TARİH]

06/04/2026 tarihli toplantıya katılamayan öğrencilerimiz için özellikle **S2 ve S3** sorularını yanıtlaması önem taşımaktadır.

Değerli katkılarınız için şimdiden teşekkür ederim.

Saygılarımla,
Dr. M. Gökhan Özdemir
Kırıkkale Üniversitesi – İİBF İktisat Bölümü

---

## 📊 ADIM 3 – Sonuçların Analizi (PUKO)

Form kapandıktan sonra Google Forms → **Yanıtlar** sekmesinden:

1. **Google E-Tablolar'a aktar** butonuna tıklayın
2. Açılan Excel/Sheets dosyasını SPSS veya R'a aktarın

### Önerilen PUKO Analizi

```r
library(readxl); library(psych); library(ggplot2)

df <- read_excel("anket_sonuclari.xlsx")

# Betimsel istatistik
describe(df[, c("S7","S8","S9","S10","S11","S12","S13","S14","S15","S16")])

# PUKO boyut ortalamaları
df$PLANLA    <- rowMeans(df[, c("S7","S8")], na.rm=TRUE)
df$UYGULA    <- rowMeans(df[, c("S9","S10")], na.rm=TRUE)
df$KONTROL   <- rowMeans(df[, c("S11","S12","S13")], na.rm=TRUE)
df$ONLEM_AL  <- rowMeans(df[, c("S14","S15")], na.rm=TRUE)

# Görselleştirme
boxplot(df[, c("PLANLA","UYGULA","KONTROL","ONLEM_AL")],
        main="PUKO Boyutları – Akademik Danışmanlık",
        ylab="Ortalama Puan (1-5)", col=c("#2196F3","#4CAF50","#FF9800","#E91E63"))

# Toplantı katılımı cross-tab
table(df$S1, df$S16)

# Ders kayıt durumu analizi
table(df$S4)
```

### STAR/PUKO Rapor Başlıkları

- **Güçlü Yönler (Puan ≥ 4):** …
- **İyileştirme Alanları (Puan < 3):** …
- **Toplantı Katılım Oranı:** 11/41 = %26.8 (danışmanlık kaydı yapanlar arasında)
- **Ders Kayıt Pasif Oranı:** 128/168 = %76.2 (riskli grup)

---

## 📎 Yasal Dayanak

| Belge | Link |
|-------|------|
| KKÜ Akademik Danışmanlık Yönergesi | [PDF](https://panel.kku.edu.tr/Content/oidb/kanun/yenimevzuat/KIRIKKALE%20%C3%9CN%C4%B0VERS%C4%B0TES%C4%B0%20AKADEM%C4%B0K%20DANI%C5%9EMANLIK%20Y%C3%96NERGES%C4%B0.pdf) |
| KKÜ Ön Lisans ve Lisans Eğitim-Öğretim Yönergesi | [PDF](https://panel.kku.edu.tr/Content/kkuhm/K%C3%9C%20%C3%96n%20Lisans%20ve%20Lisans%20E%C4%9Fitim-%C3%96%C4%9Fretim%20Y%C3%B6nergesi%2013.pdf) |
| KKÜ Ön Lisans ve Lisans Eğitim-Öğretim Yönetmeliği | [PDF](https://kku.edu.tr/Content/sbf/Documan/Y%C3%B6netmellik.pdf) |

---

*Bu belge STAR Akreditasyonu PUKO döngüsü kapsamında 2026-04-08 tarihinde hazırlanmıştır.*
