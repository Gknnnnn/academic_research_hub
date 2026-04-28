# Next Session Handoff — Sudden Stops Panel EM
**Last updated:** 2026-04-28  
**Paper:** "Global Uncertainty, Domestic Credit, and Sudden Stops: Panel Evidence with Cross-Sectional Dependence Correction"  
**Target:** IREF (Plan A, $0, Q2) | JPM (Plan B) | EMFT (Plan C)

---

## 🔴 CRITICAL BLOCKER (must do first — in MGO browser)

### 1. BOP Quarterly Gross Capital Flows
**URL:** https://data.imf.org/?sk=7A51304B-6426-40C0-83DD-CA473CA1FD52  
**Variables:** FDI liabilities + Portfolio liabilities + Other investment liabilities  
**Date range:** 1990Q1–2024Q4  
**Save as:** `02-Data/raw/imf_bop_gross_quarterly_20260428.csv`  
**Format expected:** country | date (YYYYQQ) | indicator | value_usd_mn

### 2. GPR Global Index (bot-blocked from CLI)
**URL:** https://www.matteoiacoviello.com/gpr.htm  
**Download:** `data_gpr_export.xls` → extract global column → quarterly mean  
**Save as:** `02-Data/raw/gpr_global_quarterly.csv`  
**Columns:** date, gpr

### 3. IMF iMaPP Database
**URL:** https://www.imf.org/en/Topics/financial-sector-surveillance/imapp  
**File:** `iMaPP_Database.xlsx` (ZIP)  
**Save as:** `02-Data/raw/imapp_quarterly_20260428.xlsx`

### 4. IRR Exchange Rate Regime
**URL:** https://www.ilzetzki.com/irr-data  
**Save as:** `02-Data/raw/irr_regime_annual.csv`

---

## ✅ COMPLETED (session 2026-04-28)

### Data
- Push factors (FRED API): `raw/push_factors_quarterly_20260428.csv` (145Q, VIX/FFR/US GDP/10Y) ✅
- WDI controls (WB API): `raw/wdi_controls_annual_20260428.csv` (40 ctry, 1399 rows) ✅
- Trilemma ACI: `raw/trilemma_aci_iso3_20260428.csv` (179 ctry, 1970-2020) ✅

### Code
- `03-Code/01_episode_identification_FW2012.R` — Forbes-Warnock rolling 5yr SD algorithm ✅
- `03-Code/02_data_collection_imf_bop.R` — all API downloads except BOP/GPR/iMaPP ✅
- `03-Code/03_panel_probit_estimation.R` — M1–M5, DK-SE, AME, robustness battery ✅
- `03-Code/04_merge_panel.R` — full panel merge, audit function ✅

### Manuscript
- `04-Manuscript/sudden_stops_v01.qmd` — full skeleton (intro + lit review + methods written) ✅
- `04-Manuscript/sudden_stops.bib` — 17 entries, 15 DOIs verified ✅

### Bibliography DOI Status (all 17 entries)
| Key | DOI | Status |
|-----|-----|--------|
| calvo1998capital | none | pre-DOI era |
| calvo2004empirics | 10.3386/w10520 | ✅ |
| edwards2004financial | — | [UNVERIFIED] |
| forbes2012capital | 10.1016/j.jinteco.2012.03.006 | ✅ |
| eichengreen2016sudden | 10.1596/1813-9450-7639 | ✅ |
| emter2023leverage | 10.1016/j.iref.2022.11.029 | ✅ |
| du2025us | 10.1002/ijfe.2914 | ✅ |
| wang2025sudden | 10.1016/j.intfin.2025.102111 | ✅ |
| hakhverdyan2026sudden | 10.21511/imfi.23(1).2026.24 | ✅ |
| acosta2025firm | 10.5089/9798229005128.001 | ✅ |
| chinn2006ito | 10.1016/j.jdeveco.2005.05.010 | ✅ |
| caldara2022measuring | 10.1257/aer.20191823 | ✅ |
| alam2019macroprudential | 10.5089/9781498302708.001 | ✅ |
| calvo1993leiderman | 10.2307/3867379 | ✅ |
| fernandez1996new | 10.1016/0304-3878(95)00041-0 | ✅ |
| chuhan1998cross | 10.1016/S0304-3878(98)00044-3 | ✅ |
| pesaran2004cd | — | [UNVERIFIED — consider citing Econometrics 2021 DOI:10.3390/econometrics9030028] |
| driscoll1998consistent | 10.1162/003465398557825 | ✅ |

---

## ⏭️ NEXT TASKS (after BOP/GPR/iMaPP downloads)

```
Step 1: source("03-Code/01_episode_identification_FW2012.R")
        # → 02-Data/raw/sudden_stop_binary_fw2012.csv
        # Cross-check: GFC 2008Q4-2009Q1 and COVID 2020Q1-Q2 should show SS=1

Step 2: source("03-Code/04_merge_panel.R")
        # data_list <- load_all()
        # df_merged <- build_panel(data_list)
        # df_clean  <- clean_panel(df_merged)
        # audit_panel(df_clean)
        # → 02-Data/clean/panel_sudden_stops_YYYYMMDD.csv

Step 3: source("03-Code/03_panel_probit_estimation.R")
        # → Pesaran CD pretests → Table 3
        # → M1–M5 baseline results → Table 4
        # → AME table → Table 5
        # → Robustness → Table 6
        # → Eurasian subsample → Table 7

Step 4: Fill in manuscript placeholders (Tables 1–7 + abstract + conclusion)
```

---

## 📐 KEY DESIGN DECISIONS (locked)

- **Episode definition:** Forbes-Warnock (2012) gross inflows; ≥1SD sustained + ≥2SD peak; 20-quarter rolling window
- **Core novelty:** Driscoll-Kraay SE on all panel probits — first CSD-robust sudden stop study
- **Model sequence:** M1 push-only → M2 pull-only → M3 baseline → M4 +MPP → M5 +MPP×credit (main result)
- **Eurasian subsample:** N<30 clusters → Webb wild bootstrap mandatory
- **Benchmark to beat:** Hakhverdyan et al. (2026) IMFI — VIX→0.39pp AME (our result should replicate/extend)
- **JIMF excluded:** non-refundable $250 fee — Anayasa rule

---

## 📍 Literature Synthesis
Full 12-section synthesis with confidence scores: `01-Literature/RESEARCH_SYNTHESIS_2026-04-28.md`
