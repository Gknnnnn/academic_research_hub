"""
Method-rigor boost — UY-MGO-Sustainability-Nexus (N=24, 2000-2023)
Webb wild bootstrap (MacKinnon-Webb 2018) on the CO2 ARDL-error-correction eq.
Small N invalidates asymptotic SEs; Webb 6-point Rademacher weights used.
Single time series → residual (pair-cluster-free) wild bootstrap.
"""
import numpy as np, pandas as pd
from pathlib import Path
from statsmodels.regression.linear_model import OLS
from statsmodels.tools import add_constant

rng = np.random.default_rng(20260407)
ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "03-Results/data_UY_2000_2023.csv"
OUT  = ROOT / "03-Results/webb_wild_bootstrap.txt"

df = pd.read_csv(DATA).set_index("year")
d = df.diff().dropna()
lev = df.shift(1).loc[d.index]
lev_ = lev[["CO2","GDP","MIG","GI"]].add_prefix("L_")
dlag = d[["GDP","MIG","GI"]].add_prefix("d_")
X = add_constant(pd.concat([lev_, dlag], axis=1)).dropna()
Y = d["CO2"].loc[X.index]
n, k = X.shape
print(f"N = {n}, K = {k}")

fit = OLS(Y, X).fit()
beta_hat = fit.params.values
t_hat    = fit.tvalues.values
e_hat    = fit.resid.values
Xv       = X.values

webb = np.array([-np.sqrt(1.5),-1,-np.sqrt(0.5),np.sqrt(0.5),1,np.sqrt(1.5)])
B = 999
t_boot = np.zeros((B, k))
for b in range(B):
    w  = rng.choice(webb, size=n)
    Yb = Xv @ beta_hat + w * e_hat
    fb = OLS(Yb, Xv).fit()
    t_boot[b] = (fb.params - beta_hat) / fb.bse

p_boot = np.mean(np.abs(t_boot) >= np.abs(t_hat), axis=0)
tab = pd.DataFrame({
    "coef": beta_hat,
    "t_hat": t_hat,
    "p_asymp": fit.pvalues.values,
    "p_webb_999": p_boot,
}, index=X.columns)
print("\nWebb wild bootstrap (B=999, Rademacher-6):")
print(tab.round(4).to_string())

with open(OUT,"w") as f:
    f.write(f"N = {n}, K = {k}\n")
    f.write("ARDL-ECM form for CO2 (error-correction):\n")
    f.write("Webb wild bootstrap (B=999, Rademacher-6):\n\n")
    f.write(tab.round(4).to_string()+"\n")
    f.write("\nInterpretation: compare p_asymp vs p_webb_999. Small-N asymptotic SEs\n"
            "often under-cover; Webb bootstrap is mandatory before Q1 submission.\n")
print(f"\n[OK] → {OUT}")
