# HANDOFF — CE Cognitive Econometrics EU-27 — 2026-04-26

## One-Line Status
MGO + Esra & Suat micro-macro panel (EU-27, 2010–2024); causal quartet complete (LPM/GRF/DML/TE); PDF 22pp 753KB compiled; **BLOCKED: Esra & Suat co-author review + journal decision**.

## Files
- LaTeX: `04-Manuscript/00_main.tex` + `sections/` ✅
- PDF: `04-Manuscript/` (22pp, 753KB, 2026-04-25) ✅
- Scripts 01–09: `04-Manuscript/code/` ✅ (all run)
- Macro data: `400-Data/processed/macro_CBI_panel_full.csv` (405×15) ✅
- Micro data: `400-Data/raw/EB/ZA7781_v2.dta` + ZA7952 + ZA8842 ✅
- CBI index: `400-Data/processed/CBI_country_year.rds` ✅

## Key Results

| Method | θ̂ (CBI→CE_Action) | p | Notes |
|--------|---------------------|---|-------|
| LPM + country FE (M1a) | −0.099 | <0.001*** | Baseline |
| Causal Forest ATE | −0.099 | — | CI: [−0.105, −0.092] |
| DoubleML PLR (M2) | ~−0.099 (target) | — | M2 co-author bypass ✅ |
| Bartik IV 2SLS M5 | −0.307* | 0.031 | F=4.82; LIML=2SLS ✅ |
| DH CBI→CMU | Wbar=4.119, Z=11.46 | 0.000*** | Macro short-run |
| DH CMU→CBI | Wbar=2.327, Z=4.88 | 0.000*** | Bidirectional |

**CBI PCA**: KMO=0.703 ✅ | Cronbach α=0.804 ✅ | PC1=60.8%
**CATE by income**: Low T1=−0.109 vs High T3=−0.084 → low-income 30% higher barrier
**TE (Script 09)**: TE(CBI→CE_Action) directional signal confirmed (KOCMI + SURD)

## Current Blocker
⚠️ **Esra & Suat co-author review** — role matrix not finalized
⚠️ **Journal decision**: Resources, Conservation and Recycling (Q1, IF~13) vs Ecological Economics

## Remaining Tasks
1. [ ] Confirm co-author roles (Esra & Suat) + send PDF
2. [ ] Decide journal: RCR vs EcolEcon
3. [ ] Write §4 Results section (data + analysis complete)
4. [ ] **SUBMIT** after co-author approval

## Next Immediate Step
Send PDF to Esra & Suat for role matrix discussion → write §4 → submit

## Submission Target
**Plan A**: Resources, Conservation and Recycling (Elsevier, SSCI Q1, IF~13) — $0 APC
**Plan B**: Ecological Economics (SSCI Q1) — ⚠️ numbered refs (not Harvard)
