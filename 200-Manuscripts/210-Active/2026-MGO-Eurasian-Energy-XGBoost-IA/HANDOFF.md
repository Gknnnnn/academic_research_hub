# HANDOFF — Eurasian Energy XGBoost + SHAP — 2026-04-26

## One-Line Status
Solo XGBoost+SHAP paper on Eurasian energy import dependency (N=14, 2000–2022); all scripts, figures, DOCX, anonymous version, cover letter, and audit complete; Hormuz 2026 policy paragraph added; **NO BLOCKER — submit to Inteligencia Artificial (SCIE Q2)**.

## Files
- QMD/Script: `02-Methods/xgboost_eurasian_energy.py` ✅
- Latest DOCX: `04-Manuscript/main.docx` (522KB)
- Anonymous: `04-Manuscript/main_anonymous.docx` (522KB) ✅
- Cover letter: `01-Admin/cover_letter_IA_v1.md` ✅
- Data: `../2026-IGI-Eurasian-Energy-Geopolitics/02-Data/panel_eurasian_energy_v2_20260422.csv` (N=14, T=2000–2022, 320 obs)
- Figures: `03-Results/fig_shap_bar.tiff` + `fig_shap_beeswarm.tiff` + `fig_waterfall_Turkiye.tiff` + 2 more waterfall .tiff ✅

## Key Results (2026-04-24 run, verified)

| Model | Train R² | Test R² | RMSE |
|-------|----------|---------|------|
| XGBoost | 0.997 | 0.871 | 45.64 pp |
| Random Forest | — | 0.877 | 44.57 pp |
| Pooled OLS | — | 0.696 | 70.12 pp |

**Top SHAP Features (Mean |SHAP|, pp):**
1. Net Energy Exporter: 70.07 (dominant)
2. Resource Rents (% GDP): 23.93
3. ln(GDP per capita): 15.39
4. Current Account Balance: 9.78
5. Trade Openness: 6.91

**Temporal split:** Train 2000–2017 (250 obs) / Test 2018–2022 (70 obs)

## Tried & Failed
- `shap.TreeExplainer` version conflict → replaced with `pred_contribs=True` (version-safe)

## Working / Confirmed
- XGBoost + SHAP: pred_contribs=True (compatible, verified)
- Two sparring rounds complete; humanization (AI fingerprint removed)
- Submission audit complete: all declarations, numbered refs, anonymous version, cover letter ✅
- Hormuz 2026 crisis paragraph added to Discussion §"Implications for Energy Policy" (2026-04-25)
- Portal: editorialmanager.com/inta/ (Springer)
- APC: Free (Inteligencia Artificial, SCIE Q2, IF=3.7)

## Current Blocker
NONE

## Remaining Tasks (ordered)
1. [ ] **SUBMIT** — editorialmanager.com/inta/ — MGO login
2. [ ] Upload: `main.docx` (regular) + `main_anonymous.docx` (blind review) + cover letter
3. [ ] Springer EM portal: numbered references ✅, no JEL/highlights required

## Next Immediate Step
Go to editorialmanager.com/inta/ → MGO login → New Submission → upload main.docx + main_anonymous.docx + cover_letter_IA_v1.md

## Submission Target
**Inteligencia Artificial** (Springer, SCIE Q2, IF=3.7) — editorialmanager.com/inta/ — $0 APC — No deadline
