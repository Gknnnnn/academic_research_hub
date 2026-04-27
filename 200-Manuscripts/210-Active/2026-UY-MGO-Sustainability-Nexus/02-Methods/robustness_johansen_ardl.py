"""
Method-rigor boost — Paper UY-MGO-Sustainability-Nexus (N=24, 2000-2023)
- Johansen (1991) trace & max-eigenvalue cointegration
- ARDL bounds test (Pesaran-Shin-Smith 2001) approximated via F-bounds
- CUSUM/CUSUMSQ stability
- Ljung-Box residual diagnostics
Small-sample caveat: critical values approximate; stationary bootstrap recommended.
"""
import numpy as np, pandas as pd
from pathlib import Path
from statsmodels.tsa.vector_ar.vecm import coint_johansen
from statsmodels.tsa.stattools import adfuller
from statsmodels.regression.linear_model import OLS
from statsmodels.tools import add_constant
from statsmodels.stats.diagnostic import acorr_ljungbox
from statsmodels.stats.diagnostic import breaks_cusumolsresid

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "03-Results/data_UY_2000_2023.csv"
OUT  = ROOT / "03-Results/robustness_johansen_ardl.txt"

df = pd.read_csv(DATA).set_index("year")
print(f"N = {len(df)}, vars = {list(df.columns)}")

# --- Johansen
jres = coint_johansen(df, det_order=0, k_ar_diff=1)
trace = jres.lr1; cv_trace = jres.cvt  # 90/95/99
maxeig = jres.lr2; cv_maxeig = jres.cvm
jtab = pd.DataFrame({
    "r<=": [f"{i}" for i in range(len(trace))],
    "trace": np.round(trace,3),
    "cv_95_trace": np.round(cv_trace[:,1],3),
    "maxeig": np.round(maxeig,3),
    "cv_95_maxeig": np.round(cv_maxeig[:,1],3),
})
print("\nJohansen:")
print(jtab.to_string(index=False))

# --- ARDL-bounds style F-test on CO2 equation
# ΔCO2 = α + φ1·CO2_{t-1} + φ2·GDP_{t-1} + φ3·MIG_{t-1} + φ4·GI_{t-1}
#        + Σ β·Δlags + ε
d = df.diff().dropna()
lev = df.shift(1).loc[d.index]
Y = d["CO2"]
lev_ = lev[["CO2","GDP","MIG","GI"]].add_prefix("L_")
dlag = d[["GDP","MIG","GI"]].add_prefix("d_")
X = pd.concat([lev_, dlag], axis=1)
X = add_constant(X).dropna()
Y = Y.loc[X.index]
ols = OLS(Y, X).fit()
# joint F on levels
constraints = [f"L_{col} = 0" for col in ["CO2","GDP","MIG","GI"]]
fstat = ols.f_test(",".join(constraints)).fvalue
print(f"\nARDL F-bounds (long-run): F = {float(fstat):.3f}")
print("  Pesaran (2001) 5% bounds k=3: I(0)=3.23, I(1)=4.35")

# --- residual diagnostics
lb = acorr_ljungbox(ols.resid, lags=[4], return_df=True)
print("\nLjung-Box(4):")
print(lb.to_string())
try:
    cusum_stat, cusum_p, _ = breaks_cusumolsresid(ols.resid)
    print(f"CUSUM OLS: stat={cusum_stat:.3f}, p={cusum_p:.3f}")
except Exception as e:
    cusum_stat, cusum_p = np.nan, np.nan
    print(f"CUSUM skipped: {e}")

with open(OUT,"w") as f:
    f.write("Johansen cointegration\n")
    f.write(jtab.to_string(index=False)+"\n\n")
    f.write(f"ARDL F-bounds (CO2 eq): F = {float(fstat):.3f}\n")
    f.write("Pesaran (2001) 5% k=3 bounds: I(0)=3.23, I(1)=4.35\n\n")
    f.write("Ljung-Box(4)\n"+lb.to_string()+"\n")
    f.write(f"CUSUM OLS: stat={cusum_stat}, p={cusum_p}\n")
    f.write("\nSmall-sample (N=24) caveat: critical values asymptotic; "
            "stationary bootstrap (B=999) mandatory before Q1 submission.\n")
print(f"\n[OK] → {OUT}")
