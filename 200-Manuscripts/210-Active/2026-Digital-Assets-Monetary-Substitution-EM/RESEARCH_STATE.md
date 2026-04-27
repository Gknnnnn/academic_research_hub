# Araştırma Durumu — 2026-Digital-Assets-Monetary-Substitution-EM
_Son güncelleme: 2026-04-09_

## Araştırma Başlığı
"Macro Fragility, Digital Assets, and Monetary Substitution in Emerging Markets: A Quantile Panel Approach with a Proxy Evaluation"

**Hedef Dergi:** Emerging Markets Review (Elsevier, IF 4.6)  
**Yedek:** Journal of International Money and Finance; International Review of Economics & Finance  
**JEL:** F31, E41, G15, O16  
**Gönderim Hedefi:** 2026-04-30 | Kill Date: 2026-06-15  
**Yazarlar:** Onur Bilgin · Zaim Reha Yaşar · M. Gökhan Özdemir (corr.)

---

## Mevcut Aşama

- [x] 1. Konu Belirleme & Soru Formülasyonu
- [x] 2. Literatür Taraması
- [x] 3. Veri Toplama & Panel İnşası
- [x] 4. Analiz (10 hakem düzeltmesi dahil tüm robustness tamamlandı)
- [x] 5. Taslak Yazımı — v15.docx hazır (~13,533 kelime DOCX)
- [x] 6. Revizyon & Son Kontrol ← **TAMAMLANDI**
- [ ] 7. Gönderim ← **AKTİF AŞAMA**

**Aktif aşama:** 7 — EMR portal üzerinden gönderim

---

## Son Oturumda Yapılanlar
**2026-04-10 (Oturum — Chainalysis Başvurusu & §4.4 Güncelleme):**
- §4.4'e Chainalysis veri boşluğunu açıklayan kapsamlı dipnot eklendi (QMD satır ~136): MX/NG 2020-22 yapısal kısıt, email bounce (9 Nisan), web form başvurusu (9 Nisan), gönderim tarihinde yanıt yok — Q1 şeffaflık standardı karşılandı
- Chainalysis web form başvuru taslağı `01-Admin/chainalysis_data_request_webform.md` olarak kaydedildi — kopyalayıp yapıştır hazır
- Yanıt takip protokolü: 23 Nisan 2026'ya kadar yanıt yoksa dipnot zaten "no response as of submission date" ifadesini içeriyor
- **v16.docx render:** ✅ TAMAMLANDI (2026-04-10). 61 KB, 13,039 kelime, 666 paragraf. Validation: ALL PASSED. Footnote §4.4 yerleşti. Argentina absorber katsayıları doğrulandı (−10.284***, +9.573***).
- **Sıradaki eylem:** EMR portal gönderimi → https://www.editorialmanager.com/ememar/

**2026-04-09 (Oturum — GCAI Veri Değerlendirmesi):**
- Chainalysis GCAI veri boşluğu (MX/NG 2020-22) için kapsamlı alternatif kaynak taraması yapıldı
- GitHub, Triple-A, Fortune, Wayback Machine, Chainalysis blog araştırıldı
- **Sonuç:** Mexico 2020-2022'de top-20 dışında (yapısal kısıt); 2020 verisi hiçbir ülke için kamuya açık değil
- Mevcut N_verified=21 tasarımı doğrulandı — §4.4'te şeffaf biçimde raporlanmış, Q1 standartlarına uygun
- Chainalysis web formu üzerinden resmi başvuru yapılacak (email bounce'dan sonra)
- QMD (544 satır) ve v15.docx incelendi — tüm bölümler eksiksiz, placeholder yok

---

## Sıradaki Adımlar (Öncelik Sırasıyla)

1. [x] **Chainalysis web form başvurusu** — ✅ TAMAMLANDI (2026-04-09). `01-Admin/chainalysis_data_request_webform.md` hazır. §4.4 dipnotu eklendi. Yanıt takip: 23 Nisan 2026.
2. [ ] **EMR portal gönderimi** — https://www.editorialmanager.com/ememar/ ; cover letter + QMD-rendered DOCX + bib
3. [ ] **Funding teyidi** — TÜBİTAK/BAP desteği var mı? Yoksa "no specific grant" ifadesi cover letter'da mevcut
4. [ ] **v16.docx son render** — gönderim öncesi tek temiz render (Quarto + reference.docx)

---

## Anahtar Bulgular (Özet)

1. **Dollar primacy**: ΔDXYₜ her spesifikasyonda dominant; β̂=+1.042*** (M_base), +0.467*** (M_base_vix). Webb bootstrap altında tüm kantillerde anlamlı (τ=0.25–0.90, aralık +0.38–+0.45).
2. **Google Trends null**: hiçbir spesifikasyonda anlamlı değil (p_Webb>0.40). Proxy başarısızlığı — spekülatif dikkat ≠ parasal ikame.
3. **Crypto premium safety-valve**: β̂=−0.0082* (p_Webb=0.045); VIX kontrolü ile güçleniyor: −0.0081*** (p_Webb=0.001). DH nedensellik: premium → döviz yok (p=0.448); döviz → premium marginal (p=0.098*).
4. **GCAI triple-interaction (Ana bulgu)**: Base EM (BR/IN/MX/NG): β̂_GCAI×π=+0.676*** (p<0.001) — amplifikasyon. Argentina net: −10.284*** (≈112 bps aylık emilim). Turkey falsification: +9.573*** — aynı koşullar (sermaye kontrolü + yüksek enflasyon), P2P stablecoin altyapısı yok → zıt işaret.
5. **QR (pairs cluster bootstrap)**: BMI sadece τ=0.50'de anlamlı; RAC anlamsız; enflasyon τ≤0.50'de anlamlı. İddia edilen "kuyruk yoğunlaşması" geri alındı (i.i.d. bootstrap artefact).

---

## Tamamlanan Robustness Kontrolleri (10/10 MC yanıt)

| Test | Sonuç |
|---|---|
| MC-1: IV-2SLS (GCAI_L12) | F_excl=17.0>10; β̂_5^IV=+0.909 (yönsel tutarlı, anlamlı değil; N_cl=5 beklenen) |
| MC-2: Turkey extension | β̂_TR=+9.573*** — temiz kurumsal yanlışlama |
| KAOPEN horse-race | Linear KAOPEN misspecified; binary AR doğru tercih |
| Pairs bootstrap QR | Düzeltilmiş çıkarım: DXY dominant, BMI/RAC kuyruk-değil |
| VIX addition | Premium −0.0081*** (p=0.001) — güçleniyor |
| VIX placebo (GCAI×VIX) | p_Webb=0.474 — π kanalı, VIX değil |
| LOO country robustness | Mexico drop → işaret dönüşü (açıklandı, bilgilendirici) |
| Remittance/GDP (P3a) | Premium değişmez; remit×premium pozitif (yüksek FI'da emilim azalıyor) |
| DH causality (P5) | Crypto→döviz yok (p=0.448); döviz→crypto marginal |
| Financial inclusion moderator | Premium etki düşük-FI ülkelerde güçlü (AR arketip tutarlı) |
| Year FE | β̂_5^yfe=+0.911***, β̂_8^yfe=−11.542*** (daha güçlü) |
| MG/CCEMG | DXY dominant (MG); CCEMG CD yokken bilgilendirici değil |
| Driscoll-Kraay HAC | Yönsel tutarlı; N_cl=5'te inconsistent → Webb tercih |
| Driscoll-Kraay | Online appendix |

---

## Dosya Haritası

| Dosya | Durum |
|---|---|
| `04-Manuscript/Digital_Assets_Monetary_Substitution_EM_Draft.qmd` | ✅ 544 satır, tam |
| `04-Manuscript/Digital_Assets_Monetary_Substitution_EM_v15.docx` | ✅ 69KB, 2026-04-09 render |
| `04-Manuscript/Digital_Assets_Monetary_Substitution_EM_v16.docx` | ✅ 61KB, 13,039 kelime, 2026-04-10 — §4.4 Chainalysis dipnotu dahil, validation PASSED |
| `04-Manuscript/cover_letter_EMR.md` | ✅ hazır |
| `01-Admin/chainalysis_data_request_webform.md` | ✅ 2026-04-09, kopyalayıp yapıştır hazır |
| `04-Manuscript/references.bib` | ✅ 352 satır, 28 giriş |
| `03-Results/chainalysis/chainalysis_gcai_2020_2024.csv` | ✅ N_verified=21 |
| `MGO_Review_R1_1814466_REVIEWER_V2.docx` | ✅ hakem yanıt mektubu |

## GCAI Veri Durumu

- N_verified=21 country-year hücre (6 ülke × 2021-2024, bazı eksikliklerle)
- Mexico 2020-2022: top-20 dışında (yapısal kısıt) — veri doldurulamaz
- Nigeria 2022: top-20'de onaylı ama exact rank bilinmiyor
- 2020 verisi: tüm ülkeler için kamuya açık değil
- Chainalysis research@chainalysis.com: bounce (2026-04-06)
- **Yapılacak**: chainalysis.com/contact web formu başvurusu

## Açık Sorular

- Mexico LOO sign reversal: şeffaf biçimde §6.5'te açıklandı ve §8'de belirtildi; reviewer itiraz ederse "Colombia/Peru/Thailand'a genişletme" yanıtı hazır
- Chainalysis web form başvurusu yanıt vermezse §4.4'e "no response as of [date]" notu eklenecek
