# 2026-CE Cognitive Econometrics

## Objective
Quantify impact of digital cognitive capital (CBI 5-dim PCA) on firm-level productivity & innovation in EU-27 using multi-model inference (TWFE/SysGMM/CS-ARDL/DH/Bartik).

## Data
- **Source:** Eurobarometer (GESIS), Eurostat, firm-level micro surveys
- **Panel:** EU-27 firms/regions, 2010–2023 (macro arm complete)
- **Variables:** CBI index (5 dimensions), TFP growth, innovation output, R&D intensity

## Methodology
1. CBI 5-dim PCA reduction
2. Pesaran CD + CIPS tests (cross-section dependence, unit roots)
3. Model M1: TWFE with Driscoll–Kraay SE
4. Model M2: System-GMM (Blundell–Bond, lags of D.Y)
5. Model M3: CS-ARDL with MG/PMG comparison
6. Model M4: Dumitrescu–Hurlin causality
7. Model M5: Bartik-IV identification (regional shock exposure)
8. Webb wild cluster bootstrap (all models)

## Output
- Coefficients, heterogeneous effects, causal estimates, 95% bootstrap CIs
- Q1 target (EE&P, Journal of Economic Policy)
- Tables: CD/CIPS, dynamic panels, causal decomposition

## Status
Macro arm complete (CD/CIPS/Westerlund/CS-ARDL/DH); M1/M2 awaiting firm-level GESIS data; v0.2 with Webb bootstrap ready
