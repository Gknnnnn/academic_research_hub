# HANDOFF — WQR Short-Term Pipeline (P1/P2/P3) — 2026-04-26

## One-Line Status
Three solo wqr-method papers (QQR, NP-quantile causality, Wavelet-QR); all v03 disk-verified with Cover+Highlights; **P2→JEPO and P3→RENE have NO BLOCKER; P1→IRFA ready**.

## Files

### P1 — EPU→INR QQR
- DOCX: `P1-EPU-INR-QQR/04-Manuscript/P1_EPU_INR_QQR_v03.docx` (1.0MB, 2026-04-25)
- Submit: IRFA (Q1, 30pt) — or FRL (Q1)
- Portal: editorialmanager.com (IRFA)

### P2 — EKC NP Quantile Causality BRICS-T
- DOCX: `P2-EKC-NP-BRICST/04-Manuscript/P2_EKC_NP_BRICST_v03.docx` (25KB)
- Cover: `Cover_Letter_EnergyPolicy_P2.docx` ✅
- Highlights: `Highlights_P2_EKC_NP_BRICST.docx` (5×≤85) ✅
- Submit: **editorialmanager.com/JEPO** (Energy Policy, Q1, 30pt, $100 APC ⚠️)
- Backup: Resources Policy ($0)

### P3 — G7 Wavelet QR Energy-Growth
- DOCX: `P3-G7-Wavelet-QR/04-Manuscript/P3_G7_WaveletQR_v03.docx` (23KB)
- Cover: `Cover_Letter_RenewableEnergy_P3.docx` ✅
- Highlights: `Highlights_P3_G7_WaveletQR.docx` (5×≤85) ✅
- Submit: **editorialmanager.com/RENE** (Renewable Energy, Q1)
- Backup: Energy Economics

## Key Findings

| Paper | Main Finding |
|-------|-------------|
| P1 | EPU→INR depreciation 61.5% of cells; EPU→EUR appreciation (safe-haven); EM/DM dichotomy |
| P2 | EF→GDP: τ=0.10–0.90 all panels; China/India τ=0.50 significant; no GDP→EF at 5% |
| P3 | EC→GDP D1 broad-quantile, narrows to median at D2/D3; Germany+UK structural decoupling |

## Current Blocker
NONE for P2 and P3. P1 also NO BLOCKER.

**⚠️ P2→Energy Policy has $100 non-refundable submission fee.** Confirm before submitting — Resources Policy ($0) is equally strong backup.

## Remaining Tasks (ordered)
1. [ ] **DECIDE**: P2 → Energy Policy ($100) or Resources Policy ($0)?
2. [ ] Submit P2 → winner portal (MGO login)
3. [ ] Submit P3 → editorialmanager.com/RENE (MGO login)
4. [ ] Submit P1 → IRFA or FRL (MGO login)

## Next Immediate Step
Decide P2 journal (fee decision) → then submit P3 first (RENE, $0, faster)

## wqr Bug Fix (keep for reproducibility)
`/opt/homebrew/lib/python3.14/site-packages/wqr/causality.py:238`
Change: `tstat_vec[j] = float(numerator * denominator)`
To: `tstat_vec[j] = float(np.asarray(numerator * denominator).item())`
