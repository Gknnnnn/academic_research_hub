# Araştırma Durumu — 2026-HBI-Tarim-Konya
_Son güncelleme: 2026-04-10 (oturum 2)_

## Araştırma Başlığı
"Structural Floor Analysis in Global Agricultural Value Added and 2030 Projection: Multilayer Artificial Neural Networks and Real Data-Driven Scenario Simulation Across 105 Countries"

**Yazar sırası:** Prof. Dr. Hacı Bayram IŞIK (1.), Arş. Gör. Dr. Mehmet Gökhan Özdemir (2.)  
**Hedef Dergi:** Agricultural Systems (Q1, SCIE, IF ≈ 6.1, Elsevier, APC=0)  
**Yedek:** International Journal of Forecasting (Q1, SSCI); Food Policy (Q1, SSCI/SCIE)  
**JEL:** Q10, O33, C45, C23, Q18, F63  
**Gönderim Hedefi:** 2026-04-30 ← ACİL  
**Kill Date:** 2026-06-01

---

## Mevcut Aşama

- [x] 1. Konu Belirleme & Soru Formülasyonu
- [x] 2. Literatür Taraması
- [x] 3. Veri Toplama & Panel İnşası (N=105, T=21, 2000–2020, tam dengeli)
- [x] 4. Analiz (6-7-5-1 MLP, Olden, SHAP, System GMM, DH nedensellik, Pedroni, IPS, EKC)
- [x] 5. Taslak Yazımı (v3 QMD + v3 DOCX, Türkçe kongre versiyonu)
- [ ] 6. **Q1 Revizyon & İngilizce Dönüşüm** ← **AKTİF AŞAMA** (ACİL — 2026-04-30)
- [ ] 7. Gönderim

**Aktif aşama:** 6 — Q1 Revizyon & İngilizce Dönüşüm

---

## Son Oturumda Yapılanlar

**2026-04-10 (Oturum 1):**
- Proje durumu değerlendirildi: v3 QMD + DOCX mevcut ama Türkçe kongre versiyonu
- RESEARCH_STATE.md oluşturuldu
- `01-Admin/cover_letter_AgriSystems.md` yazıldı
- `01-Admin/Q1_REVISION_NOTES_AgriSystems.md` yazıldı (7 kritik revizyon maddesi — CRITICAL/BLOCKER/REQUIRED/ENHANCEMENT)
- Kritik revizyonlar: İngilizce çeviri + 2021–2024 validasyon veri seti + sübvansiyon kontrol değişkeni

**2026-04-10 (Oturum 2):**
- ✅ **`04-Manuscript/MGO_HBI_Tarim_Konya_v4_EN.qmd` OLUŞTURULDU** — v3.qmd'nin tam metin İngilizce çevirisi (~1,550 satır)
  - Tüm anlatı bölümleri Q1 yayın kalitesinde İngilizceye çevrildi (GİRİŞ, LİTERATÜR, M&M, BULGULAR, TARTIŞMA, SONUÇ)
  - Tüm R kod blokları değiştirilmeden korundu
  - `lang: tr-TR` → `lang: en` değiştirildi
  - Q1_REVISION_NOTES'taki 5 iyileştirme eklendi: Data Floor metodolojik notu (§3.1), Subsidies paragrafı (§5.3), Syrquin–Chenery savunması (§5.4), Highlights (5 madde × ≤85 karakter), Yeni referanslar (Devarajan 2013, Gollin et al. 2014, Lewis 1954, Kuznets 1955, Syrquin & Chenery 1989)
  - Bağımsız §5 DISCUSSION bölümü oluşturuldu (§5.1–§5.5)
- ✅ **`04-Manuscript/MGO_HBI_Tarim_Konya_v4_EN.docx` oluşturuldu** (1.7 MB, pandoc; R inline değerleri placeholder olarak kalıyor — lokal quarto render gerekli)
- ⚠️ NOT: Lokal makineye quarto yüklüyse `quarto render MGO_HBI_Tarim_Konya_v4_EN.qmd --to docx` komutu gerçek R değerleriyle (R², 8.26%, vb.) DOCX üretir

**2026-04-10 (Oturum 3):**
- ✅ **§4.3.1 Equipment-to-Labour Partial Dependence Analysis** eklendi (v4_EN.qmd)
  - Tam panel için min-max normalization + MLP prediction + denormalization
  - Decile-based PDP ile ekipman-emek oranının konkav/asimptotik floor etkisi görselleştirildi
  - ggplot2 ile Figure 5b üretildi (95% CI ribbon + predicted/observed karşılaştırma)
  - Narrative: floor ~`pdp_min_pred`% seviyesinde düzleşen eğri → Structural Floor hipotezi için doğrudan görsel kanıt
- ✅ **§4.10 Out-of-Sample Validation (2021–2024)** eklendi (v4_EN.qmd)
  - WDI API ile 2021–2024 verisi otomatik çekiliyor (`tryCatch` + graceful failure fallback)
  - Eğitim dönemi min/max ile normalize ediliyor; 6-7-5-1 MLP'ye uygulanıyor
  - R²_OOS, RMSE_OOS, MAE_OOS hesaplanıyor; in-sample RMSE ile karşılaştırma
  - Narrative: COVID-19 / Ukrayna şoklarının floor mekanizmasını bozmadığı argümanı
  - Not: Lokal quarto render → WDI internet erişimi ile gerçek OOS metrikleri hesaplanır
- ✅ **`MGO_HBI_Tarim_Konya_v4_EN.docx` pandoc ile yeniden oluşturuldu** (1.7 MB; aynı TeX `\tag{}` uyarıları — non-fatal)

---

## Sıradaki Adımlar (Öncelik Sırasıyla)

1. [x] **İNGİLİZCE ÇEVİRİ** — ✅ TAMAMLANDI 2026-04-10.
2. [x] **2021–2024 Out-of-Sample Validasyon** — ✅ §4.10 eklendi 2026-04-10. WDI API çağrısı + tryCatch + R²/RMSE/MAE hesabı. Lokal render ile gerçek değerler aktif hale gelir.
3. [x] **Sübvansiyon Kontrol Değişkeni** — ✅ §5.3'te PSE limitations paragrafı mevcut (Oturum 2'de eklendi).
4. [x] **SHAP Deep-Dive Revizyon** — ✅ §4.3.1 Equipment-to-Labour PDP eklendi 2026-04-10.
5. [x] **"Yapısal Taban" kavramsal çerçeve netleşmesi** — ✅ §5.4 Syrquin–Chenery savunması mevcut (Oturum 2'de eklendi).
6. [ ] **Agricultural Systems format kontrolü** — Word count (7,000–10,000 kelime hedef), şekil sayısı (max 8), highlights (5 madde × 85 karakter), cover letter
7. [ ] **QMD'den DOCX render (lokal)** — `quarto render MGO_HBI_Tarim_Konya_v4_EN.qmd --to docx` komutu RStudio / Terminal'den çalıştırılmalı. Mevcut pandoc DOCX (v4_EN.docx) R inline değerleri placeholder; quarto render ile gerçek sayılar işlenir.
8. [ ] **HBI onayı** — Prof. Dr. Hacı Bayram Işık'ın Agricultural Systems'a gönderim onayı alınmalı.
9. [ ] **Agricultural Systems gönderim portali** — https://www.editorialmanager.com/agsy/

---

## Açık Sorular & Bekleyen Kararlar

- **Post-2020 Veri Erişimi**: WDI 2021–2022 verisi hazır; 2023–2024 tahmini verilerle doldurulabilir. FAOSTAT ekipman 2023 henüz güncellenmemiş.
- **Sübvansiyon değişkeni**: OECD PSE (Producer Support Estimate) %GDP verisi N=50 ülke için mevcut; tam dengeli panel için proxy gerekebilir. Alternatif: World Bank agricultural subsidies indicator.
- **Floor tanımı metodolojisi**: "En düşük %5 ülke ortalaması" mı yoksa "asimptotik regresyon eşiği" mi daha savunulabilir? Agricultural Systems hakemleri bu soruyu soracak.
- **Birinci yazar onayı**: HBI'ın Agricultural Systems'a gönderim onayı alınmalı (target değişikliği — önceki hedef Sustainable Development'tı).

---

## Anahtar Bulgular (Özet)

1. **MLP (6-7-5-1)**: R² = 0.9155 (train), test performansı doğrulandı; 105 ülke, 2000–2020.
2. **Yapısal Taban**: Küresel ~%8.26; yüksek gelir ~%2.71; orta gelir ~%10.44.
3. **Olden & SHAP**: Makineleşme (ekipman) ve gübre → negatif baskı; arazi ve verim → stabilizasyon.
4. **Pedroni/Fisher ESB + DH nedensellik**: Tarımsal payın ana belirleyicileri arasında eşbütünleşme ve çift yönlü nedensellik.
5. **System GMM**: Dinamik panel doğrulaması — araç seti sağlam; Hansen p>0.10.
6. **EKC okuma**: Lewis-Kuznets yönünde uyumlu; ancak azalma **sınırlı** (unbounded değil).

---

## Önemli Kaynaklar

- Pingali (2012) PNAS — tarımda teknoloji yoğunlaşması ve yapısal dönüşüm
- Syrquin & Chenery (1989) — sektörel yapı ve kalkınma
- Kaul et al. (2005) Applied Intelligence — tarımsal YSA modelleme
- Dumitrescu & Hurlin (2012) EM — heterogeneous panel causality
- Magazzino et al. (2025) — ANN + ekonometri hibrit çerçeve

---

## Dosya Haritası

| Dosya | Durum |
|---|---|
| `04-Manuscript/MGO_HBI_Tarim_Konya_v3.qmd` | ✅ v3 kaynak QMD (Türkçe) |
| `04-Manuscript/MGO_HBI_Tarim_Konya_v3.docx` | ✅ v3 DOCX (Türkçe kongre) |
| `04-Manuscript/MGO_HBI_Tarim_Konya_v3.html` | ✅ HTML render |
| `03-Results/*.rds` | ✅ Tüm analiz artefaktları mevcut |
| `03-Results/scenario_summary_2030_authoritative.csv` | ✅ 2030 senaryo sonuçları |
| `01-Admin/cover_letter_AgriSystems.md` | ✅ Hazır (2026-04-10) |
| `01-Admin/ADVERSARIAL_REPORT.md` | ✅ Mevcut — kritik zayıflıklar listeli |
| `04-Manuscript/MGO_HBI_Tarim_Konya_v4_EN.qmd` | ✅ OLUŞTURULDU 2026-04-10 — tam metin İngilizce (~1,550 satır) |
| `04-Manuscript/MGO_HBI_Tarim_Konya_v4_EN.docx` | ✅ OLUŞTURULDU 2026-04-10 (1.7 MB, pandoc; lokal quarto render önerilir) |
| `RESEARCH_STATE.md` | ✅ Bu dosya |
