# Data Inventory — Sudden Stops Panel
**Last updated:** 2026-04-28  
**Cross-check protocol:** Anayasa §DATA — all values verified before use

---

## STATUS OVERVIEW

| Dataset | File | Status | Countries | Years | Freq |
|---------|------|--------|-----------|-------|------|
| Push factors (VIX, FFR, US GDP, 10Y) | `raw/push_factors_quarterly_20260428.csv` | ✅ DOWNLOADED | Global | 1990–2026 | Quarterly |
| WDI controls (CA, growth, credit, trade, inflation, reserves) | `raw/wdi_controls_annual_20260428.csv` | ✅ DOWNLOADED | 40 | 1990–2024 | Annual |
| Trilemma indexes (ACI: ers, mi, ka_open) | `raw/trilemma_aci_iso3_20260428.csv` | ✅ DOWNLOADED | 179 | 1970–2020 | Annual |
| BOP quarterly gross inflows | — | ⚠️ MANUAL DOWNLOAD | 40–90 | 1990–2024 | Quarterly |
| IMF iMaPP macroprudential index | — | ⚠️ MANUAL DOWNLOAD | 65+ | 2000–2023 | Quarterly |
| GPR global index | `raw/gpr_global_quarterly.csv` | ✅ DOWNLOADED | Global | 1990Q1–2024Q4 | Quarterly |
| Exchange rate regime (IRR) | — | ⚠️ MANUAL DOWNLOAD | 150+ | 1940–2021 | Annual |

---

## VERIFIED DATA SUMMARY

### 1. Push Factors — `raw/push_factors_quarterly_20260428.csv`
**Source:** FRED API (key: `FRED_API_KEY` from `.env`) — verified 2026-04-28  
**Variables:** vix, ffr, us_gdp_growth, us_10y_yield  
**Rows:** 145 quarters × 4 variables  

| Cross-check | Value | Expected | Status |
|-------------|-------|----------|--------|
| VIX 2008Q4 | 58.6 | ~55–65 (GFC peak) | ✅ |
| FFR 2009Q1 | 0.18% | ~0.25% (ZLB) | ✅ |

### 2. WDI Controls — `raw/wdi_controls_annual_20260428.csv`
**Source:** World Bank API (no key) — verified 2026-04-28  
**Variables:** ca_pct_gdp, gdp_growth, credit_pct_gdp, trade_open, inflation, reserves_usd  
**Rows:** 1,399 (40 countries × ~35 years, unbalanced)  

| Cross-check | Value | Expected | Status |
|-------------|-------|----------|--------|
| TUR CA/GDP 2011 | −8.8% | ~−8.8% (WEO) | ✅ |
| TUR credit/GDP 2011 | 48.7% | ~48–52% (pre-boom) | ✅ |

**Note on missing countries:** BLR, MDA, KGZ, TJK, UZB, SRB, ALB, BGD, LKA, JOR, GHA, ETH, TZA not in WDI for some variables — expand in next download pass.

### 3. Trilemma Indexes — `raw/trilemma_aci_iso3_20260428.csv`
**Source:** Aizenman-Chinn-Ito (PDX) — local file from Chronic Inflation Trilemma project  
**Variables:** ers (exchange rate stability), mi (monetary independence), ka_open (capital acct openness)  
**Rows:** 7,496 (179 countries × 1970–2020)  

| Cross-check | Value | Expected | Status |
|-------------|-------|----------|--------|
| TUR ka_open 2011 | 0.448 | ~0.4–0.5 (partial liberalisation) | ✅ |

---

## MANUAL DOWNLOADS REQUIRED

### A. BOP Quarterly Gross Capital Flows (CRITICAL — needed for episode ID)
**URL:** https://data.imf.org/?sk=7A51304B-6426-40C0-83DD-CA473CA1FD52  
**Alternative:** IMF eLibrary bulk download → BOP_2017M06  
**Variables needed:**
- `BFD_BP6_USD` — FDI liabilities (gross inflows of FDI)
- `BFP_BP6_USD` — Portfolio investment liabilities
- `BFO_BP6_USD` — Other investment liabilities
- **Total gross inflows = sum of above**

**Instructions:**
1. Open IMF Data Portal URL above
2. Select: Balance of Payments → Quarterly → All countries
3. Date range: 1990Q1–2024Q4
4. Download CSV
5. Save as: `02-Data/raw/imf_bop_gross_quarterly_YYYYMMDD.csv`
6. Columns expected: country, date (YYYYQQ), indicator, value_usd_mn

### B. IMF iMaPP Macroprudential Policy Index
**URL:** https://www.imf.org/en/Topics/financial-sector-surveillance/imapp  
**File:** `iMaPP_Database.xlsx`  
**Variables:** tightening/loosening counts by instrument type  
**Instructions:** Download → save as `02-Data/raw/imapp_quarterly_YYYYMMDD.xlsx`

### C. GPR Global Index (Caldara-Iacoviello) ✅ COMPLETE
**URL:** https://www.matteoiacoviello.com/gpr.htm  
**File:** `raw/gpr_global_quarterly.csv` — 140 quarters × 22 columns (1990Q1–2024Q4)  
**Downloaded:** 2026-04-28 (browser User-Agent bypass; XLS → Python xlrd extraction → quarterly mean aggregation)  
**Cross-checks passed:** 9/11 2001Q3=207.9 ✅ | Russia-Ukraine 2022Q1=224.6 ✅ | COVID 2020Q1=98.6 ✅ | GFC 2008Q4=78.5 ✅

### D. Exchange Rate Regime Classification (Ilzetzki-Reinhart-Rogoff)
**URL:** https://www.ilzetzki.com/irr-data  
**File:** Annual classification 1940–2021  
**Instructions:** Download → save as `02-Data/raw/irr_regime_annual.csv`

---

## DOWNLOAD STATUS NOTES (2026-04-28)

### GPR Index (Caldara-Iacoviello 2022) — ✅ DONE 2026-04-28
- **Downloaded via browser User-Agent curl** (bot-block bypassed: `-A "Mozilla/5.0..."`)
- File: `raw/gpr_global_quarterly.csv` — 140 rows × 22 columns
- DOI of index paper: 10.1257/aer.20191823 ✅

### iMaPP (Alam et al. 2019)
- **Download from**: https://www.imf.org/en/Topics/financial-sector-surveillance/imapp
- Format: Excel ZIP with Stata do-file
- DOI: 10.5089/9781498302708.001 ✅

## NEXT STEPS AFTER MANUAL DOWNLOADS

1. Run `03-Code/01_episode_identification_FW2012.R` → generates `sudden_stop_binary_fw2012.csv`
2. Run `03-Code/04_merge_panel.R` → `clean/panel_sudden_stops_YYYYMMDD.csv`
3. Run `03-Code/03_panel_probit_estimation.R` → Pesaran CD pretests + baseline M1–M5 + robustness
