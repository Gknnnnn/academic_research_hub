# PROJECT — Monetary Policy Asymmetry & Current Account — Türkiye

**Author:** Res. Asst. Dr. M. Gökhan Özdemir | mgozdemirera@kku.edu.tr | ORCID: 0000-0002-6756-7285
**Target:** Emerging Markets Finance & Trade (SSCI Q2) — IF 2.3 | Backup: IREF (ESCI)
**Created:** 2026-04-24 | **Data fixed:** 2026-04-26

---

## Research Question

Does monetary policy tightening improve Türkiye's current account asymmetrically relative
to easing — and does this asymmetry hold across three distinct CBRT policy regimes?

## Core Finding (T=46Q, pre-fix, v02)

NARDL: L⁺=0.469 vs L⁻=0.166 (ratio 2.8×); ρ=−0.291**
LP: tightening β=+0.381* vs easing β=+0.019 NS
→ Absorption channel dominates; easing has no CA effect.

## Data Fix — 2026-04-26

| | Before | After |
|-|--------|-------|
| CA series | BPCACCD01TRQ188S (disc. 2014) | TURB6BLTT02STSAQ (BPM6, SA, 2024Q3) |
| GDP | NGDPRSAXDCTRQ (real — WRONG) | TURGDPNQDSMEI (nominal — CORRECT) |
| Sample | T=46Q (2003–2014) | T=82Q (2003Q1–2023Q3) |
| CA/GDP range | −20% artifact | −5.22% to +1.75% ✅ |

## Three-Regime Design (NEW — enabled by T=82)

| Regime | Period | T | CBRT stance |
|--------|--------|----|-------------|
| I | 2003Q1–2018Q2 | 62Q | Conventional IT |
| II | 2018Q3–2021Q4 | 14Q | Unorthodox easing |
| III | 2022Q1–2023Q3 | 7Q | Orthodox restart |

H0: Asymmetry holds in Regime I only (conventional policy).
H1: Asymmetry breaks in Regime II (rate cuts amid inflation = "policy reversal").
H2: Asymmetry re-emerges in Regime III.

## File Map

scripts/
  01_data_assembly.R          ← STALE (old CA series)
  01b_ca_data_corrected.R     ← ✅ USE THIS (TURB6BLTT02STSAQ + TURGDPNQDSMEI)
  02_nardl_estimation.R       ← needs update to read corrected panel
  03_qardl_distributional.py  ← optional distributional extension

data/
  turkey_quarterly_panel_corrected_20260426.csv  ← ✅ CURRENT PANEL (T=82)
  turkey_quarterly_panel_20260425.csv            ← STALE (real GDP artifact)
  raw/bis_reer_broad_quarterly_20260425.csv      ← ✅ BIS REER, 93Q

04-Manuscript/
  main.qmd         ← needs re-estimation update
  main_v02.docx    ← ✅ Sparring R1 done (valid for T=46 results)
  references.bib   ← 23 refs verified

## Next Steps (in order)

1. [ ] Rscript scripts/01b_ca_data_corrected.R   (verify corrected panel)
2. [ ] Update scripts/02_nardl_estimation.R       (read _corrected_ panel)
3. [ ] Re-run NARDL full + 3 regimes
4. [ ] Re-run LP IRFs per regime
5. [ ] Update 04-Manuscript/main.qmd with new results + three-regime framing
6. [ ] Sparring Round 2
7. [ ] quarto render → main_v03.docx
8. [ ] Submit editorialmanager.com/EMFT
