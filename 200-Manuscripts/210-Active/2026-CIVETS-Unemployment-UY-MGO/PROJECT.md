# PROJECT: Macroeconomic Determinants of Unemployment in CIVETS Economies
**Authors:** MGO + Uğur Yıldırım  
**Vade:** Orta vadeli (3–12 ay)  
**Created:** 2026-04-26  
**Folder:** `200-Manuscripts/210-Active/2026-CIVETS-Unemployment-UY-MGO/`

## Objective
First second-generation heterogeneous-slope panel analysis of unemployment determinants
in CIVETS (N=6, T≈2000–2023) incorporating WB Governance Indicators and Human Capital Index.

## Countries
COL · IDN · VNM · EGY · TUR · ZAF

## Data Sources
- WB WDI (API): unemployment, GDP growth, inflation, trade, FDI, gov exp, internet
- WB WGI (API or CSV): GOVEFF, RULELAW, CORRUPT (1996–2023)
- WB HCI (CSV): HD.HCI.OVRL (2010–2020 with gaps)
- ILO ILOSTAT: labour force participation, wages (supplementary)

## Methodology (planned)
1. Pesaran (2004) CD + Pesaran-Yamagata (2008) slope homogeneity
2. CIPS unit root (Pesaran 2007)
3. Westerlund (2007) cointegration + bootstrap
4. AMG / CCEMG long-run estimation
5. Webb wild cluster bootstrap CI (N=6 — mandatory)
6. Konya (2006) bootstrap causality (preferred over DH for N=6)
7. Bai-Perron structural breaks (2008 GFC, 2020 COVID)

## Target Journal
Plan A: Emerging Markets Finance and Trade (SSCI Q2)
Plan B: Journal of the Asia Pacific Economy (SSCI Q3)
Plan C: Economic Research-Ekonomska Istraživanja (ESCI, free)

## Status
- [x] Folder created 2026-04-26
- [x] WDI data fetched: `01-Data/raw/civets_wdi_raw_20260426.csv`
- [x] WGI data fetched: `01-Data/raw/civets_wgi_raw_20260426.csv`
- [ ] HCI data — manual download needed (WB HCI portal)
- [ ] ILO supplementary data
- [ ] Data cleaning + panel assembly
- [ ] Pre-tests (CD, slope homogeneity, unit root)
- [ ] UY co-author sign-off
