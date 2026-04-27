#!/usr/bin/env python3
"""
01_data_collection_fast.py - Optimized data collection with reduced timeout.
"""

import sys
sys.path.insert(0, '/usr/local/lib/python3.12/site-packages')

from pathlib import Path
import json
import requests
import pandas as pd
import numpy as np
from io import StringIO

# Configuration
BASE_DIR = Path.home() / "Library" / "CloudStorage" / "OneDrive-Kişisel" / "Akademik_Arastirma" / \
           "200-Manuscripts" / "210-Active" / "2026-AgTFP-EnergyCarbon-MENA-Africa"
DATA_DIR = BASE_DIR / "data"
OUTPUT_DIR = BASE_DIR / "output" / "tables"
CODE_DIR = BASE_DIR / "code"

# Create directories
for d in [DATA_DIR, OUTPUT_DIR, CODE_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# Country classifications
frontier = ["NLD", "ISR", "DNK", "NZL", "AUS"]
mena = ["TUR", "EGY", "MAR", "TUN", "DZA", "SDN", "JOR", "IRN", "SAU", "PAK"]
ssa = ["ETH", "KEN", "TZA", "UGA", "MOZ", "ZWE", "MLI", "NER", "TCD", "SEN", "NGA", "GHA", "ZMB", "MDG", "MWI"]

countries = frontier + mena + ssa
country_groups = {
    "Frontier": frontier,
    "MENA": mena,
    "SSA": ssa,
}

# World Bank indicators
wb_indicators = {
    "NY.GDP.PCAP.KD": "gdppc_const",
    "NY.GDP.PCAP.KD.ZG": "gdppc_growth",
    "NE.TRD.GNFS.ZS": "trade_openness",
    "EG.ELC.RNEW.ZS": "renewable_elec_share",
    "AG.LND.AGRI.ZS": "agri_land_share",
    "AG.LND.TRAC.ZS": "tractors_per_100sqkm",
    "SP.RUR.TOTL.ZS": "rural_pop_share",
    "SH.STA.MALN.ZS": "malnutrition",
}

years = list(range(2000, 2021))

print("\n" + "="*80)
print("WORLD BANK DATA COLLECTION (Fast Mode)")
print("="*80)

wb_data = []
errors_wb = []

# Use World Bank REST API
for country in countries:
    print(f"Downloading {country}...", end=" ", flush=True)
    for wb_code, var_name in wb_indicators.items():
        try:
            url = f"https://api.worldbank.org/v2/country/{country}/indicators/{wb_code}?format=json&per_page=100"
            response = requests.get(url, timeout=5)
            response.raise_for_status()

            data = response.json()
            if data[1] is not None:
                for record in data[1]:
                    year = record.get("date")
                    value = record.get("value")
                    if year and value:
                        try:
                            year_int = int(year)
                            value_float = float(value)
                            if 2000 <= year_int <= 2020:
                                wb_data.append({
                                    "country_code": country,
                                    "year": year_int,
                                    "variable_name": var_name,
                                    "value": value_float,
                                })
                        except (ValueError, TypeError):
                            pass
        except Exception as e:
            errors_wb.append(f"{country}/{wb_code}: {str(e)[:50]}")
    print("✓")

# Create DataFrames
df_long = pd.DataFrame(wb_data) if wb_data else pd.DataFrame(columns=["country_code", "year", "variable_name", "value"])
print(f"\nTotal observations: {len(df_long)}")

if len(df_long) > 0:
    df_wide = df_long.pivot_table(
        index=["country_code", "year"],
        columns="variable_name",
        values="value",
        aggfunc="first"
    ).reset_index()

    print(f"Wide format shape: {df_wide.shape}\n")

    # Coverage table
    print("DATA COVERAGE (%)")
    print("-" * 80)
    coverage_data = []
    for group_name, group_countries in country_groups.items():
        for var in wb_indicators.values():
            mask = (df_long["variable_name"] == var) & (df_long["country_code"].isin(group_countries))
            subset = df_long[mask]
            n_obs = len(subset)
            max_obs = len(group_countries) * len(years)
            coverage_pct = (n_obs / max_obs * 100) if max_obs > 0 else 0
            coverage_data.append({
                "group": group_name,
                "variable": var,
                "n_obs": n_obs,
                "max_obs": max_obs,
                "coverage_pct": coverage_pct,
            })

    coverage_df = pd.DataFrame(coverage_data)
    coverage_pivot = coverage_df.pivot_table(
        index="variable",
        columns="group",
        values="coverage_pct",
        aggfunc="first"
    )
    print(coverage_pivot.round(1))

    # Descriptive statistics
    print("\n" + "="*80)
    print("DESCRIPTIVE STATISTICS")
    print("="*80)

    descriptive_data = []
    for group_name, group_countries in country_groups.items():
        group_subset = df_wide[df_wide["country_code"].isin(group_countries)]
        numeric_cols = group_subset.select_dtypes(include=[np.number]).columns
        for col in numeric_cols:
            values = group_subset[col].dropna()
            if len(values) > 0:
                descriptive_data.append({
                    "group": group_name,
                    "variable": col,
                    "mean": values.mean(),
                    "sd": values.std(),
                    "min": values.min(),
                    "max": values.max(),
                    "n": len(values),
                })

    descriptive_df = pd.DataFrame(descriptive_data)
    for group in ["Frontier", "MENA", "SSA"]:
        group_stats = descriptive_df[descriptive_df["group"] == group]
        print(f"\n{group}:")
        print(group_stats[["variable", "mean", "sd", "min", "max", "n"]].round(3).to_string(index=False))

    # Save files
    output_long = DATA_DIR / "panel_wb_raw.csv"
    df_long.to_csv(output_long, index=False)

    output_wide = DATA_DIR / "panel_wb_wide.csv"
    df_wide.to_csv(output_wide, index=False)

    output_coverage = OUTPUT_DIR / "coverage_table.csv"
    coverage_df.to_csv(output_coverage, index=False)

    output_descriptive = OUTPUT_DIR / "descriptive_stats.csv"
    descriptive_df.to_csv(output_descriptive, index=False)

    # Correlation
    numeric_cols = df_wide.select_dtypes(include=[np.number]).columns
    if len(numeric_cols) > 1:
        corr_matrix = df_wide[numeric_cols].corr()
        output_corr = OUTPUT_DIR / "correlation_matrix.csv"
        corr_matrix.to_csv(output_corr)

    print("\n" + "="*80)
    print("FILES SAVED:")
    print("="*80)
    print(f"✓ {output_long}")
    print(f"✓ {output_wide}")
    print(f"✓ {output_coverage}")
    print(f"✓ {output_descriptive}")
    if len(numeric_cols) > 1:
        print(f"✓ {output_corr}")

# USDA AgTFP
print("\n" + "="*80)
print("USDA AgTFP DATA")
print("="*80)

output_usda = DATA_DIR / "USDA_AgTFP_raw.xlsx"
try:
    url = "https://www.ers.usda.gov/webdocs/DataFiles/50048/InternationalTFPData.xlsx"
    print("Downloading USDA AgTFP...")
    response = requests.get(url, timeout=15)
    response.raise_for_status()
    with open(output_usda, "wb") as f:
        f.write(response.content)
    print(f"✓ Saved: {output_usda}")
except Exception as e:
    print(f"✗ Failed: {str(e)[:100]}")

# FAOSTAT GHG
print("\n" + "="*80)
print("FAOSTAT GHG DATA")
print("="*80)

faostat_area_codes = {
    "TUR": 223, "EGY": 59, "MAR": 149, "TUN": 220, "DZA": 4, "SDN": 206,
    "JOR": 116, "IRN": 100, "SAU": 201, "PAK": 169, "ETH": 68, "KEN": 124,
    "TZA": 218, "UGA": 238, "MOZ": 158, "ZWE": 281, "MLI": 147, "NER": 164,
    "TCD": 42, "SEN": 204, "NGA": 166, "GHA": 81, "ZMB": 279, "MDG": 137,
    "MWI": 141, "NLD": 157, "ISR": 108, "DNK": 57, "NZL": 165, "AUS": 12,
}

output_faostat = DATA_DIR / "FAOSTAT_GHG_raw.csv"
try:
    area_codes = ",".join(str(faostat_area_codes[c]) for c in countries if c in faostat_area_codes)
    url = f"http://fenixservices.fao.org/faostat/api/v1/en/data/GT?area={area_codes}&element=7231&item=6820&year=2000:2020&output_type=csv"
    print("Downloading FAOSTAT GHG...")
    response = requests.get(url, timeout=15)
    response.raise_for_status()
    with open(output_faostat, "w") as f:
        f.write(response.text)
    print(f"✓ Saved: {output_faostat}")
except Exception as e:
    print(f"✗ Failed: {str(e)[:100]}")

print("\n" + "="*80)
print("COMPLETED")
print("="*80)
print(f"Output directory: {BASE_DIR}")
