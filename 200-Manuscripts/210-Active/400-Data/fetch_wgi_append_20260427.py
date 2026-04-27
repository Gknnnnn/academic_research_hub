"""
WGI Governance Indicators — Bulk CSV Append
MGO Research Portfolio | Date: 2026-04-27

WGI codes NOT available via standard WDI API endpoint (archived/moved).
Fix: Download WGI bulk CSV from World Bank DataBank, filter, merge into
existing panels.

WGI source URL: https://databank.worldbank.org/data/download/WGI_csv.zip
Fallback: direct CSV per indicator via WB API source=3

WGI indicators fetched:
  CC.EST → wgi_control_corruption
  GE.EST → wgi_gov_effectiveness
  PV.EST → wgi_political_stability
  RL.EST → wgi_rule_of_law
  RQ.EST → wgi_reg_quality
  VA.EST → wgi_voice_accountability
"""

import requests, zipfile, io, os, glob
import pandas as pd
from datetime import date

TODAY = date.today().strftime("%Y%m%d")
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Country groups (same as main fetch script) ────────────────────────────────
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

WGI_MAP = {
    "CC.EST": "wgi_control_corruption",
    "GE.EST": "wgi_gov_effectiveness",
    "PV.EST": "wgi_political_stability",
    "RL.EST": "wgi_rule_of_law",
    "RQ.EST": "wgi_reg_quality",
    "VA.EST": "wgi_voice_accountability",
}

ALL_ISO = sorted(set(c for group in GROUPS.values() for c in group))

# ── Method 1: WB API source=3 (WGI dataset) ──────────────────────────────────
def fetch_wgi_source3(countries, indicator, per_page=20000):
    """Try WB source=3 API endpoint for WGI indicators."""
    iso = ";".join(countries)
    url = (f"https://api.worldbank.org/v2/sources/3/country/{iso}"
           f"/series/{indicator}/data?format=json&per_page={per_page}")
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        text = r.text.strip()
        if not text or text == "":
            return pd.DataFrame()
        data = r.json()
        # Source-3 API returns {"source": {"data": [...]}}
        if "source" not in data:
            return pd.DataFrame()
        items = data["source"].get("data", [])
        rows = []
        for obs in items:
            val = obs.get("value")
            country_code = obs.get("country", {}).get("id", "")
            year = obs.get("date", "")
            if country_code and year:
                rows.append({
                    "iso3": country_code,
                    "year": int(year),
                    "value": float(val) if val else None,
                })
        return pd.DataFrame(rows)
    except Exception as e:
        print(f"    source3 fail: {e}")
        return pd.DataFrame()

# ── Method 2: WGI bulk CSV download ──────────────────────────────────────────
WGI_ZIP_URL = "https://databank.worldbank.org/data/download/WGI_csv.zip"
WGI_CACHE   = os.path.join(OUT_DIR, "wgi_bulk_raw.csv")

def download_wgi_bulk():
    """Download WGI bulk CSV; cache locally to avoid re-download."""
    if os.path.exists(WGI_CACHE):
        print(f"  [cached] Reading WGI bulk from {WGI_CACHE}")
        return pd.read_csv(WGI_CACHE, low_memory=False)

    print(f"  Downloading WGI bulk ZIP from World Bank...")
    try:
        r = requests.get(WGI_ZIP_URL, timeout=120, stream=True)
        r.raise_for_status()
        z = zipfile.ZipFile(io.BytesIO(r.content))
        # Usually the main data file is named WGIData.csv or similar
        csv_names = [n for n in z.namelist() if n.endswith(".csv") and "Data" in n]
        if not csv_names:
            csv_names = [n for n in z.namelist() if n.endswith(".csv")]
        print(f"  ZIP contents: {z.namelist()}")
        if not csv_names:
            print("  ❌ No CSV found in WGI ZIP")
            return pd.DataFrame()
        df = pd.read_csv(z.open(csv_names[0]), low_memory=False)
        df.to_csv(WGI_CACHE, index=False)
        print(f"  ✅ WGI bulk cached: {WGI_CACHE}  [{len(df)} rows]")
        return df
    except Exception as e:
        print(f"  ❌ WGI bulk download failed: {e}")
        return pd.DataFrame()

def parse_wgi_bulk(df_raw, countries, indicator, col_name):
    """
    Parse WGI bulk CSV.
    Expected columns: Country Code, Indicator Code, [year columns 1996-2023]
    """
    if df_raw.empty:
        return pd.DataFrame()

    # Normalize column names
    cols = [str(c).strip() for c in df_raw.columns]
    df_raw.columns = cols

    # Filter by indicator code
    indic_col = None
    for c in ["Indicator Code", "Series Code", "IndicatorCode"]:
        if c in cols:
            indic_col = c
            break
    country_col = None
    for c in ["Country Code", "CountryCode"]:
        if c in cols:
            country_col = c
            break

    if indic_col is None or country_col is None:
        print(f"  ⚠️  Cannot find indicator/country columns. Cols: {cols[:10]}")
        return pd.DataFrame()

    sub = df_raw[(df_raw[indic_col] == indicator) &
                 (df_raw[country_col].isin(countries))].copy()
    if sub.empty:
        print(f"  ⚠️  No rows for {indicator} in bulk CSV")
        return pd.DataFrame()

    # Year columns: numeric 4-digit column names
    year_cols = [c for c in cols if c.isdigit() and 1990 <= int(c) <= 2024]
    if not year_cols:
        # Some formats use "YYYY [YRxxxx]"
        year_cols = [c for c in cols if len(c) >= 4 and c[:4].isdigit() and
                     1990 <= int(c[:4]) <= 2024]

    rows = []
    for _, row in sub.iterrows():
        iso = row[country_col]
        for yc in year_cols:
            val = row[yc]
            try:
                val = float(val)
            except (ValueError, TypeError):
                val = None
            year = int(str(yc)[:4])
            rows.append({"iso3": iso, "year": year, "value": val})

    df_out = pd.DataFrame(rows).rename(columns={"value": col_name})
    return df_out[["iso3", "year", col_name]]

# ── Main execution ─────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("WGI GOVERNANCE INDICATORS — FETCH & APPEND")
print("="*60)

# Step 1: Try source=3 API for all indicators × all countries at once
print("\n[1] Attempting WB source=3 API...")
wgi_panels = {}
all_countries = ALL_ISO

source3_success = False
test_indic = "CC.EST"
test_df = fetch_wgi_source3(all_countries[:5], test_indic)
if not test_df.empty:
    print(f"  ✅ source=3 API works! Fetching all indicators...")
    source3_success = True
else:
    print(f"  ❌ source=3 API failed. Switching to bulk CSV download...")

if source3_success:
    import time
    wgi_all = []
    for indic, col_name in WGI_MAP.items():
        print(f"  {col_name}...", end=" ")
        df = fetch_wgi_source3(all_countries, indic)
        if df.empty:
            print("EMPTY")
        else:
            df = df.rename(columns={"value": col_name})
            wgi_all.append(df[["iso3", "year", col_name]])
            print(f"{len(df)} obs ✓")
        time.sleep(0.3)

    if wgi_all:
        wgi_merged = wgi_all[0]
        for d in wgi_all[1:]:
            wgi_merged = pd.merge(wgi_merged, d, on=["iso3","year"], how="outer")
    else:
        wgi_merged = pd.DataFrame()
else:
    # Step 2: Bulk CSV
    print("\n[2] Downloading WGI bulk CSV...")
    df_raw = download_wgi_bulk()

    if df_raw.empty:
        print("❌ BOTH methods failed. WGI data NOT fetched.")
        print("   Manual download: https://databank.worldbank.org/source/worldwide-governance-indicators")
        raise SystemExit(1)

    wgi_all = []
    for indic, col_name in WGI_MAP.items():
        print(f"  Parsing {col_name}...", end=" ")
        df = parse_wgi_bulk(df_raw, all_countries, indic, col_name)
        if df.empty:
            print("EMPTY")
        else:
            wgi_all.append(df)
            print(f"{len(df)} obs ✓")

    if wgi_all:
        wgi_merged = wgi_all[0]
        for d in wgi_all[1:]:
            wgi_merged = pd.merge(wgi_merged, d, on=["iso3","year"], how="outer")
    else:
        wgi_merged = pd.DataFrame()

# Save standalone WGI panel (all countries)
if not wgi_merged.empty:
    wgi_path = os.path.join(OUT_DIR, f"wgi_all_countries_{TODAY}.csv")
    wgi_merged.to_csv(wgi_path, index=False)
    print(f"\n✅ WGI panel saved: {wgi_path}  [{len(wgi_merged)} rows]")
else:
    print("\n❌ wgi_merged is empty — check errors above")
    raise SystemExit(1)

# ── Step 3: Append WGI to existing WDI panel CSVs ─────────────────────────────
print("\n" + "="*60)
print("APPENDING WGI TO EXISTING WDI PANELS")
print("="*60)

wgi_cols = list(WGI_MAP.values())

for grp_name, ctries in GROUPS.items():
    # Find the existing WDI panel CSV
    pattern = os.path.join(OUT_DIR, f"panel_{grp_name.lower()}_*.csv")
    matches = glob.glob(pattern)
    if not matches:
        print(f"  ⚠️  No WDI panel found for {grp_name} — skipping")
        continue
    wdi_path = sorted(matches)[-1]  # most recent
    print(f"\n  {grp_name}: loading {os.path.basename(wdi_path)}")

    wdi = pd.read_csv(wdi_path)
    wgi_grp = wgi_merged[wgi_merged["iso3"].isin(ctries)].copy()

    if wgi_grp.empty:
        print(f"    ⚠️  No WGI rows for {grp_name}")
        continue

    merged = pd.merge(wdi, wgi_grp, on=["iso3","year"], how="left")
    # Overwrite with merged version
    merged.to_csv(wdi_path, index=False)

    n_wgi = merged[wgi_cols].notna().any(axis=1).sum()
    print(f"    ✅ Appended WGI: {n_wgi}/{len(merged)} rows have ≥1 governance value")
    print(f"    Cols added: {wgi_cols}")
    print(f"    File updated: {os.path.basename(wdi_path)}")

print("\n" + "="*60)
print("WGI APPEND COMPLETE")
print("="*60)
print("\n⚠️  CROSS-CHECK REMINDER: WGI estimates range approx −2.5 to +2.5")
print("    Source: World Bank Worldwide Governance Indicators (Kaufmann et al.)")
print("    Coverage: 1996–2023 (biennial pre-2002, annual 2002+)")
print("    Missing: VNM WGI coverage sparse; TKM/TJK similarly sparse")
