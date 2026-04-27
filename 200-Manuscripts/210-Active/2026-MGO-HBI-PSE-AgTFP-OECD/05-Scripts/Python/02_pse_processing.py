"""
02_pse_processing.py
Process manually downloaded OECD PSE CSV → merge into panel_master.csv

DOWNLOAD INSTRUCTIONS (do once):
  1. Go to: https://stats.oecd.org/Index.aspx?DataSetCode=MON2023
  2. Left panel → Select ALL OECD countries
  3. Indicators: check all of:
       - Total PSE (USD million)      → PSECT
       - Market Price Support (USD)   → PSET01
       - % PSE                        → PSECT_P
       - General Services Support (USD) → GSSE
       - Budgetary payments (USD)     → PSENA  [optional]
  4. Time: 1986 → 2023
  5. Top menu: Export → Text File (CSV)
  6. Save as: 06-Data/raw/OECD_PSE_raw.csv
  7. Run this script.
"""

import pandas as pd
import numpy as np
import os

BASE  = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW   = os.path.join(BASE, "06-Data", "raw")
CLEAN = os.path.join(BASE, "06-Data", "clean")

PSE_FILE   = os.path.join(RAW, "OECD_PSE_raw.csv")
PANEL_FILE = os.path.join(CLEAN, "panel_master.csv")

YEAR_START, YEAR_END = 1990, 2020

# Map OECD country names → ISO3 (as used in panel_master)
OECD_NAME_TO_ISO3 = {
    "Australia": "AUS", "Austria": "AUT", "Belgium": "BEL",
    "Canada": "CAN", "Chile": "CHL", "Colombia": "COL",
    "Costa Rica": "CRI", "Czech Republic": "CZE", "Czechia": "CZE",
    "Denmark": "DNK", "Estonia": "EST", "Finland": "FIN",
    "France": "FRA", "Germany": "DEU", "Greece": "GRC",
    "Hungary": "HUN", "Iceland": "ISL", "Ireland": "IRL",
    "Israel": "ISR", "Italy": "ITA", "Japan": "JPN",
    "Korea": "KOR", "Latvia": "LVA", "Lithuania": "LTU",
    "Luxembourg": "LUX", "Mexico": "MEX", "Netherlands": "NLD",
    "New Zealand": "NZL", "Norway": "NOR", "Poland": "POL",
    "Portugal": "PRT", "Slovak Republic": "SVK", "Slovakia": "SVK",
    "Slovenia": "SVN", "Spain": "ESP", "Sweden": "SWE",
    "Switzerland": "CHE", "Turkey": "TUR", "Türkiye": "TUR",
    "United Kingdom": "GBR", "United States": "USA",
    "European Union": "EU28", "OECD": "OECD",
}

# Map indicator labels that may appear in the OECD CSV
INDICATOR_MAP = {
    # Column name variants → our variable name
    "Total PSE (USD million)":           "pse_total_usd",
    "Producer Support Estimate (USD)":   "pse_total_usd",
    "PSECT":                             "pse_total_usd",
    "Market Price Support (USD million)":"mps_usd",
    "Market Price Support (USD)":        "mps_usd",
    "PSET01":                            "mps_usd",
    "% PSE":                             "pse_pct",
    "Percentage PSE":                    "pse_pct",
    "PSECT_P":                           "pse_pct",
    "General Services Support Estimate (USD million)": "gsse_usd",
    "General Services Support Estimate (USD)":         "gsse_usd",
    "GSSE":                              "gsse_usd",
    "Budgetary payments (USD million)":  "bda_usd",
    "PSENA":                             "bda_usd",
}


def process_pse():
    if not os.path.exists(PSE_FILE):
        print(f"ERROR: PSE file not found at {PSE_FILE}")
        print("Please download from OECD.Stat per instructions in script header.")
        return

    print(f"Reading: {PSE_FILE}")
    # OECD CSV exports typically have this structure:
    # Country | Indicator | 1990 | 1991 | ... | 2023
    # OR long format: Country | Indicator | Year | Value
    df_raw = pd.read_csv(PSE_FILE, encoding="utf-8-sig", low_memory=False)
    print(f"Raw shape: {df_raw.shape}")
    print(f"Columns: {df_raw.columns.tolist()[:10]}")
    print(f"First row: {df_raw.iloc[0].tolist()[:6]}")

    # Detect format: wide vs long
    year_cols = [c for c in df_raw.columns if str(c).strip().isdigit() and
                 1986 <= int(str(c).strip()) <= 2023]

    if year_cols:
        print("Detected: WIDE format")
        # Identify country and indicator columns
        country_col = next((c for c in df_raw.columns if any(
            x in c.upper() for x in ["COUNTRY", "LOCATION", "COU"])), df_raw.columns[0])
        indicator_col = next((c for c in df_raw.columns if any(
            x in c.upper() for x in ["INDICATOR", "VARIABLE", "MEASURE"])), df_raw.columns[1])

        df_long = df_raw.melt(
            id_vars=[country_col, indicator_col],
            value_vars=year_cols,
            var_name="year",
            value_name="value"
        ).rename(columns={country_col: "country_raw", indicator_col: "indicator_raw"})

    else:
        print("Detected: LONG format")
        country_col   = next(c for c in df_raw.columns if any(x in c.upper() for x in ["COUNTRY","LOCATION"]))
        indicator_col = next(c for c in df_raw.columns if any(x in c.upper() for x in ["INDICATOR","VARIABLE","MEASURE"]))
        year_col      = next(c for c in df_raw.columns if any(x in c.upper() for x in ["YEAR","TIME","PERIOD"]))
        value_col     = next(c for c in df_raw.columns if any(x in c.upper() for x in ["VALUE","OBS"]))
        df_long = df_raw[[country_col, indicator_col, year_col, value_col]].rename(columns={
            country_col:   "country_raw",
            indicator_col: "indicator_raw",
            year_col:      "year",
            value_col:     "value",
        })

    df_long["year"] = pd.to_numeric(df_long["year"], errors="coerce")
    df_long["value"] = pd.to_numeric(df_long["value"], errors="coerce")
    df_long = df_long.dropna(subset=["year"])
    df_long["year"] = df_long["year"].astype(int)
    df_long = df_long[df_long["year"].between(YEAR_START, YEAR_END)]

    # Map indicators
    df_long["var_name"] = df_long["indicator_raw"].map(INDICATOR_MAP)
    unmapped = df_long[df_long["var_name"].isna()]["indicator_raw"].unique()
    if len(unmapped) > 0:
        print(f"Unmapped indicators (will be dropped): {unmapped[:10]}")
    df_long = df_long.dropna(subset=["var_name"])

    # Map countries → ISO3
    df_long["iso3"] = df_long["country_raw"].map(OECD_NAME_TO_ISO3)
    unmapped_cou = df_long[df_long["iso3"].isna()]["country_raw"].unique()
    if len(unmapped_cou) > 0:
        print(f"Unmapped countries (will be dropped): {unmapped_cou[:10]}")
    df_long = df_long.dropna(subset=["iso3"])
    df_long = df_long[~df_long["iso3"].isin(["EU28", "OECD"])]  # Drop aggregates

    # Pivot to wide
    df_pse = df_long.pivot_table(
        index=["iso3", "year"], columns="var_name", values="value", aggfunc="first"
    ).reset_index()
    df_pse.columns.name = None

    # Compute composition shares
    if "pse_total_usd" in df_pse.columns and "mps_usd" in df_pse.columns:
        df_pse["mps_share"] = np.where(
            df_pse["pse_total_usd"].abs() > 0.001,
            df_pse["mps_usd"] / df_pse["pse_total_usd"],
            np.nan
        )
        df_pse["mps_share"] = df_pse["mps_share"].clip(-2, 2)  # Winsorize extremes

    if "pse_total_usd" in df_pse.columns and "gsse_usd" in df_pse.columns:
        total_support = df_pse["pse_total_usd"] + df_pse["gsse_usd"]
        df_pse["gsse_share"] = np.where(
            total_support.abs() > 0.001,
            df_pse["gsse_usd"] / total_support,
            np.nan
        )

    print(f"\nPSE panel: {df_pse['iso3'].nunique()} countries × {df_pse['year'].nunique()} years")
    print(f"Variables: {[c for c in df_pse.columns if c not in ['iso3','year']]}")
    print(f"Missing %PSE: {df_pse['pse_pct'].isna().sum() if 'pse_pct' in df_pse.columns else 'N/A'}")

    # Save PSE clean
    pse_out = os.path.join(CLEAN, "PSE_OECD_clean.csv")
    df_pse.to_csv(pse_out, index=False)
    print(f"Saved → {pse_out}")

    # Merge into panel_master
    if os.path.exists(PANEL_FILE):
        df_panel = pd.read_csv(PANEL_FILE)
        # Drop old PSE cols if they exist
        pse_cols = [c for c in df_panel.columns if c in
                    ["pse_total_usd","mps_usd","gsse_usd","bda_usd","pse_pct","mps_share","gsse_share"]]
        df_panel = df_panel.drop(columns=pse_cols, errors="ignore")
        df_panel = df_panel.merge(df_pse, on=["iso3","year"], how="left")
        df_panel.to_csv(PANEL_FILE, index=False)
        print(f"panel_master.csv updated → {PANEL_FILE}")
        print(f"Final shape: {df_panel.shape}")

        # Balance report
        for v in ["pse_pct","mps_share","gsse_share"]:
            if v in df_panel.columns:
                miss = df_panel[v].isna().sum()
                pct  = 100*miss/len(df_panel)
                print(f"  {v}: {miss} missing ({pct:.1f}%)")
    else:
        print("panel_master.csv not found. Run 01_data_assembly.py first.")


if __name__ == "__main__":
    process_pse()
