# Migration-Carbon-Growth Nexus — Dincer Collaboration

## Objective
Model bidirectional links: migration → remittances → carbon & growth (MINT + Turkey).

## Authors
- Res. Asst. Dr. M. Gökhan Özdemir (KKÜ, ORCID: 0000-0002-6756-7285)
- Co-author: Dincer (confirm affiliation + ORCID before submission)

## Data
| Variable | Source | Coverage |
|----------|--------|---------|
| Migration stocks | UN DESA | MINT + Turkey, 1995–2023 |
| Remittances | World Bank WDI | N=5, 1995–2023 |
| CO₂ emissions | WDI (EN.GHG.CO2.PC.CE.AR5) | N=5, 1995–2023 |
| GDP per capita | WDI | N=5, 1995–2023 |
| Energy use | IEA / WDI | N=5, 1995–2023 |
| Renewable energy share | IRENA / WDI | N=5, 1995–2023 |

**Panel:** MINT = Mexico, Indonesia, Nigeria, Turkey → N=4 küme

## Methodology

1. Pesaran CD test (cross-section dependence ön testi)
2. CIPS unit root (CD-robust)
3. Westerlund kointegrasyon
4. System-GMM (Blundell-Bond) — dinamik panel
5. Mediation analizi: göç → havale → karbon (dolaylı kanal)
6. Dumitrescu-Hurlin causality (bootstrap, R `plm`)
7. **⚠️ Webb wild cluster bootstrap — ZORUNLU (N=4 < 30)**

**Webb notu (2026-04-22):** N=4 küme → Webb bootstrap tüm modellerde zorunlu.
B=999, 6-point weights. Sys-GMM dahil Webb-robust SE raporlanacak.
R: `fwildclusterboot` paketi.

**Karul-GAUSS:** DH (R `plm::phtest`) kabul edilebilir alternatif. Fourier tabanlı test planlanırsa GAUSS zorunlu.

## Output
Q1 development/environmental journal; co-authored with Dincer.

## Status
Stage 3-4: Data assembly + baseline estimation in progress.
**⚠️ Webb bootstrap kod tarafında henüz eklenmedi — bir sonraki çalışma seansında zorunlu.**
