"""
MASTER ECONOMIC INDEX & DATA FETCH — MGO Research Portfolio
Date: 2026-04-27
Author: Dr. M. Gökhan Özdemir, Kırıkkale University

Sources covered (all free, no APC, cross-check required per ANAYASA):
  01. World Bank WDI — additional 30 vars (health/edu/finance/env/innovation)
  02. Penn World Tables 10.01 — Feenstra et al. (NBER direct download)
  03. OWID CO2 — Our World in Data (GitHub raw CSV)
  04. OWID Energy — Our World in Data (GitHub raw CSV)
  05. FAO Food Price Index — monthly → annual aggregation
  06. FAOSTAT — agricultural production, land, food security (API)
  07. Caldara-Iacoviello GPR — Geopolitical Risk Index (direct Excel)
  08. FRED — VIX, gold, oil, policy rates (API key required)
  09. IMF DataMapper — commodity prices, WEO macro (free API)
  10. USDA ERS AgTFP — agricultural total factor productivity (direct Excel)
  11. Harvard Growth Lab ECI — Economic Complexity Index (direct CSV)
  12. ILO ILOSTAT — labour market indicators (REST API)
  13. World Bank HCI — Human Capital Index (WDI additional vars)

Country groups (same as main WDI/WGI fetch):
  CIVETS, BRICST_MINT, EU27, EURASIAN, OECD35

Output format: iso3 × year × variable (long→wide merged panels)
All CSVs: 400-Data/ with date stamp; source column mandatory.

⚠️  CROSS-CHECK REMINDER (ANAYASA): Verify all values before manuscript use.
"""

import requests, zipfile, io, os, glob, time, json, re
import pandas as pd
import numpy as np
from datetime import date

TODAY    = date.today().strftime("%Y%m%d")
OUT_DIR  = os.path.dirname(os.path.abspath(__file__))
SRC_DIR  = os.path.join(OUT_DIR, "sources")
os.makedirs(SRC_DIR, exist_ok=True)

FRED_KEY = "e82836f843f58092e3b885349e102b83"

# ── Country groups ────────────────────────────────────────────────────────────
GROUPS = {
    "CIVETS":     ["COL", "IDN", "VNM", "EGY", "TUR", "ZAF"],
    "BRICST_MINT":["BRA", "RUS", "IND", "CHN", "ZAF", "TUR", "MEX", "IDN", "NGA"],
    "EU27":       ["AUT","BEL","BGR","HRV","CYP","CZE","DNK","EST","FIN","FRA","DEU",
                   "GRC","HUN","IRL","ITA","LVA","LTU","LUX","MLT","NLD","POL","PRT",
                   "ROU","SVK","SVN","ESP","SWE"],
    "EURASIAN":   ["AZE","ARM","BLR","GEO","KAZ","KGZ","MDA","RUS","TJK","TKM",
                   "UKR","UZB","TUR"],
    "OECD35":     ["AUS","AUT","BEL","CAN","CHL","CZE","DNK","EST","FIN","FRA","DEU",
                   "GRC","HUN","ISL","IRL","ISR","ITA","JPN","KOR","LVA","LTU","LUX",
                   "MEX","NLD","NZL","NOR","POL","PRT","SVK","SVN","ESP","SWE","CHE",
                   "TUR","GBR","USA"],
}
ALL_ISO = sorted(set(c for g in GROUPS.values() for c in g))

FETCH_LOG = []  # running log of all fetches

def log(source, indicator, status, n_rows=0, note=""):
    FETCH_LOG.append({
        "source": source, "indicator": indicator,
        "status": status, "n_rows": n_rows, "note": note
    })
    tag = "✅" if status == "OK" else "⚠️ " if status == "WARN" else "❌"
    print(f"    {tag} {source}/{indicator}: {status} ({n_rows} rows) {note}")

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 01 — World Bank WDI Additional Variables
# ══════════════════════════════════════════════════════════════════════════════
WDI_ADD_INDICATORS = {
    # Health
    "SP.DYN.LE00.IN":      "life_expectancy",       # Life expectancy at birth
    "SH.DYN.MORT":         "child_mortality",        # Under-5 mortality per 1000
    "SH.XPD.CHEX.GD.ZS":  "health_exp_gdp",        # Health expenditure % GDP
    "SH.STA.BASS.ZS":      "sanitation_access",      # Improved sanitation %
    "SH.H2O.BASW.ZS":      "water_access",           # Basic drinking water %
    # Education
    "SE.SEC.ENRR":         "sec_school_enrollment",  # Secondary enrollment %
    "SE.TER.ENRR":         "tert_school_enrollment", # Tertiary enrollment %
    "GB.XPD.RSDV.GD.ZS":  "rnd_exp_gdp",            # R&D expenditure % GDP
    "SE.ADT.LITR.ZS":      "adult_literacy",         # Adult literacy rate %
    # Finance / Monetary
    "BN.CAB.XOKA.GD.ZS":  "current_account_gdp",    # Current account % GDP
    "DT.DOD.DECT.GD.ZS":  "ext_debt_gdp",           # External debt % GNI
    "FI.RES.TOTL.MO":      "reserves_months",        # Reserves in months imports
    "FM.LBL.BMNY.GD.ZS":  "broad_money_gdp",        # Broad money % GDP
    "FD.AST.PRVT.GD.ZS":  "credit_private_gdp",     # Domestic credit to priv %GDP
    "BX.TRF.PWKR.DT.GD.ZS":"remittances_gdp",       # Personal remittances % GDP
    "GC.BAL.CASH.GD.ZS":  "fiscal_balance_gdp",     # Cash surplus/deficit % GDP
    "GC.DOD.TOTL.GD.ZS":  "govt_debt_gdp",          # Govt debt % GDP
    # Innovation / Technology
    "TX.VAL.TECH.MF.ZS":  "hitech_exports_pct",     # High-tech exports % mfg
    "IP.PAT.RESD.EL":      "patent_apps",            # Patent applications residents
    "IT.CEL.SETS.P2":      "mobile_subs",            # Mobile subscriptions per 100
    "IT.NET.BBND.P2":      "broadband_subs",         # Fixed broadband per 100
    # Infrastructure
    "IS.AIR.PSGR":         "air_passengers",         # Air passengers carried
    "IS.SHP.GCNW.XQ":      "liner_shipping_idx",     # Liner shipping connectivity
    # Environment / Climate
    "AG.LND.FRST.ZS":      "forest_area_pct",        # Forest area % land
    "EN.ATM.PM25.MC.M3":   "pm25_exposure",          # PM2.5 mean annual µg/m³
    "ER.H2O.FWST.ZS":      "water_stress",           # Level of water stress %
    # Inequality / Social
    "SI.POV.GINI":         "gini_index",             # GINI coefficient
    "SI.POV.DDAY":         "poverty_190",            # Poverty headcount < $1.90/day
    "SP.DYN.TFRT.IN":      "fertility_rate",         # Total fertility rate
    # Political / Institutional
    "IQ.CPA.PUBS.XQ":      "cpia_pubsector",         # CPIA public sector (IDA only)
}

def wb_fetch_batch(countries, indicator, per_page=20000, date_range="1990:2024"):
    iso = ";".join(countries)
    url = (f"https://api.worldbank.org/v2/country/{iso}/indicator/{indicator}"
           f"?date={date_range}&format=json&per_page={per_page}")
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        data = r.json()
        if len(data) < 2 or not data[1]:
            return pd.DataFrame()
        rows = [{"iso3": o["countryiso3code"], "year": int(o["date"]),
                 "value": o["value"]} for o in data[1]]
        return pd.DataFrame(rows)
    except Exception as e:
        return pd.DataFrame()

print("\n" + "="*70)
print("SOURCE 01 — WDI ADDITIONAL VARIABLES")
print("="*70)
wdi_add_panels = []
for indic, col in WDI_ADD_INDICATORS.items():
    df = wb_fetch_batch(ALL_ISO, indic)
    if df.empty:
        log("WDI_ADD", col, "EMPTY")
    else:
        df = df[df["iso3"].isin(ALL_ISO)].rename(columns={"value": col})
        wdi_add_panels.append(df[["iso3","year",col]])
        log("WDI_ADD", col, "OK", len(df))
    time.sleep(0.2)

if wdi_add_panels:
    wdi_add = wdi_add_panels[0]
    for p in wdi_add_panels[1:]:
        wdi_add = pd.merge(wdi_add, p, on=["iso3","year"], how="outer")
    wdi_add = wdi_add[wdi_add["iso3"].isin(ALL_ISO)].sort_values(["iso3","year"])
    path = os.path.join(SRC_DIR, f"wdi_additional_{TODAY}.csv")
    wdi_add.to_csv(path, index=False)
    print(f"  → Saved: {path}  [{wdi_add.shape}]")
else:
    wdi_add = pd.DataFrame()
    print("  ❌ No WDI additional data fetched")

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 02 — Penn World Tables 10.01 (Feenstra, Inklaar & Timmer)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 02 — PENN WORLD TABLES 10.01")
print("="*70)
PWT_URL = "https://dataverse.nl/api/access/datafile/354098"  # PWT 10.01 CSV

pwt_key_vars = ["countrycode","year","rgdpe","rgdpo","pop","emp","avh","hc",
                "ck","ctfp","cwtfp","labsh","delta","xr","pl_gdpo","i_cig"]
pwt_rename = {
    "countrycode":"iso3", "rgdpe":"pwt_rgdpe", "rgdpo":"pwt_rgdpo",
    "pop":"pwt_pop", "emp":"pwt_emp", "avh":"pwt_avh", "hc":"pwt_hc",
    "ck":"pwt_capital", "ctfp":"pwt_ctfp", "cwtfp":"pwt_cwtfp",
    "labsh":"pwt_labsh", "delta":"pwt_delta", "xr":"pwt_xr",
    "pl_gdpo":"pwt_pl_gdpo", "i_cig":"pwt_i_cig",
}
try:
    r = requests.get(PWT_URL, timeout=60, allow_redirects=True)
    r.raise_for_status()
    # Try CSV
    from io import StringIO
    try:
        df_pwt = pd.read_csv(StringIO(r.text), low_memory=False)
        print(f"  PWT raw shape: {df_pwt.shape}")
    except Exception:
        # Might be Stata format or binary — try Excel URL
        raise ValueError("Not CSV format")

    df_pwt.columns = [c.lower().strip() for c in df_pwt.columns]
    avail = [c for c in pwt_key_vars if c in df_pwt.columns]
    df_pwt = df_pwt[avail].copy()
    df_pwt = df_pwt[df_pwt["countrycode"].isin(ALL_ISO)]
    df_pwt = df_pwt.rename(columns=pwt_rename)
    df_pwt["year"] = df_pwt["year"].astype(int)
    path = os.path.join(SRC_DIR, f"pwt_1001_{TODAY}.csv")
    df_pwt.to_csv(path, index=False)
    log("PWT", "all_vars", "OK", len(df_pwt), f"vars={list(df_pwt.columns)[:5]}...")
    print(f"  → Saved: {path}  [{df_pwt.shape}]")
except Exception as e:
    # Fallback: try Groningen dataverse alternate URL
    try:
        alt_url = "https://dataverse.nl/api/access/datafile/395310"
        r2 = requests.get(alt_url, timeout=60, allow_redirects=True)
        r2.raise_for_status()
        df_pwt = pd.read_csv(StringIO(r2.text), low_memory=False)
        df_pwt.columns = [c.lower().strip() for c in df_pwt.columns]
        avail = [c for c in pwt_key_vars if c in df_pwt.columns]
        df_pwt = df_pwt[avail]
        df_pwt = df_pwt[df_pwt["countrycode"].isin(ALL_ISO)].rename(columns=pwt_rename)
        path = os.path.join(SRC_DIR, f"pwt_1001_{TODAY}.csv")
        df_pwt.to_csv(path, index=False)
        log("PWT", "all_vars", "OK", len(df_pwt))
    except Exception as e2:
        log("PWT", "all_vars", "FAILED", 0, str(e2)[:80])
        df_pwt = pd.DataFrame()

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 03 — OWID CO2 Data
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 03 — OWID CO2 DATA (GitHub)")
print("="*70)

OWID_CO2_URL = "https://raw.githubusercontent.com/owid/co2-data/master/owid-co2-data.csv"
OWID_CO2_COLS = {
    "iso_code": "iso3",
    "year": "year",
    "co2": "owid_co2_mt",                      # Annual CO2 emissions (MtCO2)
    "co2_per_capita": "owid_co2_pc",            # CO2 per capita (t)
    "consumption_co2": "owid_consump_co2",      # Consumption-based CO2
    "consumption_co2_per_capita": "owid_consump_co2_pc",
    "co2_per_gdp": "owid_co2_per_gdp",         # CO2 per unit of GDP
    "coal_co2": "owid_coal_co2",
    "gas_co2": "owid_gas_co2",
    "oil_co2": "owid_oil_co2",
    "cement_co2": "owid_cement_co2",
    "land_use_change_co2": "owid_luc_co2",
    "cumulative_co2": "owid_cumul_co2",
    "share_global_co2": "owid_share_global_co2",
    "temperature_change_from_co2": "owid_temp_change_co2",
    "ghg_per_capita": "owid_ghg_pc",
    "methane_per_capita": "owid_ch4_pc",
    "nitrous_oxide_per_capita": "owid_n2o_pc",
}

try:
    r = requests.get(OWID_CO2_URL, timeout=60)
    r.raise_for_status()
    df_co2 = pd.read_csv(io.StringIO(r.text), low_memory=False)
    avail_cols = {k: v for k, v in OWID_CO2_COLS.items() if k in df_co2.columns}
    df_co2 = df_co2[list(avail_cols.keys())].rename(columns=avail_cols)
    df_co2 = df_co2[df_co2["iso3"].isin(ALL_ISO)].dropna(subset=["iso3"])
    df_co2["year"] = df_co2["year"].astype(int)
    df_co2 = df_co2[(df_co2["year"] >= 1990) & (df_co2["year"] <= 2024)]
    path = os.path.join(SRC_DIR, f"owid_co2_{TODAY}.csv")
    df_co2.to_csv(path, index=False)
    log("OWID_CO2", "all_vars", "OK", len(df_co2),
        f"cols={len(df_co2.columns)} countries={df_co2['iso3'].nunique()}")
    print(f"  → Saved: {path}  [{df_co2.shape}]")
except Exception as e:
    log("OWID_CO2", "all_vars", "FAILED", 0, str(e)[:80])
    df_co2 = pd.DataFrame()

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 04 — OWID Energy Data
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 04 — OWID ENERGY DATA (GitHub)")
print("="*70)

OWID_EN_URL = "https://raw.githubusercontent.com/owid/energy-data/master/owid-energy-data.csv"
OWID_EN_COLS = {
    "iso_code": "iso3", "year": "year",
    "primary_energy_consumption": "owid_energy_twh",      # Primary energy (TWh)
    "energy_per_capita": "owid_energy_pc",                # Energy per capita kWh
    "energy_per_gdp": "owid_energy_per_gdp",
    "renewables_share_energy": "owid_ren_share",          # Renewables % primary
    "renewables_electricity": "owid_ren_elec_twh",
    "fossil_fuel_consumption": "owid_fossil_twh",
    "coal_share_energy": "owid_coal_share",
    "gas_share_energy": "owid_gas_share",
    "oil_share_energy": "owid_oil_share",
    "nuclear_share_energy": "owid_nuclear_share",
    "solar_share_energy": "owid_solar_share",
    "wind_share_energy": "owid_wind_share",
    "electricity_generation": "owid_elec_gen_twh",
    "electricity_from_renewables": "owid_elec_ren_twh",
    "per_capita_electricity": "owid_elec_pc_kwh",
    "carbon_intensity_elec": "owid_carbon_intensity_elec", # gCO2/kWh
    "energy_intensity_gdp": "owid_energy_intensity",       # kWh/$2019 PPP
}

try:
    r = requests.get(OWID_EN_URL, timeout=60)
    r.raise_for_status()
    df_en = pd.read_csv(io.StringIO(r.text), low_memory=False)
    avail = {k: v for k, v in OWID_EN_COLS.items() if k in df_en.columns}
    df_en = df_en[list(avail.keys())].rename(columns=avail)
    df_en = df_en[df_en["iso3"].isin(ALL_ISO)].dropna(subset=["iso3"])
    df_en["year"] = df_en["year"].astype(int)
    df_en = df_en[(df_en["year"] >= 1990) & (df_en["year"] <= 2024)]
    path = os.path.join(SRC_DIR, f"owid_energy_{TODAY}.csv")
    df_en.to_csv(path, index=False)
    log("OWID_EN", "all_vars", "OK", len(df_en),
        f"cols={len(df_en.columns)} countries={df_en['iso3'].nunique()}")
    print(f"  → Saved: {path}  [{df_en.shape}]")
except Exception as e:
    log("OWID_EN", "all_vars", "FAILED", 0, str(e)[:80])
    df_en = pd.DataFrame()

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 05 — FAO Food Price Index (monthly → annual)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 05 — FAO FOOD PRICE INDEX")
print("="*70)

FAO_FPI_URL = "https://www.fao.org/3/cc9940en/cc9940en.csv"  # FAO FPI historical
# Fallback: direct FAO data endpoint
FAO_FPI_ALT = "https://fenixservices.fao.org/faostat/api/v1/en/data/FP?area=5000&element=5531&year=1990:2024&output_type=csv"

try:
    r = requests.get(FAO_FPI_URL, timeout=30)
    r.raise_for_status()
    if len(r.content) < 500:
        raise ValueError("Too small")
    df_fpi_raw = pd.read_csv(io.StringIO(r.text))
    print(f"  FAO FPI cols: {list(df_fpi_raw.columns[:8])}")
    # Parse monthly data → annual mean
    # Expected: columns like 'Year', 'Month', 'Food Price Index', etc.
    if "Food Price Index" in df_fpi_raw.columns and "Year" in df_fpi_raw.columns:
        df_fpi_ann = df_fpi_raw.groupby("Year")["Food Price Index"].mean().reset_index()
        df_fpi_ann.columns = ["year","fao_food_price_idx"]
        df_fpi_ann["iso3"] = "WLD"
        path = os.path.join(SRC_DIR, f"fao_food_price_index_{TODAY}.csv")
        df_fpi_ann.to_csv(path, index=False)
        log("FAO_FPI", "food_price_index", "OK", len(df_fpi_ann))
        print(f"  → Saved: {path}  [{df_fpi_ann.shape}]")
    else:
        raise ValueError(f"Unexpected cols: {list(df_fpi_raw.columns)}")
except Exception as e:
    log("FAO_FPI", "food_price_index", "WARN", 0, f"Primary URL failed: {str(e)[:60]}")
    # Try alternative endpoint for global food price index
    try:
        # FAO FAOSTAT API — cereals price
        alt_url = "https://fenixservices.fao.org/faostat/api/v1/en/data/PP?area=5000&element=5532&item=2511&year=1990:2024&output_type=csv"
        r2 = requests.get(alt_url, timeout=30)
        df_fpi_raw2 = pd.read_csv(io.StringIO(r2.text))
        print(f"  FAO alt cols: {list(df_fpi_raw2.columns[:8])}")
        # Expect: Area,Year,Item,Element,Unit,Value
        if "Year" in df_fpi_raw2.columns and "Value" in df_fpi_raw2.columns:
            df_fpi2 = df_fpi_raw2[["Year","Value"]].rename(
                columns={"Year":"year","Value":"fao_food_price_idx"})
            df_fpi2["iso3"] = "WLD"
            path = os.path.join(SRC_DIR, f"fao_food_price_index_{TODAY}.csv")
            df_fpi2.to_csv(path, index=False)
            log("FAO_FPI", "food_price_index", "OK", len(df_fpi2), "alt endpoint")
        else:
            raise ValueError("No valid columns")
    except Exception as e2:
        log("FAO_FPI", "food_price_index", "FAILED", 0, str(e2)[:60])

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 06 — FAOSTAT Country-level Agricultural Data
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 06 — FAOSTAT COUNTRY AGRICULTURAL DATA")
print("="*70)

# ISO3 → FAO area codes mapping (key countries only)
FAO_AREA_MAP = {
    "AUS":10,"AUT":12,"AZE":52,"ARM":1,"BEL":15,"BGR":35,"BLR":57,"BRA":21,
    "CAN":33,"CHL":40,"CHN":351,"COL":44,"CZE":167,"DEU":79,"DNK":61,"EGY":59,
    "ESP":203,"EST":68,"FIN":69,"FRA":68,"GBR":229,"GEO":73,"GRC":84,
    "HRV":55,"HUN":97,"IDN":101,"IND":100,"IRL":104,"ISL":105,"ISR":106,
    "ITA":106,"JPN":110,"KAZ":108,"KGZ":113,"KOR":116,"LTU":119,"LUX":122,
    "LVA":119,"MEX":138,"MDA":146,"MLT":145,"NGA":159,"NLD":154,"NOR":162,
    "NZL":156,"POL":173,"PRT":174,"ROU":186,"RUS":185,"SVK":199,
    "SVN":198,"SWE":210,"TJK":208,"TKM":213,"TUR":223,"UKR":230,
    "UZB":235,"VNM":237,"ZAF":202,"CHE":209,"CYP":57,"ISR":106,
}

FAOSTAT_QUERIES = [
    # (dataset_code, element_code, item_code, col_name, description)
    ("QCL", 5510, 2905, "fao_cereal_prod_mt",    "Cereal production (Mt)"),
    ("QCL", 5510, 2903, "fao_food_prod_mt",       "Food production (Mt)"),
    ("QCL", 5419, 2905, "fao_cereal_area_ha",     "Cereal harvested area (ha)"),
    ("FS",  21,   21,    "fao_dietary_energy",     "Dietary energy supply (kcal)"),
    ("FS",  210,  21,    "fao_undernourishment",   "Prevalence undernourishment %"),
    ("RL",  5110, 6620,  "fao_arable_land_ha",    "Arable land (1000 ha)"),
    ("RL",  5110, 6655,  "fao_agri_land_ha",      "Agricultural land (1000 ha)"),
    ("RT",  5911, 1717,  "fao_fertilizer_kg_ha",  "Fertilizer use (kg/ha)"),
]

def faostat_fetch(dataset, element, item, col_name, countries_fao):
    """Fetch FAOSTAT data via REST API."""
    area_codes = [str(v) for k, v in FAO_AREA_MAP.items() if k in countries_fao and v]
    if not area_codes:
        return pd.DataFrame()
    area_str = "%2C".join(area_codes)
    url = (f"https://fenixservices.fao.org/faostat/api/v1/en/data/{dataset}"
           f"?area={area_str}&element={element}&item={item}"
           f"&year=1990:2024&output_type=csv")
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        text = r.text.strip()
        if len(text) < 100:
            return pd.DataFrame()
        df = pd.read_csv(io.StringIO(text))
        if "Area Code (ISO3)" in df.columns and "Year" in df.columns and "Value" in df.columns:
            df = df[["Area Code (ISO3)","Year","Value"]].rename(
                columns={"Area Code (ISO3)":"iso3","Year":"year","Value":col_name})
            df = df[df["iso3"].isin(ALL_ISO)]
            return df
        elif "Area Code" in df.columns:
            # Reverse-map area code to ISO3
            rev = {v: k for k, v in FAO_AREA_MAP.items()}
            df["iso3"] = df["Area Code"].map(rev)
            df = df[["iso3","Year","Value"]].rename(columns={"Year":"year","Value":col_name})
            return df.dropna(subset=["iso3"])
        return pd.DataFrame()
    except Exception as e:
        return pd.DataFrame()

fao_panels = []
for ds, el, it, col, desc in FAOSTAT_QUERIES:
    df_f = faostat_fetch(ds, el, it, col, ALL_ISO)
    if df_f.empty:
        log("FAOSTAT", col, "EMPTY")
    else:
        fao_panels.append(df_f[["iso3","year",col]])
        log("FAOSTAT", col, "OK", len(df_f))
    time.sleep(0.3)

if fao_panels:
    fao_merged = fao_panels[0]
    for p in fao_panels[1:]:
        fao_merged = pd.merge(fao_merged, p, on=["iso3","year"], how="outer")
    fao_merged = fao_merged[fao_merged["iso3"].isin(ALL_ISO)].sort_values(["iso3","year"])
    path = os.path.join(SRC_DIR, f"faostat_agri_{TODAY}.csv")
    fao_merged.to_csv(path, index=False)
    print(f"  → Saved: {path}  [{fao_merged.shape}]")
else:
    fao_merged = pd.DataFrame()
    print("  ❌ No FAOSTAT data fetched")

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 07 — Caldara-Iacoviello Geopolitical Risk Index (GPR)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 07 — CALDARA-IACOVIELLO GPR INDEX")
print("="*70)

GPR_URLS = [
    "https://matteoiacoviello.com/gpr_files/data_gpr_export.xls",
    "https://matteoiacoviello.com/gpr_files/data_gpr_export.xlsx",
    "https://www.federalreserve.gov/econres/notes/feds-notes/gpr_web_latest.xlsx",
]

gpr_ok = False
for gpr_url in GPR_URLS:
    try:
        r = requests.get(gpr_url, timeout=30, allow_redirects=True)
        r.raise_for_status()
        if len(r.content) < 1000:
            continue
        ext = "xlsx" if gpr_url.endswith("xlsx") else "xls"
        df_gpr_raw = pd.read_excel(io.BytesIO(r.content), engine=None)
        print(f"  GPR raw shape: {df_gpr_raw.shape}")
        print(f"  GPR cols: {list(df_gpr_raw.columns[:10])}")

        # GPR dataset has month, year, and country-level GPR indices
        df_gpr_raw.columns = [str(c).strip().lower() for c in df_gpr_raw.columns]

        # Find year/month columns
        if "year" in df_gpr_raw.columns and "month" in df_gpr_raw.columns:
            # Get GPR columns (usually named gpr, gprt, gprh, or country codes)
            gpr_cols = [c for c in df_gpr_raw.columns if c not in ["year","month","date"]]
            # Annual average
            df_gpr_ann = df_gpr_raw.groupby("year")[gpr_cols].mean().reset_index()
            # Identify global GPR column
            global_gpr_cols = [c for c in gpr_cols if c in ["gpr","gprt","gprh","gpr_all"]]
            country_gpr_cols = [c for c in gpr_cols if c not in global_gpr_cols and
                               len(c) <= 5 and c.isalpha()]
            print(f"  Global GPR cols: {global_gpr_cols[:5]}")
            print(f"  Country GPR cols: {country_gpr_cols[:10]}")

            # Save global GPR (WORLD)
            df_gpr_world = df_gpr_ann[["year"] + global_gpr_cols[:3]].copy()
            df_gpr_world["iso3"] = "WLD"
            df_gpr_world = df_gpr_world.rename(columns={
                global_gpr_cols[0]: "gpr_index" if global_gpr_cols else "gpr_index"
            })
            df_gpr_world = df_gpr_world[(df_gpr_world["year"] >= 1990) & (df_gpr_world["year"] <= 2024)]

            path = os.path.join(SRC_DIR, f"gpr_caldara_iacoviello_{TODAY}.csv")
            df_gpr_ann.to_csv(path, index=False)
            log("GPR", "gpr_index", "OK", len(df_gpr_ann), f"from {gpr_url[-40:]}")
            print(f"  → Saved: {path}  [{df_gpr_ann.shape}]")
            gpr_ok = True
            break
        else:
            # Try date-based format
            date_col = [c for c in df_gpr_raw.columns if "date" in c or "month" in c]
            if date_col:
                df_gpr_raw["year"] = pd.to_datetime(df_gpr_raw[date_col[0]], errors="coerce").dt.year
                gpr_cols = [c for c in df_gpr_raw.columns if c not in [date_col[0],"year"]]
                df_gpr_ann = df_gpr_raw.groupby("year")[gpr_cols].mean().reset_index()
                path = os.path.join(SRC_DIR, f"gpr_caldara_iacoviello_{TODAY}.csv")
                df_gpr_ann.to_csv(path, index=False)
                log("GPR", "gpr_index", "OK", len(df_gpr_ann))
                gpr_ok = True
                break
    except Exception as e:
        log("GPR", gpr_url[-30:], "FAILED", 0, str(e)[:60])

if not gpr_ok:
    log("GPR", "gpr_index", "FAILED", 0, "All URLs failed — check matteoiacoviello.com manually")

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 08 — FRED API (financial / commodity / monetary)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 08 — FRED FINANCIAL & COMMODITY DATA")
print("="*70)

FRED_SERIES = {
    # Commodities (global)
    "GOLDAMGBD228NLBM": "fred_gold_usd",         # Gold price USD/troy oz (daily→annual)
    "DCOILWTICO":       "fred_wti_usd",           # WTI crude oil price USD/barrel
    "DCOILBRENTEU":     "fred_brent_usd",         # Brent crude oil price
    "PNRGINDEXM":       "fred_energy_price_idx",  # Global energy price index
    "PALLFNFINDEXQ":    "fred_nonfuel_comm_idx",  # Non-fuel commodity price index
    "PFOODINDEXM":      "fred_food_comm_idx",     # Food commodity price index (IMF)
    # Financial
    "VIXCLS":           "fred_vix",               # CBOE VIX volatility index
    "BAMLH0A0HYM2":     "fred_us_hy_spread",      # US high-yield OAS spread
    "FEDFUNDS":         "fred_us_ffr",            # US federal funds rate
    "IORB":             "fred_us_iorb",           # Interest on reserve balances
    "DGS10":            "fred_us_10yr",           # US 10-year Treasury yield
    "T10Y2Y":           "fred_us_yield_curve",    # 10Y-2Y Treasury spread (recession signal)
    # Global / EM
    "DEXUSEU":          "fred_eurusd",            # EUR/USD exchange rate
    "DEXJPUS":          "fred_jpyusd",            # JPY/USD
    "DEXBZUS":          "fred_brlusd",            # BRL/USD
    "DEXCHUS":          "fred_cnhusd",            # CNY/USD
    "EMVOVERALLEMV":    "fred_em_volatility",     # EM market volatility
    "GEPUCURRENT":      "fred_global_epu",        # Global Economic Policy Uncertainty
    "USEPUINDXD":       "fred_us_epu",            # US Economic Policy Uncertainty (Baker et al.)
    # Macro
    "CPIAUCSL":         "fred_us_cpi",            # US CPI
    "CPILFESL":         "fred_us_core_cpi",       # US Core CPI
    "UNRATE":           "fred_us_unemp",          # US unemployment rate
    "USROA":            "fred_us_roa",            # US bank ROA (financial health proxy)
}

def fred_fetch_annual(series_id, col_name, obs_start="1990-01-01", obs_end="2024-12-31"):
    """Fetch FRED series and aggregate to annual mean."""
    url = (f"https://api.stlouisfed.org/fred/series/observations"
           f"?series_id={series_id}&api_key={FRED_KEY}&file_type=json"
           f"&observation_start={obs_start}&observation_end={obs_end}")
    try:
        r = requests.get(url, timeout=20)
        r.raise_for_status()
        data = r.json()
        if "observations" not in data:
            return pd.DataFrame()
        rows = []
        for obs in data["observations"]:
            try:
                val = float(obs["value"])
                rows.append({"date": obs["date"], "value": val})
            except ValueError:
                pass  # "." missing value
        if not rows:
            return pd.DataFrame()
        df = pd.DataFrame(rows)
        df["year"] = pd.to_datetime(df["date"]).dt.year
        df_ann = df.groupby("year")["value"].mean().reset_index()
        df_ann.columns = ["year", col_name]
        df_ann["iso3"] = "USA"  # FRED global series: tag as USA/WLD for joins
        return df_ann
    except Exception as e:
        return pd.DataFrame()

fred_panels = []
for series_id, col in FRED_SERIES.items():
    df_f = fred_fetch_annual(series_id, col)
    if df_f.empty:
        log("FRED", col, "EMPTY")
    else:
        fred_panels.append(df_f[["year", col]])
        log("FRED", col, "OK", len(df_f))
    time.sleep(0.15)

if fred_panels:
    fred_merged = fred_panels[0]
    for p in fred_panels[1:]:
        fred_merged = pd.merge(fred_merged, p, on="year", how="outer")
    fred_merged = fred_merged.sort_values("year")
    path = os.path.join(SRC_DIR, f"fred_financial_{TODAY}.csv")
    fred_merged.to_csv(path, index=False)
    log("FRED", "MERGED", "OK", len(fred_merged),
        f"cols={len(fred_merged.columns)} years={fred_merged['year'].min()}-{fred_merged['year'].max()}")
    print(f"  → Saved: {path}  [{fred_merged.shape}]")
else:
    fred_merged = pd.DataFrame()
    print("  ❌ No FRED data fetched")

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 09 — IMF DataMapper API (WEO + commodity)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 09 — IMF DATAMAPPER API")
print("="*70)

IMF_INDICATORS = {
    # WEO macro indicators (country-level)
    "NGDP_RPCH":   "imf_gdp_growth",      # Real GDP growth %
    "PCPIPCH":     "imf_inflation",        # CPI inflation %
    "LUR":         "imf_unemp_rate",       # Unemployment rate %
    "BCA_NGDPD":   "imf_ca_gdp",          # Current account % GDP
    "GGR_NGDP":    "imf_gov_rev_gdp",     # Govt revenue % GDP
    "GGX_NGDP":    "imf_gov_exp_gdp",     # Govt expenditure % GDP
    "GGSB_NPGDP":  "imf_fiscal_balance",  # Fiscal balance % GDP
    "NGDP_D":      "imf_gdp_deflator",    # GDP deflator
    "PPPGDP":      "imf_ppp_gdp",         # PPP GDP (international $)
    "PPPPC":       "imf_ppp_gdp_pc",      # PPP GDP per capita
    "GGXWDG_NGDP": "imf_govt_debt_gdp",  # Gross government debt % GDP
    "BM_NGDPD":    "imf_imports_gdp",    # Imports % GDP
    "BX_NGDPD":    "imf_exports_gdp",    # Exports % GDP
}

# ISO2 mapping needed for IMF API
ISO3_TO_ISO2 = {
    "ARG":"AR","AUS":"AU","AUT":"AT","AZE":"AZ","ARM":"AM","BEL":"BE",
    "BGR":"BG","BLR":"BY","BRA":"BR","CAN":"CA","CHL":"CL","CHN":"CN",
    "COL":"CO","CYP":"CY","CZE":"CZ","DEU":"DE","DNK":"DK","EGY":"EG",
    "ESP":"ES","EST":"EE","FIN":"FI","FRA":"FR","GBR":"GB","GEO":"GE",
    "GRC":"GR","HRV":"HR","HUN":"HU","IDN":"ID","IND":"IN","IRL":"IE",
    "ISL":"IS","ISR":"IL","ITA":"IT","JPN":"JP","KAZ":"KZ","KGZ":"KG",
    "KOR":"KR","LTU":"LT","LUX":"LU","LVA":"LV","MEX":"MX","MDA":"MD",
    "MLT":"MT","NGA":"NG","NLD":"NL","NOR":"NO","NZL":"NZ","POL":"PL",
    "PRT":"PT","ROU":"RO","RUS":"RU","SVK":"SK","SVN":"SI","SWE":"SE",
    "TJK":"TJ","TKM":"TM","TUR":"TR","UKR":"UA","USA":"US","UZB":"UZ",
    "VNM":"VN","ZAF":"ZA","CHE":"CH",
}

def imf_fetch(indicator, col_name, iso3_list):
    """Fetch IMF DataMapper indicator for list of countries."""
    iso2s = [ISO3_TO_ISO2.get(c) for c in iso3_list if ISO3_TO_ISO2.get(c)]
    if not iso2s:
        return pd.DataFrame()
    iso_str = "/".join(iso2s)
    url = f"https://www.imf.org/external/datamapper/api/v1/{indicator}/{iso_str}"
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        data = r.json()
        if "values" not in data:
            return pd.DataFrame()
        rows = []
        rev_map = {v: k for k, v in ISO3_TO_ISO2.items()}
        for iso2, years_dict in data["values"].get(indicator, {}).items():
            iso3 = rev_map.get(iso2)
            if not iso3:
                continue
            for yr_str, val in years_dict.items():
                rows.append({"iso3": iso3, "year": int(yr_str), col_name: val})
        return pd.DataFrame(rows)
    except Exception as e:
        return pd.DataFrame()

imf_panels = []
for indic, col in IMF_INDICATORS.items():
    df_i = imf_fetch(indic, col, ALL_ISO)
    if df_i.empty:
        log("IMF", col, "EMPTY")
    else:
        df_i = df_i[(df_i["year"] >= 1990) & (df_i["year"] <= 2024)]
        imf_panels.append(df_i)
        log("IMF", col, "OK", len(df_i))
    time.sleep(0.2)

if imf_panels:
    imf_merged = imf_panels[0]
    for p in imf_panels[1:]:
        imf_merged = pd.merge(imf_merged, p, on=["iso3","year"], how="outer")
    imf_merged = imf_merged[imf_merged["iso3"].isin(ALL_ISO)].sort_values(["iso3","year"])
    path = os.path.join(SRC_DIR, f"imf_weo_{TODAY}.csv")
    imf_merged.to_csv(path, index=False)
    log("IMF", "MERGED", "OK", len(imf_merged))
    print(f"  → Saved: {path}  [{imf_merged.shape}]")
else:
    imf_merged = pd.DataFrame()
    print("  ❌ No IMF data fetched")

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 10 — USDA ERS Agricultural TFP (Fuglie 2022)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 10 — USDA ERS AGRICULTURAL TFP")
print("="*70)

USDA_URLS = [
    "https://www.ers.usda.gov/webdocs/DataFiles/50048/AgTFPInternational2022.xlsx",
    "https://www.ers.usda.gov/webdocs/DataFiles/50048/AgTFPInternational2023.xlsx",
    "https://www.ers.usda.gov/webdocs/DataFiles/50048/AgTFPInternational2024.xlsx",
]

usda_ok = False
for usda_url in USDA_URLS:
    try:
        r = requests.get(usda_url, timeout=60, allow_redirects=True)
        r.raise_for_status()
        if len(r.content) < 10000:
            continue
        df_usda_raw = pd.read_excel(io.BytesIO(r.content), sheet_name=None)
        print(f"  USDA sheets: {list(df_usda_raw.keys())[:6]}")

        # Look for TFP data sheet
        tfp_sheet = None
        for sname in df_usda_raw.keys():
            if "tfp" in sname.lower() or "index" in sname.lower() or "all" in sname.lower():
                tfp_sheet = sname
                break
        if tfp_sheet is None:
            tfp_sheet = list(df_usda_raw.keys())[0]

        df_tfp = df_usda_raw[tfp_sheet]
        print(f"  TFP sheet '{tfp_sheet}' shape: {df_tfp.shape}")
        print(f"  Cols: {list(df_tfp.columns[:8])}")
        print(df_tfp.head(3).to_string())

        # Expected structure: country in rows, years in columns (wide)
        # or: Country, Year, TFP, Output, Input (long)
        if "Country" in df_tfp.columns and "Year" in df_tfp.columns:
            # Long format
            df_tfp.columns = [str(c).strip() for c in df_tfp.columns]
            # Map country names to ISO3 — use a basic lookup
            pass  # will handle below
        else:
            # Wide format with country names in first column, years in header
            df_tfp = df_tfp.set_index(df_tfp.columns[0])
            year_cols = [c for c in df_tfp.columns if str(c).isdigit() and 1960 <= int(str(c)) <= 2024]
            df_tfp = df_tfp[year_cols].reset_index()
            df_tfp = df_tfp.rename(columns={df_tfp.columns[0]: "country_name"})
            df_tfp_long = df_tfp.melt(id_vars=["country_name"], var_name="year", value_name="usda_agtfp")
            df_tfp_long["year"] = df_tfp_long["year"].astype(int)

        path = os.path.join(SRC_DIR, f"usda_agtfp_{TODAY}.xlsx")
        # Save raw for manual processing
        with pd.ExcelWriter(path) as writer:
            for sn, df_s in df_usda_raw.items():
                df_s.to_excel(writer, sheet_name=sn[:31], index=False)
        log("USDA_TFP", "agtfp", "OK", 0, f"Saved raw Excel from {usda_url[-30:]}")
        print(f"  → Saved raw: {path}")
        usda_ok = True
        break
    except Exception as e:
        log("USDA_TFP", usda_url[-30:], "FAILED", 0, str(e)[:80])

if not usda_ok:
    log("USDA_TFP", "agtfp", "FAILED", 0, "All URLs failed")

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 11 — Harvard Growth Lab ECI (Economic Complexity Index)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 11 — HARVARD GROWTH LAB ECI")
print("="*70)

ECI_URLS = [
    # Harvard Growth Lab direct data
    "https://raw.githubusercontent.com/cid-harvard/country-level-data/master/data/country/eci_1995-2021.csv",
    # OEC direct ECI (historical export)
    "https://oec.world/api/eci/eci/?flow=export&year=2000:2022&output_type=csv",
    # Alternative: CEPII BACI-derived ECI (not available directly)
]

eci_ok = False
for eci_url in ECI_URLS:
    try:
        r = requests.get(eci_url, timeout=30, allow_redirects=True)
        r.raise_for_status()
        if len(r.content) < 500:
            continue
        df_eci = pd.read_csv(io.StringIO(r.text))
        print(f"  ECI cols: {list(df_eci.columns[:8])}")
        print(df_eci.head(3).to_string())

        # Standardize: need iso3, year, eci columns
        col_map = {}
        for c in df_eci.columns:
            cl = str(c).lower()
            if "iso" in cl or "country_code" in cl or "iso3" in cl:
                col_map[c] = "iso3"
            elif "year" in cl:
                col_map[c] = "year"
            elif "eci" in cl and "iso" not in cl and "year" not in cl:
                col_map[c] = "eci"

        if "iso3" in col_map.values() and "eci" in col_map.values():
            df_eci = df_eci.rename(columns=col_map)
            df_eci = df_eci[["iso3","year","eci"]]
            df_eci = df_eci[df_eci["iso3"].isin(ALL_ISO)]
            df_eci["year"] = df_eci["year"].astype(int)
            df_eci = df_eci[(df_eci["year"] >= 1990) & (df_eci["year"] <= 2024)]
            path = os.path.join(SRC_DIR, f"eci_harvard_{TODAY}.csv")
            df_eci.to_csv(path, index=False)
            log("ECI", "eci", "OK", len(df_eci),
                f"countries={df_eci['iso3'].nunique()} years={df_eci['year'].min()}-{df_eci['year'].max()}")
            print(f"  → Saved: {path}  [{df_eci.shape}]")
            eci_ok = True
            break
        else:
            print(f"  ⚠️  Could not map columns: {col_map}")
    except Exception as e:
        log("ECI", eci_url[-40:], "FAILED", 0, str(e)[:60])

if not eci_ok:
    log("ECI", "eci", "WARN", 0, "Auto-fetch failed — download from atlas.cid.harvard.edu manually")

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 12 — ILO ILOSTAT REST API (Labour Market)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 12 — ILO ILOSTAT LABOUR MARKET DATA")
print("="*70)

ILO_INDICATORS = {
    "EMP_TEMP_SEX_STE_NB_A": "ilo_employment_total",     # Employment total
    "EAP_TEAP_SEX_AGE_NB_A": "ilo_lfpr",                 # Labour force participation
    "UNE_TUNE_SEX_AGE_NB_A": "ilo_unemployment_total",   # Unemployment total
    "UNE_DEAP_SEX_AGE_RT_A": "ilo_unemp_rate",           # Unemployment rate
    "EMP_TEMP_SEX_STE_STE_NB_A": "ilo_self_employed",    # Self-employment
    "EMP_NIFL_SEX_NB_A": "ilo_informal_employment",      # Informal employment
    "HOW_TEMP_SEX_ECO_NB_A": "ilo_hours_worked",         # Hours worked
    "EAR_4MTH_SEX_ECO_CUR_NB_A": "ilo_mean_wages",       # Mean nominal wages
}

def ilo_fetch(indicator, col_name, iso3_list, start=1990, end=2024):
    """Fetch ILO ILOSTAT REST API."""
    countries = "|".join(iso3_list)
    url = (f"https://rplumber.ilo.org/data/indicator/"
           f"?id={indicator}"
           f"&ref_area={countries}"
           f"&time={start}:{end}"
           f"&lang=en"
           f"&type=label"
           f"&format=.csv")
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        df = pd.read_csv(io.StringIO(r.text))
        if df.empty:
            return pd.DataFrame()
        # ILO standard: ref_area, time, obs_value
        col_mappings = {}
        for c in df.columns:
            cl = str(c).lower()
            if "ref_area" in cl or cl == "country":
                col_mappings[c] = "iso3"
            elif cl in ["time","year","ref_year"]:
                col_mappings[c] = "year"
            elif "obs_value" in cl or "value" in cl:
                col_mappings[c] = col_name
        if "iso3" not in col_mappings.values():
            return pd.DataFrame()
        df = df.rename(columns=col_mappings)
        df = df[["iso3","year",col_name]].copy()
        # ILO ref_area is ISO3 code
        df["iso3"] = df["iso3"].str.strip().str.upper()
        df = df[df["iso3"].isin(iso3_list)]
        df["year"] = pd.to_numeric(df["year"], errors="coerce").dropna()
        df = df.dropna(subset=["year"])
        df["year"] = df["year"].astype(int)
        return df
    except Exception as e:
        return pd.DataFrame()

ilo_panels = []
for indic, col in ILO_INDICATORS.items():
    df_i = ilo_fetch(indic, col, ALL_ISO)
    if df_i.empty:
        log("ILO", col, "EMPTY")
    else:
        ilo_panels.append(df_i[["iso3","year",col]])
        log("ILO", col, "OK", len(df_i))
    time.sleep(0.3)

if ilo_panels:
    ilo_merged = ilo_panels[0]
    for p in ilo_panels[1:]:
        ilo_merged = pd.merge(ilo_merged, p, on=["iso3","year"], how="outer")
    ilo_merged = ilo_merged[ilo_merged["iso3"].isin(ALL_ISO)].sort_values(["iso3","year"])
    path = os.path.join(SRC_DIR, f"ilo_labour_{TODAY}.csv")
    ilo_merged.to_csv(path, index=False)
    log("ILO", "MERGED", "OK", len(ilo_merged))
    print(f"  → Saved: {path}  [{ilo_merged.shape}]")
else:
    ilo_merged = pd.DataFrame()
    print("  ❌ No ILO data fetched (API may be slow/down)")

# ══════════════════════════════════════════════════════════════════════════════
# SOURCE 13 — World Bank Human Capital Index + additional composite indexes
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("SOURCE 13 — WB HUMAN CAPITAL INDEX + COMPOSITE INDEXES")
print("="*70)

COMPOSITE_INDICATORS = {
    "HD.HCI.OVRL":     "hci_overall",           # Human Capital Index (0-1)
    "HD.HCI.HLOS":     "hci_harmonized_learning",  # HCI harmonized test scores
    "HD.HCI.MORT":     "hci_u5_survival",        # HCI under-5 survival rate
    "HD.HCI.EYRS":     "hci_expected_years_schl",# HCI expected years of school
    "IQ.WEF.XINF.XQ":  "wef_infrastructure",    # WEF infrastructure index
    "IQ.WEF.PORT.XQ":  "wef_port_quality",       # WEF port infrastructure
    "IQ.WEF.ROAD.XQ":  "wef_road_quality",       # WEF road quality
    "IQ.WEF.EOSQ048":  "wef_tech_readiness",     # WEF technological readiness
    "IC.BUS.EASE.XQ":  "doing_business_ease",    # Ease of Doing Business score
    "IC.LGL.CRED.XQ":  "legal_rights_idx",       # Strength of legal rights (0-12)
    "IQ.SCI.OVRL":     "statistical_capacity",   # Statistical capacity indicator
}

comp_panels = []
for indic, col in COMPOSITE_INDICATORS.items():
    if col.startswith("#"):
        continue
    df = wb_fetch_batch(ALL_ISO, indic)
    if df.empty:
        log("WB_COMPOSITE", col, "EMPTY")
    else:
        df = df[df["iso3"].isin(ALL_ISO)].rename(columns={"value": col})
        comp_panels.append(df[["iso3","year",col]])
        log("WB_COMPOSITE", col, "OK", len(df))
    time.sleep(0.2)

if comp_panels:
    comp_merged = comp_panels[0]
    for p in comp_panels[1:]:
        comp_merged = pd.merge(comp_merged, p, on=["iso3","year"], how="outer")
    comp_merged = comp_merged[comp_merged["iso3"].isin(ALL_ISO)].sort_values(["iso3","year"])
    path = os.path.join(SRC_DIR, f"wb_composite_indexes_{TODAY}.csv")
    comp_merged.to_csv(path, index=False)
    log("WB_COMPOSITE", "MERGED", "OK", len(comp_merged))
    print(f"  → Saved: {path}  [{comp_merged.shape}]")
else:
    comp_merged = pd.DataFrame()

# ══════════════════════════════════════════════════════════════════════════════
# FINAL MERGE — Append all sources to existing group panels
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("FINAL MERGE — ALL SOURCES → GROUP PANELS")
print("="*70)

# Collect all country-level panels (iso3 × year)
all_country_panels = []
for df_src, src_name in [
    (wdi_add,    "WDI_ADD"),
    (df_co2,     "OWID_CO2"),
    (df_en,      "OWID_EN"),
    (imf_merged, "IMF_WEO"),
    (ilo_merged, "ILO"),
    (comp_merged, "WB_COMPOSITE"),
]:
    if isinstance(df_src, pd.DataFrame) and not df_src.empty and \
       "iso3" in df_src.columns and "year" in df_src.columns:
        all_country_panels.append((df_src, src_name))

# FRED is global (no iso3) — save separately, not merged into country panels
# PWT — might not have been successfully loaded; skip if empty
if isinstance(df_pwt, pd.DataFrame) and not df_pwt.empty and "iso3" in df_pwt.columns:
    all_country_panels.append((df_pwt, "PWT"))

merge_summary = []
for grp_name, ctries in GROUPS.items():
    pattern = os.path.join(OUT_DIR, f"panel_{grp_name.lower()}_*.csv")
    matches = glob.glob(pattern)
    if not matches:
        print(f"  ⚠️  No existing panel for {grp_name}")
        continue
    wdi_path = sorted(matches)[-1]
    panel = pd.read_csv(wdi_path)
    original_cols = list(panel.columns)

    for df_src, src_name in all_country_panels:
        grp_src = df_src[df_src["iso3"].isin(ctries)].copy()
        if grp_src.empty:
            continue
        # Drop duplicate columns that already exist in panel (except iso3/year)
        new_cols = [c for c in grp_src.columns
                    if c not in panel.columns or c in ["iso3","year"]]
        if len(new_cols) <= 2:
            continue
        grp_src = grp_src[new_cols]
        panel = pd.merge(panel, grp_src, on=["iso3","year"], how="left")

    panel["source_master"] = f"MGO_MASTER_{TODAY}"
    panel.to_csv(wdi_path, index=False)
    new_vars = [c for c in panel.columns if c not in original_cols]
    n_obs = len(panel)
    print(f"\n  ✅ {grp_name}: {panel.shape[1]} total cols | +{len(new_vars)} new vars | {n_obs} rows")
    if new_vars:
        print(f"     New vars: {new_vars[:8]}{'...' if len(new_vars)>8 else ''}")
    merge_summary.append({
        "group": grp_name,
        "total_cols": panel.shape[1],
        "new_vars": len(new_vars),
        "rows": n_obs,
    })

# ══════════════════════════════════════════════════════════════════════════════
# MASTER FETCH REPORT
# ══════════════════════════════════════════════════════════════════════════════
print("\n\n" + "="*70)
print("MASTER FETCH REPORT")
print("="*70)

df_log = pd.DataFrame(FETCH_LOG)
if not df_log.empty:
    ok_count   = (df_log["status"] == "OK").sum()
    fail_count = (df_log["status"] == "FAILED").sum()
    warn_count = (df_log["status"].isin(["WARN","EMPTY"])).sum()
    print(f"\nFetch log: {ok_count} OK | {warn_count} WARN/EMPTY | {fail_count} FAILED")
    print("\nFailed sources:")
    failed = df_log[df_log["status"].isin(["FAILED","EMPTY"])]
    if not failed.empty:
        print(failed[["source","indicator","note"]].to_string(index=False))

report_path = os.path.join(OUT_DIR, f"master_fetch_report_{TODAY}.csv")
df_log.to_csv(report_path, index=False)
print(f"\nFull log saved: {report_path}")

print("\nGroup panel summary:")
for s in merge_summary:
    print(f"  {s['group']:15} {s['total_cols']:3} vars | {s['rows']:4} rows | +{s['new_vars']} new")

print("\n" + "="*70)
print("ALL SOURCES COMPLETE")
print("="*70)
print("\n⚠️  ANAYASA CROSS-CHECK REQUIRED before any manuscript use.")
print("   Sources inventory:")
print("   01. WDI_ADD   — World Bank WDI (30 additional vars)")
print("   02. PWT       — Penn World Tables 10.01 (Feenstra et al.)")
print("   03. OWID_CO2  — Our World in Data CO2 (owid/co2-data)")
print("   04. OWID_EN   — Our World in Data Energy (owid/energy-data)")
print("   05. FAO_FPI   — FAO Food Price Index (gobal, annual)")
print("   06. FAOSTAT   — FAOSTAT agricultural country data")
print("   07. GPR       — Caldara-Iacoviello (2022) Geopolitical Risk")
print("   08. FRED      — St. Louis Fed (VIX, gold, oil, EPU, rates)")
print("   09. IMF_WEO   — IMF DataMapper (WEO macro indicators)")
print("   10. USDA_TFP  — USDA ERS Agricultural TFP (Fuglie 2022)")
print("   11. ECI       — Harvard Growth Lab Economic Complexity Index")
print("   12. ILO       — ILOSTAT labour market indicators")
print("   13. WB_HCI    — World Bank HCI + composite governance indexes")
