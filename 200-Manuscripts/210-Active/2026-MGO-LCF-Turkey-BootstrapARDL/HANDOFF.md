# HANDOFF — LCF Turkey Bootstrap ARDL — 2026-04-26 22:00

## One-Line Status
Solo MGO paper on Türkiye LCF determinants (Bootstrap ARDL + NARDL + FMOLS); v04 rendered clean 32KB; sparring P1–P5 all fixed; **NO BLOCKER — submit to Resources Policy**.

## Files
- QMD: `04-Manuscript/main.qmd`
- BIB: `04-Manuscript/references.bib`
- Latest DOCX: `04-Manuscript/main_v04_LCF_20260426.docx` (32KB)
- Data: `data/raw/turkey_lcf_panel_20260426.csv` (T=32, 1990–2021)
- Results: `results/RESULTS_LCF_20260426.md`

## Key Results (verified)

| Stat | Value | Source |
|------|-------|--------|
| PSS Bounds F-stat | 10.92 >> 1% CV=6.37 | Script 04 |
| ECT | −0.518*** (t=−8.26) | Script 04 |
| FMOLS lnREN | β=+0.407*** (SE=0.077) | Script 06 — MAIN FINDING |
| OLS lnGDP | β=−8.065** | Script 06 |
| OLS lnGDP² | β=+0.420** | U-shaped EKC ✅ |
| EKC turning point | $14,842 (2015 PPP) | Script 06 |
| NARDL Wald LR | F=0.098, p=0.758 | No income asymmetry |
| TY: LCF→REN | Chi²=2.17, p=0.054* | Borderline reverse |
| BG serial corr. | p=0.736 | ✅ Clean |
| CUSUM stability | p=0.778 | ✅ Stable |

## Tried & Failed
- GFN API (api.footprintnetwork.org) → 403 Forbidden (requires registration). Fix: York NEFBA 2025 free Excel
- `mcnair2021` citation → HALLUCINATION (doesn't exist). Fix: replaced with `mcnown2018` + `bertelli2022`
- Render from within project folder → fails ("Book chapter index.qmd not found"). Fix: copy to `/tmp/lcf_render/` (no book `_quarto.yml`)
- `apa.csl` missing from render path → fix: download from CSL GitHub repo to render folder

## Working / Confirmed
- bootCT v2.1.0 Bootstrap ARDL: PSS F=10.92 cointegration confirmed
- FMOLS β=+0.407*** is robust primary long-run estimator
- U-shaped EKC: Turkey at $14,800 in 2021, exactly at turning point ($14,842)
- All bib entries verified: `mcnown2018` DOI:10.1080/00036846.2017.1366643 ✅ | `bertelli2022` DOI:10.1016/j.econmod.2022.105987 ✅ | `yurtkuran2021` DOI:10.1016/j.renene.2021.03.009 ✅ | `naimoglu2025resources` DOI:10.1016/j.resourpol.2025.105705 ✅
- `gregory1996` DOI: `10.1016/0304-4076(69)41685-7` — Elsevier PII-based format ✅ CORRECT
- 12th Development Plan (2024–2028) citation: `turkiye2023plan12` ✅
- Sparring P1–P5 all fixed in v04

## Current Blocker
NONE

## Remaining Tasks (ordered)
1. [ ] **SUBMIT** — editorialmanager.com/jresourpol (MGO login, $0 APC)
2. [ ] Upload cover letter (write fresh from §1 Abstract)
3. [ ] Highlights file: 3–5 bullets ≤85 chars each (Resources Policy requires separate file)
4. [ ] CRediT: solo → "M. Gökhan Özdemir: Conceptualization, Methodology, Software, Formal Analysis, Writing"
5. [ ] Competing interests: "The author declares no competing interests."
6. [ ] Data availability: "Data available from York NEFBA 2025 and World Bank WDI"

## Next Immediate Step
Go to editorialmanager.com/jresourpol → MGO login → New Submission → upload `main_v04_LCF_20260426.docx` + `references.bib` + highlights file.

## Submission Target
**Resources Policy** (Elsevier SSCI Q1, IF≈8.2) — editorialmanager.com/jresourpol — $0 APC — No deadline
