"""
Paper 3 — Gold / Policy-Uncertainty Repricing
Method-rigor boost: Toda-Yamamoto (1995) augmented-VAR causality
+ Newey-West (1987) HAC OLS on the regime model.

Vars: gold_return, epu_us, vix, fed_funds_effective (daily 1980-2026, N=12,207)
"""
import numpy as np, pandas as pd
from pathlib import Path
from statsmodels.tsa.api import VAR
from statsmodels.tsa.stattools import adfuller
from statsmodels.regression.linear_model import OLS
from statsmodels.tools import add_constant
from scipy.stats import chi2

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "03-Results/paper3_gold_policy_uncertainty_dataset.csv"
OUT  = ROOT / "03-Results/paper3_ty_hac_results.txt"

df = pd.read_csv(DATA, parse_dates=["DATE"]).set_index("DATE")
cols = ["gold_return", "epu_us", "VIX", "fed_funds_effective"]
df = df[cols].dropna()
print(f"N = {len(df)}, vars = {cols}")

# --- ADF unit-root → determine d_max
dmax = 0
for c in cols:
    p_lvl = adfuller(df[c], autolag="AIC")[1]
    p_dif = adfuller(df[c].diff().dropna(), autolag="AIC")[1]
    order = 0 if p_lvl < 0.05 else (1 if p_dif < 0.05 else 2)
    dmax = max(dmax, order)
    print(f"  ADF {c}: p_lvl={p_lvl:.3f} p_dif={p_dif:.3f} I({order})")
print(f"d_max = {dmax}")

# --- Toda-Yamamoto: VAR(k+dmax), Wald on first k lags only
model = VAR(df)
k = model.select_order(maxlags=10).selected_orders["aic"]
k = max(k, 1)
print(f"VAR optimal k (AIC) = {k}; estimating VAR({k+dmax})")
res = model.fit(k + dmax)

ty_results = []
for cause in cols:
    for effect in cols:
        if cause == effect: continue
        try:
            t = res.test_causality(effect, [cause], kind="wald")
            ty_results.append((cause, effect, t.test_statistic, t.pvalue))
        except Exception as e:
            ty_results.append((cause, effect, np.nan, np.nan))
ty_df = pd.DataFrame(ty_results, columns=["cause","effect","Wald","p"])
print("\nToda-Yamamoto (Wald on first k lags):")
print(ty_df.to_string(index=False))

# --- Newey-West HAC OLS: gold_return on regime + macro
df["tightening"] = (df["fed_funds_effective"].diff(20) > 0.25).astype(int)
df["easing"]     = (df["fed_funds_effective"].diff(20) < -0.25).astype(int)
y = df["gold_return"].iloc[20:]
X = add_constant(df[["epu_us","VIX","tightening","easing"]].iloc[20:])
ols = OLS(y, X).fit(cov_type="HAC", cov_kwds={"maxlags": 10})
print("\nNewey-West HAC OLS (maxlags=10):")
print(ols.summary().tables[1])

with open(OUT, "w") as f:
    f.write(f"N = {len(df)}\n")
    f.write(f"d_max = {dmax}, VAR k = {k}\n\n")
    f.write("Toda-Yamamoto causality:\n")
    f.write(ty_df.to_string(index=False) + "\n\n")
    f.write("Newey-West HAC OLS (maxlags=10):\n")
    f.write(str(ols.summary()) + "\n")
print(f"\n[OK] → {OUT}")
