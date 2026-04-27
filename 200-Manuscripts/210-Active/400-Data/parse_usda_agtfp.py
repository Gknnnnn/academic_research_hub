"""
USDA AgTFP Parser — MGO Research Portfolio
Date: 2026-04-27

MANUAL STEP REQUIRED before running:
  1. Go to: https://www.ers.usda.gov/data-products/international-agricultural-productivity/
  2. Download: AgTFPInternational2023_long.csv (~17.4 MB)
  3. Save to: 400-Data/sources/AgTFPInternational2023_long.csv
  4. Run: python3 400-Data/parse_usda_agtfp.py

Data: Fuglie (2023), USDA ERS — International Agricultural TFP
Citation: Fuglie, K., et al. (2023). International Agricultural Productivity.
          USDA Economic Research Service. ers.usda.gov/data-products/
          international-agricultural-productivity/
"""

import pandas as pd, os, glob

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCES_DIR = os.path.join(OUT_DIR, "sources")
RAW_PATH = os.path.join(SOURCES_DIR, "AgTFPInternational2023_long.csv")
OUT_PATH = os.path.join(SOURCES_DIR, "usda_agtfp_20260427.csv")

GROUPS = {
    "CIVETS":      ["COL","IDN","VNM","EGY","TUR","ZAF"],
    "BRICST_MINT": ["BRA","RUS","IND","CHN","ZAF","TUR","MEX","IDN","NGA"],
    "EU27":        ["AUT","BEL","BGR","HRV","CYP","CZE","DNK","EST","FIN","FRA","DEU",
                    "GRC","HUN","IRL","ITA","LVA","LTU","LUX","MLT","NLD","POL","PRT",
                    "ROU","SVK","SVN","ESP","SWE"],
    "EURASIAN":    ["AZE","ARM","BLR","GEO","KAZ","KGZ","MDA","RUS","TJK","TKM","UKR","UZB","TUR"],
    "OECD35":      ["AUS","AUT","BEL","CAN","CHL","CZE","DNK","EST","FIN","FRA","DEU",
                    "GRC","HUN","ISL","IRL","ISR","ITA","JPN","KOR","LVA","LTU","LUX",
                    "MEX","NLD","NZL","NOR","POL","PRT","SVK","SVN","ESP","SWE","CHE","TUR","GBR","USA"],
}
ALL_ISO = sorted(set(c for g in GROUPS.values() for c in g))

# USDA uses country names, not ISO3 — mapping
USDA_NAME_ISO = {
    "Colombia":"COL","Indonesia":"IDN","Vietnam":"VNM","Egypt":"EGY",
    "Turkey":"TUR","South Africa":"ZAF","Brazil":"BRA","Russia":"RUS",
    "India":"IND","China":"CHN","Mexico":"MEX","Nigeria":"NGA",
    "Austria":"AUT","Belgium":"BEL","Bulgaria":"BGR","Croatia":"HRV",
    "Cyprus":"CYP","Czech Republic":"CZE","Denmark":"DNK","Estonia":"EST",
    "Finland":"FIN","France":"FRA","Germany":"DEU","Greece":"GRC",
    "Hungary":"HUN","Ireland":"IRL","Italy":"ITA","Latvia":"LVA",
    "Lithuania":"LTU","Luxembourg":"LUX","Malta":"MLT","Netherlands":"NLD",
    "Poland":"POL","Portugal":"PRT","Romania":"ROU","Slovak Republic":"SVK",
    "Slovenia":"SVN","Spain":"ESP","Sweden":"SWE","Azerbaijan":"AZE",
    "Armenia":"ARM","Belarus":"BLR","Georgia":"GEO","Kazakhstan":"KAZ",
    "Kyrgyz Republic":"KGZ","Moldova":"MDA","Tajikistan":"TJK",
    "Turkmenistan":"TKM","Ukraine":"UKR","Uzbekistan":"UZB",
    "Australia":"AUS","Canada":"CAN","Chile":"CHL","Iceland":"ISL",
    "Israel":"ISR","Japan":"JPN","Korea":"KOR","New Zealand":"NZL",
    "Norway":"NOR","Switzerland":"CHE",
    "United Kingdom":"GBR","United States":"USA",
}

if not os.path.exists(RAW_PATH):
    print(f"❌ File not found: {RAW_PATH}")
    print("\nManual download required:")
    print("  https://www.ers.usda.gov/data-products/international-agricultural-productivity/")
    print(f"  Save as: {RAW_PATH}")
    exit(1)

print(f"Reading: {RAW_PATH}")
df = pd.read_csv(RAW_PATH)
print(f"Shape: {df.shape}")
print(f"Columns: {list(df.columns)}")
print(f"Sample:\n{df.head(3)}")

# Expected columns: Country, Year, TFP (or similar name)
# USDA long format: country name, year, variable name, value
ctry_col = next((c for c in df.columns if "country" in c.lower()), None)
year_col = next((c for c in df.columns if "year" in c.lower()), None)
var_col  = next((c for c in df.columns if "variable" in c.lower() or "indicator" in c.lower()), None)
val_col  = next((c for c in df.columns if "value" in c.lower() or "index" in c.lower() or "tfp" in c.lower()), None)

if not all([ctry_col, year_col, val_col]):
    print("❌ Could not identify required columns. Check column names above.")
    exit(1)

# Map country names to ISO3
df["iso3"] = df[ctry_col].map(USDA_NAME_ISO)
df["year"] = pd.to_numeric(df[year_col], errors="coerce").astype("Int64")
df["usda_agtfp"] = pd.to_numeric(df[val_col], errors="coerce")

# If long format with variable names, filter for TFP
if var_col:
    tfp_vals = df[var_col].unique()
    tfp_labels = [v for v in tfp_vals if "tfp" in str(v).lower() or "total factor" in str(v).lower()]
    print(f"Variable labels: {tfp_vals[:10]}")
    if tfp_labels:
        df = df[df[var_col].isin(tfp_labels)].copy()
        print(f"Filtered to TFP: {len(df)} rows")

df = df[df["iso3"].isin(ALL_ISO)].copy()
df = df[(df["year"] >= 1990) & (df["year"] <= 2024)].copy()
result = df[["iso3","year","usda_agtfp"]].dropna(subset=["iso3","year","usda_agtfp"])
result = result.groupby(["iso3","year"])["usda_agtfp"].mean().reset_index()
result = result.sort_values(["iso3","year"])

result.to_csv(OUT_PATH, index=False)
print(f"\n✅ USDA AgTFP saved: {result['iso3'].nunique()} countries × {result['year'].nunique()} years")
print(f"   Range: {result['usda_agtfp'].min():.3f} — {result['usda_agtfp'].max():.3f}")
print(f"   Saved: {OUT_PATH}")

# Append to panels
print("\nAppending to group panels...")
import glob as glob_module

def find_panel(grp):
    matches = sorted(glob_module.glob(os.path.join(OUT_DIR, f"panel_{grp.lower()}_*.csv")))
    return matches[-1] if matches else None

for grp_name, ctries in GROUPS.items():
    path = find_panel(grp_name)
    if not path: continue
    panel = pd.read_csv(path)
    if "usda_agtfp" in panel.columns:
        panel = panel.drop(columns=["usda_agtfp"])
    sub = result[result["iso3"].isin(ctries)][["iso3","year","usda_agtfp"]].copy()
    merged = pd.merge(panel, sub, on=["iso3","year"], how="left")
    merged.to_csv(path, index=False)
    n = merged["usda_agtfp"].notna().sum()
    print(f"  {grp_name}: {n}/{len(merged)} rows have AgTFP → {os.path.basename(path)}")

print("\n⚠️  CROSS-CHECK: AgTFP is an index (base year varies by version).")
print("    Fuglie et al. (2023): index 2015=1.0 approximately.")
print("    Citation: Fuglie, K., et al. (2023). International Agricultural Productivity.")
print("    USDA ERS. ers.usda.gov/data-products/international-agricultural-productivity/")
