"""
ECI Parser — Harvard Growth Lab Economic Complexity Index
MGO Research Portfolio | Date: 2026-04-27

MANUAL STEP REQUIRED before running:
  1. Go to: https://atlas.cid.harvard.edu/data-downloads
  2. Download: "Country Rankings" CSV (contains ECI by country × year)
     OR: "Economic Complexity Rankings" — whichever is available
  3. Save to: 400-Data/sources/eci_raw.csv
  4. Run: python3 400-Data/parse_eci.py

Data: Hausmann, R., Hidalgo, C.A., et al. — The Atlas of Economic Complexity
Citation: Harvard Growth Lab (2024). The Atlas of Economic Complexity.
          atlas.cid.harvard.edu. Center for International Development,
          Harvard University. DOI: 10.7910/DVN/XTAQMC (Harvard Dataverse)

⚠️  ANAYASA: ECI values range approximately −3 to +3 (standardized).
    Cross-check any value before manuscript use.
    Notable: JPN ~2.3, DEU ~2.0, CHN ~0.8, TUR ~0.2 (recent years, approx)
"""

import pandas as pd, os, glob as glob_module

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCES_DIR = os.path.join(OUT_DIR, "sources")
RAW_PATH = os.path.join(SOURCES_DIR, "eci_raw.csv")
OUT_PATH = os.path.join(SOURCES_DIR, "eci_harvard_20260427.csv")

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

if not os.path.exists(RAW_PATH):
    print(f"❌ File not found: {RAW_PATH}")
    print("\nManual download required:")
    print("  https://atlas.cid.harvard.edu/data-downloads")
    print("  Look for 'Country Rankings' or 'ECI Rankings' CSV")
    print(f"  Save as: {RAW_PATH}")
    print("\nAlternative: Harvard Dataverse")
    print("  https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/XTAQMC")
    exit(1)

print(f"Reading: {RAW_PATH}")
df = pd.read_csv(RAW_PATH)
print(f"Shape: {df.shape}")
print(f"Columns: {list(df.columns)}")
print(f"Sample:\n{df.head(5)}")

# Auto-detect column names — Harvard Atlas uses different formats
# Format 1: country_id (ISO3), year, eci
# Format 2: Country, Year, ECI Rank, ECI
# Format 3: location_code, year, eci_rank, eci

iso_col = next((c for c in df.columns if any(x in c.lower() for x in
               ["iso3","iso_3","location_code","country_id","country_code","code"])), None)
if not iso_col:
    # May need country name → ISO3 mapping
    name_col = next((c for c in df.columns if "country" in c.lower()), None)
    iso_col = name_col

year_col = next((c for c in df.columns if "year" in c.lower()), None)
eci_col  = next((c for c in df.columns if c.lower() in ["eci","eci_value","economic_complexity_index"]
                 or ("eci" in c.lower() and "rank" not in c.lower())), None)

print(f"\nDetected: iso_col={iso_col}, year_col={year_col}, eci_col={eci_col}")

if not all([iso_col, year_col, eci_col]):
    print("❌ Could not auto-detect columns. Manual inspection needed.")
    print("Available columns:", list(df.columns))
    exit(1)

df["iso3"] = df[iso_col]
# If iso_col contains country names, map to ISO3
if df["iso3"].str.len().max() > 3:
    print("  iso3 column appears to be country names — applying name→ISO3 mapping")
    NAME_MAP = {
        "Colombia":"COL","Indonesia":"IDN","Vietnam":"VNM","Viet Nam":"VNM",
        "Egypt":"EGY","Turkey":"TUR","Türkiye":"TUR","South Africa":"ZAF",
        "Brazil":"BRA","Russia":"RUS","Russian Federation":"RUS",
        "India":"IND","China":"CHN","Mexico":"MEX","Nigeria":"NGA",
        "Austria":"AUT","Belgium":"BEL","Bulgaria":"BGR","Croatia":"HRV",
        "Cyprus":"CYP","Czechia":"CZE","Czech Republic":"CZE","Denmark":"DNK",
        "Estonia":"EST","Finland":"FIN","France":"FRA","Germany":"DEU",
        "Greece":"GRC","Hungary":"HUN","Ireland":"IRL","Italy":"ITA",
        "Latvia":"LVA","Lithuania":"LTU","Luxembourg":"LUX","Malta":"MLT",
        "Netherlands":"NLD","Poland":"POL","Portugal":"PRT","Romania":"ROU",
        "Slovakia":"SVK","Slovak Republic":"SVK","Slovenia":"SVN",
        "Spain":"ESP","Sweden":"SWE","Azerbaijan":"AZE","Armenia":"ARM",
        "Belarus":"BLR","Georgia":"GEO","Kazakhstan":"KAZ","Kyrgyzstan":"KGZ",
        "Moldova":"MDA","Republic of Moldova":"MDA","Tajikistan":"TJK",
        "Turkmenistan":"TKM","Ukraine":"UKR","Uzbekistan":"UZB",
        "Australia":"AUS","Canada":"CAN","Chile":"CHL","Iceland":"ISL",
        "Israel":"ISR","Japan":"JPN","South Korea":"KOR","Republic of Korea":"KOR",
        "New Zealand":"NZL","Norway":"NOR","Switzerland":"CHE",
        "United Kingdom":"GBR","United States":"USA",
    }
    df["iso3"] = df["iso3"].map(NAME_MAP)

df["year"] = pd.to_numeric(df[year_col], errors="coerce").astype("Int64")
df["eci_harvard"] = pd.to_numeric(df[eci_col], errors="coerce")

df = df[df["iso3"].isin(ALL_ISO)].copy()
df = df[(df["year"] >= 1990) & (df["year"] <= 2024)].copy()

result = df[["iso3","year","eci_harvard"]].dropna(subset=["iso3","year","eci_harvard"])
result = result.groupby(["iso3","year"])["eci_harvard"].mean().reset_index()
result = result.sort_values(["iso3","year"])

# Cross-check range
eci_min, eci_max = result["eci_harvard"].min(), result["eci_harvard"].max()
if not (-5 < eci_min < 5 and -5 < eci_max < 5):
    print(f"⚠️  ECI range unusual: {eci_min:.2f} to {eci_max:.2f}")
    print("    Expected roughly -3 to +3 for standardized ECI")
    print("    May be ranking (1-130) rather than index value — check column selection")

result.to_csv(OUT_PATH, index=False)
print(f"\n✅ ECI saved: {result['iso3'].nunique()} countries × {result['year'].nunique()} years")
print(f"   ECI range: {eci_min:.3f} — {eci_max:.3f}")
print(f"   Saved: {OUT_PATH}")

# Spot-check known values
spot = result[result["iso3"].isin(["JPN","DEU","CHN","TUR","NGA"])].groupby("iso3")["eci_harvard"].last()
print(f"\nSpot-check (most recent available year):")
print(spot)
print("  Expected approx: JPN~2.3, DEU~2.0, CHN~0.8, TUR~0.2, NGA~-1.5")

# Append to panels
print("\nAppending to group panels...")
def find_panel(grp):
    matches = sorted(glob_module.glob(os.path.join(OUT_DIR, f"panel_{grp.lower()}_*.csv")))
    return matches[-1] if matches else None

for grp_name, ctries in GROUPS.items():
    path = find_panel(grp_name)
    if not path: continue
    panel = pd.read_csv(path)
    if "eci_harvard" in panel.columns:
        panel = panel.drop(columns=["eci_harvard"])
    sub = result[result["iso3"].isin(ctries)][["iso3","year","eci_harvard"]].copy()
    merged = pd.merge(panel, sub, on=["iso3","year"], how="left")
    merged.to_csv(path, index=False)
    n = merged["eci_harvard"].notna().sum()
    print(f"  {grp_name}: {n}/{len(merged)} rows have ECI → {os.path.basename(path)}")

print("\n⚠️  Citation reminder:")
print("    Harvard Growth Lab (2024). The Atlas of Economic Complexity.")
print("    Center for International Development, Harvard University.")
print("    atlas.cid.harvard.edu")
