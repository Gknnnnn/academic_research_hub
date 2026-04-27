# PROJECT: Automation, Economic Complexity & Labor Share in Eurasian Economies
**Status:** DATA ✓ | ESTIMATION PARTIAL ✓ | QMD ✓ | DOCX PENDING  
**Author:** Solo MGO  
**Target:** Economic Modelling (SSCI Q2, IF≈6.5) | APC=0  
**Version:** v01 — 2026-04-24

## Key Results (2026-04-24)
- CIPS: all variables I(1) → I(0) in FD ✓
- CCEMG (N=13 PWT-only): β_cap=+0.121* | Country: TUR=−0.152, ARM=−0.131 negative
- D-H causality: `data/results_dh_causality_20260424.csv`
- QMD: `04-Manuscript/main.qmd` ✓

## Pending
- [ ] ECI: manual download oec.world/en/resources/bulk-download → data/raw/oec_eci_country_year.csv
- [ ] CSD fix: plm empty model error (use different pdata construction)
- [ ] DOCX render → sparring → submit Economic Modelling

## Column Mapping
`labsh` → `labor_share` | `ln_cap_worker` → `capital_intensity` | `ln_gdppc` = ECI proxy

---

## Research Question
Does the effect of automation/technological development on labor share depend on a country's level of economic complexity? Is the relationship heterogeneous across Eurasian economies?

## Contribution
- Göksel (2020) showed technology ↓ labor share in a broad panel. This paper:
  1. Focuses on **N=14 Eurasian economies** (MGO's niche)
  2. Adds **Economic Complexity Index (ECI)** as moderator
  3. Uses **second-generation panel methods** (CS-ARDL, CCEMG, AMG) — methodological upgrade
  4. Tests whether **high-complexity economies** are more/less vulnerable

## Hypothesis
H1: Technology development → labor share (negative, baseline)  
H2: ECI moderates the technology–labor share nexus (interaction term)  
H3: Long-run cointegration exists; error-correction speed varies by complexity tier

## Data
| Variable | Source | Coverage |
|----------|--------|----------|
| Labor share (compensation/GDP) | ILO ILOSTAT | 1995–2022 |
| Technology proxy: ICT capital / TFP | Penn World Tables 10.01 | 1995–2019 |
| Robot density | IFR World Robotics Report | 2000–2022 |
| Economic Complexity Index (ECI) | OEC / Atlas of Economic Complexity | 1995–2021 |
| GDP per capita, trade openness | WB WDI | — |

**N:** 14 Eurasian economies (same panel as IGI paper)  
**T:** ~1995–2022 (unbalanced where needed)

## Methodology
1. Cross-section dependence: Pesaran CD test
2. Slope homogeneity: Pesaran-Yamagata Δ test
3. Panel unit root: CIPS + CADF
4. Cointegration: Westerlund (2007)
5. Long-run estimation: **CS-ARDL + CCEMG + AMG** (all three for robustness)
6. Interaction: ECI × tech variable (split sample + threshold panel)
7. Causality: Dumitrescu-Hurlin (2012)
8. Robustness: Bootstrap CS-ARDL; alternative tech proxy (R&D/GDP)

## Target Journal
**Primary:** Economic Modelling (SSCI Q2, IF≈7.9) — Göksel published here ×3; MGO methodology fits perfectly  
**Backup:** World Economy (SSCI Q3) or International Labour Review

## ÜAK Value
Economic Modelling Q2 = **20 puan**

## Expected Results
- Negative tech → labor share in low-ECI Eurasian economies
- Less negative (or positive via skill premium) in high-ECI economies
- Russia, Kazakhstan, Türkiye: negative; Estonia, Georgia: heterogeneous

## ✅ Progress — 2026-04-24

### Data & Results
- [x] PWT 10.01 → `pwt1001_eurasian_20260424.csv` (N=13, T=1998-2022)
- [x] Panel master → `panel_automation_eurasian_20260424.csv`
- [x] CSD: **All variables significant** (p<0.001) — 2nd-gen confirmed
- [x] CADF CIPS: All **I(1)** — cointegration valid
- [x] CCEMG: **β=+0.121, SE=0.066, t=1.83 [*]** 🔑
- [x] FE DK: β=-0.048 ns → CSD bias flips sign
- [x] FE Interaction: cap×gdppc β=+0.073*** (t=3.33) 🔥
- [x] Country plot → `fig_ccemg_country_estimates.png`

### Key Finding
CSD bias reverses sign (FE: -0.05 → CCEMG: +0.12) = methodological contribution  
cap×GDPpc significant = complexity moderates capital-labor relationship  
TUR(-0.17**), MDA(+0.60**), RUS(+0.52), GEO(+0.31) = rich heterogeneity story

## Next Steps
- [ ] OEC ECI manual download → replace gdppc proxy
- [ ] Westerlund cointegration (install cointmonitoR)
- [ ] Dumitrescu-Hurlin causality
- [ ] Draft QMD (§1 Introduction + §2 Lit + §3 Method)
- [ ] TFP robustness (9-country subsample)
- [ ] Sparring → submit Economic Modelling

## Files
```
2026-Automation-LaborShare-Eurasian/
├── PROJECT.md
├── data/           ← panel_automation_eurasian_raw.csv (tarih damgası ekle)
├── scripts/        ← 01_data_prep.R, 02_csd_unitroot.R, 03_csardl.R
└── drafts/         ← v01_draft.qmd
```

## Notes
- IFR robot data: manufacturing sectors only for some countries → use ICT capital as primary proxy
- ECI: use Atlas of Economic Complexity (Hausmann et al.) — already in Zotero?
- Eurasian panel = Azerbaijan, Belarus, Georgia, Kazakhstan, Kyrgyzstan, Moldova, Russia, Tajikistan, Türkiye, Ukraine, Armenia, Uzbekistan, Estonia (observer), Mongolia
