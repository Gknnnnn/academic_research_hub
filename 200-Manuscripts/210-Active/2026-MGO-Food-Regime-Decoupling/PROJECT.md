# 2026-MGO Food Regime Decoupling

## Objective
Decompose food trade flows (BACI HS92) into factor-content (USDA AgTFP, FAOSTAT) and emissions intensity (EDGAR-FOOD, FBS, Exiobase) to quantify decoupling of agricultural growth from land/GHG.

## Data
- **Source:** BACI HS92 (CEPII), FAOSTAT, USDA AgTFP, EDGAR-FOOD, FBS (pending), Exiobase (pending)
- **Panel:** Global trade 1995–2024; HS-92 product codes; country production, emissions, factor shares
- **Status:** BACI+FAOSTAT+AgTFP symlinked; FBS/EDGAR-FOOD/Exiobase still missing

## Methodology
1. Bilateral trade flow decomposition by product (HS codes)
2. Merge production data (FAOSTAT) + factor inputs (AgTFP)
3. Compute factor content of trade (labor, capital, land) per Leontief
4. Merge emissions intensity (EDGAR-FOOD / FBS / Exiobase)
5. Estimate embodied emissions in trade flows
6. Panel cointegration (Westerlund) & long-run decoupling elasticity (CS-ARDL)
7. Robustness: Subsample analysis (major traders, product families)

## Output
- Decoupling elasticity estimates (%, long-run), factor-content tables, embodied-emissions maps
- Q1 target (Ecological Economics, Global Food Security)
- Appendix: factor decompositions, alternative emissions datasets

## Status
Data acquisition in progress; ready for estimation once FBS/EDGAR-FOOD received
