# HANDOFF — Digital Assets Monetary Substitution EM (P6) — 2026-04-26

## One-Line Status
Bilgin (Istanbul Medeniyet) + MGO; QR panel N=6 EMs; stablecoin Δ β=+0.000402** + GCAI ARG differential −10.284***; v18 DOCX; **BLOCKED: Bilgin co-author approval (new CRediT after Yaşar removed)**.

## Files
- QMD: `04-Manuscript/Digital_Assets_Monetary_Substitution_EM_v17.qmd`
- DOCX v15: `04-Manuscript/Digital_Assets_Monetary_Substitution_EM_v15.docx` (69K, JIMF styled) ✅
- DOCX v16: `04-Manuscript/Digital_Assets_Monetary_Substitution_EM_v16.docx` (71K) ✅
- Scripts: `02-Methods/run_paper6_v8_webb_bootstrap.py` + `run_paper6_v17_cd_ccemg_fi.py` ✅
- Graphical abstract: `03-Results/graphical_abstract.tiff` (300 DPI, 27MB) + `.png` ✅
- Reference.docx: `04-Manuscript/reference.docx` (JIMF Times New Roman 12pt format) ✅

## Key Results (Webb B=399, N=6 clusters)

| Model | Variable | β | p_Webb | Verdict |
|-------|----------|---|--------|---------|
| M_base | Inflation monthly | +0.0043 | <0.001*** | ROBUST |
| M_base | Broad money instability | −0.0044 | <0.001*** | ROBUST |
| M_crypto (2017+) | Crypto premium | −0.0082*** | 0.001 (with VIX) | ROBUST |
| M_GCAI base EM | β5 amplification | +0.676*** | <0.001 | — |
| M_GCAI ARG diff | β8 dampener | −10.960*** | <0.001 | — |
| Net ARG absorber | β5 + β8 | −10.284*** | — | 112 bps monthly |
| FI interaction | cp×FI | +0.082** | 0.013 | Low-FI safety-valve |

**CD test**: Pesaran CD=−0.391 (p=0.696) → No CSD → FE valid ✅
**Mexico sensitivity**: Drop MEX → β5 reverses sign; disclosed §6.5 Table A3

## Tried & Failed
- Conventional cluster-robust SEs → undersized at N=6; replaced with Webb bootstrap
- Zaim Reha Yaşar as co-author → removed 2026-04-24
- QR Table 2 iid bootstrap → replaced with pairs cluster QR bootstrap (Hagemann 2017)

## Working / Confirmed
- Webb bootstrap B=399 ✅ crypto premium strengthens with VIX control
- GAP extensions: CD test + P-Y + MG + CCEMG + FI interaction ✅
- DH Granger: dep→crypto p=0.098* (demand-pull) ✅
- CRediT updated: Bilgin + MGO only ✅

## Current Blocker
⚠️ **Onur Bilgin (KKÜ) co-author approval** — new CRediT after Yaşar removed; needs confirmation
⚠️ JIMF $250 non-refundable submission fee — confirm Bilgin approval first

## Remaining Tasks
1. [ ] Bilgin confirms new CRediT taxonomy (Conceptualization+Methodology+Data+Formal Analysis+Writing–OD+RE)
2. [ ] Tables 1–3: formal Word formatting for JIMF portal
3. [ ] **SUBMIT** — editorialmanager.com/jimf ($250 non-refundable) after Bilgin approval

## Next Immediate Step
Email Bilgin with updated CRediT table → await approval → format tables → submit JIMF

## Submission Target
**JIMF** (Elsevier, SSCI Q1, IF~4) — $250 non-refundable fee
Backup: Emerging Markets Review (Q1, $0)
