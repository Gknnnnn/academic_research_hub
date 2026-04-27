# HANDOFF — P1 Currency Wars Gold QQR — 2026-04-26

## One-Line Status
Solo QQR (Quantile-on-Quantile) analysis of DXY/JPY → gold (N=315, 2000–2026 monthly); DOCX 26KB re-rendered SOLO 2026-04-24; cover letter complete; **NO BLOCKER — submit to Finance Research Letters**.

## Files
- QMD: `04-Manuscript/Currency_Wars_Gold_Asymmetry_Draft.qmd`
- DOCX: `04-Manuscript/Currency_Wars_Gold_Asymmetry_Draft.docx` (26KB, SOLO MGO 2026-04-24) ✅
- QQR script: `02-Methods/run_paper1_qqr_v1.py` (B=500, scipy L-BFGS-B kernel-weighted QR)
- Beta surface: `03-Results/paper1_qqr_v1_beta_surface.csv`
- Figures: `04-Figures/fig_qqr_dxy.{png,tiff}` + `fig_qqr_jpy.{png,tiff}` + `fig_qqr_asymmetry_lines.{png,tiff}` (all 300 DPI)
- References: `04-Manuscript/references.bib` (17 entries, DOIs verified) ✅
- Cover letter: `01-Admin/cover_letter_FRL_v01.{md,docx}` (13KB) ✅

## Key Results (B=500, N=315, 2000–2026)

| Channel | β (τ≤0.3) | β (τ≥0.7) | Asymmetry | Sig. cells |
|---------|-----------|-----------|-----------|------------|
| DXY depreciation vs appreciation | −0.763 | −0.312 | **2.4:1** | 95.1% |
| JPY appreciation vs depreciation | −0.527 | −0.392 | **1.4:1** | 100% |

**Core finding:** β(θ,τ) surface is flat along θ (gold quantile) — asymmetry stems from currency regime (τ), not gold state.

## Tried & Failed
- Block-based NARDL: PSS F=2.94 inconclusive, ECM p=0.19, Wald asymmetry p>0.35 → abandoned → QQR pivot

## Working / Confirmed
- QQR (Sim & Zhou 2015) — kernel-weighted quantile regression, B=500 bootstrap
- SOLO MGO confirmed 2026-04-24: Öksüzkaya + Nimet Varlık removed; YAML/CRediT/cover letter updated ✅
- FRL Q1 precedent: Bouri et al. (2017, FRL) used QQR → excellent fit

## Current Blocker
NONE

## Remaining Tasks (ordered)
1. [ ] **SUBMIT** — editorialmanager.com/frl — MGO login
2. [ ] Upload: DOCX + cover letter
3. [ ] FRL: ≤2,500 words hard limit — verify word count before upload

## Next Immediate Step
Check DOCX word count (≤2,500 FRL limit) → editorialmanager.com/frl → MGO login → submit

## Submission Target
**Finance Research Letters** (Elsevier, SSCI Q1, IF=6.9) — editorialmanager.com/frl — $0 APC — ~7 day decision
Backup: IRFA (Q1) | Resources Policy (Q1) | IREF (Q1)
