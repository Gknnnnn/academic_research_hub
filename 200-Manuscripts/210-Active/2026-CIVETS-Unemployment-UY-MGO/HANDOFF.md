# HANDOFF — CIVETS Unemployment (UY + MGO) — 2026-04-28 (v2)

## One-Line Status
MGO + Uğur Yıldırım; first 2nd-gen heterogeneous panel of unemployment determinants in CIVETS (N=6, T=24); **SUBMISSION PACKAGE READY 2026-04-28**: main_anonymous.docx 25KB + Cover + Highlights (5×≤85✅) + ZIP 27KB → **⚠️ UY sign-off only → mc.manuscriptcentral.com/emft ($0)**.

## Files
- Data master: `01-Data/raw/civets_panel_full_20260428.csv` ✅ (21 vars × 144 obs)
- HCI raw: `01-Data/raw/civets_hci_raw_20260428.csv` ✅ (benchmark years only)
- WB supp: `01-Data/raw/civets_ilo_wb_supp_20260428.csv` ✅
- Pre-test log: `01-Data/raw/civets_pretest_results_20260428.txt` ✅
- Script 01: `02-Scripts/01_pretests.R` ✅
- Script 02: `02-Scripts/02_westerlund_coint.R` ✅
- Script 03: `02-Scripts/03_amg_ccemg.R` ✅
- Script 04: `02-Scripts/04_konya_causality.R` ✅
- **Westerlund ECT by country**: `03-Output/westerlund_ect_country_20260428.csv` ✅
- **Pedroni results**: `03-Output/pedroni_coint_results_20260428.csv` ✅
- **AMG/CCEMG results**: `03-Output/amg_ccemg_results_20260428.csv` ✅
- **Konya causality**: `03-Output/konya_causality_results_20260428.csv` ✅

## Design

| Component | Specification |
|-----------|--------------|
| Countries | COL, IDN, VNM, EGY, TUR, ZAF (N=6) |
| Period | 2000–2023 |
| Pre-tests | Pesaran CD + P-Y slope homogeneity + CIPS |
| Cointegration | Westerlund (2007) ECM + Pedroni (1999) |
| Estimation | AMG (primary) / CCEMG (robustness), Webb B=999 |
| Causality | Konya (2006) bootstrap B=499, lags=2 |
| Bootstrap | Webb wild cluster (N=6 < 30 — mandatory) |

## Pre-Test Results (2026-04-28)
| Test | Result | Implication |
|------|--------|-------------|
| Pesaran CD | 9/10 vars significant (p<0.05) | Strong CSD → 2nd-gen tests |
| P-Y Delta-tilde | 156.25, p<0.001 | Heterogeneous slopes → AMG/CCEMG |
| Hausman FE vs Pool | χ²=95.72, p≈0 | FE preferred |
| CIPS (avg CADF) | unemp=-1.51, trade=-1.17 | I(1) majority |

## Cointegration Results (2026-04-28)
| Test | Finding |
|------|---------|
| Westerlund (2007) ECT — IDN | t=-2.41* |
| Westerlund (2007) ECT — TUR | t=-2.20* |
| Westerlund (2007) ECT — VNM | t=-3.23*** |
| Pedroni (1999) 7-stat | 5/7 significant → cointegration confirmed |
| Country residual ADF — COL, IDN, TUR, VNM | significant |

**Conclusion: Heterogeneous partial cointegration (3-4/6 countries) → AMG/CCEMG appropriate.**

## AMG / CCEMG Results (2026-04-28) — Webb B=999
| Variable | AMG β | p(Webb) | CCEMG β | p(Webb) |
|----------|--------|---------|---------|---------|
| gdp_growth | −0.2965 | 0.016** | −0.1597 | 0.005*** |
| inflation | 0.0146 | 0.615 | −0.0214 | 0.463 |
| ln_trade | 1.5169 | 0.000*** | −3.1428 | 0.022** |
| ln_internet | −0.3704 | 0.499 | 1.7442 | 0.004*** |
| fdi | 0.0461 | 0.791 | −0.0830 | 0.232 |

⚠️ **ln_trade diverges between AMG and CCEMG** (diff=4.66): CCEMG CS-means absorbing trade dynamics → AMG preferred as primary; report divergence as robustness caveat.

**Key finding: GDP growth reduces unemployment long-run (AMG β=−0.30, p=0.016). Trade openness ambiguous. Inflation/FDI not significant.**

## Konya (2006) Causality Results (2026-04-28) — Bootstrap B=499
| Direction | Significant countries |
|-----------|----------------------|
| gdp_growth → unemp | ZAF*** |
| inflation → unemp | none |
| fdi → unemp | none |
| trade → unemp | none |
| unemp → gdp_growth | none |

**Interpretation: Unidirectional Granger causality GDP growth→unemployment in South Africa only. Long-run AMG effects without short-run predictive causality in 5/6 countries → persistence, rigidity, or lagged structural adjustment.**

## Current Blocker
⚠️ HCI: 4 benchmark years only → treat as cross-sectional robustness (don't include in main AMG)
⚠️ Uğur co-author sign-off needed before submit

## Completed Tasks
1. [x] Download WB HCI — sparse; use unemp_youth/vuln_emp proxies
2. [x] Panel balance check — N=6 T=24 balanced
3. [x] CD + slope homogeneity + CIPS
4. [x] Westerlund (2007) + Pedroni (1999) cointegration
5. [x] AMG / CCEMG + Webb wild cluster bootstrap
6. [x] Konya (2006) bootstrap causality

## Manuscript Status (2026-04-28) ✅
- `04-Manuscript/main.qmd` ✅ written — full paper (Intro + LitRev + Data/Methods + Results + Discussion + Conclusion)
- `04-Manuscript/main.docx` ✅ rendered clean (26KB, no warnings, 0 citation errors)
- `04-Manuscript/civets_unemployment.bib` ✅ 23 entries (added 6 missing: Autor/Dorn/Hanson 2013, Cameron/Miller 2015, Pesaran/Smith 1995, Stolper/Samuelson 1941, UNCTAD 2022, Wood 1995)

## Completed Tasks
7. [x] ~~Write QMD manuscript~~ — `main.qmd` + `main.docx` 26KB ✅
8. [x] ~~Anonymous copy~~ — `main_anonymous.docx` 25KB ✅
9. [x] ~~Submission package~~ — `05-Submission/CIVETS_EMFT_submission_20260428.zip` 27KB ✅

## Remaining Tasks
10. [ ] **UY sign-off** — email `uyildirim@kku.edu.tr` with `main.docx` for co-author review
11. [ ] Robustness run: goveff as control in AMG (re-run `03_amg_ccemg.R` with ext_regs)
12. [ ] **SUBMIT** → mc.manuscriptcentral.com/emft (MGO login, $0, SSCI Q2)

## Next Immediate Step
⚠️ **UY sign-off only blocker** → email `uyildirim@kku.edu.tr` → then submit EMFT.

## Submission Target
**Plan A:** Emerging Markets Finance and Trade (SSCI Q2, $0) — mc.manuscriptcentral.com/emft
**Plan B:** Journal of the Asia Pacific Economy (SSCI Q3)
**Plan C:** Economic Research-Ekonomska Istraživanja (ESCI, free)
