# 2026-MGO Climate-Agriculture Nexus (Turkey ARDL)

## Objective
Estimate long-run climate-agriculture production elasticity for Turkey using ARDL bounds testing; quantify shock transmission and policy adaptation.

## Data
- **Source:** TurkStat, World Bank WDI, Turkish meteorological records
- **Time series:** Turkey annual 1970–2021 (T=52)
- **Variables:** Agricultural output (crop/livestock), temperature anomalies, precipitation, irrigation, labor, capital stock

## Methodology
1. Augmented Dickey–Fuller test (Unit root, H₀: I(1))
2. ARDL bounds test (H₀: no cointegration; critical values Pesaran 2001)
3. Long-run coefficients (ARDL levels; temperature, precipitation elasticities)
4. Short-run dynamic adjustment (ECM term)
5. Structural break test (Bai–Perron / Zivot–Andrews)
6. Granger causality (VECM formulation if cointegrated)
7. Robustness: Alternative lag selection (AIC, BIC), rolling-window stability

## Output
- Long-run climate elasticities, speed of adjustment, impulse-response functions
- Q1 target (Journal of Environmental Management, EE&P)
- Tables: ADF results, bounds test, ARDL coefficients, error-correction model

## Status
v08 ready (2026-04-14); builds on v07 citation cleanup with adversarial sparring (9 attacks), JEM-style peer review (M1–M6 + m1–m12), and humanizer pass (6 passages reframed). Substantive improvements embedded via humanization: novelty reframed around mixed-integration finding; USD 3.4 bn loss now reported as USD 0.1–6.6 bn CI; "elasticity" softened to "long-run conditional association" for non-climate regressors per M1. Outputs: `v08.docx` (29983 B, 6 tables, 0 unresolved citations), `v08.pdf` (85562 B, xelatex clean), three audit reports (sparring / peer review / humanizer DOCXs). Submission-ready conditional on: (i) Online Appendix A4 empirical estimation; (ii) Işık co-author sign-off; (iii) [revision-round] KPSS/DF-GLS columns, wild-bootstrap SEs, land-mechanism decomposition. Target: JEM Q1.
