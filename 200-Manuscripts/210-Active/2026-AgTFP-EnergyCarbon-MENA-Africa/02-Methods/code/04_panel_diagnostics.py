"""
04_panel_diagnostics.py
========================
AgTFP-EnergyCarbon-MENA-Africa Project — Panel Diagnostic Suite
Author : M. Gökhan Özdemir (Kırıkkale University)
Date   : 2026-04-10
Version: 1.0

Tests implemented (second-generation panel sequence):
  1. Pesaran (2004) CD test — cross-section dependence (all variables)
  2. Pesaran (2007) CIPS test — cross-sectionally augmented unit root
     (levels + first differences; with intercept; with intercept+trend)
  3. Pesaran & Yamagata (2008) Δ̃ / Δ̃_adj — slope homogeneity
  4. Westerlund (2007) — Gt, Ga, Pt, Pa panel cointegration
     with sieve bootstrap p-values (preserves cross-section dependence)

Reference critical values:
  CIPS (Pesaran 2007, Table IIa/IIb): T≈20, N≈20
  Westerlund (2007): bootstrap p-values used throughout (N=22 < 30 → mandatory)

Inputs:
  data/panel_main_extended.csv
  output/tables/sw_dea_scores_biascorrected.csv

Outputs:
  output/tables/cd_test_results.csv
  output/tables/cips_unit_root_levels.csv
  output/tables/cips_unit_root_differences.csv
  output/tables/slope_homogeneity_test.csv
  output/tables/westerlund_cointegration.csv

Usage:
  cd 200-Manuscripts/210-Active/2026-AgTFP-EnergyCarbon-MENA-Africa
  python3 code/04_panel_diagnostics.py
"""

import warnings
warnings.filterwarnings("ignore")

import numpy as np
import pandas as pd
from scipy import stats
from scipy.stats import norm
import os

# ─── Paths ───────────────────────────────────────────────────────────────────
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR   = os.path.join(BASE, "data")
OUTPUT_DIR = os.path.join(BASE, "output", "tables")
os.makedirs(OUTPUT_DIR, exist_ok=True)

SEED = 2026
np.random.seed(SEED)

# ─── 1. Load & Merge Data ─────────────────────────────────────────────────────

panel = pd.read_csv(os.path.join(DATA_DIR, "panel_main_extended.csv"))
panel = panel.sort_values(["iso3c", "year"]).reset_index(drop=True)

# Merge SW bias-corrected DEA scores
sw = pd.read_csv(os.path.join(OUTPUT_DIR, "sw_dea_scores_biascorrected.csv"))
sw = sw[["iso3c", "year", "theta_bc"]].rename(columns={"theta_bc": "dea_bc"})
panel = panel.merge(sw, on=["iso3c", "year"], how="left")

# Variables for unit root testing
VARS_LEVELS = [
    "ln_tarim_gsyh", "ln_emek", "ln_toprak",
    "ln_gubre", "ln_verim", "ln_ekipman", "ln_ticaret"
]
VARS_DIFF = [
    "d_ln_tarim_gsyh", "d_ln_emek", "d_ln_toprak",
    "d_ln_gubre", "d_ln_verim", "d_ln_ekipman", "d_ln_ticaret"
]

countries = panel["iso3c"].unique()
N = len(countries)
years = sorted(panel["year"].unique())
T = len(years)
print(f"Panel: N={N}, T={T}, obs={N*T}")

# ─── Helper: Extract balanced sub-panel ───────────────────────────────────────

def get_balanced(df: pd.DataFrame, var: str) -> dict[str, np.ndarray]:
    """Return {iso3c: time-series array} for a balanced panel, dropping NaNs."""
    out = {}
    for c in countries:
        ts = df.loc[df["iso3c"] == c, var].dropna().values
        if len(ts) >= 5:          # require at least 5 obs per unit
            out[c] = ts
    return out


# ═══════════════════════════════════════════════════════════════════════════════
# 1.  PESARAN (2004) CD TEST
# ═══════════════════════════════════════════════════════════════════════════════

def pesaran_cd(series_dict: dict[str, np.ndarray]) -> tuple[float, float, int]:
    """
    Pesaran (2004) CD test statistic.
    CD = sqrt(2T/(N(N-1))) * Σ_{i<j} ρ̂_{ij}
    where ρ̂_{ij} is the sample correlation of residuals for pair (i,j).
    For raw levels we demean by OLS on intercept+trend first.
    Returns: (CD, p_value, T_used)
    """
    codes  = list(series_dict.keys())
    n      = len(codes)
    # Use minimum available T across units for alignment
    T_min  = min(len(v) for v in series_dict.values())
    # Truncate to common T (use last T_min obs)
    mat    = np.column_stack([v[-T_min:] for v in series_dict.values()])  # (T_min × n)

    # Demean with intercept + linear trend
    t_vec  = np.arange(1, T_min + 1, dtype=float)
    Z      = np.column_stack([np.ones(T_min), t_vec])
    resid  = mat - Z @ np.linalg.lstsq(Z, mat, rcond=None)[0]

    # Pairwise correlations
    corr_sum = 0.0
    cnt      = 0
    for i in range(n):
        for j in range(i + 1, n):
            r  = np.corrcoef(resid[:, i], resid[:, j])[0, 1]
            corr_sum += r
            cnt      += 1

    cd_stat = np.sqrt(2 * T_min / (n * (n - 1))) * corr_sum
    p_val   = 2 * (1 - norm.cdf(abs(cd_stat)))
    return cd_stat, p_val, T_min


def run_cd_tests(df: pd.DataFrame, variables: list[str]) -> pd.DataFrame:
    records = []
    for var in variables:
        sd = get_balanced(df, var)
        if len(sd) < 3:
            continue
        cd, pv, t_used = pesaran_cd(sd)
        records.append({
            "Variable": var,
            "N": len(sd),
            "T": t_used,
            "CD_stat": round(cd, 4),
            "p_value": round(pv, 4),
            "Sig": "***" if pv < 0.01 else ("**" if pv < 0.05 else ("*" if pv < 0.10 else ""))
        })
        print(f"  CD  {var:25s}  CD={cd:7.3f}  p={pv:.4f}  {records[-1]['Sig']}")
    return pd.DataFrame(records)


print("\n" + "="*70)
print("1. PESARAN (2004) CD TEST — CROSS-SECTION DEPENDENCE")
print("="*70)
cd_levels = run_cd_tests(panel, VARS_LEVELS)
cd_diffs  = run_cd_tests(panel, VARS_DIFF)
cd_all    = pd.concat([cd_levels, cd_diffs], ignore_index=True)
cd_all.to_csv(os.path.join(OUTPUT_DIR, "cd_test_results.csv"), index=False)
print(f"\n  → Saved: output/tables/cd_test_results.csv")


# ═══════════════════════════════════════════════════════════════════════════════
# 2.  PESARAN (2007) CIPS TEST — CROSS-SECTIONALLY AUGMENTED IPS
# ═══════════════════════════════════════════════════════════════════════════════

# Critical values: Pesaran (2007) Table IIa (intercept only) & IIb (intercept+trend)
# N≈20, T≈20, p=0
CIPS_CV = {
    "intercept":       {"10%": -2.25, "5%": -2.33, "1%": -2.50},
    "intercept+trend": {"10%": -2.71, "5%": -2.80, "1%": -2.98},
}

def cadf_tstat(y: np.ndarray, p: int = 1, include_trend: bool = False) -> float:
    """
    CADF t-statistic for a single series.
    Augmented DF regression with cross-sectional mean and its lag:
      Δy_t = a + ρ·y_{t-1} + d0·ȳ_{t-1} + d1·Δȳ_t
             + Σ_{j=1}^p [c_j·Δy_{t-j} + d_{j+1}·Δȳ_{t-j}]  [+ trend]  + ε_t
    Returns t-stat on ρ (the unit-root coefficient).
    NOTE: cross-sectional mean ȳ must already be included in y as a separate column.
    y : array of shape (T,) — individual series
    The caller is responsible for passing the correct cross-section mean.
    """
    # This function is called with the individual and panel-mean info embedded.
    # See cadf_series below.
    raise NotImplementedError("Use cadf_series instead.")


def cadf_series(y_i: np.ndarray, y_bar: np.ndarray,
                p: int = 1, include_trend: bool = False) -> float:
    """
    CADF t-statistic (Pesaran 2007) for unit i.
    y_i   : (T,)  individual series (levels)
    y_bar : (T,)  cross-sectional mean (levels)
    p     : number of augmentation lags
    Returns t-statistic on ρ in:
      Δy_{i,t} = a + ρ·y_{i,t-1} + d0·ȳ_{t-1} + d1·Δȳ_t
                 + Σ lag terms + [trend] + ε
    """
    T_   = len(y_i)
    dy   = np.diff(y_i)               # length T_-1
    dyb  = np.diff(y_bar)             # length T_-1
    # Align: drop first p+1 obs to accommodate lags and lag-1
    # Regressor matrix construction
    # Start index: p+1 (need y_{t-1} which needs t≥1, plus p lags of Δy)
    start = p + 1   # we lose 1 for diff, p for lags → use obs [p+1 ... T_-1] of Δy
    n_obs = len(dy) - p   # = T_ - 1 - p

    if n_obs < 5:
        return np.nan

    # Dependent: Δy_{i,t}  for t = p+2 ... T_  (Python: dy[p:])
    dep = dy[p:]                                          # (n_obs,)

    # Regressors:
    cols = []
    # intercept
    cols.append(np.ones(n_obs))
    # y_{i,t-1}  (target — for t-stat)
    cols.append(y_i[p : T_ - 1])                        # y[p..T_-2]
    # ȳ_{t-1}
    cols.append(y_bar[p : T_ - 1])
    # Δȳ_t
    cols.append(dyb[p:])                                  # dyb[p..end]
    # lags Δy_{i,t-j}, j=1..p
    for j in range(1, p + 1):
        cols.append(dy[p - j: len(dy) - j])
    # lags Δȳ_{t-j}, j=1..p
    for j in range(1, p + 1):
        lag_start = p - j
        lag_end   = lag_start + n_obs
        if lag_end <= len(dyb):
            cols.append(dyb[lag_start:lag_end])
        else:
            cols.append(np.zeros(n_obs))
    # optional trend
    if include_trend:
        cols.append(np.arange(1, n_obs + 1, dtype=float))

    X = np.column_stack(cols)

    try:
        beta, resid, rank, sv = np.linalg.lstsq(X, dep, rcond=None)
        fitted = X @ beta
        e      = dep - fitted
        s2     = np.sum(e**2) / max(n_obs - X.shape[1], 1)
        xtxi   = np.linalg.inv(X.T @ X)
        se_rho = np.sqrt(s2 * xtxi[1, 1])   # index 1 → y_{i,t-1}
        t_rho  = beta[1] / se_rho
    except np.linalg.LinAlgError:
        return np.nan

    return t_rho


def cips_test(series_dict: dict[str, np.ndarray],
              p: int = 1,
              include_trend: bool = False) -> tuple[float, list[float]]:
    """
    CIPS = (1/N) Σ_i CADF_i(p).
    Returns: (CIPS_stat, [individual CADF t-stats])
    """
    codes  = list(series_dict.keys())
    n      = len(codes)
    T_min  = min(len(v) for v in series_dict.values())
    mat    = np.column_stack([v[-T_min:] for v in series_dict.values()])  # (T×n)
    y_bar  = mat.mean(axis=1)   # cross-sectional mean

    t_stats = []
    for i, c in enumerate(codes):
        y_i  = mat[:, i]
        t_i  = cadf_series(y_i, y_bar, p=p, include_trend=include_trend)
        t_stats.append(t_i)

    valid = [t for t in t_stats if not np.isnan(t)]
    cips  = np.mean(valid) if valid else np.nan
    return cips, t_stats


def cips_inference(cips_stat: float, include_trend: bool = False) -> dict:
    cv_key = "intercept+trend" if include_trend else "intercept"
    cvs    = CIPS_CV[cv_key]
    sig    = ""
    if not np.isnan(cips_stat):
        if cips_stat < cvs["1%"]:
            sig = "***"
        elif cips_stat < cvs["5%"]:
            sig = "**"
        elif cips_stat < cvs["10%"]:
            sig = "*"
    result = {"CIPS": round(cips_stat, 4), "Sig": sig}
    result.update({k: v for k, v in cvs.items()})
    return result


def run_cips_suite(df: pd.DataFrame, variables: list[str],
                   label: str = "levels") -> pd.DataFrame:
    """Run CIPS for a list of variables; both intercept-only and intercept+trend."""
    records = []
    for var in variables:
        sd = get_balanced(df, var)
        if len(sd) < 3:
            continue
        for trend in [False, True]:
            cips_val, _ = cips_test(sd, p=1, include_trend=trend)
            inf  = cips_inference(cips_val, include_trend=trend)
            spec = "Intercept+Trend" if trend else "Intercept"
            records.append({
                "Variable": var, "Specification": spec,
                "CIPS": inf["CIPS"], "CV_10%": inf["10%"],
                "CV_5%":  inf["5%"],  "CV_1%":  inf["1%"],
                "Sig": inf["Sig"],
                "Decision": "I(0)" if inf["Sig"] else "I(1)"
            })
            stars = inf["Sig"] if inf["Sig"] else "n.s."
            print(f"  CIPS [{spec:16s}] {var:25s}  {cips_val:7.4f}  {stars}")
    return pd.DataFrame(records)


print("\n" + "="*70)
print("2. CIPS UNIT ROOT TEST — LEVELS")
print("="*70)
cips_levels = run_cips_suite(panel, VARS_LEVELS, label="levels")
cips_levels.to_csv(os.path.join(OUTPUT_DIR, "cips_unit_root_levels.csv"), index=False)

print("\n" + "="*70)
print("2b. CIPS UNIT ROOT TEST — FIRST DIFFERENCES")
print("="*70)
cips_diffs = run_cips_suite(panel, VARS_DIFF, label="differences")
cips_diffs.to_csv(os.path.join(OUTPUT_DIR, "cips_unit_root_differences.csv"), index=False)
print(f"\n  → Saved: output/tables/cips_unit_root_*.csv")


# ═══════════════════════════════════════════════════════════════════════════════
# 3.  PESARAN & YAMAGATA (2008) SLOPE HOMOGENEITY TEST
# ═══════════════════════════════════════════════════════════════════════════════
# Tests H0: β_i = β (homogeneous slopes) for the main yield equation:
#   ln_verim = f(ln_gubre, ln_ticaret, dea_bc)

def pesaran_yamagata_test(df: pd.DataFrame, dep_var: str,
                          regressors: list[str]) -> dict:
    """
    Pesaran & Yamagata (2008) standardised slope homogeneity test.
    Δ̃     = √N · (S̃ − k) / √(2k)
    Δ̃_adj = √N · (S̃ − k) / √(2k(T−k−1)/(T−k+1))
    where S̃ = Σ_i (β̂_i − β̂_RE)' Ω̂_i^{-1} (β̂_i − β̂_RE) (Swamy stat)
    Under H0: Δ̃, Δ̃_adj → N(0,1)
    """
    groups = df.groupby("iso3c")
    k      = len(regressors)
    betas  = []
    V_list = []   # individual covariance matrices
    T_list = []

    for iso, grp in groups:
        grp_s = grp[regressors + [dep_var]].dropna()
        Ti    = len(grp_s)
        if Ti < k + 2:
            continue
        Xi = grp_s[regressors].values
        yi = grp_s[dep_var].values
        Xi = np.column_stack([np.ones(Ti), Xi])   # add intercept
        try:
            beta_i = np.linalg.lstsq(Xi, yi, rcond=None)[0]
            ei     = yi - Xi @ beta_i
            s2_i   = np.sum(ei**2) / (Ti - k - 1)
            Vi     = s2_i * np.linalg.inv(Xi.T @ Xi)
        except np.linalg.LinAlgError:
            continue
        betas.append(beta_i[1:])   # drop intercept for slope test
        V_list.append(Vi[1:, 1:])  # drop intercept block
        T_list.append(Ti)

    if len(betas) < 3:
        return {"error": "insufficient units"}

    N_eff  = len(betas)
    # FGLS pooled estimate: β̂_RE = (Σ V_i^{-1})^{-1} (Σ V_i^{-1} β̂_i)
    sum_Vi_inv    = sum(np.linalg.inv(V) for V in V_list)
    sum_Vi_inv_b  = sum(np.linalg.inv(V) @ b for V, b in zip(V_list, betas))
    try:
        beta_re = np.linalg.solve(sum_Vi_inv, sum_Vi_inv_b)
    except np.linalg.LinAlgError:
        beta_re = np.mean(betas, axis=0)

    # Swamy statistic
    S_tilde = sum(
        float((b - beta_re) @ np.linalg.inv(V) @ (b - beta_re))
        for b, V in zip(betas, V_list)
    )

    T_avg = np.mean(T_list)
    denom_std  = np.sqrt(2 * k)
    denom_adj  = np.sqrt(2 * k * (T_avg - k - 1) / (T_avg - k + 1))

    delta_tilde     = np.sqrt(N_eff) * (S_tilde / N_eff - k) / denom_std
    delta_tilde_adj = np.sqrt(N_eff) * (S_tilde / N_eff - k) / denom_adj

    p_delta     = 2 * (1 - norm.cdf(abs(delta_tilde)))
    p_delta_adj = 2 * (1 - norm.cdf(abs(delta_tilde_adj)))

    def stars(p):
        return "***" if p < 0.01 else ("**" if p < 0.05 else ("*" if p < 0.10 else ""))

    return {
        "N_units": N_eff, "k": k, "T_avg": round(T_avg, 1),
        "S_tilde": round(S_tilde, 4),
        "Delta_tilde":     round(delta_tilde, 4),
        "p_Delta":         round(p_delta,     4),
        "Sig_Delta":       stars(p_delta),
        "Delta_tilde_adj": round(delta_tilde_adj, 4),
        "p_Delta_adj":     round(p_delta_adj,     4),
        "Sig_Delta_adj":   stars(p_delta_adj),
        "Decision":        "Heterogeneous" if p_delta < 0.05 else "Homogeneous"
    }


print("\n" + "="*70)
print("3. PESARAN-YAMAGATA (2008) SLOPE HOMOGENEITY")
print("="*70)

# Main yield equation regressors
SH_REGRESSORS = ["ln_gubre", "ln_ticaret", "dea_bc"]

# Only keep rows where dea_bc is non-missing
panel_sh = panel.dropna(subset=["dea_bc"])

sh_result = pesaran_yamagata_test(panel_sh, dep_var="ln_verim",
                                  regressors=SH_REGRESSORS)
print(f"  Δ̃     = {sh_result.get('Delta_tilde', 'NA'):>8.4f}  "
      f"p = {sh_result.get('p_Delta', 'NA'):.4f}  {sh_result.get('Sig_Delta', '')}")
print(f"  Δ̃_adj = {sh_result.get('Delta_tilde_adj', 'NA'):>8.4f}  "
      f"p = {sh_result.get('p_Delta_adj', 'NA'):.4f}  {sh_result.get('Sig_Delta_adj', '')}")
print(f"  Decision: {sh_result.get('Decision', 'NA')}")

sh_df = pd.DataFrame([sh_result])
sh_df.to_csv(os.path.join(OUTPUT_DIR, "slope_homogeneity_test.csv"), index=False)
print(f"\n  → Saved: output/tables/slope_homogeneity_test.csv")


# ═══════════════════════════════════════════════════════════════════════════════
# 4.  WESTERLUND (2007) PANEL COINTEGRATION TEST
# ═══════════════════════════════════════════════════════════════════════════════
# Equation: Δy_{it} = δ'_i·d_t + α_i·(y_{i,t-1} − β'_i·x_{i,t-1})
#                      + Σ_{j=1}^{p} Γ_{ij}·ΔW_{i,t-j} + ε_{it}
# Statistics:
#   Gt = (1/N) Σ_i [α̂_i / SE(α̂_i)]        (group-mean t)
#   Ga = (1/N) Σ_i [T·α̂_i / α̂_i(1)]       (group-mean alpha; α̂_i(1) = Newey-West at lag 0 ≈ ĉ_i)
#   Pt = α̂_pool / SE(α̂_pool)               (panel t)
#   Pa = T · α̂_pool                         (panel alpha)
# H0: no cointegration (α_i = 0 ∀i)
# H1 (Ga, Gt): some units cointegrated; (Pa, Pt): all units cointegrated
# Bootstrap preserves cross-section dependence via joint residual resampling.

DEP_VAR  = "ln_verim"
X_VARS   = ["ln_gubre", "ln_ticaret", "dea_bc"]
LAGS     = 1   # ECM augmentation lags
N_BOOT   = 499   # bootstrap replications


def _ecm_alpha(y_i: np.ndarray, X_i: np.ndarray, p: int = 1) -> tuple:
    """
    Estimate α_i (ECT speed) from the ECM:
      Δy_t = c + α·y_{t-1} + γ·x_{t-1} + Σ_{j=1}^p Λ·ΔW_{t-j} + ε_t
    Returns: (alpha_hat, se_alpha, T_used, residuals_full_length)
    """
    T_   = len(y_i)
    dy   = np.diff(y_i)                          # (T_-1,)
    dX   = np.diff(X_i, axis=0)                  # (T_-1, k)

    start = p
    n_obs = T_ - 1 - p

    if n_obs < 5:
        return np.nan, np.nan, 0, np.zeros(T_)

    dep  = dy[start:]                            # Δy_t

    cols = [np.ones(n_obs),
            y_i[start : T_ - 1],                # y_{t-1}
            X_i[start : T_ - 1, :]]             # x_{t-1}
    for j in range(1, p + 1):
        cols.append(dy[start - j: start - j + n_obs])   # Δy_{t-j}
        cols.append(dX[start - j: start - j + n_obs, :])  # ΔX_{t-j}

    Xmat = np.column_stack([c.reshape(n_obs, -1) if c.ndim == 1
                             else c for c in cols])

    try:
        beta, _, rank, _ = np.linalg.lstsq(Xmat, dep, rcond=None)
        resid = dep - Xmat @ beta
        s2    = np.sum(resid**2) / max(n_obs - Xmat.shape[1], 1)
        xtxi  = np.linalg.inv(Xmat.T @ Xmat)
        alpha = beta[1]   # index 0=intercept, 1=y_{t-1} → α̂
        se    = np.sqrt(s2 * xtxi[1, 1])
        # Pad residuals to length T_ with zeros at start
        pad   = np.zeros(T_ - len(resid))
        resid_full = np.concatenate([pad, resid])
        return alpha, se, n_obs, resid_full
    except (np.linalg.LinAlgError, ValueError):
        return np.nan, np.nan, 0, np.zeros(T_)


def westerlund_stats(df: pd.DataFrame, dep: str, xvars: list[str],
                     p: int = 1) -> tuple[dict, dict]:
    """
    Compute Gt, Ga, Pt, Pa statistics.
    Returns: (stats_dict, residuals_dict {iso3c: array})
    """
    groups  = df.groupby("iso3c")
    alphas, ses, T_list = [], [], []
    resid_dict = {}

    for iso, grp in groups:
        grp_s = grp[[dep] + xvars].dropna().sort_index()
        if len(grp_s) < p + 4:
            continue
        y_i = grp_s[dep].values
        X_i = grp_s[xvars].values
        a, se, Ti, res = _ecm_alpha(y_i, X_i, p=p)
        if np.isnan(a):
            continue
        alphas.append(a)
        ses.append(se)
        T_list.append(Ti)
        resid_dict[iso] = res

    N_e   = len(alphas)
    T_avg = np.mean(T_list) if T_list else np.nan

    # Group-mean statistics
    Gt    = np.mean([a / s for a, s in zip(alphas, ses) if s > 0])
    Ga    = (1 / N_e) * np.sum([T_avg * a for a in alphas])

    # Pooled statistics
    # α_pool = Σ(α_i/se_i²) / Σ(1/se_i²)  [GLS pooling]
    weights = [1 / s**2 for s in ses if s > 0]
    w_alphas = [a / s**2 for a, s in zip(alphas, ses) if s > 0]
    if sum(weights) > 0:
        alpha_pool = sum(w_alphas) / sum(weights)
        se_pool    = 1 / np.sqrt(sum(weights))
    else:
        alpha_pool, se_pool = np.mean(alphas), np.nan

    Pt = alpha_pool / se_pool if se_pool and se_pool > 0 else np.nan
    Pa = T_avg * alpha_pool

    stats = {"N": N_e, "T_avg": round(T_avg, 1),
             "Gt": round(Gt, 4), "Ga": round(Ga, 4),
             "Pt": round(Pt, 4) if not np.isnan(Pt) else np.nan,
             "Pa": round(Pa, 4)}
    return stats, resid_dict


def bootstrap_westerlund(df: pd.DataFrame, dep: str, xvars: list[str],
                          p: int = 1, B: int = 499,
                          seed: int = 2026) -> dict[str, float]:
    """
    Sieve bootstrap p-values for Gt, Ga, Pt, Pa.
    Null: α_i = 0 for all i (impose by setting y_null_{it} = cumsum(residuals)).
    Resample cross-sectional residuals jointly to preserve CD.
    """
    rng = np.random.default_rng(seed)

    # Step 1: observed stats
    obs_stats, resid_dict = westerlund_stats(df, dep, xvars, p=p)
    if "N" not in obs_stats:
        return {k: np.nan for k in ["Gt_p", "Ga_p", "Pt_p", "Pa_p"]}

    codes_w  = list(resid_dict.keys())
    N_w      = len(codes_w)
    T_max    = max(len(v) for v in resid_dict.values())

    # Build residual matrix (T_max × N_w), pad short series with 0
    resid_mat = np.zeros((T_max, N_w))
    for i, c in enumerate(codes_w):
        r = resid_dict[c]
        resid_mat[-len(r):, i] = r

    # Bootstrap distribution under H0
    boot_gt, boot_ga, boot_pt, boot_pa = [], [], [], []

    # Sieve block length (rule-of-thumb: int(T^0.25))
    block = max(1, int(T_max**0.25))

    for _ in range(B):
        # Block bootstrap of residuals (preserves cross-section dependence)
        idx_pool = np.arange(T_max)
        n_blocks  = int(np.ceil(T_max / block))
        starts    = rng.integers(0, max(1, T_max - block + 1), size=n_blocks)
        boot_idx  = np.concatenate([np.arange(s, min(s + block, T_max)) for s in starts])
        boot_idx  = boot_idx[:T_max]
        e_boot    = resid_mat[boot_idx, :]   # (T_max × N_w)

        # Generate null data: y*_{it} = cumsum(e*_{it}) (random walk under H0)
        y_null = np.cumsum(e_boot, axis=0)   # (T_max × N_w)

        # Reconstruct a temporary DataFrame
        rows = []
        for k_idx, c in enumerate(codes_w):
            for t_idx, yr in enumerate(range(2000, 2000 + T_max)):
                xrow = df.loc[(df["iso3c"] == c), xvars].dropna().values
                if len(xrow) > 0 and t_idx < len(xrow):
                    row = {"iso3c": c, "year": yr,
                           dep: y_null[t_idx, k_idx]}
                    row.update({v: xrow[min(t_idx, len(xrow)-1), j]
                                for j, v in enumerate(xvars)})
                    rows.append(row)

        if not rows:
            continue
        df_boot = pd.DataFrame(rows)
        try:
            bs, _ = westerlund_stats(df_boot, dep, xvars, p=p)
        except Exception:
            continue

        if "Gt" in bs:
            boot_gt.append(bs["Gt"])
            boot_ga.append(bs["Ga"])
            boot_pt.append(bs["Pt"] if not np.isnan(bs.get("Pt", np.nan)) else 0)
            boot_pa.append(bs["Pa"])

    def p_left(obs_val, boot_dist):
        """Left-tailed p-value (H1: stat << 0)."""
        bd = np.array([x for x in boot_dist if not np.isnan(x)])
        if len(bd) == 0:
            return np.nan
        return float(np.mean(bd <= obs_val))

    p_vals = {
        "Gt_p": p_left(obs_stats["Gt"], boot_gt),
        "Ga_p": p_left(obs_stats["Ga"], boot_ga),
        "Pt_p": p_left(obs_stats["Pt"], boot_pt) if not np.isnan(obs_stats["Pt"]) else np.nan,
        "Pa_p": p_left(obs_stats["Pa"], boot_pa),
    }
    return p_vals


print("\n" + "="*70)
print("4. WESTERLUND (2007) PANEL COINTEGRATION")
print(f"   Dep: {DEP_VAR}  |  Regressors: {X_VARS}")
print(f"   N_boot = {N_BOOT}  (sieve bootstrap, preserves CD)")
print("="*70)

# Only use rows with complete data
panel_w = panel.dropna(subset=[DEP_VAR] + X_VARS)

print("  Computing observed statistics…")
obs, resid_d = westerlund_stats(panel_w, DEP_VAR, X_VARS, p=LAGS)
print(f"  Gt = {obs['Gt']:7.4f}   Ga = {obs['Ga']:8.4f}")
print(f"  Pt = {obs['Pt']:7.4f}   Pa = {obs['Pa']:8.4f}")

print(f"  Running sieve bootstrap (B={N_BOOT})… ", end="", flush=True)
p_vals = bootstrap_westerlund(panel_w, DEP_VAR, X_VARS,
                               p=LAGS, B=N_BOOT, seed=SEED)
print("done.")

def sig_stars(p):
    if np.isnan(p): return ""
    return "***" if p < 0.01 else ("**" if p < 0.05 else ("*" if p < 0.10 else ""))

print(f"\n  Gt = {obs['Gt']:7.4f}   p_boot = {p_vals['Gt_p']:.4f}  {sig_stars(p_vals['Gt_p'])}")
print(f"  Ga = {obs['Ga']:8.4f}   p_boot = {p_vals['Ga_p']:.4f}  {sig_stars(p_vals['Ga_p'])}")
print(f"  Pt = {obs['Pt']:7.4f}   p_boot = {p_vals['Pt_p']:.4f}  {sig_stars(p_vals['Pt_p'])}")
print(f"  Pa = {obs['Pa']:8.4f}   p_boot = {p_vals['Pa_p']:.4f}  {sig_stars(p_vals['Pa_p'])}")

wrl_record = {**{k: v for k, v in obs.items()},
              "Gt_p_boot": round(p_vals["Gt_p"], 4),
              "Ga_p_boot": round(p_vals["Ga_p"], 4),
              "Pt_p_boot": round(p_vals["Pt_p"], 4) if not np.isnan(p_vals["Pt_p"]) else np.nan,
              "Pa_p_boot": round(p_vals["Pa_p"], 4),
              "Gt_sig": sig_stars(p_vals["Gt_p"]),
              "Ga_sig": sig_stars(p_vals["Ga_p"]),
              "Pt_sig": sig_stars(p_vals["Pt_p"]),
              "Pa_sig": sig_stars(p_vals["Pa_p"]),
              "H1_type": "Group-mean (some i cointegrated)",
              "Dep": DEP_VAR,
              "Regressors": str(X_VARS),
              "Lags": LAGS, "N_boot": N_BOOT}

wrl_df = pd.DataFrame([wrl_record])
wrl_df.to_csv(os.path.join(OUTPUT_DIR, "westerlund_cointegration.csv"), index=False)
print(f"\n  → Saved: output/tables/westerlund_cointegration.csv")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. SUMMARY PRINT
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*70)
print("DIAGNOSTIC SUMMARY")
print("="*70)
print(f"\nPanel: N={N}, T={T}, obs={N*T}")
print(f"\nCD Test: Cross-section dependence present? →")
sig_cd = cd_levels[cd_levels["Sig"].str.len() > 0]
print(f"  {len(sig_cd)}/{len(cd_levels)} level variables show significant CD (→ 2nd-gen tests mandatory)")

print(f"\nCIPS (levels, intercept):")
lev_int = cips_levels[cips_levels["Specification"] == "Intercept"]
n_i0    = (lev_int["Decision"] == "I(0)").sum()
n_i1    = (lev_int["Decision"] == "I(1)").sum()
print(f"  I(0): {n_i0}   I(1): {n_i1}   → {'ARDL/CS-ARDL appropriate' if n_i1 > 0 else 'All stationary'}")

print(f"\nSlope Homogeneity (Δ̃_adj):")
print(f"  Δ̃_adj = {sh_result.get('Delta_tilde_adj','NA')}  "
      f"p = {sh_result.get('p_Delta_adj','NA')}  {sh_result.get('Sig_Delta_adj','')}")
print(f"  → CS-ARDL/PMG (heterogeneous slopes) required: {sh_result.get('Decision','NA')}")

print(f"\nWesterlund (2007) cointegration:")
print(f"  Gt={obs['Gt']:.4f} ({sig_stars(p_vals['Gt_p'])}),  "
      f"Ga={obs['Ga']:.4f} ({sig_stars(p_vals['Ga_p'])}),  "
      f"Pt={obs['Pt']:.4f} ({sig_stars(p_vals['Pt_p'])}),  "
      f"Pa={obs['Pa']:.4f} ({sig_stars(p_vals['Pa_p'])})")
coint_confirmed = any(
    not np.isnan(p) and p < 0.05
    for p in [p_vals["Gt_p"], p_vals["Ga_p"], p_vals["Pt_p"], p_vals["Pa_p"]]
)
print(f"  → Long-run relationship confirmed: {coint_confirmed}")

print("\n" + "="*70)
print("ALL OUTPUTS SAVED TO output/tables/")
print("="*70)
