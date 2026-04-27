# PROJECT: LCF Turkey Bootstrap ARDL

**Title (working):** "Economic Growth, Renewable Energy, and Structural Lock-In: Asymmetric Effects on Türkiye's Load Capacity Factor"

**Author:** Res. Asst. Dr. M. Gökhan Özdemir (solo)
**Email:** mgozdemirera@kku.edu.tr | ORCID: 0000-0002-6756-7285
**Affiliation:** Kırıkkale University, Department of Economics (Economic Theory Division)

**Target journal:** Resources Policy (Elsevier, SSCI Q1, IF≈8.2, $0 APC)
**Backup:** Energy Reports (Elsevier, ESCI) | Environmental Science and Pollution Research (Springer)

**Replication basis:** Özbek-Naimoğlu pipeline (Gregory-Hansen + FMOLS + CCR) + Naimoğlu's Bootstrap ARDL upgrade (Energy/Elsevier 2026)

---

## Research Question

Does economic growth exhibit an asymmetric (EKC-inconsistent) relationship with Türkiye's load capacity factor, and does renewable energy adoption provide a structural escape from ecological lock-in?

---

## Data

| Variable | Code | Source | Expected range |
|----------|------|--------|----------------|
| **LCF** (biocapacity / EF) | — | Global Footprint Network open data | 1961–2021 |
| **lnGDP** (per capita, const. 2015 USD) | NY.GDP.PCAP.KD | World Bank WDI | 1961–2022 |
| **lnGDP²** | derived | derived | EKC test |
| **lnREN** (renewable energy share, %) | EG.FEC.RNEW.ZS | World Bank WDI | 1990–2022 |
| **lnTrade** (% GDP) | NE.TRD.GNFS.ZS | World Bank WDI | 1960–2022 |
| **lnFDI** (net inflow, % GDP) | BX.KLT.DINV.WD.GD.ZS | World Bank WDI | 1970–2022 |

**Effective sample:** ~1990–2021 (constrained by renewable energy data; T≈31)
**Extended sample (robustness):** 1961–2021 dropping lnREN (T≈60)

---

## Methodology Pipeline

### Step 1 — Descriptive Statistics
- Summary stats, correlations, time trends

### Step 2 — Unit Root Tests (4 tests)
1. ADF + PP (traditional baseline)
2. KPSS (stationarity null)
3. Zivot-Andrews (1992) — single endogenous structural break
4. Lee-Strazicich (2003) — double structural break [stronger]

### Step 3 — Structural Break Cointegration
- Gregory-Hansen (1996) — level shift, trend shift, regime shift variants
- [Optional upgrade] Hatemi-J (2008) — two structural breaks

### Step 4 — Bootstrap ARDL (MAIN METHOD)
- Özen & Shahbaz (2021, Energy Reports) bootstrap cointegration
- R: `bootCT` package or manual bootstrap simulation
- Bootstrap F and t statistics; 5%/10% critical values via 10,000 replications
- Report: bootstrap F-stat, p-value, bounds decision

### Step 5 — Asymmetric (NARDL) Estimation
- Shin, Yu & Greenwood-Nimmo (2014) NARDL
- Decompose GDP into positive (GDP⁺) and negative (GDP⁻) partial sums
- Long-run asymmetry test: Wald test H₀: β⁺ = β⁻
- R: `ARDL` package `nardl()` or `nardl` package

### Step 6 — Long-Run Robustness
- FMOLS (Fully Modified OLS)
- CCR (Canonical Cointegrating Regression)
- [Optional] DOLS

### Step 7 — Causality
- Toda-Yamamoto (1995) modified Wald test
- R: `vars` package + tYamagata bootstrap

---

## Key Hypothesis

**H1:** GDP growth has a non-monotonic (U-shaped or inverted-U) relationship with LCF — EKC test
**H2:** Renewable energy adoption significantly improves LCF (positive β)
**H3:** The relationship is asymmetric: income increases vs. decreases have different LCF effects
**H4:** Long-run cointegration holds despite structural breaks (bootstrap confirms bounds)

---

## Files

- `scripts/01_data_download.R` — WB WDI + GFN data download
- `scripts/02_unit_root.R` — ADF/PP/KPSS/ZA/LS tests
- `scripts/03_cointegration.R` — Gregory-Hansen test
- `scripts/04_bootstrap_ardl.R` — Bootstrap ARDL main estimation
- `scripts/05_nardl.R` — NARDL asymmetric estimation
- `scripts/06_fmols_ccr.R` — Long-run robustness
- `scripts/07_causality.R` — Toda-Yamamoto
- `04-Manuscript/main.qmd` — Manuscript QMD (English)
- `data/raw/` — raw downloads (date-stamped, never modified)

---

## DAMOKLES II Check

- ✅ Declarative title (no "Impact of X on Y")
- ✅ MGO real expertise: Turkey energy-environment panel econometrics
- ✅ Solo authorship
- ✅ Method (Bootstrap ARDL) derived from research question (structural breaks + cointegration)
- ✅ Not MDPI
- ✅ Resources Policy = Q1 SSCI = 30 ÜAK points

---

## Status

- [ ] 01_data_download.R — pending
- [ ] Unit root battery — pending
- [ ] Bootstrap ARDL estimation — pending
- [ ] Manuscript QMD — pending
