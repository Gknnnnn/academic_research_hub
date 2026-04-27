# EKC_BRICST v0.4

## Objective
Estimate Environmental Kuznets Curve for BRICS-T+MINT (N=9, 1995-2021) using CS-ARDL; identify EKC turning point (expected USD 3–7k GDP per capita).

## Data
- **Source:** World Bank WDI, IEA, IRENA
- **Panel:** 9 countries (Brazil, Russia, India, China, South Africa, Turkey, Mexico, Indonesia, Nigeria), 1995–2021 (N×T=243)
- **Variables:** CO₂ pc, GDP pc, renewable energy share, urbanization, trade openness

## Methodology
1. Pesaran CD test → confirm cross-section dependence
2. CIPS unit root test (H₀: I(1) with breaks)
3. Westerlund cointegration test
4. CS-ARDL estimation (Pesaran 2015)
5. Webb wild cluster bootstrap (N<30 clusters)
6. Structural break detection (Bai–Perron)

## Output
- Turning point estimate (USD pp), policy elasticities, long-run multipliers
- Q1 target (Energy Economics, Ecological Economics)
- Tables: CD/CIPS/Westerlund results, CS-ARDL coefficients, bootstrap CIs, sensitivity

## Status
v38 ✅ CURRENT SUBMIT FILE (60K) | **⚡ JEPO "Sent Back to Author" → MGO login required**

## v38 → v39 Upgrade (2026-04-26) — Appendix Table A6
- **tabA6_csdm_bootstrap_robustness.docx** ✅ → `03-Results/tables/word/`
- Panel A: csdm MG/CCE/DCCE/CS-ARDL — ln_ren robustly negative across all CSD-robust estimators
- Panel B: CCE bootstrap β_BC(ln_ren)=−0.238** p=0.009, CI [−0.376, −0.111] ✅
- 2 new bib entries added: `juodis2024cce` (DOI ✅) + `devos2024rank` (DOI ✅ CrossRef verified)
- **Manuscript narrative ready** (script output from 16_appendix_tabA6_csdm.R)
- **MGO action:** Insert tabA6 as Appendix A6 → save as v39 → submit JEPO

## 🔴 ANAYASA AUDIT — 2026-04-20 (Lissack Protocol)
**Kritik bulgu:** CS-ARDL MG income coefficients istatistiksel olarak anlamsız:
- M1: ln_gdp p=0.256, ln_gdp_sq p=0.260 (NS)
- M2: ln_gdp p=0.154, ln_gdp_sq p=0.158 (NS)
- CCEMG/AMG: tüm income quadratic terms NS
- Webb bootstrap: M1 p_boot=0.276, M2 p_boot=0.151 (NS)

**CCEMG robustness tablosunda hata DÜZELTILDI (2026-04-20):**
Yanlış *** işaretleri kaldırıldı → 11_ccemg_amg_robustness.md güncellendi.

**Doğru EKC kanıtı:**
- ✅ MMQR: τ=0.25–0.75 quantilelerinde EKC katsayıları anlamlı (p<0.001)
- ✅ Webb TP bootstrap: M1 %85.8, M2 %93.5 çizim inverted-U gösteriyor
- ✅ DH nedensellik: ln_gdp → ln_ef p=0.000

**Manuscript v33 FINAL doğrulandı (2026-04-20):** DOCX kontrol edildi.
- "EKC confirmed" ifadesi MEVCUT DEĞİL ✅
- CS-ARDL turning points "not statistically confirmed at 95% bootstrap level" olarak doğru etiketlenmiş ✅
- CCEMG/AMG ana tablolardan bilinçli olarak çıkarılmış, gerekçe açıkça yazılmış ✅
- Webb bootstrap CI'lar "span zero → significance cannot be confirmed" olarak doğru yorumlanmış ✅
- *** notasyonu hatası yalnızca INTERNAL `11_ccemg_amg_robustness.md` dosyasındaydı (düzeltildi) — submitted DOCX'ta bu hata YOK ✅

**Submitted manuscript ANAYASA COMPLIANT.**

## GAUSS Pipeline
```r
setwd("200-Manuscripts/210-Active/EKC_BRICST")
source("02-Methods/scripts/gauss_pipeline.R")
ekc_run_all()          # CD → CIPS → Westerlund → CS-ARDL → Bai-Perron
ekc_run_all(from_step=4)  # sadece CS-ARDL ve sonrası
```

## Veri (GAUSS formatı)
- `02-Methods/400-Data/processed/ekc_panel_gauss.csv` — N=9, T=27, 243 obs, 0 NA
- Sütunlar: id(1-9), year, ln_ef, ln_gdp, ln_gdp_sq, ln_ren, ln_trade, ln_urb
- GAUSS ülke kodları: BRA=1 CHN=2 IDN=3 IND=4 MEX=5 NGA=6 RUS=7 TUR=8 ZAF=9
