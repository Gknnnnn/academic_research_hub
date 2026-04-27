#!/usr/bin/env python3
"""
build_oxford_gairi_panel.py — Oxford GAIRI 2019-2025 panel builder.

Input  : 400-Data/*Government-AI-Readiness*.xlsx + *GAIRI*.xlsx + *SHARED*Index*.xlsx
Output : 03-Data/ai_indices/oxford_gairi_panel.csv  (iso3, year, ai_readiness, ai_rank)
"""
from __future__ import annotations
import re
import numpy as np
import pandas as pd
from pathlib import Path

DATA_DIR = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/"
                "Akademik_Arastirma/400-Data")
OUT_DIR  = Path(__file__).resolve().parents[1] / "03-Data" / "ai_indices"
OUT_DIR.mkdir(parents=True, exist_ok=True)
OUT_CSV  = OUT_DIR / "oxford_gairi_panel.csv"

# ─── Country name → ISO3 mapping (Oxford uses full names) ───────────────────
NAME_TO_ISO3 = {
    "United States of America": "USA", "United States": "USA",
    "United Kingdom": "GBR", "Singapore": "SGP", "Finland": "FIN",
    "Germany": "DEU", "France": "FRA", "Sweden": "SWE",
    "Netherlands": "NLD", "Canada": "CAN", "Denmark": "DNK",
    "Australia": "AUS", "Japan": "JPN", "South Korea": "KOR",
    "Republic of Korea": "KOR", "Korea": "KOR",
    "Norway": "NOR", "Estonia": "EST", "New Zealand": "NZL",
    "Switzerland": "CHE", "Austria": "AUT", "Belgium": "BEL",
    "Spain": "ESP", "Ireland": "IRL", "Luxembourg": "LUX",
    "Portugal": "PRT", "Israel": "ISR", "Italy": "ITA",
    "Poland": "POL", "Czech Republic": "CZE", "Czechia": "CZE",
    "Hungary": "HUN", "Slovakia": "SVK", "Slovenia": "SVN",
    "Greece": "GRC", "Croatia": "HRV", "Romania": "ROU",
    "Bulgaria": "BGR", "Latvia": "LVA", "Lithuania": "LTU",
    "Cyprus": "CYP", "Malta": "MLT",
    "China": "CHN", "India": "IND", "Brazil": "BRA",
    "Russia": "RUS", "Russian Federation": "RUS",
    "South Africa": "ZAF", "Mexico": "MEX", "Indonesia": "IDN",
    "Turkey": "TUR", "Türkiye": "TUR", "Argentina": "ARG",
    "Saudi Arabia": "SAU", "United Arab Emirates": "ARE",
    "Nigeria": "NGA", "Kenya": "KEN", "Egypt": "EGY",
    "Morocco": "MAR", "Ethiopia": "ETH", "Ghana": "GHA",
    "Malaysia": "MYS", "Thailand": "THA", "Vietnam": "VNM",
    "Philippines": "PHL", "Pakistan": "PAK", "Bangladesh": "BGD",
    "Sri Lanka": "LKA", "Myanmar": "MMR", "Cambodia": "KHM",
    "Uzbekistan": "UZB", "Kazakhstan": "KAZ", "Georgia": "GEO",
    "Armenia": "ARM", "Azerbaijan": "AZE", "Ukraine": "UKR",
    "Belarus": "BLR", "Moldova": "MDA", "Serbia": "SRB",
    "Bosnia and Herzegovina": "BIH", "Bosnia & Herzegovina": "BIH",
    "North Macedonia": "MKD", "Albania": "ALB", "Montenegro": "MNE",
    "Kosovo": "XKX", "Iceland": "ISL", "Liechtenstein": "LIE",
    "Iceland ": "ISL",
    "Chile": "CHL", "Colombia": "COL", "Peru": "PER",
    "Venezuela": "VEN", "Bolivia": "BOL", "Ecuador": "ECU",
    "Paraguay": "PRY", "Uruguay": "URY", "Cuba": "CUB",
    "Dominican Republic": "DOM", "Guatemala": "GTM", "Honduras": "HND",
    "El Salvador": "SLV", "Nicaragua": "NIC", "Costa Rica": "CRI",
    "Panama": "PAN", "Trinidad and Tobago": "TTO", "Jamaica": "JAM",
    "Barbados": "BRB", "Bahamas": "BHS", "Belize": "BLZ",
    "Guyana": "GUY", "Suriname": "SUR",
    "Taiwan": "TWN", "Hong Kong": "HKG", "Macao": "MAC",
    "Brunei Darussalam": "BRN", "Brunei": "BRN", "Laos": "LAO",
    "Timor-Leste": "TLS",
    "Afghanistan": "AFG", "Iran": "IRN", "Iraq": "IRQ",
    "Syria": "SYR", "Lebanon": "LBN", "Jordan": "JOR",
    "Kuwait": "KWT", "Qatar": "QAT", "Bahrain": "BHR",
    "Oman": "OMN", "Yemen": "YEM",
    "Sudan": "SDN", "South Sudan": "SSD", "Libya": "LBY",
    "Tunisia": "TUN", "Algeria": "DZA", "Mauritius": "MUS",
    "Senegal": "SEN", "Ivory Coast": "CIV", "Côte d'Ivoire": "CIV",
    "Cameroon": "CMR", "Tanzania": "TZA", "Uganda": "UGA",
    "Zimbabwe": "ZWE", "Zambia": "ZMB", "Mozambique": "MOZ",
    "Madagascar": "MDG", "Angola": "AGO", "Botswana": "BWA",
    "Namibia": "NAM", "Rwanda": "RWA", "Malawi": "MWI",
    "Benin": "BEN", "Burkina Faso": "BFA", "Chad": "TCD",
    "Togo": "TGO", "Niger": "NER", "Mali": "MLI",
    "Guinea": "GIN", "Sierra Leone": "SLE", "Liberia": "LBR",
    "Democratic Republic of the Congo": "COD", "Congo": "COG",
    "Republic of the Congo": "COG",
    "New Zealand ": "NZL",
    "Fiji": "FJI", "Papua New Guinea": "PNG",
    "Kyrgyzstan": "KGZ", "Tajikistan": "TJK", "Turkmenistan": "TKM",
    "Mongolia": "MNG",
    "Nepal": "NPL", "Bhutan": "BTN", "Maldives": "MDV",
    "Trinidad & Tobago": "TTO",
    "Eswatini": "SWZ", "Swaziland": "SWZ", "Lesotho": "LSO",
    "Cabo Verde": "CPV", "Cape Verde": "CPV",
    "São Tomé and Príncipe": "STP", "Seychelles": "SYC",
    "Comoros": "COM", "Djibouti": "DJI", "Eritrea": "ERI",
    "Somalia": "SOM", "Gabon": "GAB", "Equatorial Guinea": "GNQ",
    "Central African Republic": "CAF",
    "Gambia": "GMB", "Guinea-Bissau": "GNB",
    "Mauritania": "MRT", "Western Sahara": "ESH",
    "North Korea": "PRK", "East Timor": "TLS",
    "Palestine": "PSE", "State of Palestine": "PSE",
    "Bahamas, The": "BHS", "Gambia, The": "GMB",
}


def name_to_iso3(name: str) -> str | None:
    if pd.isna(name):
        return None
    name = str(name).strip()
    iso = NAME_TO_ISO3.get(name)
    if iso:
        return iso
    # Fuzzy: try stripping trailing spaces, common variants
    iso = NAME_TO_ISO3.get(name.rstrip())
    return iso


def parse_2019(path: Path) -> pd.DataFrame:
    """2019 file: regional tables side-by-side; 'Rankings' sheet."""
    xl  = pd.ExcelFile(path)
    df  = pd.read_excel(path, sheet_name="Rankings", header=None)
    # Row 0: headers for 8 regional tables (Rank, Country, Score repeated)
    # Skip row 0, use row 1 as header, then regional blocks at columns 0,4,8,...
    df  = pd.read_excel(path, sheet_name="Rankings", header=1)
    rows = []
    # Each regional block: Rank(of194...) | Country | Score | NaN   (4 wide, 8 blocks)
    n_blocks = df.shape[1] // 4
    for b in range(n_blocks):
        base = b * 4
        sub  = df.iloc[:, base:base+3].copy()
        sub.columns = ["rank","country","score"]
        sub = sub.dropna(subset=["country","score"])
        sub = sub[pd.to_numeric(sub["score"], errors="coerce").notna()]
        rows.append(sub[["country","score"]])
    out = pd.concat(rows).drop_duplicates(subset="country")
    out["year"] = 2019
    out["ai_readiness"] = pd.to_numeric(out["score"], errors="coerce")
    return out[["country","year","ai_readiness"]]


def parse_standard(path: Path, year: int) -> pd.DataFrame:
    """2020-2024: 'Global ranking(s)' sheet has Rank, Country, Score/Total."""
    xl = pd.ExcelFile(path)
    sheet = [s for s in xl.sheet_names
             if "ranking" in s.lower() or "global" in s.lower()][0]
    df = pd.read_excel(path, sheet_name=sheet)
    df.columns = [str(c).strip().lower() for c in df.columns]
    # Find country and score columns
    country_col = next((c for c in df.columns if "country" in c), None)
    score_col   = next((c for c in df.columns
                        if any(k in c for k in ["total","score"]) and "country" not in c), None)
    if country_col is None or score_col is None:
        print(f"  [WARN] {path.name}: cannot find country/score cols → {df.columns.tolist()[:8]}")
        return pd.DataFrame()
    out = df[[country_col, score_col]].copy()
    out.columns = ["country", "ai_readiness"]
    out["year"] = year
    out["ai_readiness"] = pd.to_numeric(out["ai_readiness"], errors="coerce")
    return out.dropna(subset=["country","ai_readiness"])


def parse_2025(path: Path) -> pd.DataFrame:
    """2025 file: row 0 is blank header; row 1 has real headers."""
    xl = pd.ExcelFile(path)
    sheet = xl.sheet_names[0]
    df = pd.read_excel(path, sheet_name=sheet, header=1)
    df.columns = [str(c).strip().lower() for c in df.columns]
    country_col = next((c for c in df.columns if "country" in c), None)
    score_col   = next((c for c in df.columns
                        if any(k in c for k in ["total","score"]) and "country" not in c), None)
    if country_col is None or score_col is None:
        # Try unnamed columns
        df = pd.read_excel(path, sheet_name=sheet, header=None)
        # Row 0 is blank, row 1 has Ranking, Country, Total Score
        df.columns = df.iloc[1]
        df = df.iloc[2:].reset_index(drop=True)
        df.columns = [str(c).strip().lower() for c in df.columns]
        country_col = next((c for c in df.columns if "country" in c), None)
        score_col   = next((c for c in df.columns
                            if "total" in c or "score" in c), None)
    out = df[[country_col, score_col]].copy()
    out.columns = ["country", "ai_readiness"]
    out["year"] = 2025
    out["ai_readiness"] = pd.to_numeric(out["ai_readiness"], errors="coerce")
    return out.dropna(subset=["country","ai_readiness"])


# ─────────────────────────────────────────────────────────────────────────────

def main():
    file_map = {
        2019: DATA_DIR / "SHARED_-2019-Index-data-for-report.xlsx",
        2020: DATA_DIR / "2020-Government-AI-Readiness-Index-public-dataset.xlsx",
        2021: DATA_DIR / "2021-Government-AI-Readiness-Index-public-dataset.xlsx",
        2022: DATA_DIR / "2022-Government-AI-Readiness-Index-public-data.xlsx",
        2023: DATA_DIR / "2023-Government-AI-Readiness-Index-Public-Indicator-Data.xlsx",
        2024: DATA_DIR / "2024-GAIRI-data.xlsx",
        2025: DATA_DIR / "2025-Government-AI-Readiness-Index-data-1.xlsx",
    }

    frames = []
    for year, path in file_map.items():
        if not path.exists():
            print(f"[MISS] {year}: {path.name}")
            continue
        try:
            if year == 2019:
                df = parse_2019(path)
            elif year == 2025:
                df = parse_2025(path)
            else:
                df = parse_standard(path, year)
            print(f"  [{year}] {len(df)} countries parsed")
            frames.append(df)
        except Exception as e:
            print(f"  [ERR] {year}: {e}")

    if not frames:
        print("[ERROR] No data parsed.")
        return

    panel = pd.concat(frames, ignore_index=True)

    # Map country names to ISO3
    panel["iso3"] = panel["country"].apply(name_to_iso3)
    unmapped = panel[panel["iso3"].isna()]["country"].unique()
    if len(unmapped) > 0:
        print(f"\n[WARN] {len(unmapped)} unmapped country names (sample):")
        for u in unmapped[:10]:
            print(f"  '{u}'")

    panel = panel.dropna(subset=["iso3"])

    # Normalise score to 0-100 range (2019 uses 0-10 scale → rescale)
    for yr in panel["year"].unique():
        mx = panel.loc[panel["year"]==yr, "ai_readiness"].max()
        if mx <= 15:  # 2019 is on 0-10 scale
            panel.loc[panel["year"]==yr, "ai_readiness"] *= 10
            print(f"  [{yr}] score rescaled ×10 (was 0-{mx:.1f})")

    panel = panel[["iso3","year","ai_readiness"]].sort_values(["iso3","year"]).reset_index(drop=True)

    # Pivot for summary
    print(f"\n[GAIRI] Total: {len(panel)} obs, {panel['iso3'].nunique()} countries, "
          f"years {panel['year'].min()}-{panel['year'].max()}")
    print(panel.groupby("year").size().rename("N_countries"))

    panel.to_csv(OUT_CSV, index=False)
    print(f"\nSaved: {OUT_CSV}")

    # Also copy to ai_indices dir for pipeline
    return panel


if __name__ == "__main__":
    main()
