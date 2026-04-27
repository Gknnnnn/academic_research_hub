# Eurasian Energy Dependency — XGBoost + SHAP (Inteligencia Artificial)

## Objective
What drives energy import dependency in Eurasian economies?
An Explainable AI approach using XGBoost and SHAP decomposition.

## Target Journal
**Inteligencia Artificial** (SCIE Q2, IF=3.7, APC=free)
- Scope: AI/ML methodology + applied domains
- Perfect fit: XGBoost + SHAP + economic panel

## Data
- Source: IGI Eurasian Energy panel (already collected 2026-04-22)
- Path: `../2026-IGI-Eurasian-Energy-Geopolitics/02-Data/panel_eurasian_energy_v2_20260422.csv`
- N=14 Eurasian countries, T=2000–2022, ~308 obs
- DV: energy_dep (energy import dependency %)
- Features: gdppc, trade, inflation, exrate_dep, res_rents, fiscal_comp, exporter, ca_bal

## Countries (N=14)
Armenia, Azerbaijan, Belarus, Georgia, Kazakhstan, Kyrgyzstan, Moldova,
Russia, Tajikistan, Türkiye, Ukraine, Uzbekistan + 2 others (from panel)

## Methodology
1. EDA + correlation matrix
2. XGBoost (temporal hold-out: train 2000-2017, test 2018-2022)
3. SHAP beeswarm + bar + waterfall (country-level)
4. Benchmark: OLS + FE-DK
5. Robustness: Random Forest, LOO by country

## Research Gap
No published study applies XAI/SHAP to energy import dependency in Eurasian panel.
All existing studies use linear panel models (CS-ARDL, MG, CCEMG) — MGO fills this gap.

## Authors
Solo: Res. Asst. Dr. M. Gökhan Özdemir (mgozdemirera@kku.edu.tr | ORCID: 0000-0002-6756-7285)

## Status
- [x] Data available (IGI panel)
- [x] XGBoost + SHAP script (02-Methods/xgboost_eurasian_energy.py) — 2026-04-24
- [x] Results: model_comparison_xgb.csv + shap_importance_energy.csv + 5×TIFF figures + pred_vs_actual
- [x] Manuscript (QMD) — 04-Manuscript/main.qmd ✅ 2026-04-24
- [x] DOCX render — main.docx 522KB ✅ 2026-04-24
- [x] Sparring Round 1 — P1–P8 fixed (balanced→unbalanced, HP table, policy institutions, abstract trimmed, zombie citations removed) ✅ 2026-04-24
- [x] Sparring Round 2 — P1–P8 fixed (full-panel SHAP justified, r=0.77 disclosure, fiscal_comp defined, LOO limitation, train R² all models, pred-vs-actual figure) ✅ 2026-04-24
- [x] Humanization — AI-fingerprint language removed; MGO Q1 English style applied ✅ 2026-04-24
- [x] Anonymous version — main_anonymous.docx 522KB ✅ 2026-04-24
- [x] Cover letter — 01-Admin/cover_letter_IA_v1.md ✅ 2026-04-24
- [ ] Submit → Inteligencia Artificial (https://www.editorialmanager.com/inta/)

## Key Results (2026-04-24)
- XGBoost Test R²=0.871, RMSE=45.64 pp | RF=0.877 | OLS=0.696
- Top SHAP: Net Energy Exporter (70.07pp) >> Resource Rents (23.93) >> ln(GDPpc) (15.39)
