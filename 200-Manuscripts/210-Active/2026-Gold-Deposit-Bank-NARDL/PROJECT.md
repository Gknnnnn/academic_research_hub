# PROJECT: Gold Deposits, Bank Performance, and Currency Risk — NARDL Investigation
**Proje No:** MGO-GoldDeposit  
**Durum:** ✅ SUBMIT READY — v04.docx 26KB, Sparring R7-R9 DONE  
**Tarih:** 2026-04-24 | **Son güncelleme:** 2026-04-25 (SOLO MGO — KG çıkarıldı)  
**Hedef Dergi:** Finance Research Letters (SSCI Q1, IF=6.9, ≤2,500 kelime)  
**ÜAK:** 30 pt (SOLO)

---

## Araştırma Sorusu

> Türk bankalarındaki altın mevduat yükümlülüklerindeki artış ve azalış banka karlılığını  
> (ROA, NIM) asimetrik etkiler mi?  
> TRY değer kaybı bu kanalı güçlendirir mi?

**Neden şimdi şimdi önemli:**  
- Türkiye altın mevduatı 2025 Q3'te **%99 YoY büyüdü**  
- TCMB Mart 2026: $135 milyar altın rezervini TL savunmasında kullanmayı değerlendiriyor  
- Bu konuda **hiçbir yayın yok** (literature gap tamamen boş)

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
| Altın mevduat (hacim, ağırlık) | BDDK Aylık Bülten | Aylık/Çeyreklik | 2015–2026 |
| Altın mevduat / toplam pasif (%) | BDDK | Çeyreklik | 2015–2026 |
| ROA, NIM, ROE | BDDK banka bazlı | Çeyreklik | 2015–2026 |
| NPL oranı, CAR | BDDK | Çeyreklik | 2015–2026 |
| TRY/USD spot kur | TCMB EVDS | Günlük → aylık ort. | 2015–2026 |
| Altın fiyatı (USD/ons) | FRED (GOLDAMGBD228NLBM) | Günlük → aylık ort. | 2015–2026 |
| BIST100 | Borsa Istanbul | Aylık | 2015–2026 |
| Politika faizi (TCMB) | TCMB EVDS | Aylık | 2015–2026 |
| CPI enflasyonu | TÜİK | Aylık | 2015–2026 |

**Banka sayısı:** N≈20–28 (altın mevduat sunan bankalar — katılım dahil)  
**Panel boyutu:** N≈25, T=44 çeyrek (2015Q1–2025Q4)

**Kritik veri kaynağı:**
- BDDK Türk Bankacılık Sistemi İstatistikleri: https://www.bddk.org.tr/Istatistiki-Veriler
- TCMB EVDS: altın rezervleri + kur + faiz
- FRED: GOLDAMGBD228NLBM (London Fix altın fiyatı)

---

## Metodoloji

### Teori: Altın Mevduat Kanalı

```
TRY değer kaybı → hane altın talebi ↑ → altın mevduat ↑ 
    → banka pasif maliyeti ↑ (altın faizi ödeme yükümlülüğü)
    → NIM ↓ (düşük getirili varlıkla finanse)
    → ROA ↓ (maliyetlerin artması)

TERS SENARYO: Altın fiyatı artışı + TRY değer kazanma
    → altın mevduat çözme (vadesiz çıkış) 
    → banka bilanço boşalması riski
    → kısa vadeli likidite baskısı
```

### Aşama 1 — Betimleyici Analiz
- Altın mevduat/toplam pasif trend analizi (2015–2026)
- TRY değer kaybı episodları ile altın mevduat büyümesi arasındaki korelasyon
- Banka tipi segmentasyon: özel vs kamu vs katılım

### Aşama 2 — NARDL Asimetrik Analiz (ANA KATKI)
```
ROA_it = α_i + β₁⁺GOLD_DEP_it⁺ + β₁⁻GOLD_DEP_it⁻ 
         + β₂ΔTRY_t + β₃GOLD_PRICE_t + β₄INF_t + β₅POLICY_RATE_t + ε_it

# Partial sum decomposition:
GOLD_DEP⁺ = Σ max(ΔGOLD_DEP, 0)  → altın mevduat artışı
GOLD_DEP⁻ = Σ min(ΔGOLD_DEP, 0)  → altın mevduat azalışı
```
Wald testi: H₀: β₁⁺ = β₁⁻ (simetri) → reddedilirse asimetri kanıtlanmış

### Aşama 3 — Etkileşim Terimi (Moderasyon)
```
ROA_it = ... + β₅(GOLD_DEP × ΔTRY)_it + ...
```
TRY değer kaybı altın mevduat etkisini güçlendiriyor mu?

### Aşama 4 — Heterogeneous Panel
- PMG (Pooled Mean Group) uzun dönem + kısa dönem katsayıları
- AMG (Augmented Mean Group) — yatay kesit bağımlılık robustness
- CCEMG — cross-sectionally augmented

### Aşama 5 — Robustness
- NIM bağımlı değişkeni (ROA yerine)
- Altın fiyatını kontrol olarak vs. etkileşim olarak
- 2018 TRY krizi + 2021 faiz krizi yapısal kırılma (Bai-Perron)
- Sadece özel bankalar (kamu bankaları hariç)

---

## Tahmini Zaman Çizelgesi

| Aşama | Görev | Süre | Sorumlu |
|-------|-------|------|---------|
| 1–7 | ✅ TAMAMLANDI — v04.docx render edildi | — | MGO |
| 8 | `/review-paper FRL` çalıştır → submit | 1 gün | MGO |

**Hedef submission:** Nisan–Mayıs 2026 → **editorialmanager.com/FRL** (veya benzer platform)

---

## Taslak Başlık Seçenekleri

```
1. "Gold Deposits and Bank Profitability Under Currency Stress: 
   Asymmetric Evidence from Türkiye"
   
2. "When Households Hedge in Gold: Bank Performance Consequences 
   of the Gold Deposit Channel in Türkiye"
   
3. "Currency War Safe-Haven Demand and Bank Balance Sheet Stress: 
   NARDL Evidence from Turkish Banking"
```

---

## Taslak Highlights (≤85 karakter)

```
- Gold deposit liabilities grew 99% YoY in 2025; no published study examines bank impact.
- NARDL shows asymmetric pass-through: deposit inflows hurt NIM more than outflows help.
- TRY depreciation amplifies gold deposit–profitability channel (interaction significant).
- State and participation banks face differential exposure to gold liability dynamics.
- CBRT's gold reserve policy creates systemic feedback: a novel macro-prudential risk.
```

---

## Bağlantı: MGO Currency Wars Portföyü

Bu proje MGO'nun CW portföyündeki **P4 (Hard vs EM Currency Stress)** ve **P3 (Gold Policy Uncertainty)** çalışmalarıyla doğrudan bağlantılı:

```
CW Portföyü (makro): TRY → Gold price (QQR, FRL)
Bu Proje (mikro):    TRY → Gold deposits → Bank ROA/NIM (NARDL, IRFA)
```
→ Portföy derinliği: aynı TRY-altın kanalını makro (P4) + mikro (bu) düzeyde belgeler.

---

## Dosyalar

```
01-Data/raw/          → bddk_gold_deposits_quarterly.xlsx (Kandil Göker'den)
                      → tcmb_gold_reserves_monthly.csv (EVDS'den)
                      → fred_gold_price_monthly.csv (FRED'den)
                      → bddk_bank_financials_quarterly.xlsx
02-Methods/           → 01_data_panel.R
                      → 02_nardl_partial_sum.R
                      → 03_heterogeneous_panel.R
                      → 04_robustness.R
04-Manuscript/        → KG_MGO_GoldDeposit_v01.qmd
                      → references.bib
```
