"""
Remaining Data Sources — MGO Research Portfolio
Date: 2026-04-27

Targets:
  1. FAOSTAT — bulk ZIP (33.9MB, confirmed 200 OK)
  2. ILO ILOSTAT — unemployment/labor via REST API (fixed params)
  3. USDA AgTFP — try Wayback Machine + direct ERS paths
  4. ECI — Harvard Growth Lab (report manual download if all fail)

Output: sources/faostat_20260427.csv
        sources/ilo_labor_20260427.csv
        sources/usda_agtfp_20260427.csv  (if successful)
Panels updated: panel_*_20260427.csv (appended new columns)
"""

import requests, zipfile, io, os, glob, time, json
import pandas as pd
from datetime import date

TODAY = date.today().strftime("%Y%m%d")
OUT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCES_DIR = os.path.join(OUT_DIR, "sources")
os.makedirs(SOURCES_DIR, exist_ok=True)

GROUPS = {
    "CIVETS":      ["COL", "IDN", "VNM", "EGY", "TUR", "ZAF"],
    "BRICST_MINT": ["BRA", "RUS", "IND", "CHN", "ZAF", "TUR", "MEX", "IDN", "NGA"],
    "EU27":        ["AUT","BEL","BGR","HRV","CYP","CZE","DNK","EST","FIN","FRA","DEU",
                    "GRC","HUN","IRL","ITA","LVA","LTU","LUX","MLT","NLD","POL","PRT",
                    "ROU","SVK","SVN","ESP","SWE"],
    "EURASIAN":    ["AZE","ARM","BLR","GEO","KAZ","KGZ","MDA","RUS","TJK","TKM",
                    "UKR","UZB","TUR"],
    "OECD35":      ["AUS","AUT","BEL","CAN","CHL","CZE","DNK","EST","FIN","FRA","DEU",
                    "GRC","HUN","ISL","IRL","ISR","ITA","JPN","KOR","LVA","LTU","LUX",
                    "MEX","NLD","NZL","NOR","POL","PRT","SVK","SVN","ESP","SWE","CHE",
                    "TUR","GBR","USA"],
}
ALL_ISO = sorted(set(c for g in GROUPS.values() for c in g))

def find_panel(grp_name):
    pattern = os.path.join(OUT_DIR, f"panel_{grp_name.lower()}_*.csv")
    matches = sorted(glob.glob(pattern))
    return matches[-1] if matches else None

def append_to_panels(df_source, merge_cols, new_cols, label):
    """Merge df_source (with iso3+year+new_cols) into all group panels."""
    merged_count = 0
    for grp_name, ctries in GROUPS.items():
        path = find_panel(grp_name)
        if not path:
            print(f"  ⚠️  No panel for {grp_name}")
            continue
        panel = pd.read_csv(path)
        # Drop cols that already exist to avoid duplicates
        existing = [c for c in new_cols if c in panel.columns]
        if existing:
            panel = panel.drop(columns=existing)
        sub = df_source[df_source["iso3"].isin(ctries)][merge_cols + new_cols].copy()
        merged = pd.merge(panel, sub, on=merge_cols, how="left")
        merged.to_csv(path, index=False)
        n = merged[new_cols].notna().any(axis=1).sum()
        print(f"    {grp_name}: {n}/{len(merged)} rows have ≥1 {label} value → {os.path.basename(path)}")
        merged_count += 1
    return merged_count

# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("SOURCE 1: FAOSTAT BULK")
print("="*60)

# FAOSTAT ISO3 map (FAOSTAT uses M49 numeric codes internally, but country names)
# We'll match on CountryCode (ISO3) column if present, else use country name map
FAO_ISO_NAME = {
    "COL": "Colombia", "IDN": "Indonesia", "VNM": "Viet Nam",
    "EGY": "Egypt", "TUR": "Türkiye", "ZAF": "South Africa",
    "BRA": "Brazil", "RUS": "Russian Federation", "IND": "India",
    "CHN": "China, mainland", "MEX": "Mexico", "NGA": "Nigeria",
    "AUT": "Austria", "BEL": "Belgium", "BGR": "Bulgaria",
    "HRV": "Croatia", "CYP": "Cyprus", "CZE": "Czechia",
    "DNK": "Denmark", "EST": "Estonia", "FIN": "Finland",
    "FRA": "France", "DEU": "Germany", "GRC": "Greece",
    "HUN": "Hungary", "IRL": "Ireland", "ITA": "Italy",
    "LVA": "Latvia", "LTU": "Lithuania", "LUX": "Luxembourg",
    "MLT": "Malta", "NLD": "Netherlands (Kingdom of the)",
    "POL": "Poland", "PRT": "Portugal", "ROU": "Romania",
    "SVK": "Slovakia", "SVN": "Slovenia", "ESP": "Spain",
    "SWE": "Sweden", "AZE": "Azerbaijan", "ARM": "Armenia",
    "BLR": "Belarus", "GEO": "Georgia", "KAZ": "Kazakhstan",
    "KGZ": "Kyrgyzstan", "MDA": "Republic of Moldova",
    "TJK": "Tajikistan", "TKM": "Turkmenistan",
    "UKR": "Ukraine", "UZB": "Uzbekistan",
    "AUS": "Australia", "CAN": "Canada", "CHL": "Chile",
    "ISL": "Iceland", "ISR": "Israel", "JPN": "Japan",
    "KOR": "Republic of Korea", "NZL": "New Zealand",
    "NOR": "Norway", "CHE": "Switzerland", "GBR": "United Kingdom of Great Britain and Northern Ireland",
    "USA": "United States of America",
}
FAO_NAME_ISO = {v: k for k, v in FAO_ISO_NAME.items()}

FAOSTAT_CACHE = os.path.join(SOURCES_DIR, "faostat_raw_cache.zip")
FAOSTAT_OUT   = os.path.join(SOURCES_DIR, f"faostat_20260427.csv")

# FAOSTAT items we want: cereals, vegetables, fruits, meat for food security
FAO_ITEMS = {
    "Cereals (including rice milled equivalent)": "fao_cereal_prod_mt",
    "Cereals, Total": "fao_cereal_total_mt",
    "Wheat": "fao_wheat_prod_mt",
    "Rice, paddy (rice milled equivalent)": "fao_rice_prod_mt",
    "Vegetables, Fresh": "fao_veg_prod_mt",
    "Fruit, Fresh": "fao_fruit_prod_mt",
    "Meat, total": "fao_meat_prod_mt",
    "Milk, Total": "fao_milk_prod_mt",
    "Sugar Crops, Total": "fao_sugarcrop_prod_mt",
    "Roots and Tubers, Total": "fao_roots_prod_mt",
    "Food crops": "fao_food_crops_mt",
    "Oil Crops, Total": "fao_oilcrop_prod_mt",
}
FAO_ELEMENT = "Production"  # tonnes

def fetch_faostat():
    # Try direct bulk URL first
    url = "https://bulks-faostat.fao.org/production/Production_Crops_Livestock_E_All_Data_(Normalized).zip"

    if os.path.exists(FAOSTAT_CACHE):
        print(f"  [cached] {FAOSTAT_CACHE}")
        with open(FAOSTAT_CACHE, "rb") as f:
            return f.read()

    print(f"  Downloading FAOSTAT bulk ZIP (~33.9 MB)...")
    try:
        r = requests.get(url, timeout=180, stream=True)
        r.raise_for_status()
        content = r.content
        with open(FAOSTAT_CACHE, "wb") as f:
            f.write(content)
        print(f"  ✅ Downloaded {len(content)/1e6:.1f} MB → cached")
        return content
    except Exception as e:
        print(f"  ❌ Primary URL failed: {e}")
        # Try alternative
        alt_urls = [
            "https://bulks-faostat.fao.org/production/Production_Crops_E_All_Data_(Normalized).zip",
            "https://www.fao.org/faostat/en/data/QCL/download",
        ]
        for au in alt_urls:
            try:
                r2 = requests.get(au, timeout=120, stream=True)
                r2.raise_for_status()
                content = r2.content
                print(f"  ✅ Alt URL: {au}")
                with open(FAOSTAT_CACHE, "wb") as f:
                    f.write(content)
                return content
            except Exception as e2:
                print(f"  ❌ {au}: {e2}")
        return None

fao_content = fetch_faostat()

if fao_content:
    try:
        z = zipfile.ZipFile(io.BytesIO(fao_content))
        csv_files = [n for n in z.namelist() if n.endswith(".csv")]
        # Use Normalized file (one row per obs)
        norm_files = [n for n in csv_files if "Normalized" in n or "normalized" in n]
        target = norm_files[0] if norm_files else csv_files[0]
        print(f"  Parsing: {target}")

        df_fao_raw = pd.read_csv(z.open(target), encoding="latin-1", low_memory=False)
        print(f"  Raw shape: {df_fao_raw.shape}")
        print(f"  Columns: {list(df_fao_raw.columns[:10])}")

        # Normalized format: Area, Item, Element, Year, Unit, Value, Flag
        # Filter: Element == "Production", Item in FAO_ITEMS
        target_items = list(FAO_ITEMS.keys())
        target_names = list(FAO_ISO_NAME.values())

        # Try to find Area column
        area_col = next((c for c in df_fao_raw.columns if "area" in c.lower()), None)
        item_col = next((c for c in df_fao_raw.columns if "item" in c.lower() and "code" not in c.lower()), None)
        elem_col = next((c for c in df_fao_raw.columns if "element" in c.lower() and "code" not in c.lower()), None)
        year_col = next((c for c in df_fao_raw.columns if "year" in c.lower() and "code" not in c.lower()), None)
        val_col  = next((c for c in df_fao_raw.columns if c.lower() == "value"), None)

        print(f"  Cols found → area:{area_col} item:{item_col} elem:{elem_col} year:{year_col} val:{val_col}")

        if all([area_col, item_col, elem_col, year_col, val_col]):
            sub = df_fao_raw[
                (df_fao_raw[area_col].isin(target_names)) &
                (df_fao_raw[item_col].isin(target_items)) &
                (df_fao_raw[elem_col] == FAO_ELEMENT)
            ].copy()
            print(f"  Filtered rows: {len(sub)}")

            if sub.empty:
                # Try broader filter — just area + element
                sub = df_fao_raw[
                    (df_fao_raw[area_col].isin(target_names)) &
                    (df_fao_raw[elem_col] == FAO_ELEMENT)
                ].copy()
                print(f"  Broad filter (all items): {len(sub)} rows")

            if not sub.empty:
                sub["iso3"] = sub[area_col].map(FAO_NAME_ISO)
                sub = sub[sub["iso3"].notna()].copy()
                sub["year"] = pd.to_numeric(sub[year_col], errors="coerce").astype("Int64")
                sub["value"] = pd.to_numeric(sub[val_col], errors="coerce")
                sub["col_name"] = sub[item_col].map(FAO_ITEMS).fillna("fao_" + sub[item_col].str.lower().str.replace(r"[^a-z0-9]","_",regex=True).str[:25])

                # Pivot wide
                sub_pivot = sub.pivot_table(
                    index=["iso3","year"], columns="col_name", values="value", aggfunc="sum"
                ).reset_index()
                sub_pivot.columns.name = None
                sub_pivot = sub_pivot.sort_values(["iso3","year"])
                sub_pivot.to_csv(FAOSTAT_OUT, index=False)

                fao_cols = [c for c in sub_pivot.columns if c not in ["iso3","year"]]
                print(f"  ✅ FAOSTAT: {sub_pivot['iso3'].nunique()} countries × {sub_pivot['year'].nunique()} years × {len(fao_cols)} items")
                print(f"  Saved: {FAOSTAT_OUT}")

                # Append to panels
                print("\n  Appending to group panels...")
                append_to_panels(sub_pivot, ["iso3","year"], fao_cols, "FAOSTAT")
            else:
                print("  ❌ No data after filtering")
        else:
            print("  ❌ Could not identify required columns")
    except Exception as e:
        print(f"  ❌ FAOSTAT parse error: {e}")
        import traceback; traceback.print_exc()
else:
    print("  ❌ FAOSTAT download failed — manual download required:")
    print("     https://www.fao.org/faostat/en/#data/QCL")


# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("SOURCE 2: ILO ILOSTAT — UNEMPLOYMENT & LABOR")
print("="*60)

# ILO REST API: https://rplumber.ilo.org/data/indicator/
# Key: use type=label or type=code; filter by ref_area
# Working format: fetch all, filter locally — same pattern as IMF

ILO_INDICATORS = {
    "UNE_DEAP_SEX_AGE_RT_A": "ilo_unemp_rate",         # Unemployment rate, total
    "EAP_TEAP_SEX_AGE_RT_A": "ilo_lfpr",               # Labour force participation rate
    "EMP_TEMP_SEX_AGE_STE_ECO_RT_A": "ilo_emp_share_agr", # Employment share agriculture
    "HOW_TEMP_SEX_ECO_NB_A": "ilo_avg_hours_worked",   # Mean weekly hours worked
}

ILO_OUT = os.path.join(SOURCES_DIR, f"ilo_labor_20260427.csv")

def fetch_ilo_indicator(indic_code, col_name, countries, max_retries=2):
    """Fetch ILO indicator — try multiple API approaches."""

    # Approach 1: Bulk fetch (no country filter), then filter locally
    # ILO API base
    base = "https://rplumber.ilo.org/data/indicator/"

    # Try with minimal params — just indicator ID
    urls_to_try = [
        f"{base}?id={indic_code}&type=label&format=.csv",
        f"{base}?id={indic_code}&format=.csv",
        f"https://rplumber.ilo.org/data/indicator/?id={indic_code}&sex=SEX_T&classif1=AGE_YTHADULT_YGE15&format=.csv",
    ]

    for url in urls_to_try:
        try:
            r = requests.get(url, timeout=60)
            if r.status_code == 200 and len(r.content) > 500:
                # Has data
                from io import StringIO
                df = pd.read_csv(StringIO(r.text))
                print(f"    {indic_code}: {len(df)} rows via {url[:60]}")
                if df.empty:
                    continue

                # Find columns
                ref_col  = next((c for c in df.columns if "ref_area" in c.lower()), None)
                time_col = next((c for c in df.columns if "time" in c.lower() or "year" in c.lower()), None)
                val_col  = next((c for c in df.columns if "obs_value" in c.lower() or "value" in c.lower()), None)
                sex_col  = next((c for c in df.columns if "sex" in c.lower()), None)

                if ref_col and time_col and val_col:
                    # Filter: total sex, target countries
                    if sex_col:
                        df = df[df[sex_col].isin(["SEX_T", "Total", "TOTAL"])].copy()
                    df = df[df[ref_col].isin(countries)].copy()
                    df["year"] = pd.to_numeric(df[time_col], errors="coerce").astype("Int64")
                    df["value"] = pd.to_numeric(df[val_col], errors="coerce")
                    df["iso3"] = df[ref_col]
                    result = df[["iso3","year","value"]].dropna(subset=["iso3","year"])
                    result = result.rename(columns={"value": col_name})
                    result = result[(result["year"] >= 1990) & (result["year"] <= 2024)]
                    if len(result) > 0:
                        return result
                break  # Got data but couldn't parse → try next url
            else:
                pass
        except Exception as e:
            print(f"    ILO url fail: {e}")
        time.sleep(0.5)

    # Approach 2: SDMX REST
    # https://www.ilo.org/sdmx/rest/data/ILO,DF_UNE_DEAP_SEX_AGE_RT_A/...
    sdmx_base = "https://www.ilo.org/sdmx/rest/data/ILO"
    # ref_area=TUR+BRA+IND+CHN+...
    ref_area = "+".join(countries[:10])  # start with subset
    sdmx_url = f"{sdmx_base},DF_{indic_code}/{ref_area}...A/?format=genericKeyValue&startPeriod=1990&endPeriod=2024"
    try:
        r2 = requests.get(sdmx_url, timeout=60, headers={"Accept": "application/json"})
        if r2.status_code == 200 and len(r2.content) > 500:
            print(f"    SDMX {indic_code}: {len(r2.content)} bytes")
            # Try JSON parse
            try:
                data = r2.json()
                rows = []
                # SDMX-JSON structure: data.dataSets[0].series
                ds = data.get("data", {}).get("dataSets", [{}])[0]
                series = ds.get("series", {})
                struct = data.get("data", {}).get("structure", {})
                dims = struct.get("dimensions", {}).get("series", [])
                obs_dims = struct.get("dimensions", {}).get("observation", [])

                ref_area_idx = next((i for i,d in enumerate(dims) if d.get("id","").lower()=="ref_area"), None)
                time_period_idx = 0  # observation dim

                for key_str, series_data in series.items():
                    parts = key_str.split(":")
                    if ref_area_idx is not None:
                        iso = dims[ref_area_idx]["values"][int(parts[ref_area_idx])].get("id","")
                    else:
                        continue
                    if iso not in countries:
                        continue
                    for obs_key, obs_val in series_data.get("observations",{}).items():
                        year_val = int(obs_dims[0]["values"][int(obs_key)]["id"])
                        val = obs_val[0] if obs_val else None
                        if 1990 <= year_val <= 2024:
                            rows.append({"iso3": iso, "year": year_val, col_name: val})

                if rows:
                    df_out = pd.DataFrame(rows)
                    df_out[col_name] = pd.to_numeric(df_out[col_name], errors="coerce")
                    return df_out
            except Exception as je:
                print(f"    SDMX JSON parse: {je}")
    except Exception as e2:
        print(f"    SDMX fail: {e2}")

    return pd.DataFrame()

print("\nFetching ILO indicators...")
ilo_dfs = []
for indic, col in ILO_INDICATORS.items():
    print(f"  {col}...", end=" ", flush=True)
    df = fetch_ilo_indicator(indic, col, ALL_ISO)
    if df.empty:
        print("EMPTY")
    else:
        ilo_dfs.append(df[["iso3","year",col]])
        print(f"{len(df)} obs ✓")
    time.sleep(0.5)

if ilo_dfs:
    ilo_merged = ilo_dfs[0]
    for d in ilo_dfs[1:]:
        ilo_merged = pd.merge(ilo_merged, d, on=["iso3","year"], how="outer")
    ilo_merged = ilo_merged.sort_values(["iso3","year"])
    ilo_merged.to_csv(ILO_OUT, index=False)
    ilo_cols = [c for c in ilo_merged.columns if c not in ["iso3","year"]]
    print(f"\n✅ ILO: {ilo_merged['iso3'].nunique()} countries × {ilo_merged['year'].nunique()} years × {len(ilo_cols)} indicators")
    print(f"Saved: {ILO_OUT}")
    append_to_panels(ilo_merged, ["iso3","year"], ilo_cols, "ILO")
else:
    print("❌ ILO data not available via API — see manual instructions below")


# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("SOURCE 3: USDA AgTFP")
print("="*60)

USDA_OUT = os.path.join(SOURCES_DIR, f"usda_agtfp_20260427.csv")

USDA_URLS = [
    # Wayback Machine (ERS pages often cached)
    "https://web.archive.org/web/2025/https://www.ers.usda.gov/webdocs/DataFiles/50048/AgTFPInternational2023_long.csv",
    "https://web.archive.org/web/2024/https://www.ers.usda.gov/webdocs/DataFiles/50048/AgTFPInternational2023_long.csv",
    # Direct ERS (various path formats)
    "https://www.ers.usda.gov/webdocs/DataFiles/50048/AgTFPInternational2023_long.csv",
    "https://apps.fas.usda.gov/psdonline/downloads/psd_alldata_csv.zip",  # not AgTFP but agricultural
    # ERS publications format
    "https://www.ers.usda.gov/media/d4hle0h3/agtfpinternational2023_long.csv",
    "https://www.ers.usda.gov/media/d4hle0h3/AgTFPInternational2023_long.csv",
]

USDA_ISO_NAME = {
    "COL": "Colombia", "IDN": "Indonesia", "VNM": "Vietnam",
    "EGY": "Egypt", "TUR": "Turkey", "ZAF": "South Africa",
    "BRA": "Brazil", "RUS": "Russia", "IND": "India",
    "CHN": "China", "MEX": "Mexico", "NGA": "Nigeria",
    "AUT": "Austria", "BEL": "Belgium", "BGR": "Bulgaria",
    "HRV": "Croatia", "CZE": "Czech Republic", "DNK": "Denmark",
    "EST": "Estonia", "FIN": "Finland", "FRA": "France",
    "DEU": "Germany", "GRC": "Greece", "HUN": "Hungary",
    "IRL": "Ireland", "ITA": "Italy", "LVA": "Latvia",
    "LTU": "Lithuania", "LUX": "Luxembourg", "NLD": "Netherlands",
    "POL": "Poland", "PRT": "Portugal", "ROU": "Romania",
    "SVK": "Slovak Republic", "SVN": "Slovenia", "ESP": "Spain",
    "SWE": "Sweden", "AZE": "Azerbaijan", "ARM": "Armenia",
    "BLR": "Belarus", "GEO": "Georgia", "KAZ": "Kazakhstan",
    "KGZ": "Kyrgyz Republic", "MDA": "Moldova", "TJK": "Tajikistan",
    "TKM": "Turkmenistan", "UKR": "Ukraine", "UZB": "Uzbekistan",
    "AUS": "Australia", "CAN": "Canada", "CHL": "Chile",
    "ISL": "Iceland", "ISR": "Israel", "JPN": "Japan",
    "KOR": "Korea", "NZL": "New Zealand", "NOR": "Norway",
    "CHE": "Switzerland", "GBR": "United Kingdom", "USA": "United States",
    "CYP": "Cyprus", "MLT": "Malta",
}
USDA_NAME_ISO = {v: k for k, v in USDA_ISO_NAME.items()}

usda_fetched = False
for url in USDA_URLS:
    try:
        print(f"  Trying: {url[:70]}")
        r = requests.get(url, timeout=60, allow_redirects=True,
                         headers={"User-Agent": "Mozilla/5.0"})
        ct = r.headers.get("Content-Type","")
        print(f"    Status: {r.status_code} | CT: {ct[:40]} | Size: {len(r.content)//1024}KB")

        if r.status_code == 200 and len(r.content) > 10000:
            if "text/csv" in ct or "text/plain" in ct or url.endswith(".csv"):
                from io import StringIO
                df_usda = pd.read_csv(StringIO(r.text))
                print(f"    Cols: {list(df_usda.columns[:6])}")

                # Expected cols: Country, Year, AgTFP (or similar)
                ctry_col = next((c for c in df_usda.columns if "country" in c.lower()), None)
                year_col = next((c for c in df_usda.columns if "year" in c.lower()), None)
                tfp_col  = next((c for c in df_usda.columns if "tfp" in c.lower() or "agtfp" in c.lower()), None)

                if ctry_col and year_col:
                    df_usda["iso3"] = df_usda[ctry_col].map(USDA_NAME_ISO)
                    df_usda = df_usda[df_usda["iso3"].isin(ALL_ISO)].copy()
                    df_usda["year"] = pd.to_numeric(df_usda[year_col], errors="coerce").astype("Int64")

                    if tfp_col:
                        df_usda["usda_agtfp"] = pd.to_numeric(df_usda[tfp_col], errors="coerce")
                        out = df_usda[["iso3","year","usda_agtfp"]].dropna(subset=["iso3","year"])
                        out.to_csv(USDA_OUT, index=False)
                        print(f"    ✅ USDA AgTFP: {out['iso3'].nunique()} countries × {out['year'].nunique()} years")
                        print(f"    Saved: {USDA_OUT}")
                        append_to_panels(out, ["iso3","year"], ["usda_agtfp"], "USDA AgTFP")
                        usda_fetched = True
                        break
            elif "application/zip" in ct or url.endswith(".zip"):
                z = zipfile.ZipFile(io.BytesIO(r.content))
                print(f"    ZIP contents: {z.namelist()[:5]}")
                tfp_files = [n for n in z.namelist() if "tfp" in n.lower() or "agtfp" in n.lower()]
                if tfp_files:
                    df_usda = pd.read_csv(z.open(tfp_files[0]))
                    print(f"    Found TFP file: {tfp_files[0]}, shape: {df_usda.shape}")
                else:
                    print(f"    No TFP files in ZIP")
    except Exception as e:
        print(f"    Error: {e}")
    time.sleep(1)

if not usda_fetched:
    print("\n⚠️  USDA AgTFP manual download required:")
    print("   1. Go to: https://www.ers.usda.gov/data-products/international-agricultural-productivity/")
    print("   2. Download: AgTFPInternational2023_long.csv (~17.4 MB)")
    print("   3. Place in: 400-Data/sources/")
    print("   4. Run: python3 400-Data/parse_usda_agtfp.py")


# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("SOURCE 4: ECI (Harvard Growth Lab)")
print("="*60)

ECI_URLS = [
    "https://intl-atlas-downloads.s3.amazonaws.com/country_hsproduct2digit_year.csv.zip",
    "https://atlas.cid.harvard.edu/api/data/country/?format=json",
    "https://atlas.cid.harvard.edu/api/data/rankings/eci/?format=json",
    "https://raw.githubusercontent.com/kklab-uth/economic-complexity/master/eci_country_year.csv",
]

ECI_OUT = os.path.join(SOURCES_DIR, f"eci_harvard_20260427.csv")
eci_fetched = False

for url in ECI_URLS:
    try:
        print(f"  Trying: {url[:70]}")
        r = requests.get(url, timeout=30, headers={"User-Agent": "Mozilla/5.0",
                                                     "Accept": "application/json,text/csv,*/*"})
        ct = r.headers.get("Content-Type","")
        print(f"    Status: {r.status_code} | CT: {ct[:40]} | Size: {len(r.content)//1024}KB")

        if r.status_code == 200 and len(r.content) > 1000:
            if "application/zip" in ct or url.endswith(".zip"):
                try:
                    z = zipfile.ZipFile(io.BytesIO(r.content))
                    csvs = [n for n in z.namelist() if n.endswith(".csv")]
                    print(f"    ZIP csvs: {csvs[:3]}")
                    if csvs:
                        df_eci = pd.read_csv(z.open(csvs[0]))
                        print(f"    Shape: {df_eci.shape}  Cols: {list(df_eci.columns[:6])}")
                        eci_fetched = True
                except Exception as ze:
                    print(f"    ZIP parse: {ze}")
            elif "application/json" in ct or url.endswith(".json"):
                try:
                    data = r.json()
                    if isinstance(data, list) and len(data) > 0:
                        df_eci = pd.DataFrame(data)
                        print(f"    JSON shape: {df_eci.shape}  Cols: {list(df_eci.columns[:6])}")
                        # Look for ECI column
                        eci_col = next((c for c in df_eci.columns if "eci" in c.lower()), None)
                        iso_col = next((c for c in df_eci.columns if "iso" in c.lower() or "country_id" in c.lower()), None)
                        yr_col  = next((c for c in df_eci.columns if "year" in c.lower()), None)
                        if eci_col and iso_col and yr_col:
                            out = df_eci[[iso_col, yr_col, eci_col]].rename(columns={
                                iso_col: "iso3", yr_col: "year", eci_col: "eci_harvard"
                            })
                            out = out[out["iso3"].isin(ALL_ISO)].copy()
                            out["year"] = pd.to_numeric(out["year"], errors="coerce").astype("Int64")
                            out["eci_harvard"] = pd.to_numeric(out["eci_harvard"], errors="coerce")
                            out.to_csv(ECI_OUT, index=False)
                            print(f"    ✅ ECI: {out['iso3'].nunique()} countries × {out['year'].nunique()} years")
                            append_to_panels(out, ["iso3","year"], ["eci_harvard"], "ECI")
                            eci_fetched = True
                            break
                except Exception as je:
                    print(f"    JSON parse: {je}")
            elif "text/csv" in ct or url.endswith(".csv"):
                from io import StringIO
                df_eci = pd.read_csv(StringIO(r.text))
                print(f"    CSV shape: {df_eci.shape}  Cols: {list(df_eci.columns[:6])}")
                eci_fetched = True
                break
    except Exception as e:
        print(f"    Error: {e}")
    time.sleep(0.5)

if not eci_fetched:
    print("\n⚠️  ECI manual download required:")
    print("   1. Go to: https://atlas.cid.harvard.edu/data-downloads")
    print("   2. Download: Country Rankings (CSV) — includes ECI by year")
    print("   3. Place in: 400-Data/sources/eci_raw.csv")
    print("   4. Run: python3 400-Data/parse_eci.py")


# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("FINAL PANEL REPORT")
print("="*60)

for grp_name in GROUPS:
    path = find_panel(grp_name)
    if path:
        df = pd.read_csv(path)
        n_non_meta = len([c for c in df.columns if c not in ["iso3","year","source"]])
        completeness = df.iloc[:,2:].notna().mean().mean() * 100
        print(f"  {grp_name:<12}: {df['iso3'].nunique()} ctr × {df['year'].nunique()} yr × {len(df.columns)} vars | "
              f"completeness: {completeness:.1f}%")

# Check sources dir
print(f"\nSources directory: {SOURCES_DIR}")
for f in sorted(os.listdir(SOURCES_DIR)):
    fpath = os.path.join(SOURCES_DIR, f)
    size = os.path.getsize(fpath) / 1024
    print(f"  {f:50s}  {size:8.1f} KB")
