# PROJECT: Bank Fragility Under TRY Depreciation — Quantile Panel Evidence
**Proje No:** MGO-BankFragility  
**Durum:** 🟡 PLANNING — VERİ BLOCKER: TBB manuel (verisistemi.tbb.org.tr)  
**Tarih:** 2026-04-24 | **Son güncelleme:** 2026-04-25 (SOLO MGO — KG çıkarıldı)  
**Hedef Dergi:** Finance Research Letters (SSCI Q1, IF=6.9, ≤2,500 kelime, ~7 gün karar)  
**ÜAK:** 30 pt (SOLO)

---

## Araştırma Sorusu

> TRY değer kaybı Türk bankalarının kırılganlığını (Z-score, Bankometer) homojen mi etkiler?  
> Yoksa zayıf sermayeliler (düşük Z-score quantilleri) orantısız risk mi üstlenir?

**Hipotez:** Panel quantile regression yüksek kırılganlıklı bankalarda TRY şok katsayısının daha büyük ve anlamlı olduğunu ortaya koyar; bu etki OLS ortalamasında gizlidir.

---

## Yazarlar & CRediT

| Yazar | Kurum | Katkı |
|-------|-------|-------|
| **Res. Asst. Dr. M. Gökhan Özdemir** | KKÜ İktisat Teorisi | Conceptualization, Methodology, Software, Data Curation, Formal Analysis, Writing–OD, Validation |

**Authorship:** SOLO MGO (KG çıkarıldı 2026-04-25)

---

## Veri

| Değişken | Kaynak | Frekans | Dönem |
|----------|--------|---------|-------|
| Z-score (bank-level) | BDDK / BRSA kamuoyu verileri | Yıllık | 2010–2024 |
| Bankometer S-score | BDDK + hesaplama | Yıllık | 2010–2024 |
| ROA, ROE, NIM, CAR, NPL | BDDK banka bazlı | Yıllık | 2010–2024 |
| TRY/USD reel efektif kur | TCMB EVDS | Yıllık ortalama | 2010–2024 |
| GDP büyümesi, enflasyon | TÜİK / WDI | Yıllık | 2010–2024 |
| BIST100 volatilitesi | Borsa Istanbul | Yıllık | 2010–2024 |
| VIX | FRED | Yıllık ortalama | 2010–2024 |

**Banka sayısı:** N≈28–33 (BDDK'da kayıtlı ticari + katılım bankaları)  
**Panel boyutu:** N≈30, T=15 → Webb wild cluster bootstrap zorunlu (N<30 küme)

**Veri indirme linkleri:**
- BDDK: https://www.bddk.org.tr/Istatistiki-Veriler/Turkce/1033/Temel-Gostergeler
- TCMB EVDS: https://evds2.tcmb.gov.tr (Döviz kurları → USDTRY)
- WDI: worldbank.org/indicator/NY.GDP.MKTP.KD.ZG

---

## Metodoloji

### Aşama 1 — Ön Testler
- [ ] Pesaran CD testi (yatay kesit bağımlılığı) → `pcdtest()` R/plm
- [ ] Pesaran-Yamagata homojenlik testi → `phtest()` R/plm
- [ ] CIPS panel birim kök → `cipstest()` R/MultipleBubbles veya Stata xtcadf

### Aşama 2 — Temel Model (OLS benchmark)
```
Z_it = α_i + β₁ ΔTRY_t + β₂ GDP_it + β₃ INF_t + β₄ VIX_t + ε_it
```
- FE/RE + Hausman testi
- Driscoll-Kraay SE (yatay kesit bağımlılığı için)

### Aşama 3 — Quantile Panel (ANA KATKI)
Machado & Santos Silva (2019) — Method of Moments Quantile Regression (MMQR):
```r
# R: quantreg paketi + MM-QR implementasyonu
library(MMQR)  # veya Manuel Lüdecke paketi
qfit <- mm_qr(Z_score ~ ΔTRY + GDP + INF + VIX,
              tau = c(0.10, 0.25, 0.50, 0.75, 0.90),
              data = panel_banks,
              index = c("bank_id", "year"))
```
**τ = 0.10** → en kırılgan bankalar (düşük Z-score)  
**τ = 0.90** → en sağlıklı bankalar

### Aşama 4 — Asimetri Testi
- TRY pozitif şok (değer kazanma) vs negatif şok (değer kaybı): NARDL partial sum decomposition
- Wald testi: β⁺ = β⁻ → reddedilirse asimetri kanıtlanmış

### Aşama 5 — Robustness
- Bankometer S-score (Z-score yerine)
- Sadece özel ticari bankalar (kamu bankaları hariç)
- 2018 TRY krizi öncesi/sonrası yapısal kırılma (Bai-Perron)
- Webb wild cluster bootstrap CI'ları (N<30 için zorunlu)

---

## Tahmini Zaman Çizelgesi

| Aşama | Görev | Süre | Sorumlu |
|-------|-------|------|---------|
| 1 | BDDK veri toplama + Z-score hesaplama | 1 hafta | Kandil Göker |
| 2 | TCMB/WDI makro veri birleştirme + panel temizleme | 3 gün | MGO |
| 3 | Ön testler + FE baseline | 3 gün | MGO |
| 4 | MM-QR quantile analizi + tablo | 1 hafta | MGO |
| 5 | NARDL asimetri testi | 3 gün | MGO |
| 6 | Robustness + Webb bootstrap | 3 gün | MGO |
| 7 | QMD yazım + DOCX render | 1 hafta | MGO |
| 8 | Kandil Göker review + revizyon | 1 hafta | Kandil Göker |
| **TOPLAM** | | **~6 hafta** | |

**Hedef submission:** Haziran 2026

---

## Taslak Başlık Seçenekleri

```
1. "TRY Depreciation and Bank Fragility: Heterogeneous Effects Across the 
   Stability Distribution in Türkiye"
   
2. "Does Dollar Strength Destabilise Weakly Capitalised Banks? 
   Quantile Panel Evidence from Türkiye"
   
3. "Asymmetric Pass-Through of Currency Depreciation to Bank Stability: 
   Distributional Evidence from Turkish Banking"
```
*(ANAYASA: "Impact of X on Y" formatı yasak)*

---

## Taslak Highlights (FRL ≤85 karakter)

```
- Panel quantile regression reveals heterogeneous TRY shock effects on bank Z-scores.
- Weakly capitalised banks (τ=0.10) face 3× larger fragility response to TRY shocks.
- OLS masks tail-distribution vulnerability: a distributional lens is essential.
- Webb wild cluster bootstrap confirms results under N<30 cluster conditions.
- 2018 TRY crisis creates structural break in banking stability dynamics.
```

---

## Literatür Boşluğu (Neden Yeni)

Topcu & Can (2025, FRL) → cross-country quantile panel, genel gelişmekte olan ülkeler.  
**Bu çalışma:** Türkiye-spesifik, banka düzeyi, TRY şoku odaklı, 2018 krizi dahil, Bankometer validasyonu.  
→ Tamamen özgün katkı, doğrudan yayınlanmış makaleyle çakışmıyor.

---

## Bib Anahtarları (eklenecek)

- `topcu2025political` — FRL 2025 (political stability + GPR + bank stability)
- `machado2019quantiles` — MMQR metodoloji (Journal of Econometrics 2019)
- `zscore_altman` — Z-score banka uyarlaması
- `bankometer` — Samad & Hassan Bankometer referansı
- `bddk_data` — BDDK veri kaynağı

---

## Dosyalar

```
01-Data/raw/          → bddk_bank_annual_raw.xlsx (TBB verisistemi.tbb.org.tr manuel indirme)
                      → tcmb_tryusd_annual.csv (EVDS'den indir)
                      → wdi_macro_panel.csv (WB API'den)
02-Methods/           → 01_data_merge.R
                      → 02_pretests.R
                      → 03_fe_baseline.R
                      → 04_mmqr_quantile.R
                      → 05_nardl_asym.R
                      → 06_robustness_webb.R
04-Manuscript/        → MGO_BankFragility_v01.qmd
                      → references.bib
```
