"""
Global Panel Data Fetch — MGO Research Portfolio
Date: 2026-04-27
Source: World Bank WDI + WGI APIs (free, no key)
Cross-check protocol: all values flagged with source; verify before manuscript use.

Country groups:
  CIVETS     : COL, IDN, VNM, EGY, TUR, ZAF  (N=6)
  BRICST_MINT: BRA, RUS, IND, CHN, ZAF, TUR, MEX, IDN, NGA (N=9)
  EU27       : AUT,BEL,BGR,HRV,CYP,CZE,DNK,EST,FIN,FRA,DEU,GRC,
               HUN,IRL,ITA,LVA,LTU,LUX,MLT,NLD,POL,PRT,ROU,SVK,SVN,ESP,SWE
  EURASIAN   : AZE,ARM,BLR,GEO,KAZ,KGZ,MDA,RUS,TJK,TKM,UKR,UZB,TUR,AZE
  OECD35     : AUS,AUT,BEL,CAN,CHL,CZE,DNK,EST,FIN,FRA,DEU,GRC,HUN,ISL,
               IRL,ISR,ITA,JPN,KOR,LVA,LTU,LUX,MEX,NLD,NZL,NOR,POL,PRT,
               SVK,SVN,ESP,SWE,CHE,TUR,GBR,USA
"""

import requests, json, pandas as pd, time, os
from datetime import date

TODAY = date.today().strftime("%Y%m%d")
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Country groups ────────────────────────────────────────────────────────────
GROUPS = {
    "CIVETS": ["COL", "IDN", "VNM", "EGY", "TUR", "ZAF"],
    "BRICST_MINT": ["BRA", "RUS", "IND", "CHN", "ZAF", "TUR", "MEX", "IDN", "NGA"],
    "EU27": ["AUT","BEL","BGR","HRV","CYP","CZE","DNK","EST","FIN","FRA","DEU",
             "GRC","HUN","IRL","ITA","LVA","LTU","LUX","MLT","NLD","POL","PRT",
             "ROU","SVK","SVN","ESP","SWE"],
    "EURASIAN": ["AZE","ARM","BLR","GEO","KAZ","KGZ","MDA","RUS","TJK","TKM",
                 "UKR","UZB","TUR"],
    "OECD35": ["AUS","AUT","BEL","CAN","CHL","CZE","DNK","EST","FIN","FRA","DEU",
               "GRC","HUN","ISL","IRL","ISR","ITA","JPN","KOR","LVA","LTU","LUX",
               "MEX","NLD","NZL","NOR","POL","PRT","SVK","SVN","ESP","SWE","CHE",
               "TUR","GBR","USA"],
}

# ── WDI indicators ────────────────────────────────────────────────────────────
WDI_INDICATORS = {
    # Macro
    "NY.GDP.PCAP.PP.KD":    "gdp_pc_ppp_2017",      # GDP per capita PPP (2017 USD)
    "NY.GDP.MKTP.KD.ZG":    "gdp_growth",            # GDP growth %
    "FP.CPI.TOTL.ZG":       "inflation_cpi",         # CPI inflation %
    "NE.TRD.GNFS.ZS":       "trade_gdp",             # Trade % GDP
    "BX.KLT.DINV.WD.GD.ZS":"fdi_gdp",               # FDI net inflows % GDP
    "NE.CON.GOVT.ZS":       "gov_exp_gdp",           # Govt final consumption % GDP
    "SP.POP.TOTL":           "population",            # Total population
    "SP.URB.TOTL.IN.ZS":    "urbanization",          # Urban pop %
    # Environment / Energy
    "EN.GHG.CO2.PC.CE.AR5": "co2_pc_ar5",           # CO2 per capita (AR5, NEW)
    "EN.ATM.GHGT.KT.CE":    "ghg_total_kt",          # Total GHG kt CO2 eq
    "EG.FEC.RNEW.ZS":       "ren_energy_share",      # Renewable energy % final consumption
    "EG.USE.PCAP.KG.OE":    "energy_use_pc",         # Energy use kg oil eq per capita
    "EG.ELC.ACCS.ZS":       "elec_access",           # Access to electricity %
    # Labour / Human capital
    "SL.UEM.TOTL.ZS":       "unemp_rate",            # Unemployment % labour force (ILO)
    "SL.UEM.TOTL.NE.ZS":    "unemp_rate_natl",       # Unemployment national estimate
    "SL.TLF.CACT.ZS":       "lfpr",                  # Labour force participation %
    "SE.XPD.TOTL.GD.ZS":    "educ_exp_gdp",          # Education expenditure % GDP
    # Agriculture / Food
    "NV.AGR.TOTL.ZS":       "agr_va_gdp",            # Agriculture VA % GDP
    "AG.PRD.FOOD.XD":        "food_prod_idx",         # Food production index (2014-16=100)
    "AG.LND.ARBL.HA.PC":    "arable_land_pc",        # Arable land ha per capita
    "AG.LND.AGRI.ZS":       "agri_land_pct",         # Agricultural land % land area
    "SN.ITK.DEFC.ZS":       "undernourishment",      # Prevalence of undernourishment %
    "AG.YLD.CREL.KG":       "cereal_yield",          # Cereal yield kg/ha
    # Finance / institutional
    "FS.AST.DOMS.GD.ZS":    "dom_credit_gdp",        # Domestic credit % GDP
    "IT.NET.USER.ZS":        "internet_users",        # Internet users %
    "GC.TAX.TOTL.GD.ZS":    "tax_revenue_gdp",       # Tax revenue % GDP
}

# WGI indicators (governance)
WGI_INDICATORS = {
    "CC.EST": "wgi_control_corruption",
    "GE.EST": "wgi_gov_effectiveness",
    "PV.EST": "wgi_political_stability",
    "RL.EST": "wgi_rule_of_law",
    "RQ.EST": "wgi_reg_quality",
    "VA.EST": "wgi_voice_accountability",
}

DATE_RANGE = "1990:2024"

# ── Fetch helpers ─────────────────────────────────────────────────────────────
def wb_fetch(countries, indicator, date_range=DATE_RANGE, per_page=20000):
    """Fetch one indicator for a list of countries from WB API."""
    iso = ";".join(countries)
    url = (f"https://api.worldbank.org/v2/country/{iso}/indicator/{indicator}"
           f"?date={date_range}&format=json&per_page={per_page}")
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        data = r.json()
        if len(data) < 2 or not data[1]:
            return pd.DataFrame()
        rows = []
        for obs in data[1]:
            rows.append({
                "iso3":    obs["countryiso3code"],
                "country": obs["country"]["value"],
                "year":    int(obs["date"]),
                "value":   obs["value"],
            })
        df = pd.DataFrame(rows)
        return df
    except Exception as e:
        print(f"  ⚠️  {indicator}: {e}")
        return pd.DataFrame()

def fetch_group(group_name, countries):
    """Fetch all WDI + WGI for one country group; return wide panel."""
    print(f"\n{'='*60}")
    print(f"GROUP: {group_name}  ({len(countries)} countries)")
    print(f"{'='*60}")

    panels = []

    # WDI
    for indic, colname in WDI_INDICATORS.items():
        print(f"  WDI  {colname}...", end=" ")
        df = wb_fetch(countries, indic)
        if df.empty:
            print("EMPTY")
            continue
        df = df.rename(columns={"value": colname})
        panels.append(df[["iso3","year", colname]])
        print(f"{len(df)} obs ✓")
        time.sleep(0.25)

    # WGI
    for indic, colname in WGI_INDICATORS.items():
        print(f"  WGI  {colname}...", end=" ")
        df = wb_fetch(countries, indic)
        if df.empty:
            print("EMPTY")
            continue
        df = df.rename(columns={"value": colname})
        panels.append(df[["iso3","year", colname]])
        print(f"{len(df)} obs ✓")
        time.sleep(0.25)

    if not panels:
        print(f"  ❌ No data fetched for {group_name}")
        return pd.DataFrame()

    # Merge all indicators on iso3 × year
    base = panels[0]
    for p in panels[1:]:
        base = pd.merge(base, p, on=["iso3","year"], how="outer")

    # Filter to target countries only (remove blanks)
    base = base[base["iso3"].isin(countries)].sort_values(["iso3","year"])
    base["source"] = f"WB_WDI_WGI_{TODAY}"

    return base

# ── Main ──────────────────────────────────────────────────────────────────────
summary = []

for grp_name, ctries in GROUPS.items():
    panel = fetch_group(grp_name, ctries)
    if panel.empty:
        summary.append({"group": grp_name, "status": "FAILED", "rows": 0, "file": ""})
        continue

    fname = f"panel_{grp_name.lower()}_{TODAY}.csv"
    fpath = os.path.join(OUT_DIR, fname)
    panel.to_csv(fpath, index=False)
    n_countries = panel["iso3"].nunique()
    n_years     = panel["year"].nunique()
    n_vars      = panel.shape[1] - 3  # exclude iso3, year, source
    print(f"\n  ✅ Saved: {fname}  [{n_countries} countries × {n_years} years × {n_vars} vars]")
    summary.append({
        "group":    grp_name,
        "status":   "OK",
        "rows":     len(panel),
        "n_countries": n_countries,
        "n_years":  n_years,
        "n_vars":   n_vars,
        "file":     fpath,
    })

# ── Summary report ────────────────────────────────────────────────────────────
print("\n\n" + "="*70)
print("SUMMARY")
print("="*70)
df_sum = pd.DataFrame(summary)
print(df_sum.to_string(index=False))

sum_path = os.path.join(OUT_DIR, f"fetch_summary_{TODAY}.csv")
df_sum.to_csv(sum_path, index=False)
print(f"\nSummary saved → {sum_path}")
print("\n⚠️  CROSS-CHECK REMINDER: Verify all values against independent source before citing.")
print("    CO2: EN.GHG.CO2.PC.CE.AR5 (AR5 basis) — replaces deprecated EN.ATM.CO2E.PC")
print("    Unemp: SL.UEM.TOTL.ZS (ILO modelled) — cross-check with ILOSTAT for CIVETS")
