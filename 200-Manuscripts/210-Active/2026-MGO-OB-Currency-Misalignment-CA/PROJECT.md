# Currency Misalignment & CA Persistence — Onur Bilgin

## Objective
Extended analysis of Onur Bilgin IERFM paper: long-run persistence of CA with MIS channel.

## Authors
- Res. Asst. Dr. M. Gökhan Özdemir (KKÜ, ORCID: 0000-0002-6756-7285)
- Onur Bilgin (confirm affiliation + ORCID before submission)

## Data
| Variable | Source | Coverage |
|----------|--------|---------|
| Current account balance | IMF WEO / IFS | 20 EM, 1973–2021 |
| REER misalignment | Rodrik PPP method (Penn World Tables) | 20 EM, 1973–2021 |
| GDP per capita | WDI | 20 EM, 1973–2021 |
| Trade openness | WDI | 20 EM, 1973–2021 |
| Financial openness | Chinn-Ito index | 20 EM, 1973–2021 |

**Panel:** N=20 EM (emerging markets), T≈48, NT≈960

## Methodology

1. Pesaran CD test + CIPS unit root
2. Westerlund kointegrasyon
3. CS-ARDL / AMG uzun-dönem katsayıları
4. Augmented TWFE (time-varying lagged CA)
5. Quantile regression (distributional effects)
6. Asymmetric long-run elasticities (AMG-based)
7. **⚠️ Webb wild cluster bootstrap — ZORUNLU (N=20 < 30)**

**Webb notu (2026-04-22):** N=20 küme → Webb bootstrap tüm spesifikasyonlarda zorunlu.
B=999, 6-point weights. R: `fwildclusterboot`; Stata: `boottest`.
IERFM kongre versiyonunda Webb uygulandı (G=20) — journal versiyonunda da zorunlu.

**Karul-GAUSS:** CS-ARDL (R `plm` / Stata `xtardl`) kabul edilebilir.
AMG: Stata `xtmg` veya R `plm` — teyitli paketler.

## Output
- A) IERFM 2026 kongre versiyonu: ✅ GÖNDERİLDİ (Nisan 2026)
- B) Economic Modelling Q1 journal versiyonu: N=17, β=−0.094*** — SUBMISSION READY

## Status
Stage 5 (journal version): Baseline estimation complete; Webb bootstrap + genişletilmiş robustness bölümü eklenecek.
**⚠️ Journal versiyonunda Webb bootstrap sistematik olarak eklenmeli.**
