# PROJECT: GPR & Export Diversification in Eurasian Economies

## Objective
Test whether geopolitical risk (GPR, Caldara-Iacoviello) asymmetrically affects export destination concentration (HHI) in 14 Eurasian economies using panel NARDL.

## Target
**International Economics** (SSCI Q2) | **Energy Economics** backup (SSCI Q1)

## Data
### Available:
- GPR annual: `data/gpr_annual_20260424.csv` (1985–2026)
- WDI controls (from Automation project): gdppc, trade_open, fdi, res_rents
- GPR+WDI master panel: `data/panel_gpr_hhi_20260424.csv` (N=14, T=1995–2022)

### PENDING:
- HHI from BACI HS92: BACI computation running (background job bf4ddt800)
  → Expected: `data/baci_hhi_eurasian_20260424.csv` (year 2010 complete, 12 more to go)
- WUI (World Uncertainty Index): manual download worlduncertaintyindex.com
  → Save as: `data/raw/wui_country_annual.csv`
- ECI (OEC Atlas): manual download oec.world/en/resources/bulk-download
  → Save as: `data/raw/oec_eci_country_year.csv`

## Key Results
- Pending BACI HHI completion

## Files
- Scripts: `scripts/02_panel_assembly.R` ✓ | `scripts/03_nardl_panel.R` ✓
- Manuscript: `04-Manuscript/` (empty — pending BACI HHI)

## Pending
- [ ] BACI HHI: Wait for background job to complete → check data/baci_hhi_eurasian_*.csv
- [ ] WUI manual download → merge into panel
- [ ] Run 02_panel_assembly.R (after BACI) → merge HHI into panel
- [ ] Run 03_nardl_panel.R → country NARDL + MG estimates
- [ ] Write QMD manuscript
- [ ] Submit International Economics / Energy Economics
