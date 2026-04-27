"""
01_data_assembly.py
PSE Composition & Agricultural TFP — OECD Panel
MGO × HBI | 2026-04-20

Steps:
  1. Extract USDA AgTFP for OECD countries (local file)
  2. Download OECD PSE components via OECD API
  3. Download WB WDI controls via World Bank API
  4. Merge → panel_master.csv (long format, 1990-2020)
"""

import pandas as pd
import numpy as np
import requests
import os
import warnings
warnings.filterwarnings("ignore")

# ── Paths ────────────────────────────────────────────────────────────────────
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW  = os.path.join(BASE, "06-Data", "raw")
CLEAN = os.path.join(BASE, "06-Data", "clean")
AGTFP_FILE = "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/400-Data/AgTFPInternational2020.xlsx"

os.makedirs(RAW, exist_ok=True)
os.makedirs(CLEAN, exist_ok=True)

# ── OECD country list (ISO3 + display names matching USDA file) ───────────────
OECD_COUNTRIES = {
    "AUS": "Australia",    "AUT": "Austria",      "BEL": "Belgium",
    "CAN": "Canada",       "CHL": "Chile",        "COL": "Colombia",
    "CRI": "Costa Rica",   "CZE": "Czech Republic","DNK": "Denmark",
    "EST": "Estonia",      "FIN": "Finland",      "FRA": "France",
    "DEU": "Germany",      "GRC": "Greece",       "HUN": "Hungary",
    "ISL": "Iceland",      "IRL": "Ireland",      "ISR": "Israel",
    "ITA": "Italy",        "JPN": "Japan",        "KOR": "Korea, Rep.",
    "LVA": "Latvia",       "LTU": "Lithuania",    "LUX": "Luxembourg",
    "MEX": "Mexico",       "NLD": "Netherlands",  "NZL": "New Zealand",
    "NOR": "Norway",       "POL": "Poland",       "PRT": "Portugal",
    "SVK": "Slovak Republic","SVN": "Slovenia",   "ESP": "Spain",
    "SWE": "Sweden",       "CHE": "Switzerland",  "TUR": "Turkey",
    "GBR": "United Kingdom","USA": "United States",
}

# USDA file uses slightly different names for a few countries
USDA_NAME_MAP = {
    "Korea, Rep.":    "Korea",
    "Slovak Republic": "Slovak Republic",  # same
    "Czech Republic":  "Czech Republic",   # same
}

YEAR_START, YEAR_END = 1990, 2020


# ═══════════════════════════════════════════════════════════════════════════════
# 1. USDA AgTFP
# ═══════════════════════════════════════════════════════════════════════════════
def extract_agtfp():
    print("── Step 1: Extracting USDA AgTFP ──")
    df_raw = pd.read_excel(AGTFP_FILE, sheet_name="AG TFP", header=2)

    # Year columns: 1961, 1962, ..., 2020
    year_cols = [c for c in df_raw.columns if str(c).replace(".0", "").isdigit()]
    year_cols = [c for c in year_cols if YEAR_START <= int(str(c).replace(".0","")) <= YEAR_END]

    keep_cols = ["ISO3", "Country/territory"] + year_cols
    df = df_raw[keep_cols].copy()
    df.columns = ["iso3", "country"] + [int(str(c).replace(".0","")) for c in year_cols]

    # Filter OECD — try ISO3 first, then name
    oecd_iso3 = list(OECD_COUNTRIES.keys())
    df_oecd = df[df["iso3"].isin(oecd_iso3)].copy()

    # Also catch by name for any ISO3 mismatches
    oecd_names = list(OECD_COUNTRIES.values())
    # Reverse USDA name map
    usda_names = [USDA_NAME_MAP.get(n, n) for n in oecd_names]
    df_name = df[df["country"].isin(usda_names) & ~df["iso3"].isin(oecd_iso3)]
    df_oecd = pd.concat([df_oecd, df_name], ignore_index=True)

    # Melt to long
    df_long = df_oecd.melt(id_vars=["iso3", "country"], var_name="year", value_name="tfp_index")
    df_long["year"] = df_long["year"].astype(int)

    print(f"   Countries found: {df_oecd['country'].nunique()} | Obs: {len(df_long)}")
    print(f"   Countries: {sorted(df_oecd['country'].tolist())}")

    out = os.path.join(RAW, "AgTFP_OECD_raw.csv")
    df_long.to_csv(out, index=False)
    print(f"   Saved → {out}")
    return df_long


# ═══════════════════════════════════════════════════════════════════════════════
# 2. OECD PSE via OECD API
# ═══════════════════════════════════════════════════════════════════════════════
# Dataset: MON2023 (OECD Agricultural Support Estimates)
# Key indicators:
#   PSECT  = Total PSE (USD million)
#   PSET01 = Market Price Support (MPS, USD million)
#   PSECT_P = %PSE
#   GSSE   = General Services Support Estimate (USD million)
#   CSECT  = Total CSE (Consumer Support Estimate)
#
# OECD API base: https://stats.oecd.org/SDMX-JSON/data/

OECD_API = "https://stats.oecd.org/SDMX-JSON/data"
OECD_API_NEW = "https://sdmx.oecd.org/public/rest/data"

# Country codes in OECD PSE dataset
OECD_PSE_COUNTRIES = (
    "AUS+AUT+BEL+CAN+CHL+COL+CRI+CZE+DNK+EST+FIN+FRA+DEU+GRC+HUN+"
    "ISL+IRL+ISR+ITA+JPN+KOR+LVA+LTU+LUX+MEX+NLD+NZL+NOR+POL+PRT+"
    "SVK+SVN+ESP+SWE+CHE+TUR+GBR+USA"
)

PSE_INDICATORS = {
    "PSECT":   "pse_total_usd",   # Total PSE USD mn
    "PSET01":  "mps_usd",          # Market Price Support USD mn
    "PSECT_P": "pse_pct",          # %PSE
    "GSSE":    "gsse_usd",         # GSSE USD mn
}

# Try alternative dataset codes
PSE_DATASET_CANDIDATES = ["MON2023", "MON2023_AGGREGATES", "PAG"]


def fetch_oecd_pse_indicator(indicator_code, indicator_name):
    """Fetch one PSE indicator, trying multiple OECD API endpoints."""
    # Try new OECD SDMX REST API first
    urls_to_try = [
        # New OECD API (2024+)
        (f"{OECD_API_NEW}/OECD.TAD.ATM,MON2023,1.0/"
         f"OECD+{OECD_PSE_COUNTRIES.replace('+','+')}....{indicator_code}..."
         f"?startPeriod={YEAR_START}&endPeriod={YEAR_END}&dimensionAtObservation=TIME_PERIOD&format=jsondata"),
        # Legacy API alternative
        (f"{OECD_API}/MON2023/{OECD_PSE_COUNTRIES}.{indicator_code}."
         f"?startTime={YEAR_START}&endTime={YEAR_END}&dimensionAtObservation=allDimensions"),
        # Try without indicator filter (get all, filter post)
        (f"https://stats.oecd.org/SDMX-JSON/data/PAG/{OECD_PSE_COUNTRIES}.{indicator_code}.."
         f"?startTime={YEAR_START}&endTime={YEAR_END}&dimensionAtObservation=allDimensions"),
    ]

    for url in urls_to_try:
        try:
            r = requests.get(url, timeout=60)
            if r.status_code != 200:
                continue
            data = r.json()
            obs_key = "observations" if "observations" in data.get("dataSets", [{}])[0] else None
            if obs_key is None:
                continue
            obs = data["dataSets"][0][obs_key]
            dims = data["structure"]["dimensions"]["observation"]
            idx_maps = []
            for d in dims:
                idx_maps.append({str(i): v["id"] for i, v in enumerate(d["values"])})
            dim_names = [d["id"] for d in dims]
            rows = []
            for key, val in obs.items():
                parts = key.split(":")
                row = {dim_names[i]: idx_maps[i].get(p, p) for i, p in enumerate(parts)}
                row["value"] = val[0]
                rows.append(row)
            df = pd.DataFrame(rows)
            country_dim = next((n for n in dim_names if any(x in n.upper() for x in ["COUNTRY","COU","LOCATION","LOC"])), dim_names[0])
            time_dim = next((n for n in dim_names if any(x in n.upper() for x in ["TIME","YEAR","PERIOD"])), dim_names[-1])
            df = df[[country_dim, time_dim, "value"]].rename(columns={
                country_dim: "iso3", time_dim: "year", "value": indicator_name
            })
            df["year"] = pd.to_numeric(df["year"], errors="coerce").dropna().astype(int)
            df[indicator_name] = pd.to_numeric(df[indicator_name], errors="coerce")
            df = df.dropna(subset=["year"])
            print(f"   {indicator_code}: {len(df)} obs fetched")
            return df
        except Exception:
            continue

    print(f"   WARNING: All endpoints failed for {indicator_code}")
    return None


def download_oecd_pse():
    print("\n── Step 2: Downloading OECD PSE components ──")
    print("   Using OECD SDMX-JSON API (stats.oecd.org) ...")

    frames = []
    for code, name in PSE_INDICATORS.items():
        df = fetch_oecd_pse_indicator(code, name)
        if df is not None:
            frames.append(df)

    if not frames:
        print("   FALLBACK: API unavailable. Manual download instructions:")
        print("   1. Go to: https://stats.oecd.org/Index.aspx?DataSetCode=MON2023")
        print("   2. Select: All OECD countries | Indicators: PSE total, MPS, %PSE, GSSE")
        print("   3. Years: 1990–2023 | Export as CSV → save to 06-Data/raw/OECD_PSE_raw.csv")
        return None

    # Merge all indicators on iso3 + year
    df_pse = frames[0]
    for df in frames[1:]:
        df_pse = df_pse.merge(df, on=["iso3", "year"], how="outer")

    # Compute composition shares
    df_pse["mps_share"] = np.where(
        df_pse["pse_total_usd"] > 0,
        df_pse["mps_usd"] / df_pse["pse_total_usd"],
        np.nan
    )
    df_pse["gsse_share"] = np.where(
        (df_pse["pse_total_usd"] + df_pse["gsse_usd"]) > 0,
        df_pse["gsse_usd"] / (df_pse["pse_total_usd"] + df_pse["gsse_usd"]),
        np.nan
    )

    # Filter OECD member countries only (exclude EU28, OECD aggregates)
    oecd_iso3 = list(OECD_COUNTRIES.keys())
    df_pse = df_pse[df_pse["iso3"].isin(oecd_iso3)].copy()

    out = os.path.join(RAW, "OECD_PSE_raw.csv")
    df_pse.to_csv(out, index=False)
    print(f"   Saved → {out}")
    print(f"   Countries: {df_pse['iso3'].nunique()} | Obs: {len(df_pse)}")
    return df_pse


# ═══════════════════════════════════════════════════════════════════════════════
# 3. World Bank WDI controls
# ═══════════════════════════════════════════════════════════════════════════════
WB_INDICATORS = {
    "NY.GDP.PCAP.KD":   "gdppc_const2015",   # GDP per capita (const. 2015 USD)
    "SP.RUR.TOTL.ZS":   "rural_share",        # Rural population %
    "AG.CON.FERT.ZS":   "fertilizer_kgha",   # Fertilizer consumption kg/ha
    "NV.AGR.TOTL.ZS":   "agr_va_gdp",        # Agriculture value added % GDP
    "AG.LND.AGRI.ZS":   "agland_share",      # Agricultural land % land area
}

WB_API = "https://api.worldbank.org/v2"


def fetch_wb_indicator(indicator, var_name, countries_iso2):
    """Fetch one WB indicator for given country list."""
    clist = ";".join(countries_iso2)
    url = (
        f"{WB_API}/country/{clist}/indicator/{indicator}"
        f"?date={YEAR_START}:{YEAR_END}&format=json&per_page=5000"
    )
    try:
        r = requests.get(url, timeout=60)
        if r.status_code != 200:
            print(f"   WARNING: WB API {r.status_code} for {indicator}")
            return None
        data = r.json()
        if len(data) < 2 or not data[1]:
            return None
        rows = []
        for obs in data[1]:
            rows.append({
                "iso3": obs["countryiso3code"],
                "year": int(obs["date"]),
                var_name: obs["value"],
            })
        df = pd.DataFrame(rows)
        df[var_name] = pd.to_numeric(df[var_name], errors="coerce")
        print(f"   {indicator}: {len(df)} obs")
        return df
    except Exception as e:
        print(f"   ERROR fetching {indicator}: {e}")
        return None


# ISO2 codes for WB API (subset of OECD)
ISO3_TO_ISO2 = {
    "AUS":"AU","AUT":"AT","BEL":"BE","CAN":"CA","CHL":"CL","COL":"CO",
    "CRI":"CR","CZE":"CZ","DNK":"DK","EST":"EE","FIN":"FI","FRA":"FR",
    "DEU":"DE","GRC":"GR","HUN":"HU","ISL":"IS","IRL":"IE","ISR":"IL",
    "ITA":"IT","JPN":"JP","KOR":"KR","LVA":"LV","LTU":"LT","LUX":"LU",
    "MEX":"MX","NLD":"NL","NZL":"NZ","NOR":"NO","POL":"PL","PRT":"PT",
    "SVK":"SK","SVN":"SI","ESP":"ES","SWE":"SE","CHE":"CH","TUR":"TR",
    "GBR":"GB","USA":"US",
}


def download_wb_controls():
    print("\n── Step 3: Downloading WB WDI controls ──")
    iso2_list = list(ISO3_TO_ISO2.values())

    frames = []
    for indicator, var_name in WB_INDICATORS.items():
        df = fetch_wb_indicator(indicator, var_name, iso2_list)
        if df is not None:
            frames.append(df)

    if not frames:
        print("   WB API unavailable. Try later or use wbstats R package.")
        return None

    df_wb = frames[0]
    for df in frames[1:]:
        df_wb = df_wb.merge(df, on=["iso3", "year"], how="outer")

    # Filter OECD only
    df_wb = df_wb[df_wb["iso3"].isin(list(OECD_COUNTRIES.keys()))].copy()
    out = os.path.join(RAW, "WB_controls_raw.csv")
    df_wb.to_csv(out, index=False)
    print(f"   Saved → {out}")
    return df_wb


# ═══════════════════════════════════════════════════════════════════════════════
# 4. Merge → panel_master.csv
# ═══════════════════════════════════════════════════════════════════════════════
def merge_panel(df_tfp, df_pse, df_wb):
    print("\n── Step 4: Merging panel ──")

    if df_tfp is None:
        print("   ERROR: AgTFP data missing. Cannot merge.")
        return None

    df = df_tfp.rename(columns={"iso3": "iso3", "country": "country"})

    # Standardize iso3 in TFP (USDA uses country names, not ISO3 for some)
    # Build reverse map: country → iso3
    name_to_iso3 = {v: k for k, v in OECD_COUNTRIES.items()}
    # USDA-specific names
    usda_extra = {"Korea": "KOR", "Slovak Republic": "SVK", "Czech Republic": "CZE"}
    name_to_iso3.update(usda_extra)
    df["iso3"] = df.apply(
        lambda r: r["iso3"] if str(r["iso3"]).strip() not in ["", "nan", "None"]
        else name_to_iso3.get(r["country"], np.nan), axis=1
    )

    if df_pse is not None:
        df = df.merge(df_pse, on=["iso3", "year"], how="left")
    else:
        print("   WARNING: PSE data not available — merging without it.")

    if df_wb is not None:
        df = df.merge(df_wb, on=["iso3", "year"], how="left")
    else:
        print("   WARNING: WB data not available — merging without it.")

    # Log transforms
    for col in ["tfp_index", "gdppc_const2015", "fertilizer_kgha"]:
        if col in df.columns:
            df[f"ln_{col}"] = np.log(df[col].replace(0, np.nan))

    # Country × year balance report
    print("\n   Balance check:")
    balance = df.groupby("iso3")["year"].count().describe()
    print(f"   T per country: mean={balance['mean']:.1f}, min={balance['min']:.0f}, max={balance['max']:.0f}")

    check_cols = [c for c in ["tfp_index", "pse_pct", "mps_share", "gsse_share",
                              "gdppc_const2015", "rural_share"] if c in df.columns]
    missing = df[check_cols].isnull().sum()
    print("\n   Missing values by variable:")
    print(missing.to_string())

    out = os.path.join(CLEAN, "panel_master.csv")
    df.to_csv(out, index=False)
    print(f"\n   panel_master.csv saved → {out}")
    print(f"   Dimensions: {df.shape[0]} obs × {df.shape[1]} vars")
    print(f"   N = {df['iso3'].nunique()} countries | T = {df['year'].min()}–{df['year'].max()}")
    return df


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    print("=" * 60)
    print("PSE Composition × AgTFP — Data Assembly")
    print("=" * 60)

    df_tfp = extract_agtfp()
    df_pse = download_oecd_pse()
    df_wb  = download_wb_controls()
    df_panel = merge_panel(df_tfp, df_pse, df_wb)

    if df_panel is not None:
        print("\n✓ Data assembly complete.")
        print("  Next: run 02_CD_slope_tests.R")
    else:
        print("\n✗ Assembly incomplete — check API connections.")
