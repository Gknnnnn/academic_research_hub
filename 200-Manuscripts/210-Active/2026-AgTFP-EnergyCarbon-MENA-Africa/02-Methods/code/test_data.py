#!/usr/bin/env python3
"""Quick test - create sample data structure"""
from pathlib import Path
import pandas as pd
import numpy as np

BASE_DIR = Path.home() / "Library" / "CloudStorage" / "OneDrive-Kişisel" / "Akademik_Arastirma" / \
           "200-Manuscripts" / "210-Active" / "2026-AgTFP-EnergyCarbon-MENA-Africa"
DATA_DIR = BASE_DIR / "data"
OUTPUT_DIR = BASE_DIR / "output" / "tables"

DATA_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Create sample long-format data
countries = ["NLD", "ISR", "DNK", "NZL", "AUS", "TUR", "EGY", "MAR", "TUN", "DZA",
             "SDN", "JOR", "IRN", "SAU", "PAK", "ETH", "KEN", "TZA", "UGA", "MOZ",
             "ZWE", "MLI", "NER", "TCD", "SEN", "NGA", "GHA", "ZMB", "MDG", "MWI"]

variables = ["gdppc_const", "gdppc_growth", "trade_openness", "renewable_elec_share",
             "agri_land_share", "tractors_per_100sqkm", "rural_pop_share", "malnutrition"]

data = []
for country in countries:
    for year in range(2000, 2021):
        for var in variables:
            if np.random.random() > 0.3:  # 70% coverage
                value = np.random.normal(100 if "land" in var else 50, 20)
                data.append({"country_code": country, "year": year, "variable_name": var, "value": value})

df_long = pd.DataFrame(data)
df_long.to_csv(DATA_DIR / "panel_wb_raw.csv", index=False)

df_wide = df_long.pivot_table(
    index=["country_code", "year"],
    columns="variable_name",
    values="value",
    aggfunc="first"
).reset_index()
df_wide.to_csv(DATA_DIR / "panel_wb_wide.csv", index=False)

# Coverage
country_groups = {
    "Frontier": ["NLD", "ISR", "DNK", "NZL", "AUS"],
    "MENA": ["TUR", "EGY", "MAR", "TUN", "DZA", "SDN", "JOR", "IRN", "SAU", "PAK"],
    "SSA": ["ETH", "KEN", "TZA", "UGA", "MOZ", "ZWE", "MLI", "NER", "TCD", "SEN", "NGA", "GHA", "ZMB", "MDG", "MWI"],
}

coverage = []
for group, gcountries in country_groups.items():
    for var in variables:
        mask = (df_long["variable_name"] == var) & (df_long["country_code"].isin(gcountries))
        n_obs = len(df_long[mask])
        coverage.append({"group": group, "variable": var, "n_obs": n_obs, "coverage_pct": 100*n_obs/(len(gcountries)*21)})

coverage_df = pd.DataFrame(coverage)
coverage_df.to_csv(OUTPUT_DIR / "coverage_table.csv", index=False)

# Descriptive stats
stats = []
for group, gcountries in country_groups.items():
    subset = df_wide[df_wide["country_code"].isin(gcountries)]
    for col in variables:
        if col in subset.columns:
            vals = subset[col].dropna()
            if len(vals) > 0:
                stats.append({"group": group, "variable": col, "mean": vals.mean(),
                             "sd": vals.std(), "min": vals.min(), "max": vals.max(), "n": len(vals)})

stats_df = pd.DataFrame(stats)
stats_df.to_csv(OUTPUT_DIR / "descriptive_stats.csv", index=False)

print("Sample data created successfully!")
print(f"Long format: {len(df_long)} rows, {df_long.shape[1]} cols")
print(f"Wide format: {df_wide.shape}")
print("Files saved:")
print(f"  - {DATA_DIR / 'panel_wb_raw.csv'}")
print(f"  - {DATA_DIR / 'panel_wb_wide.csv'}")
print(f"  - {OUTPUT_DIR / 'coverage_table.csv'}")
print(f"  - {OUTPUT_DIR / 'descriptive_stats.csv'}")
