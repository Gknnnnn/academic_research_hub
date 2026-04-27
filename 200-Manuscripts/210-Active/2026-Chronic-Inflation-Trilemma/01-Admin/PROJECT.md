# PROJECT: Chronic Inflation × Impossible Trinity

**Status:** Data assembly — 2026-04-27  
**Target:** IREF (SSCI Q1, IF ~7.5, $0) — Plan A  
**Backup:** Open Economies Review (SSCI Q2, $0) — Plan B  
**JIMF:** Plan C only — $250 non-refundable ⚠️

## Research Question
Does a country's trilemma configuration (monetary independence, exchange rate stability, capital openness) determine the probability of chronic inflation?

## Data Sources
- Aizenman-Chinn-Ito trilemma indices: web.pdx.edu/~ito/trilemma_indexes.htm
  - MI: 172 countries, 1960–2020
  - ERS: 181 countries, 1961–2020
  - KAOPEN: 181 countries, 1970–2023
  - ⚠️ MANUAL DOWNLOAD REQUIRED → save to 02-Data/raw/trilemma_indexes_update2020.dta
- World Bank WDI: inflation + controls (auto-fetch via WDI package)
- Sample: N ≈ 80–100 dev/emerging, T = 1985–2020

## Methodology
- Pre-tests: Pesaran CD → Pesaran-Yamagata → CIPS
- Main: RE Probit (binary chronic inflation) + System-GMM (level)
- LR: CS-ARDL / CCEMG if CSD confirmed
- ID: Shambaugh (2004) base country instruments for ERS endogeneity
- Robustness: alternative thresholds (7%, 15%), sub-periods, IT/non-IT

## Key Variables
- DV: chronic_inf (CPI > 10% for ≥3 consecutive years)
- Alt DV: inflation persistence (AR1 rolling)
- Key X: MII, ERS, KAOPEN, MII×KAOPEN
- Controls: GDP growth, trade openness, fiscal balance, broad money, FDI, ToT

## Verified Literature
- Ito & Kawai (2024) JIMF: DOI 10.1016/j.jimonfin.2024.103182 ✅
- ACI (2013) RIE: 21(3):447-458 ✅ (PDF verified)
- ACI (2010) JIMF: Vol.29 No.4 ✅
- Athanasopoulos et al. (2025) SSRN 5110065 ✅
- Montes et al. (2024) IJFE: DOI 10.1002/ijfe.2737 ⚠️ UNVERIFIED
- Cevik & Zhu (2020) JIOD: 32(3):375-386 ⚠️ DOI UNVERIFIED

## ⚠️ Blockers
1. Manual download: trilemma_indexes_update2020.dta → 02-Data/raw/
2. DOI verification: Montes et al. + Cevik & Zhu + 3 older papers
3. CBI index: Romelli (2022) EJPE — DOI unverified, obtain separately

## File Convention
- Data: panel_chronic_inf_trilemma_YYYYMMDD.csv
- Scripts: 01_data_assembly.R, 02_pretests.R, 03_main_models.R, 04_robustness.R
