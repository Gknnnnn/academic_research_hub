# 2026 Digital Assets & Monetary Substitution (Emerging Markets)

## Objective
Quantify monetary substitution shock: GCAI (Global Crypto Adoption Index) × inflation → M1 velocity & currency demand in EMs; identify structural breaks via Bai–Perron.

## Data
- **Source:** Chainalysis Geography Report, World Bank WDI (M1, inflation, GDP, FX), Triple-A (fallback)
- **Panel:** Major EM adopters (Argentina, Brazil, Mexico, Nigeria, Turkey, India, Vietnam, Philippines), 2015–2024
- **Note:** Chainalysis 2020–22 cells for AR/BR/IN/MX/NG unverified; pending validation or Triple-A fallback

## Methodology
1. Construct GCAI shock × inflation interaction term (time-varying treatment)
2. Unit root tests (CIPS) + cointegration (Westerlund)
3. Panel SVAR: identify monetary substitution shocks (Cholesky / sign restrictions)
4. Impulse-response: effect on M1 velocity, FX depreciation, inflation persistence
5. Bai–Perron structural breaks (EM central bank policy shifts 2017, 2020, 2022)
6. Robustness: Local projection (Jordà 2005) with varying horizons
7. Subsample: countries with high/low crypto adoption

## Output
- Monetary substitution elasticity, dynamic responses, break dates + policy interpretation
- Q1 target (Journal of International Economics, International Review of Economics & Finance)
- Appendix: Chainalysis data validation notes, Triple-A reconciliation

## Status
Data assembly in progress; awaiting Chainalysis verification; SVAR specification ready
