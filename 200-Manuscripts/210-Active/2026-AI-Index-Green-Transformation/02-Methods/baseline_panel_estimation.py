"""
Baseline TWFE Panel Estimation — AI Capacity & Green Transformation
Project: 2026-AI-Index-Green-Transformation
Sample:  Common-country panel 2019-2023 (panel_master_v1.csv)
Target:  Sustainable Development (Q1, IF 7.9)
Author:  M. G. Özdemir | Revived: 2026-04-07

Note: AI index merge pending (Oxford GAIRI + Tortoise + Stanford GAIVT).
This script establishes the BASELINE outcomes-on-controls model on real
data; AI indices will replace the placeholder `ai_proxy` once merged.

Caveats: @mackinnon_webb_2018 (Webb wild cluster bootstrap recommended for
N_country < 30 sub-samples).
"""
import pandas as pd, numpy as np, os
from pathlib import Path

DATA = Path("/sessions/eager-busy-cori/mnt/Akademik_Arastirma/400-Data/Global-Panels/Clean/panel_master_v1.csv")
OUT  = Path("../03-Data") / "baseline_results"
OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(DATA)
df = df[(df["year"] >= 2019) & (df["year"] <= 2023)].copy()

# Outcomes & controls
outcomes = ["ecological_footprint","carbon_intensity_gdp","renewable_energy"]
controls = ["gdp_per_capita","trade_openness","urbanization","fdi","eci"]

# Drop rows missing on used columns
keep = ["country_name","iso3","year"] + outcomes + controls
panel = df[keep].dropna()
print(f"[INFO] balanced rows = {len(panel)}, countries = {panel['iso3'].nunique()}")

# Log-transform positive vars
for v in ["gdp_per_capita","ecological_footprint","carbon_intensity_gdp"]:
    panel[f"ln_{v}"] = np.log(panel[v].replace({0: np.nan}))
panel = panel.dropna()

# TWFE via dummy variables (statsmodels OLS with country & year FE,
# clustered SEs by country)
import statsmodels.api as sm

def twfe(y, X, panel):
    Xd = pd.get_dummies(panel[X + ["iso3","year"]],
                        columns=["iso3","year"], drop_first=True, dtype=float)
    Xd = sm.add_constant(Xd)
    mod = sm.OLS(panel[y].astype(float), Xd.astype(float))
    res = mod.fit(cov_type="cluster",
                  cov_kwds={"groups": panel["iso3"]})
    return res

results = {}
for y in ["ln_ecological_footprint","ln_carbon_intensity_gdp","renewable_energy"]:
    X = ["ln_gdp_per_capita","trade_openness","urbanization","fdi","eci"]
    r = twfe(y, X, panel)
    coefs = r.params[X]
    ses   = r.bse[X]
    pvals = r.pvalues[X]
    results[y] = pd.DataFrame({"coef":coefs.round(4),
                               "se":ses.round(4),
                               "p":pvals.round(4)})

# Write
with open(OUT / "twfe_baseline.txt","w") as f:
    f.write(f"AI Index × Green Transformation — Baseline TWFE (2026-04-07)\n")
    f.write(f"Sample: 2019-2023 | N={len(panel)} obs, "
            f"{panel['iso3'].nunique()} countries\n")
    f.write("Estimator: OLS with country & year FE, cluster-robust SE (iso3)\n")
    f.write("CAVEAT: AI indices not yet merged — replace eci with ai_index "
            "after merge step.\n\n")
    for y, tab in results.items():
        f.write(f"--- {y} ---\n")
        f.write(tab.to_string()); f.write("\n\n")
    f.write("Next step: merge Oxford GAIRI 2019-2023 panel; rerun with "
            "ai_readiness, ai_ecosystem, ai_vibrancy as treatments.\n")

for y, tab in results.items():
    tab.to_csv(OUT / f"twfe_{y}.csv")

print(f"[OK] {OUT}/twfe_baseline.txt written")
for y, tab in results.items():
    print(f"\n=== {y} ===")
    print(tab)
