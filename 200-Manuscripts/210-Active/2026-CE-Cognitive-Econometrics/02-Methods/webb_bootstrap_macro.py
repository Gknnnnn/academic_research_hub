"""
Method-rigor boost — CE-Cognitive-Econometrics macro pilot
Webb wild cluster bootstrap (MacKinnon-Webb 2018) for small-N EU-27 panel.
Mandatory because N<30 invalidates asymptotic SEs in CS-ARDL mean-group.

Target regression: ln(res_productivity) ~ ln(gdp_pc) + recycle_muni + patents_recyc
Cluster on country (N=27). Resample Rademacher × Webb 6-point.
"""
import numpy as np, pandas as pd
from pathlib import Path
from statsmodels.regression.linear_model import OLS
from statsmodels.tools import add_constant

rng = np.random.default_rng(20260407)
ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "400-Data/processed/eurostat_macro.csv"
OUT  = ROOT / "600-Results/CE_pilot_v2/webb_bootstrap.txt"
OUT.parent.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(DATA).dropna(subset=["res_productivity","gdp_pc","recycle_muni","patents_recyc"])
df["ly"]  = np.log(df["res_productivity"])
df["lx1"] = np.log(df["gdp_pc"])
df["x2"]  = df["recycle_muni"]
df["x3"]  = df["patents_recyc"]

Y = df["ly"].values
X = add_constant(df[["lx1","x2","x3"]]).values
cluster = df["country"].values
N, K = X.shape
clusters = np.unique(cluster)
G = len(clusters)
print(f"Obs={N}, clusters(G)={G}, K={K}")

fit0 = OLS(Y, X).fit(cov_type="cluster", cov_kwds={"groups":cluster})
beta_hat = fit0.params
t_hat    = fit0.tvalues
print("\nCluster-robust baseline:")
print(fit0.summary().tables[1])

# Webb 6-point weights
webb = np.array([-np.sqrt(1.5), -1, -np.sqrt(0.5),
                  np.sqrt(0.5),  1,  np.sqrt(1.5)])

B = 999
t_boot = np.zeros((B, K))
e_hat  = Y - X @ beta_hat
for b in range(B):
    w = rng.choice(webb, size=G)
    wmap = dict(zip(clusters, w))
    w_i  = np.array([wmap[c] for c in cluster])
    Yb   = X @ beta_hat + w_i * e_hat
    fit  = OLS(Yb, X).fit(cov_type="cluster", cov_kwds={"groups":cluster})
    t_boot[b] = (fit.params - beta_hat) / fit.bse

# two-tailed bootstrap p-values
p_boot = np.mean(np.abs(t_boot) >= np.abs(t_hat), axis=0)
names = ["const","ln_gdp_pc","recycle_muni","patents_recyc"]
tbl = pd.DataFrame({
    "coef": beta_hat,
    "t_hat": t_hat,
    "p_asymp": fit0.pvalues,
    "p_webb_999": p_boot,
}, index=names)
print("\nWebb wild cluster bootstrap (B=999):")
print(tbl.round(4).to_string())

with open(OUT,"w") as f:
    f.write(f"Obs={N}, clusters={G}, K={K}\n")
    f.write("Cluster-robust baseline:\n")
    f.write(str(fit0.summary())+"\n\n")
    f.write("Webb wild cluster bootstrap (B=999, Rademacher-6):\n")
    f.write(tbl.round(4).to_string()+"\n")
print(f"\n[OK] → {OUT}")
