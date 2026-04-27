#!/usr/bin/env python3
"""
01_data_collection.py
Data collection script for 2026-AgTFP-EnergyCarbon-MENA-Africa project.
Downloads World Bank, USDA AgTFP, and FAOSTAT data for 30 countries (N=30).
"""

import subprocess
import sys
import os
from pathlib import Path

# Install required packages using /usr/bin/python3 directly
print("Installing required packages...")
packages = ["wbgapi", "pandas", "numpy", "matplotlib", "seaborn", "openpyxl", "requests"]

for pkg in packages:
    try:
        __import__(pkg.replace("-", "_"))
        print(f"  {pkg} already installed")
    except ImportError:
        print(f"  Installing {pkg}...")
        try:
            subprocess.check_call(
                ["/usr/bin/python3", "-m", "pip", "install", "-q", pkg],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            print(f"    ✓ {pkg} installed")
        except Exception as e:
            print(f"    ! Warning: could not install {pkg}: {e}")

import pandas as pd
import numpy as np
import requests
from io import StringIO

# Try to import wbgapi
try:
    import wbgapi as wb
except ImportError:
    print("Warning: wbgapi not available, will use World Bank API directly")
    wb = None

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
print("WORLD BANK DATA COLLECTION")
print("="*80)

# Download World Bank data
wb_data = []
errors_wb = []

if wb is None:
    print("Using World Bank REST API (wbgapi not available)")
    # Fallback: use REST API directly
    import json

    for country in countries:
        print(f"Downloading data for {country}...", end=" ", flush=True)
        for wb_code, var_name in wb_indicators.items():
            try:
                # World Bank REST API format
                url = f"https://api.worldbank.org/v2/country/{country}/indicators/{wb_code}?format=json&per_page=100"
                response = requests.get(url, timeout=10)
                response.raise_for_status()

                data = response.json()
                if data[1] is not None:  # data[0] is metadata, data[1] is actual data
                    for record in data[1]:
                        year = record.get("date")
                        value = record.get("value")
                        if year and value:
                            try:
                                year_int = int(year)
                                value_float = float(value)
                                if 2000 <= year_int <= 2020 and pd.notna(value_float):
                                    wb_data.append({
                                        "country_code": country,
                                        "year": year_int,
                                        "variable_name": var_name,
                                        "value": value_float,
                                    })
                            except (ValueError, TypeError):
                                pass
            except Exception as e:
                errors_wb.append(f"{country}/{wb_code}: {str(e)}")
        print("✓")
else:
    # Use wbgapi if available
    for country in countries:
        print(f"Downloading data for {country}...", end=" ", flush=True)
        for wb_code, var_name in wb_indicators.items():
            try:
                data = wb.data.get(wb_code, country, time=years)
                if data is not None:
                    for year, value in data.items():
                        if pd.notna(value):
                            wb_data.append({
                                "country_code": country,
                                "year": int(year),
                                "variable_name": var_name,
                                "value": float(value),
                            })
            except Exception as e:
                errors_wb.append(f"{country}/{wb_code}: {str(e)}")
        print("✓")

# Create long-format DataFrame
df_long = pd.DataFrame(wb_data) if wb_data else pd.DataFrame(columns=["country_code", "year", "variable_name", "value"])
print(f"\nTotal observations collected: {len(df_long)}")

if len(df_long) > 0:
    # Create wide-format DataFrame
    df_wide = df_long.pivot_table(
        index=["country_code", "year"],
        columns="variable_name",
        values="value",
        aggfunc="first"
    ).reset_index()

    print(f"Wide format shape: {df_wide.shape}")

    # Data coverage table
    print("\n" + "="*80)
    print("DATA COVERAGE TABLE")
    print("="*80)

    coverage_data = []
    for group_name, group_countries in country_groups.items():
        for var in wb_indicators.values():
            # Count non-null observations for this group and variable
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
    print("\nCoverage (%) by Variable and Group:")
    print(coverage_pivot.round(2))

    # Descriptive statistics by group
    print("\n" + "="*80)
    print("DESCRIPTIVE STATISTICS BY GROUP")
    print("="*80)

    descriptive_data = []
    for group_name, group_countries in country_groups.items():
        group_subset = df_wide[df_wide["country_code"].isin(group_countries)]

        # Exclude country_code and year for statistics
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
    print("\nDescriptive Statistics (mean, sd, min, max, n):")
    for group in ["Frontier", "MENA", "SSA"]:
        group_stats = descriptive_df[descriptive_df["group"] == group]
        print(f"\n{group}:")
        print(group_stats[["variable", "mean", "sd", "min", "max", "n"]].to_string(index=False))

    # Correlation matrix
    print("\n" + "="*80)
    print("CORRELATION MATRIX")
    print("="*80)

    numeric_cols = df_wide.select_dtypes(include=[np.number]).columns
    if len(numeric_cols) > 1:
        corr_matrix = df_wide[numeric_cols].corr()
        print("\nCorrelation Matrix:")
        print(corr_matrix.round(3))

    # Save long-format data
    output_long = DATA_DIR / "panel_wb_raw.csv"
    df_long.to_csv(output_long, index=False)
    print(f"\n✓ Long-format data saved: {output_long}")

    # Save wide-format data
    output_wide = DATA_DIR / "panel_wb_wide.csv"
    df_wide.to_csv(output_wide, index=False)
    print(f"✓ Wide-format data saved: {output_wide}")

    # Save coverage table
    output_coverage = OUTPUT_DIR / "coverage_table.csv"
    coverage_df.to_csv(output_coverage, index=False)
    print(f"✓ Coverage table saved: {output_coverage}")

    # Save descriptive statistics
    output_descriptive = OUTPUT_DIR / "descriptive_stats.csv"
    descriptive_df.to_csv(output_descriptive, index=False)
    print(f"✓ Descriptive statistics saved: {output_descriptive}")

    # Save correlation matrix
    if len(numeric_cols) > 1:
        output_corr = OUTPUT_DIR / "correlation_matrix.csv"
        corr_matrix.to_csv(output_corr)
        print(f"✓ Correlation matrix saved: {output_corr}")
else:
    print("Warning: No data was collected from World Bank")

# USDA AgTFP Data
print("\n" + "="*80)
print("USDA AgTFP DATA COLLECTION")
print("="*80)

usda_url = "https://www.ers.usda.gov/webdocs/DataFiles/50048/InternationalTFPData.xlsx"
output_usda = DATA_DIR / "USDA_AgTFP_raw.xlsx"

try:
    print(f"Downloading from {usda_url}...")
    response = requests.get(usda_url, timeout=30)
    response.raise_for_status()

    with open(output_usda, "wb") as f:
        f.write(response.content)

    # Read and check countries
    try:
        df_usda = pd.read_excel(output_usda, sheet_name=0)
        available_countries = []
        if "Country" in df_usda.columns or "country" in df_usda.columns:
            country_col = "Country" if "Country" in df_usda.columns else "country"
            available_countries = [c for c in df_usda[country_col].unique() if c in countries]

        print(f"✓ USDA AgTFP data saved: {output_usda}")
        if available_countries:
            print(f"  Available countries from our list: {', '.join(available_countries)}")
        else:
            print("  (Countries from our list will need to be checked manually)")
    except Exception as e:
        print(f"✓ USDA AgTFP data saved but could not read: {str(e)}")

except Exception as e:
    print(f"✗ USDA AgTFP download failed: {str(e)}")

# FAOSTAT GHG Data
print("\n" + "="*80)
print("FAOSTAT GHG DATA COLLECTION")
print("="*80)

# Map countries to FAOSTAT area codes
faostat_area_codes = {
    "TUR": 223,   # Turkey
    "EGY": 59,    # Egypt
    "MAR": 149,   # Morocco
    "TUN": 220,   # Tunisia
    "DZA": 4,     # Algeria
    "SDN": 206,   # Sudan
    "JOR": 116,   # Jordan
    "IRN": 100,   # Iran
    "SAU": 201,   # Saudi Arabia
    "PAK": 169,   # Pakistan
    "ETH": 68,    # Ethiopia
    "KEN": 124,   # Kenya
    "TZA": 218,   # Tanzania
    "UGA": 238,   # Uganda
    "MOZ": 158,   # Mozambique
    "ZWE": 281,   # Zimbabwe
    "MLI": 147,   # Mali
    "NER": 164,   # Niger
    "TCD": 42,    # Chad
    "SEN": 204,   # Senegal
    "NGA": 166,   # Nigeria
    "GHA": 81,    # Ghana
    "ZMB": 279,   # Zambia
    "MDG": 137,   # Madagascar
    "MWI": 141,   # Malawi
    "NLD": 157,   # Netherlands
    "ISR": 108,   # Israel
    "DNK": 57,    # Denmark
    "NZL": 165,   # New Zealand
    "AUS": 12,    # Australia
}

area_codes_str = ",".join(str(faostat_area_codes[c]) for c in countries if c in faostat_area_codes)
faostat_url = f"http://fenixservices.fao.org/faostat/api/v1/en/data/GT?area={area_codes_str}&element=7231&item=6820&year=2000:2020&output_type=csv"
output_faostat = DATA_DIR / "FAOSTAT_GHG_raw.csv"

try:
    print(f"Downloading FAOSTAT data...")
    response = requests.get(faostat_url, timeout=30)
    response.raise_for_status()

    # Save raw response
    with open(output_faostat, "w") as f:
        f.write(response.text)

    print(f"✓ FAOSTAT GHG data saved: {output_faostat}")

    # Try to parse and show summary
    try:
        df_faostat = pd.read_csv(StringIO(response.text))
        print(f"  Shape: {df_faostat.shape}")
        if "Area" in df_faostat.columns:
            print(f"  Unique areas: {df_faostat['Area'].nunique()}")
    except:
        pass

except Exception as e:
    print(f"✗ FAOSTAT download failed: {str(e)}")

# Final summary
print("\n" + "="*80)
print("DATA COLLECTION COMPLETE")
print("="*80)
print(f"\nOutput directory: {BASE_DIR}")
print(f"Data files saved in: {DATA_DIR}")
print(f"Analysis tables saved in: {OUTPUT_DIR}")
if errors_wb:
    print(f"\nWorld Bank errors ({len(errors_wb)}):")
    for err in errors_wb[:5]:
        print(f"  - {err}")
    if len(errors_wb) > 5:
        print(f"  ... and {len(errors_wb) - 5} more")

print("\nScript completed successfully!")
