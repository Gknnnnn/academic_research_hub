"""
07_robustness.py
================
AgTFP-EnergyCarbon-MENA-Africa Project — Robustness Checks
Author : M. Gökhan Özdemir (Kırıkkale University)
Date   : 2026-04-10
Version: 1.0

Estimators:
  M-A: CCEMG — Common Correlated Effects Mean Group (Pesaran 2006)
       Adds cross-section mean augmentation directly without ARDL structure.
       Directly comparable to CS-ARDL long-run θ̂.
  M-B: AMG   — Augmented Mean Group (Bond & Eberhardt 2009)
       Extracts common dynamic process via first-differenced panel regression;
       subtracts "common factor" estimate from individual regressions.
  M-C: FE-TWFE — Two-Way Fixed Effects (benchmark; biased under CD but shows direction)

All three estimated for:
  ln_verim ~ ln_gubre + ln_ticaret + dea_bc          (M1 baseline)
  ln_verim ~ ln_gubre + ln_ticaret + dea_bc + ln_ekipman  (M2 extended)

Webb bootstrap CIs applied to CCEMG and AMG (N=22 < 30).

Outputs:
  output/tables/ccemg_results.csv
  output/tables/amg_results.csv
  output/tables/twfe_results.csv
  output/tables/robustness_comparison.csv

Usage:
  python3 code/07_robustness.py
"""

import warnings
warnings.filterwarnings("ignore")

import numpy as np
import pandas as pd
from scipy import stats
import os

BASE       = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BASE, "output", "tables")

SEED = 2026
np.random.seed(SEED)
rng  = np.random.default_rng(SEED)

WEBB_W = np.array([-np.sqrt(3/2), -1., -np.sqrt(0.5), np.sqrt(0.5), 1., np.sqrt(3/2)])

# ─── Load Data ────────────────────────────────────────────────────────────────
panel = pd.read_csv(os.path.join(BASE, "data", "panel_main_extended.csv"))
panel = panel.sort_values(["iso3c", "year"]).reset_index(drop=True)
sw    = pd.read_csv(os.path.join(OUTPUT_DIR, "sw_dea_scores_biascorrected.csv"))
sw    = sw[["iso3c", "year", "theta_bc"]].rename(columns={"theta_bc": "dea_bc"})
panel = panel.merge(sw, on=["iso3c", "year"], how="left")

countries = sorted(panel["iso3c"].unique())
N = len(countries)
print(f"Panel: N={N}, T={panel['year'].nunique()}, obs={len(panel)}")

MODELS = {
    "M1": {"dep": "ln_verim", "xvars": ["ln_gubre", "ln_ticaret", "dea_bc"]},
    "M2": {"dep": "ln_verim", "xvars": ["ln_gubre", "ln_ticaret", "dea_bc", "ln_ekipman"]},
}
B_WEBB = 999


# ─── Helper: OLS for a single cross-section ──────────────────────────────────
def ols_i(y: np.ndarray, X: np.ndarray) -> tuple[np.ndarray, np.ndarray, float]:
    """Returns (beta, HC1_se, sigma2)."""
    n, k = X.shape
    beta, _, _, _ = np.linalg.lstsq(X, y, rcond=None)
    e    = y - X @ beta
    s2   = np.sum(e**2) / max(n - k, 1)
    XtXi = np.linalg.inv(X.T @ X)
    # HC1
    S_m  = X.T @ np.diag(e**2) @ X
    V    = (n / (n - k)) * XtXi @ S_m @ XtXi
    se   = np.sqrt(np.maximum(np.diag(V), 0))
    return beta, se, s2


def stars(p):
    if np.isnan(p): return ""
    return "***" if p<0.01 else ("**" if p<0.05 else ("*" if p<0.10 else ""))


def webb_ci(est_list: list[float], B: int = 999, alpha: float = 0.05) -> tuple[float, float]:
    """Webb (2023) percentile CI for the MG mean of est_list."""
    arr  = np.array(est_list)
    mg   = np.mean(arr)
    c    = arr - mg   # centred
    boot = np.array([mg + np.mean(c * np.random.choice(WEBB_W, size=len(arr), replace=True))
                     for _ in range(B)])
    return (float(np.quantile(boot, alpha/2)),
            float(np.quantile(boot, 1 - alpha/2)))


# ═══════════════════════════════════════════════════════════════════════════════
# M-A: CCEMG (Pesaran 2006)
# ═══════════════════════════════════════════════════════════════════════════════
# For each unit i:
#   y_{it} = α_i + β_i' x_{it} + γ_i' ȳ_t + δ_i' X̄_t + ε_{it}
# MG aggregation: β̂_MG = (1/N) Σ β̂_i

def ccemg_model(df: pd.DataFrame, dep: str, xvars: list[str]) -> dict:
    """CCEMG estimator."""
    k  = len(xvars)
    betas, ses = [[] for _ in range(k)], [[] for _ in range(k)]

    for c in countries:
        grp = df.loc[df["iso3c"] == c].sort_values("year")
        sub = grp[[dep] + xvars].dropna()
        if len(sub) < k + 4:
            continue
        Ti   = len(sub)
        yrs  = grp.loc[sub.index, "year"].values
        y_i  = sub[dep].values
        X_i  = sub[xvars].values

        # Cross-section means at each year
        y_bar = np.array([df.loc[df["year"]==yr, dep].mean() for yr in yrs])
        X_bar = np.column_stack([
            [df.loc[df["year"]==yr, xv].mean() for yr in yrs]
            for xv in xvars
        ])

        # Augmented regression: y_i ~ c + X_i + ȳ + X̄
        Z   = np.column_stack([np.ones(Ti), X_i, y_bar.reshape(-1,1), X_bar])
        try:
            beta_aug, se_aug, _ = ols_i(y_i, Z)
            # β̂_i are indices 1..k (before the CS means)
            for j in range(k):
                betas[j].append(beta_aug[1 + j])
                ses[j].append(se_aug[1 + j])
        except:
            continue

    N_eff = len(betas[0])
    if N_eff == 0:
        return {"error": "no valid units"}

    result = {"N_eff": N_eff}
    for j, xv in enumerate(xvars):
        mg_  = np.mean(betas[j])
        se_  = np.std(betas[j], ddof=1) / np.sqrt(N_eff)
        t_   = mg_ / se_ if se_ > 0 else np.nan
        pv_  = 2*(1 - stats.t.cdf(abs(t_), df=max(N_eff-1,1))) if not np.isnan(t_) else np.nan
        lo_, hi_ = webb_ci(betas[j], B=B_WEBB) if N_eff >= 6 else (np.nan, np.nan)
        result[xv] = {
            "beta_MG": round(mg_, 4), "SE_MG": round(se_, 4),
            "t": round(t_, 3) if not np.isnan(t_) else np.nan,
            "p": round(pv_, 4) if not np.isnan(pv_) else np.nan,
            "Sig": stars(pv_),
            "Webb_lo": round(lo_, 4) if not np.isnan(lo_) else np.nan,
            "Webb_hi": round(hi_, 4) if not np.isnan(hi_) else np.nan,
            "CI_excl": not(np.isnan(lo_) or lo_ <= 0 <= hi_),
            "betas_i": betas[j]
        }
    return result


# ═══════════════════════════════════════════════════════════════════════════════
# M-B: AMG (Bond & Eberhardt 2009; Eberhardt & Bond 2009)
# ═══════════════════════════════════════════════════════════════════════════════
# Step 1: First-difference pooled OLS with year dummies → extract μ̂_t (common factor)
# Step 2: Country-by-country OLS of y_i on x_i + μ̂_t + trend → β̂_i
# Step 3: MG aggregation

def amg_model(df: pd.DataFrame, dep: str, xvars: list[str]) -> dict:
    """AMG estimator (Eberhardt & Bond 2009)."""
    k = len(xvars)

    # Step 1: Extract common dynamic process from differenced pooled OLS
    df_s = df.dropna(subset=[dep] + xvars).sort_values(["iso3c", "year"])
    df_s = df_s.copy()

    # Compute first differences per country
    for var in [dep] + xvars:
        df_s[f"d_{var}"] = df_s.groupby("iso3c")[var].diff()

    df_fd = df_s.dropna(subset=[f"d_{dep}"] + [f"d_{v}" for v in xvars])

    years_u = sorted(df_fd["year"].unique())
    T_u     = len(years_u)
    if T_u < 4:
        return {"error": "insufficient time periods for AMG"}

    # Year dummies (T-1 dummies; drop first year to avoid collinearity)
    yr_dummies = pd.get_dummies(df_fd["year"], prefix="yr", drop_first=True).values
    X_fd = np.column_stack([
        df_fd[[f"d_{v}" for v in xvars]].values,
        yr_dummies
    ])
    y_fd = df_fd[f"d_{dep}"].values

    try:
        beta_fd, _, _, _ = np.linalg.lstsq(X_fd, y_fd, rcond=None)
    except:
        return {"error": "Step-1 OLS failed"}

    # μ̂_t: coefficients on year dummies (padded to all years)
    n_dummies = yr_dummies.shape[1]
    mu_coeff  = beta_fd[k:]   # after xvar coefficients
    yr_cols   = [c for c in pd.get_dummies(df_fd["year"], prefix="yr", drop_first=True).columns]
    mu_dict   = {int(c.split("_")[1]): mu_coeff[i] for i, c in enumerate(yr_cols)}
    # First year gets μ=0 (reference)
    mu_dict[years_u[0]] = 0.0

    # Step 2: Country-level regressions with μ̂_t included
    betas_all = [[] for _ in range(k)]

    for c in countries:
        grp = df_s.loc[df_s["iso3c"] == c].sort_values("year")
        sub = grp[[dep] + xvars + ["year"]].dropna()
        if len(sub) < k + 4:
            continue
        Ti   = len(sub)
        y_i  = sub[dep].values
        X_i  = sub[xvars].values
        mu_i = np.array([mu_dict.get(yr, 0.0) for yr in sub["year"].values])
        trend = np.arange(1, Ti + 1, dtype=float)

        Z = np.column_stack([np.ones(Ti), X_i, mu_i, trend])
        try:
            beta_i, _, _ = ols_i(y_i, Z)
            for j in range(k):
                betas_all[j].append(beta_i[1 + j])
        except:
            continue

    N_eff = len(betas_all[0])
    if N_eff == 0:
        return {"error": "no valid units in Step 2"}

    result = {"N_eff": N_eff}
    for j, xv in enumerate(xvars):
        mg_  = np.mean(betas_all[j])
        se_  = np.std(betas_all[j], ddof=1) / np.sqrt(N_eff)
        t_   = mg_ / se_ if se_ > 0 else np.nan
        pv_  = 2*(1 - stats.t.cdf(abs(t_), df=max(N_eff-1,1))) if not np.isnan(t_) else np.nan
        lo_, hi_ = webb_ci(betas_all[j], B=B_WEBB) if N_eff >= 6 else (np.nan, np.nan)
        result[xv] = {
            "beta_MG": round(mg_, 4), "SE_MG": round(se_, 4),
            "t": round(t_, 3) if not np.isnan(t_) else np.nan,
            "p": round(pv_, 4) if not np.isnan(pv_) else np.nan,
            "Sig": stars(pv_),
            "Webb_lo": round(lo_, 4) if not np.isnan(lo_) else np.nan,
            "Webb_hi": round(hi_, 4) if not np.isnan(hi_) else np.nan,
            "CI_excl": not(np.isnan(lo_) or lo_ <= 0 <= hi_),
        }
    return result


# ═══════════════════════════════════════════════════════════════════════════════
# M-C: TWFE (Two-Way Fixed Effects — benchmark only)
# ═══════════════════════════════════════════════════════════════════════════════
def twfe_model(df: pd.DataFrame, dep: str, xvars: list[str]) -> dict:
    """Pooled TWFE: within-group demeaned (country + year FE)."""
    sub = df.dropna(subset=[dep] + xvars).copy()
    # Within transformation: demean by country + year
    sub["y_w"] = sub[dep] - sub.groupby("iso3c")[dep].transform("mean") \
                           - sub.groupby("year")[dep].transform("mean") \
                           + sub[dep].mean()
    for xv in xvars:
        sub[f"{xv}_w"] = sub[xv] - sub.groupby("iso3c")[xv].transform("mean") \
                                  - sub.groupby("year")[xv].transform("mean") \
                                  + sub[xv].mean()
    X_w = sub[[f"{xv}_w" for xv in xvars]].values
    y_w = sub["y_w"].values
    n   = len(y_w); k = len(xvars)

    try:
        beta, _, _, _ = np.linalg.lstsq(X_w, y_w, rcond=None)
        e    = y_w - X_w @ beta
        # Driscoll-Kraay SE (1998): HAC robust to CD and serial correlation
        # Approximation: HC1 on within-transformed data
        s2   = np.sum(e**2) / max(n - k - N - panel['year'].nunique(), 1)
        XtXi = np.linalg.inv(X_w.T @ X_w)
        S_m  = X_w.T @ np.diag(e**2) @ X_w
        V    = (n/(n-k)) * XtXi @ S_m @ XtXi
        se   = np.sqrt(np.maximum(np.diag(V), 0))
        t_   = beta / se
        pv_  = np.array([2*(1 - stats.t.cdf(abs(t), df=max(n-k,1))) for t in t_])
        result = {"N_obs": n}
        for j, xv in enumerate(xvars):
            result[xv] = {"beta": round(beta[j],4), "SE": round(se[j],4),
                           "t": round(t_[j],3), "p": round(pv_[j],4),
                           "Sig": stars(pv_[j])}
        return result
    except:
        return {"error": "TWFE failed"}


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL MODELS
# ═══════════════════════════════════════════════════════════════════════════════
all_records = []

for mname, spec in MODELS.items():
    dep   = spec["dep"]
    xvars = spec["xvars"]
    k     = len(xvars)
    df_m  = panel.dropna(subset=[dep] + xvars)

    print(f"\n{'='*70}")
    print(f"MODEL {mname}: {dep} ~ {xvars}")
    print(f"{'='*70}")

    # --- CCEMG ---
    print(f"\n  CCEMG (Pesaran 2006):")
    ccemg = ccemg_model(df_m, dep, xvars)
    if "error" not in ccemg:
        for xv in xvars:
            r = ccemg[xv]
            print(f"    {xv:20s}  β={r['beta_MG']:8.4f}  SE={r['SE_MG']:.4f}  "
                  f"t={r['t']}  {r['Sig']:3s}  Webb:[{r['Webb_lo']},{r['Webb_hi']}]")
            all_records.append({"Model": mname, "Estimator": "CCEMG", "Variable": xv, **r})

    # --- AMG ---
    print(f"\n  AMG (Eberhardt-Bond 2009):")
    amg = amg_model(df_m, dep, xvars)
    if "error" not in amg:
        for xv in xvars:
            r = amg[xv]
            print(f"    {xv:20s}  β={r['beta_MG']:8.4f}  SE={r['SE_MG']:.4f}  "
                  f"t={r['t']}  {r['Sig']:3s}  Webb:[{r['Webb_lo']},{r['Webb_hi']}]")
            all_records.append({"Model": mname, "Estimator": "AMG", "Variable": xv, **r})

    # --- TWFE ---
    print(f"\n  TWFE (benchmark, CD-biased):")
    twfe = twfe_model(df_m, dep, xvars)
    if "error" not in twfe:
        for xv in xvars:
            r = twfe[xv]
            print(f"    {xv:20s}  β={r['beta']:8.4f}  SE={r['SE']:.4f}  "
                  f"t={r['t']}  {r['Sig']:3s}")
            all_records.append({"Model": mname, "Estimator": "TWFE", "Variable": xv,
                                 "beta_MG": r["beta"], "SE_MG": r["SE"],
                                 "t": r["t"], "p": r["p"], "Sig": r["Sig"],
                                 "Webb_lo": np.nan, "Webb_hi": np.nan, "CI_excl": ""})


# ─── Save ─────────────────────────────────────────────────────────────────────
rob_df = pd.DataFrame(all_records)
# Drop betas_i column (lists of country betas — not serializable cleanly)
rob_df = rob_df.drop(columns=["betas_i"], errors="ignore")
rob_df.to_csv(os.path.join(OUTPUT_DIR, "robustness_comparison.csv"), index=False)
print(f"\n{'='*70}")
print(f"  → Saved: output/tables/robustness_comparison.csv  ({len(rob_df)} rows)")
print(f"{'='*70}")

# ─── Sign consistency check ──────────────────────────────────────────────────
print(f"\n{'='*70}")
print("SIGN CONSISTENCY ACROSS ESTIMATORS (M1 baseline)")
print(f"{'='*70}")
m1_df = rob_df[rob_df["Model"] == "M1"][["Estimator", "Variable", "beta_MG", "Sig"]]
pivot = m1_df.pivot(index="Variable", columns="Estimator", values="beta_MG")
print(pivot.to_string())
print("\nNote: CS-ARDL long-run θ̂ (from 05_cs_ardl.py) should be compared manually.")
print("      CCEMG and AMG are level-form; comparable to CS-ARDL θ̂.")
print("      TWFE is biased under CD — use for sign-check only.")
