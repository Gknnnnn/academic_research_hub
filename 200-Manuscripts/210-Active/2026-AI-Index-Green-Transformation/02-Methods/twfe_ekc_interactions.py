"""
EKC + ECI Interaction TWFE
Project: 2026-AI-Index-Green-Transformation (revival round 2)
Adds quadratic GDP term + ECI×renewable interaction.
Author: M. G. Özdemir | 2026-04-07
"""
import pandas as pd, numpy as np
from pathlib import Path
import statsmodels.api as sm

DATA = Path("/sessions/eager-busy-cori/mnt/Akademik_Arastirma/400-Data/Global-Panels/Clean/panel_master_v1.csv")
OUT  = Path(__file__).resolve().parents[1] / "03-Data/baseline_results"
OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(DATA)
df = df[(df.year>=2010)&(df.year<=2023)].dropna(
    subset=["ecological_footprint","eci","gdp_per_capita","renewable_energy",
            "trade_openness","urbanization","fdi"]).copy()
df["ln_gdp"]  = np.log(df["gdp_per_capita"])
df["ln_gdp2"] = df["ln_gdp"]**2
df["ln_ef"]   = np.log(df["ecological_footprint"])
df["eci_x_ren"] = df["eci"] * df["renewable_energy"]

X = ["ln_gdp","ln_gdp2","eci","renewable_energy","eci_x_ren",
     "trade_openness","urbanization","fdi"]
Xd = pd.get_dummies(df[X+["iso3","year"]], columns=["iso3","year"],
                    drop_first=True, dtype=float)
Xd = sm.add_constant(Xd).astype(float)
mod = sm.OLS(df["ln_ef"].astype(float), Xd).fit(
    cov_type="cluster", cov_kwds={"groups": df["iso3"]})

# EKC turning point
b1 = mod.params["ln_gdp"]; b2 = mod.params["ln_gdp2"]
tp = float(np.exp(-b1/(2*b2))) if b2 != 0 else np.nan

tab = pd.DataFrame({"coef":mod.params[X].round(4),
                    "se":mod.bse[X].round(4),
                    "p":mod.pvalues[X].round(4)})
tab.to_csv(OUT/"twfe_ekc_interaction.csv")
with open(OUT/"twfe_ekc_interaction.txt","w") as f:
    f.write("AI-Index — EKC + ECI×REN interaction (revival round 2)\n")
    f.write(f"Sample 2010-2023 | N={len(df)} | countries={df.iso3.nunique()}\n")
    f.write("Estimator: OLS with country & year FE, cluster-robust SE (iso3)\n\n")
    f.write(tab.to_string()); f.write("\n\n")
    f.write(f"EKC turning point (USD pc, current): {tp:,.0f}\n")
    f.write(f"R² adj = {mod.rsquared_adj:.3f}\n")

print(tab)
print(f"\nEKC turning point: USD {tp:,.0f}")
