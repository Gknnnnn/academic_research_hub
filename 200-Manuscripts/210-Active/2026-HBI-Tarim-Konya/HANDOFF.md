# HANDOFF — HBI Tarım Konya (Işık Hoca) — 2026-04-26

## One-Line Status
MGO + Işık Hoca; Human Behavioral Index × Konya agricultural yield; ARDL bounds + VECM Granger; Stage 3-4 data assembly ongoing; overlaps with Konya-HBI-Agricultural-Floor project.

## Files
- PROJECT.md: `PROJECT.md` ✅
- **Climate data: `03-Results/data/konya_climate_annual_20260428.csv` ✅** (2000–2023, 24 years)
  - Source: Open-Meteo ERA5 reanalysis, Konya (37.871°N, 32.485°E)
  - Variables: `temp_mean_c` (annual mean °C), `precip_total_mm` (annual total mm)

## Design

| Component | Specification |
|-----------|--------------|
| Scope | Konya province agricultural output + climate + HBI indices |
| Period | 2000–2023 |
| Method | ARDL bounds cointegration + VECM Granger causality |
| Robustness | Regional heterogeneity (intra-Konya districts) |

## Current Blocker
⚠️ **Stage 3-4 — data assembly ongoing**
⚠️ Overlaps with `2026-Konya-HBI-Agricultural-Floor` — check deduplication

## Remaining Tasks
1. [x] ~~Climate data~~ — ✅ `konya_climate_annual_20260428.csv` (ERA5, 2000-2023)
2. [ ] Konya agricultural output (TÜİK provincial — manual download from tuik.gov.tr)
3. [ ] HBI indices — clarify source (Işık Hoca)
4. [ ] Complete data assembly → panel merge
5. [ ] Run ARDL bounds cointegration
3. [ ] VECM Granger causality
4. [ ] Write manuscript QMD
5. [ ] Işık Hoca sign-off

## Next Immediate Step
Clarify scope overlap with `2026-Konya-HBI-Agricultural-Floor` → merge or separate?

## Submission Target
Q1 regional / agricultural economics journal (TBD)
