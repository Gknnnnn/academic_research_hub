# PROJECT: Financial Stress, Credit Conditions & Current Account Dynamics in Türkiye

## Objective
Construct a DFM-based Financial Stress Index (FSI) for Türkiye (2003–2024) and estimate asymmetric FSI → CA dynamics using NARDL + Local Projections.

## Target
**Economic Modelling** (SSCI Q2, $125 submission fee) | APC=$125

## Data Status
### Available (FRED downloaded):
- TR_CPI, TR_M2, DXY, OIL_BRENT → `data/turkey_fsi_components_fred_20260424.csv`
- Partial FSI constructed (PC1 from CPI_vol + M2_growth + DXY + OIL_vol)
  → `data/fsi_partial_fred_20260424.csv`

### MISSING (manual collection required):
- X1 TRY/USD daily volatility → CBRT EVDS TP.DK.USD.A
- X2 BIST100 return volatility → borsapy or BIST manual
- X3 5-year CDS spread (bps) → Bloomberg/Refinitiv (premium)
- X4 EMBI Turkey spread → JP Morgan/Bloomberg (premium)
- X5 Overnight-policy rate spread → CBRT EVDS
- X6 Banking sector equity beta → BIST rolling 12M
- X7 NPL ratio → BDDK quarterly data (manual at bddk.org.tr)

## Key Results (2026-04-24 — PARTIAL FSI)
- Partial FSI NARDL: ρ=−0.343 ✓ (converging)
- L^+(FSI↑→CA) = −9.82 | L^−(FSI↓→CA) = −17.15 (both negative, financial stress worsens CA)
- LP IRF: degenerate (insufficient FSI variation from partial components)

## Files
- `scripts/01_fsi_construction.R` (simulated data placeholder → replace with real data)
- `scripts/02_nardl_fsi_ca.R` ✓ (NARDL + LP)
- `data/fsi_turkey_20260424.csv` (DFM FSI from simulated data)
- `data/panel_fsi_ca_nardl_20260424.csv` (FSI+CA merged quarterly panel)

## Pending (BLOCKED on real FSI data)
- [ ] Collect BIST100 monthly returns (borsapy: borsapy.fund_prices() for BIST equities)
- [ ] CBRT EVDS API key → overnight rate series
- [ ] BDDK NPL quarterly → bddk.org.tr > Tablolar > Temel Göstergeler
- [ ] Re-run 01_fsi_construction.R with real data
- [ ] Re-run 02_nardl_fsi_ca.R → NARDL bounds + symmetry tests
- [ ] Write 04-Manuscript/main.qmd
- [ ] Submit Economic Modelling ($125)
