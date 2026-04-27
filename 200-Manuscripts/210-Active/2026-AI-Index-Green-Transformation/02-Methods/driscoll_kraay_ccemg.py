"""
Method boost — AI-Index-Green-Transformation
Driscoll-Kraay (1998) HAC panel SE (cross-section-dependence-robust)
+ CCEMG-style common-correlated effects via cross-sectional means augmentation
  (Pesaran 2006). Required by earlier CD test rejection (Pesaran 2004, p<0.001).

Model: ln_EF_it = α_i + μ_t + β·ln_GDP_it + γ·ren_it + δ·trade_it + u_it
"""
import numpy as np, pandas as pd
from pathlib import Path
from statsmodels.regression.linear_model import OLS
from statsmodels.tools import add_constant

DATA = Path("/sessions/eager-busy-cori/mnt/Akademik_Arastirma/400-Data/Global-Panels/Clean/panel_master_v1.csv")
ROOT = Path(__file__).resolve().parents[1]
OUT  = ROOT / "03-Data/baseline_results/driscoll_kraay_ccemg.txt"

df = pd.read_csv(DATA)
df = df.dropna(subset=["ecological_footprint","gdp_per_capita","renewable_energy","trade_openness","iso3","year"])
df["ln_EF"] = np.log(df["ecological_footprint"])
df["gdp_per_capita"] = np.log(df["gdp_per_capita"])  # log-transform for elasticity
print(f"N = {len(df)}, countries = {df.iso3.nunique()}, years = {sorted(df.year.unique())}")

# Add CCE augmentation: cross-sectional means per year
for col in ["ln_EF","gdp_per_capita","renewable_energy","trade_openness"]:
    df[f"csm_{col}"] = df.groupby("year")[col].transform("mean")

# Within-transform (country + year FE) on ln_EF and regressors (including CSM augments)
def within(s, by):
    return s - df.groupby(by)[s.name].transform("mean")

vars_keep = ["ln_EF","gdp_per_capita","renewable_energy","trade_openness",
             "csm_gdp_per_capita","csm_renewable_energy","csm_trade_openness"]
dd = df[["iso3","year"]+vars_keep].copy()
for v in vars_keep:
    dd[v] = dd[v] - dd.groupby("iso3")[v].transform("mean")   # country demean
    dd[v] = dd[v] - dd.groupby("year")[v].transform("mean")   # year demean

Y = dd["ln_EF"]
X = dd[["gdp_per_capita","renewable_energy","trade_openness",
        "csm_gdp_per_capita","csm_renewable_energy","csm_trade_openness"]]
ols_cce = OLS(Y, X).fit()  # no const: already two-way demeaned
print("\nCCEMG-style within regression (two-way FE + CSM augments):")
print(ols_cce.summary().tables[1])

# Driscoll-Kraay HAC (manual): lag-truncation H = floor(4*(T/100)^(2/9))
T = dd["year"].nunique()
H = max(1, int(np.floor(4*(T/100)**(2/9))))
print(f"\nDriscoll-Kraay HAC lags H = {H}")
resid = ols_cce.resid.values
Xm = X.values
k = Xm.shape[1]
# cross-sectionally summed score at each time
dd2 = dd.assign(_res=resid)
# score vector per t
times = sorted(dd["year"].unique())
h_t = np.zeros((len(times), k))
for i, t in enumerate(times):
    mask = (dd["year"]==t).values
    h_t[i] = (Xm[mask] * resid[mask, None]).sum(axis=0)
# Newey-West on h_t
S = (h_t.T @ h_t)
for L in range(1, H+1):
    w = 1 - L/(H+1)
    G = h_t[L:].T @ h_t[:-L]
    S += w*(G+G.T)
XtX_inv = np.linalg.pinv(Xm.T @ Xm)
V_dk = XtX_inv @ S @ XtX_inv
se_dk = np.sqrt(np.diag(V_dk))
t_dk  = ols_cce.params.values / se_dk
from scipy.stats import norm
p_dk  = 2*(1-norm.cdf(np.abs(t_dk)))
tab = pd.DataFrame({"coef":ols_cce.params, "se_DK":se_dk, "t_DK":t_dk, "p_DK":p_dk})
print("\nDriscoll-Kraay HAC SE (CD-robust):")
print(tab.round(4).to_string())

with open(OUT,"w") as f:
    f.write(f"N={len(df)}, countries={df.iso3.nunique()}, T={T}, H={H}\n\n")
    f.write("CCEMG-style within regression + Driscoll-Kraay HAC SE:\n")
    f.write(tab.round(4).to_string()+"\n\n")
    f.write("Interpretation: β(gdp_per_capita) captures idiosyncratic scale effect after removing\n"
            "common factors via cross-sectional means (Pesaran 2006). Driscoll-Kraay SEs\n"
            "are robust to cross-section dependence, heteroskedasticity, and autocorrelation.\n"
            f"T={T} small → H={H}; use H=1 only as indicative, not asymptotic.\n")
print(f"\n[OK] → {OUT}")
