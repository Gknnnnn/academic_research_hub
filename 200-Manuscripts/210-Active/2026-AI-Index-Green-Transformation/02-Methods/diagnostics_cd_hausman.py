"""
Panel Diagnostics — Pesaran CD + Hausman + Income-Group Heterogeneity
Project: 2026-AI-Index-Green-Transformation (revival round 3)
Adds the three Q1 diagnostic blocks missing from baseline:
  (1) Pesaran (2004) CD test for cross-section dependence
  (2) Hausman (1978) test FE vs RE
  (3) Heterogeneous effects: high vs low GDP-pc subsamples
Author:  M. G. Özdemir | 2026-04-07
Caveats: @mackinnon_webb_2018 — small-N subsample inference noisy.
"""
import pandas as pd, numpy as np
from pathlib import Path
from itertools import combinations
import statsmodels.api as sm

DATA = Path("/sessions/eager-busy-cori/mnt/Akademik_Arastirma/400-Data/Global-Panels/Clean/panel_master_v1.csv")
OUT  = Path(__file__).resolve().parents[1] / "03-Data/baseline_results"
OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(DATA)
df = df[(df.year>=2019)&(df.year<=2023)].dropna(
    subset=["ecological_footprint","eci","gdp_per_capita","renewable_energy",
            "trade_openness","urbanization","fdi"]).copy()
df["ln_gdp"] = np.log(df["gdp_per_capita"])
df["ln_ef"]  = np.log(df["ecological_footprint"])

X = ["ln_gdp","trade_openness","urbanization","fdi","eci","renewable_energy"]

# ---- 1. Pesaran CD test on residuals from a pooled OLS ----------------------
mod = sm.OLS(df["ln_ef"], sm.add_constant(df[X])).fit()
df["resid"] = mod.resid
piv = df.pivot_table(index="year", columns="iso3", values="resid")
piv = piv.dropna(axis=1, thresh=3)         # need ≥3 obs per country (T_max=5)
N, T = piv.shape[1], piv.shape[0]
from scipy.stats import norm
if N < 2 or T < 2:
    CD, CD_p, rho_bar = np.nan, np.nan, np.nan
else:
    corr = piv.corr().values
    iu = np.triu_indices_from(corr, k=1)
    rho_bar = float(np.nanmean(corr[iu]))
    CD = float(np.sqrt(2*T/(N*(N-1))) * np.nansum(corr[iu]))
    CD_p = float(2*(1 - norm.cdf(abs(CD))))

# ---- 2. Hausman test FE vs RE -----------------------------------------------
# Hand-rolled: coef diff' (V_FE - V_RE)^-1 coef diff, on coefs of X
def fe_estimate(d):
    Xd = pd.get_dummies(d[X+["iso3","year"]], columns=["iso3","year"],
                        drop_first=True, dtype=float)
    Xd = sm.add_constant(Xd).astype(float)
    return sm.OLS(d["ln_ef"].astype(float), Xd).fit(
        cov_type="cluster", cov_kwds={"groups": d["iso3"]})
def re_estimate(d):
    Xd = sm.add_constant(d[X]).astype(float)
    return sm.OLS(d["ln_ef"].astype(float), Xd).fit(
        cov_type="cluster", cov_kwds={"groups": d["iso3"]})

fe = fe_estimate(df); re = re_estimate(df)
b_diff  = (fe.params[X] - re.params[X]).values
V_diff  = fe.cov_params().loc[X,X].values - re.cov_params().loc[X,X].values
from scipy.stats import chi2
try:
    H_stat = float(b_diff @ np.linalg.pinv(V_diff) @ b_diff)
except Exception:
    H_stat = np.nan
H_p = float(chi2.sf(abs(H_stat), df=len(X))) if np.isfinite(H_stat) else np.nan

# ---- 3. Income-group heterogeneity ------------------------------------------
median_gdp = df.gdp_per_capita.median()
df["high_inc"] = (df.gdp_per_capita > median_gdp).astype(int)
hi = df[df.high_inc==1]; lo = df[df.high_inc==0]
def twfe(d):
    Xd = pd.get_dummies(d[X+["iso3","year"]], columns=["iso3","year"],
                        drop_first=True, dtype=float)
    Xd = sm.add_constant(Xd).astype(float)
    return sm.OLS(d["ln_ef"].astype(float), Xd).fit(
        cov_type="cluster", cov_kwds={"groups": d["iso3"]})
m_hi = twfe(hi); m_lo = twfe(lo)
het = pd.DataFrame({
    "coef_high": m_hi.params[X].round(4),
    "p_high":    m_hi.pvalues[X].round(4),
    "coef_low":  m_lo.params[X].round(4),
    "p_low":     m_lo.pvalues[X].round(4),
})

# ---- WRITE -------------------------------------------------------------------
with open(OUT/"diagnostics_v3.txt","w") as f:
    f.write("Panel Diagnostics — AI-Index-Green-Transformation (round 3)\n")
    f.write(f"N={len(df)}, countries={df.iso3.nunique()}, years={sorted(df.year.unique())}\n\n")
    f.write("--- (1) Pesaran (2004) CD test ---\n")
    f.write(f"CD = {CD:.3f}, p = {CD_p:.4f}, rho_bar = {rho_bar:.4f}\n")
    f.write("H0 = no cross-section dependence.\n\n")
    f.write("--- (2) Hausman FE vs RE ---\n")
    f.write(f"H = {H_stat:.3f}, df = {len(X)}, p = {H_p:.4f}\n")
    f.write("H0 = RE consistent (use RE); reject → FE preferred.\n\n")
    f.write("--- (3) Income-group heterogeneity (TWFE) ---\n")
    f.write(het.to_string()); f.write("\n\n")
    f.write("CAVEATS:\n")
    f.write("- Subsample N small for low-income (~170 obs); cluster-bootstrap recommended.\n")
    f.write("- 2019-2023 short panel: dynamic GMM not feasible (T=5).\n")

print(f"Pesaran CD = {CD:.3f} (p={CD_p:.4f}), rho_bar={rho_bar:.4f}")
print(f"Hausman H = {H_stat:.3f}, p = {H_p:.4f}")
print("\n=== Heterogeneity (high vs low income) ===")
print(het)
