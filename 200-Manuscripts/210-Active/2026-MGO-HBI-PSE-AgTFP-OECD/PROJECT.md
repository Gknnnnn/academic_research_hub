# PSE Composition & Agricultural TFP — OECD Panel
**Code:** 2026-MGO-HBI-PSE-AgTFP-OECD  
**Created:** 2026-04-20  
**Status:** Stage 1 — Data Assembly

## Authors
- Res. Asst. Dr. M. Gökhan Özdemir (KKÜ, mgozdemirera@kku.edu.tr, ORCID: 0000-0002-6756-7285) — Econometrics lead
- Prof. Dr. Hacı Bayram Işık — Agricultural economics framing, Turkey policy interpretation

## Objective
Does the *composition* of agricultural support (coupled MPS vs. decoupled payments vs. GSSE)
drive or impede agricultural TFP in OECD countries? First heterojen panel study decomposing
PSE components in a CS-ARDL framework.

## Core Hypothesis
- Market Price Support (MPS, coupled) → production distortion → TFP↓
- General Services Support Estimates (GSSE: R&D, infrastructure, extension) → TFP↑
- Budgetary decoupled payments (BDA) → neutral or mildly positive (income support only)
- %PSE level alone is uninformative; composition is the key policy variable

## Data
| Variable | Source | Coverage |
|----------|--------|---------|
| Agricultural TFP index | USDA AgTFP International (2020 release) | N=35 OECD, T=1961–2020 |
| %PSE, MPS (USD mn), GSSE (USD mn), BDA | OECD PSE/CSE Database | N=54, T=1986–2023 |
| MPS_share = MPS/PSE | Computed | same |
| GSSE_share = GSSE/(PSE+GSSE) | Computed | same |
| GDP per capita (const. 2015 USD) | WB WDI (NY.GDP.PCAP.KD) | same |
| Agricultural land (ha per worker) | WB WDI (AG.LND.AGRI.ZS × area) | same |
| Rural population share | WB WDI (SP.RUR.TOTL.ZS) | same |
| Fertilizer consumption (kg/ha) | WB WDI (AG.CON.FERT.ZS) | same |

**Estimation window:** 1990–2020 (T=31, balanced after listwise deletion ~T=28)  
**N:** ~34 OECD countries with both AgTFP + PSE coverage

## Methodology (sequential)
1. **Cross-section dependence:** Pesaran CD, CDw+ (xtcd2 in Stata / pesarantest in R)
2. **Slope homogeneity:** Pesaran-Yamagata Δ and Δ̃ test
3. **Panel unit root:** CIPS / CADF (second-generation, cross-sectionally augmented)
4. **Cointegration:** Westerlund (2007) panel ECM test (4 statistics: Ga, Gt, Pa, Pt)
5. **Long-run estimation:** CS-ARDL (Chudik & Pesaran 2015) — main estimator
   - Robustness: AMG (Bond & Eberhardt), CCEMG (Pesaran 2006)
6. **Causality:** Dumitrescu-Hurlin (2012) heterogeneous non-causality
7. **Bootstrap inference:** Webb wild cluster bootstrap (mandatory; N<30 in sub-panels)

## Key Regressors
```
ln_TFP = α + β1*MPS_share + β2*GSSE_share + β3*ln_gdppc + β4*ln_agland + 
          β5*rural_share + β6*ln_fertilizer + ε
```
**Expected signs:** β1 < 0 (distortion), β2 > 0 (public goods), β3 > 0 (development)

## Output Target
- **Primary:** *Food Policy* (Elsevier, SSCI Q1, IF≈6.5)
- **Fallback:** *European Review of Agricultural Economics* (Oxford, SSCI Q1)
- **Length:** 9,000–10,000 words + appendix

## File Map
```
06-Data/raw/           → AgTFP_OECD_raw.csv, OECD_PSE_raw.csv, WB_controls_raw.csv
06-Data/clean/         → panel_master.csv (merged, long format)
05-Scripts/Python/     → 01_data_assembly.py
05-Scripts/R/          → 02_CD_slope_tests.R, 03_unit_root.R, 04_cointegration.R,
                          05_csardl_main.R, 06_causality.R, 07_robustness.R
03-Results/tables/     → tab1_descriptives.tex, tab2_cd_tests.tex, tab3_unitroot.tex,
                          tab4_cointegration.tex, tab5_csardl_main.tex, tab6_robustness.tex
03-Results/figures/    → fig1_pse_tfp_trends.pdf, fig2_impulse_response.pdf
04-Manuscript/         → PSE_AgTFP_OECD_v01.qmd
```

## Progress Log
- [x] 2026-04-20 — Project structure created; AgTFP data confirmed (35 OECD countries, 1961-2020)
- [ ] OECD PSE data download (stats.oecd.org → Agricultural Support Estimates)
- [ ] WB WDI pull (wbstats R package)
- [ ] Panel merge + balance check
- [ ] CD + slope homogeneity tests
- [ ] CIPS unit root battery
- [ ] Westerlund cointegration
- [ ] CS-ARDL estimation
- [ ] Causality (D-H)
- [ ] Robustness (AMG, CCEMG, sub-panels)
- [ ] First draft (QMD)
