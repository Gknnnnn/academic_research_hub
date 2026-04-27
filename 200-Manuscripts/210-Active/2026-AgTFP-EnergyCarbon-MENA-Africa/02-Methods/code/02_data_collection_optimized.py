#!/usr/bin/env python3
"""
02_data_collection_optimized.py
Optimized World Bank data collection with bulk requests.
"""

from pathlib import Path
import json
import requests
import pandas as pd
import numpy as np
from io import StringIO

BASE_DIR = Path.home() / "Library" / "CloudStorage" / "OneDrive-Kişisel" / "Akademik_Arastirma" / \
           "200-Manuscripts" / "210-Active" / "2026-AgTFP-EnergyCarbon-MENA-Africa"
DATA_DIR = BASE_DIR / "data"
OUTPUT_DIR = BASE_DIR / "output" / "tables"

DATA_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Countries
countries = ["NLD", "ISR", "DNK", "NZL", "AUS", "TUR", "EGY", "MAR", "TUN", "DZA",
             "SDN", "JOR", "IRN", "SAU", "PAK", "ETH", "KEN", "TZA", "UGA", "MOZ",
             "ZWE", "MLI", "NER", "TCD", "SEN", "NGA", "GHA", "ZMB", "MDG", "MWI"]

# Indicators
indicators = {
    "NY.GDP.PCAP.KD": "gdppc_const",
    "NY.GDP.PCAP.KD.ZG": "gdppc_growth",
    "NE.TRD.GNFS.ZS": "trade_openness",
    "EG.ELC.RNEW.ZS": "renewable_elec_share",
    "AG.LND.AGRI.ZS": "agri_land_share",
    "AG.LND.TRAC.ZS": "tractors_per_100sqkm",
    "SP.RUR.TOTL.ZS": "rural_pop_share",
    "SH.STA.MALN.ZS": "malnutrition",
}

country_groups = {
    "Frontier": ["NLD", "ISR", "DNK", "NZL", "AUS"],
    "MENA": ["TUR", "EGY", "MAR", "TUN", "DZA", "SDN", "JOR", "IRN", "SAU", "PAK"],
    "SSA": ["ETH", "KEN", "TZA", "UGA", "MOZ", "ZWE", "MLI", "NER", "TCD", "SEN", "NGA", "GHA", "ZMB", "MDG", "MWI"],
}

print("\n" + "="*80)
print("FETCHING WORLD BANK DATA - Bulk Request Mode")
print("="*80)

wb_data = []

# Bulk request all countries at once per indicator
for indicator_code, indicator_name in indicators.items():
    print(f"\nFetching {indicator_name} ({indicator_code})...")
    countries_str = ";".join(countries)
    url = f"https://api.worldbank.org/v2/country/{countries_str}/indicators/{indicator_code}?format=json&per_page=500&date=2000:2020"

    try:
        response = requests.get(url, timeout=15)
        response.raise_for_status()

        data = response.json()
        if data[1] is not None and len(data[1]) > 0:
            for record in data[1]:
                country = record.get("countryiso3code")
                year = record.get("date")
                value = record.get("value")

                if country and year and value:
                    try:
                        year_int = int(year)
                        value_float = float(value)
                        if 2000 <= year_int <= 2020 and country in countries:
                            wb_data.append({
                                "country_code": country,
                                "year": year_int,
                                "variable_name": indicator_name,
                                "value": value_float,
                            })
                    except (ValueError, TypeError):
                        pass
            print(f"  ✓ Retrieved {len([r for r in data[1] if r.get('countryiso3code')])} records")
        else:
            print(f"  ! No data returned")
    except Exception as e:
        print(f"  ✗ Error: {str(e)[:80]}")

print(f"\n\nTotal observations: {len(wb_data)}")

if len(wb_data) > 0:
    # Create DataFrames
    df_long = pd.DataFrame(wb_data)

    # Save long format
    output_long = DATA_DIR / "panel_wb_raw.csv"
    df_long.to_csv(output_long, index=False)
    print(f"\n✓ Saved: {output_long}")

    # Create wide format
    df_wide = df_long.pivot_table(
        index=["country_code", "year"],
        columns="variable_name",
        values="value",
        aggfunc="first"
    ).reset_index()

    output_wide = DATA_DIR / "panel_wb_wide.csv"
    df_wide.to_csv(output_wide, index=False)
    print(f"✓ Saved: {output_wide}")
    print(f"  Shape: {df_wide.shape}")

    # Coverage
    print("\n" + "="*80)
    print("DATA COVERAGE (%)")
    print("="*80 + "\n")

    coverage_data = []
    for group_name, group_countries in country_groups.items():
        print(f"{group_name}:")
        for var in indicators.values():
            mask = (df_long["variable_name"] == var) & (df_long["country_code"].isin(group_countries))
            n_obs = len(df_long[mask])
            max_obs = len(group_countries) * 21  # 21 years (2000-2020)
            coverage_pct = (n_obs / max_obs * 100) if max_obs > 0 else 0
            print(f"  {var:30s}: {coverage_pct:6.1f}% ({n_obs}/{max_obs})")
            coverage_data.append({
                "group": group_name,
                "variable": var,
                "n_obs": n_obs,
                "max_obs": max_obs,
                "coverage_pct": coverage_pct,
            })

    coverage_df = pd.DataFrame(coverage_data)
    output_coverage = OUTPUT_DIR / "coverage_table.csv"
    coverage_df.to_csv(output_coverage, index=False)
    print(f"\n✓ Saved: {output_coverage}")

    # Descriptive statistics
    print("\n" + "="*80)
    print("DESCRIPTIVE STATISTICS BY GROUP")
    print("="*80)

    descriptive_data = []
    for group_name, group_countries in country_groups.items():
        group_subset = df_wide[df_wide["country_code"].isin(group_countries)]
        numeric_cols = group_subset.select_dtypes(include=[np.number]).columns

        print(f"\n{group_name}:")
        for col in numeric_cols:
            values = group_subset[col].dropna()
            if len(values) > 0:
                print(f"  {col:30s}: mean={values.mean():8.2f}, sd={values.std():8.2f}, " +
                      f"n={len(values):3d}, range=[{values.min():.2f}, {values.max():.2f}]")
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
    output_descriptive = OUTPUT_DIR / "descriptive_stats.csv"
    descriptive_df.to_csv(output_descriptive, index=False)
    print(f"\n✓ Saved: {output_descriptive}")

    # Correlation
    numeric_cols = df_wide.select_dtypes(include=[np.number]).columns
    if len(numeric_cols) > 1:
        print(f"\n" + "="*80)
        print("CORRELATION MATRIX")
        print("="*80)
        corr_matrix = df_wide[numeric_cols].corr()
        output_corr = OUTPUT_DIR / "correlation_matrix.csv"
        corr_matrix.to_csv(output_corr)
        print(f"✓ Saved: {output_corr}")

# USDA AgTFP
print("\n" + "="*80)
print("USDA AgTFP DATA")
print("="*80)

output_usda = DATA_DIR / "USDA_AgTFP_raw.xlsx"
try:
    url = "https://www.ers.usda.gov/webdocs/DataFiles/50048/InternationalTFPData.xlsx"
    print("Downloading...")
    response = requests.get(url, timeout=20)
    response.raise_for_status()
    with open(output_usda, "wb") as f:
        f.write(response.content)
    print(f"✓ Saved: {output_usda}")
except Exception as e:
    print(f"✗ Failed: {str(e)[:100]}")

# FAOSTAT
print("\n" + "="*80)
print("FAOSTAT GHG DATA")
print("="*80)

faostat_codes = {
    "TUR": 223, "EGY": 59, "MAR": 149, "TUN": 220, "DZA": 4, "SDN": 206,
    "JOR": 116, "IRN": 100, "SAU": 201, "PAK": 169, "ETH": 68, "KEN": 124,
    "TZA": 218, "UGA": 238, "MOZ": 158, "ZWE": 281, "MLI": 147, "NER": 164,
    "TCD": 42, "SEN": 204, "NGA": 166, "GHA": 81, "ZMB": 279, "MDG": 137,
    "MWI": 141, "NLD": 157, "ISR": 108, "DNK": 57, "NZL": 165, "AUS": 12,
}

output_faostat = DATA_DIR / "FAOSTAT_GHG_raw.csv"
try:
    areas = ",".join(str(faostat_codes[c]) for c in countries if c in faostat_codes)
    url = f"http://fenixservices.fao.org/faostat/api/v1/en/data/GT?area={areas}&element=7231&item=6820&year=2000:2020&output_type=csv"
    print("Downloading...")
    response = requests.get(url, timeout=20)
    response.raise_for_status()
    with open(output_faostat, "w") as f:
        f.write(response.text)
    print(f"✓ Saved: {output_faostat}")
except Exception as e:
    print(f"✗ Failed: {str(e)[:100]}")

print("\n" + "="*80)
print("COMPLETE")
print("="*80)
