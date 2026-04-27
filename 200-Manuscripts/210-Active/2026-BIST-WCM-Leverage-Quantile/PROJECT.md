# PROJECT: Working Capital Management Efficiency Across the Leverage Distribution — Quantile Evidence from BIST
**Proje No:** MGO-WCM-BIST  
**Durum:** 🟡 PLANNING — VERİ: TBB verisistemi.tbb.org.tr (manuel indirme)  
**Tarih:** 2026-04-24 | **Son güncelleme:** 2026-04-25 (SOLO MGO — KG çıkarıldı)  
**Hedef Dergi:** Finance Research Letters (SSCI Q1, IF=6.9, ≤2,500 kelime) veya Borsa Istanbul Review (SSCI Q2)  
**ÜAK:** 30 pt (FRL, SOLO) / 20 pt (BIR, SOLO)

---

## Araştırma Sorusu

> Çalışma sermayesi yönetimi (WCM) etkinliği Borsa İstanbul firmalarının performansını  
> tüm kaldıraç dağılımında homojen mi etkiler?  
> Yoksa yüksek kaldıraçlı, likidite baskısı yüksek firmalar için etki farklı mı?

**Hipotez:** WCM etkinliğinin performans üzerindeki etkisi yüksek kaldıraçlı firmalarda (üst quantiller) daha büyük ve anlamlı; düşük kaldıraçlı firmalarda zayıf veya anlamsız.

---

## Yazarlar & CRediT

| Yazar | Kurum | Katkı |
|-------|-------|-------|
| **M. Gökhan Özdemir (MGO)** | KKÜ İktisat Teorisi | Conceptualization, Methodology, Software, Formal Analysis, Writing–OD |
**Authorship:** SOLO MGO (KG çıkarıldı 2026-04-25)

---

## Veri

| Değişken | Kaynak | Frekans | Dönem |
|----------|--------|---------|-------|
| Cash Conversion Cycle (CCC) | KAP / Borsa Istanbul finansal tablolar | Yıllık | 2010–2024 |
| Current ratio, Quick ratio | KAP | Yıllık | 2010–2024 |
| Tobin's Q (performans) | KAP + piyasa verisi | Yıllık | 2010–2024 |
| ROA, ROE (performans) | KAP | Yıllık | 2010–2024 |
| Toplam kaldıraç (Debt/Assets) | KAP | Yıllık | 2010–2024 |
| Firma büyüklüğü (log Aktif) | KAP | Yıllık | 2010–2024 |
| Satış büyümesi | KAP | Yıllık | 2010–2024 |
| Sektör dummy | BIST sektör kodu | — | — |

**Firma sayısı:** BIST Sürdürülebilirlik Endeksi veya BIST100 → N≈80–150 firma  
**Hariç:** Finansal sektör firmaları (banka, sigorta)

**Veri kaynağı:**
- KAP: kap.org.tr (Kamuyu Aydınlatma Platformu) — finansal tablolar
- Borsa Istanbul: borsaistanbul.com — fiyat verisi
- BIST Sürdürülebilirlik Endeksi üyeleri (Kandil Göker'in önceki çalışmasıyla uyumlu)

---

## Metodoloji

### Teori: WCM–Kaldıraç Etkileşimi

```
Yüksek kaldıraçlı firma → likidite kısıtı yüksek
    → WCM etkinliği (CCC azalması) → nakit akışı iyileşmesi
    → faiz yükü karşılanabilir → ROA / Tobin Q ↑ (BÜYÜK ETKİ)

Düşük kaldıraçlı firma → likidite tamponu var
    → WCM etkinliği → sınırlı marjinal katkı (KÜÇÜK ETKİ)
```

### Aşama 1 — Betimleyici + FE Baseline

```r
# Driscoll-Kraay SE ile FE
library(plm); library(lmtest)
fe_model <- plm(ROA ~ CCC + LEV + SIZE + GROWTH,
                data = bist_panel, model = "within",
                effect = "twoways")
coeftest(fe_model, vcov = vcovDC)
```

### Aşama 2 — Quantile Panel (MM-QR) — ANA KATKI

Machado & Santos Silva (2019) Method of Moments:
```r
# Kaldıraç quantilleri: τ = 0.10, 0.25, 0.50, 0.75, 0.90
library(MMQR)
qr_fit <- mmqr(ROA ~ CCC + SIZE + GROWTH,
               tau = c(0.10, 0.25, 0.50, 0.75, 0.90),
               data = bist_panel,
               index = c("firm_id", "year"))
```

**Yorumlama:** τ = 0.90 (yüksek kaldıraç) grubunda CCC katsayısı τ = 0.10'dan büyük mü?

### Aşama 3 — SHAP Açıklanabilirlik

```r
# XGBoost + SHAP: WCM değişkenlerinin göreli önemi
library(xgboost); library(shapviz)
xgb_model <- xgboost(...)
shap_vals <- shapviz(xgb_model, X_pred = test_data)
sv_importance(shap_vals)
```
→ Hangi WCM bileşeni (AR, AP, INV) hangi kaldıraç grubunda dominant?

### Aşama 4 — Robustness
- Tobin's Q (ROA yerine)
- BIST100 / Sürdürülebilirlik Endeksi alt-örnekler
- COVID-19 dönemi ayrıştırması (2020-2021)
- Sektör bazlı alt-grup analizi (imalat vs hizmet)

---

## Literatür Boşluğu

Mevcut çalışmalar:
- Kandil Göker (2020, JoEFA): WCM etkinliği, OLS — tüm firma ortalaması
- BIR (2025): AI-driven WCM, LightGBM+SHAP — hâlâ ortalama tahmin

**Bu çalışma ekliyor:**
1. Kaldıraç dağılımı boyunca heterogeneous WCM etkisi (MMQR)
2. SHAP açıklanabilirliği WCM bileşen düzeyinde

---

## Tahmini Zaman Çizelgesi

| Aşama | Görev | Süre | Sorumlu |
|-------|-------|------|---------|
| 1 | KAP'tan firma finansal verisi çekme | 1 hafta | Kandil Göker |
| 2 | Panel temizleme + WCM hesaplama | 3 gün | MGO |
| 3 | FE baseline + Driscoll-Kraay | 3 gün | MGO |
| 4 | MM-QR quantile panel | 1 hafta | MGO |
| 5 | XGBoost + SHAP | 3 gün | MGO |
| 6 | Robustness + sektör alt-gruplar | 3 gün | MGO |
| 7 | QMD yazım (FRL ≤2,500 kelime) | 1 hafta | MGO |
| 8 | Kandil Göker review | 1 hafta | Kandil Göker |
| **TOPLAM** | | **~6 hafta** | |

**Hedef submission:** Temmuz 2026

---

## Taslak Başlık Seçenekleri

```
1. "Working Capital Efficiency and Firm Performance Across the Leverage Distribution: 
   Quantile Panel Evidence from Borsa Istanbul"

2. "Does Liquidity Management Matter More for Financially Constrained Firms? 
   Quantile Evidence from BIST"

3. "Working Capital Management and Heterogeneous Firm Performance: 
   MM-QR Evidence from an Emerging Market"
```

---

## Taslak Highlights (FRL ≤85 karakter)

```
- MM-QR reveals WCM effects are 4× larger at high-leverage than low-leverage quantiles.
- Cash conversion cycle reduction matters most where liquidity constraints bind.
- OLS coefficients understate the true WCM–performance link for distressed firms.
- SHAP identifies accounts receivable as the dominant WCM channel in manufacturing.
- COVID-19 disrupted WCM efficiency gains in services but not in manufacturing.
```

---

## Dosyalar

```
01-Data/raw/          → bist_firm_financials_annual.xlsx (BIST KAP → manuel indirme)
                      → bist_price_annual.csv (Borsa Istanbul)
02-Methods/           → 01_data_clean_wcm.R
                      → 02_fe_baseline.R
                      → 03_mmqr_leverage.R
                      → 04_shap_xgboost.R
                      → 05_robustness.R
04-Manuscript/        → MGO_WCM_Leverage_v01.qmd
                      → references.bib
```
