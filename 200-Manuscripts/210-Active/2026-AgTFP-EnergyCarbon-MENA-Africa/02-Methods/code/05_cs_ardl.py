"""
05_cs_ardl.py
=============
AgTFP-EnergyCarbon-MENA-Africa Project — CS-ARDL / PMG-ECM Estimation
Author : M. Gökhan Özdemir (Kırıkkale University)
Date   : 2026-04-10
Version: 1.0

Prerequisites (confirmed from 04_panel_diagnostics.py):
  ✓ Cross-section dependence: Pesaran CD significant (4/7 variables) → 2nd-gen mandatory
  ✓ Unit roots: predominantly I(1) in levels, I(0) in differences → ARDL order valid
  ✓ Slope heterogeneity: Δ̃_adj=26.88*** → heterogeneous slopes → CS-ARDL (not pooled FE)
  ✓ Cointegration: Westerlund Gt=−2.08, Ga=−16.17, Pt=−6.84, Pa=−10.17 (bootstrap needed)

Specification — Main Equation:
  ln_verim_{it} = α_i + β_{1i}·ln_gubre_{it} + β_{2i}·ln_ticaret_{it}
                + β_{3i}·DEA_BC_{it} + β_{4i}·ln_ekipman_{it}
                + cross-section augmentation terms + ε_{it}

Models:
  M1: ln_verim ~ ln_gubre + ln_ticaret + dea_bc  (baseline)
  M2: ln_verim ~ ln_gubre + ln_ticaret + dea_bc + ln_ekipman  (extended)

CS-ARDL(p,q): Cross-sectionally Augmented ARDL
  Step 1: Cross-section demeaning + CS augmentation
  Step 2: Individual ARDL(p,q) per country with CS means as extra regressors
  Step 3: Mean Group (MG) aggregation of long-run coefficients
  Step 4: ECT speed-of-adjustment: φ̂_i from ECM reparametrisation
  Step 5: Webb (2023) wild cluster bootstrap CIs (N=22 < 30 → mandatory)

Reference: Chudik & Pesaran (2015), Eberhardt & Teal (2011)

Outputs:
  output/tables/csardl_m1_long_run.csv
  output/tables/csardl_m2_long_run.csv
  output/tables/csardl_country_ecm.csv
  output/tables/csardl_m1_webb_ci.csv
  output/tables/csardl_m2_webb_ci.csv

Usage:
  python3 code/05_cs_ardl.py
"""

import warnings
warnings.filterwarnings("ignore")

import numpy as np
import pandas as pd
from scipy import stats
from scipy.stats import norm
import os

BASE       = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR   = os.path.join(BASE, "data")
OUTPUT_DIR = os.path.join(BASE, "output", "tables")
os.makedirs(OUTPUT_DIR, exist_ok=True)

SEED = 2026
rng  = np.random.default_rng(SEED)

# ─── Load Data ───────────────────────────────────────────────────────────────
panel = pd.read_csv(os.path.join(DATA_DIR, "panel_main_extended.csv"))
panel = panel.sort_values(["iso3c", "year"]).reset_index(drop=True)

sw = pd.read_csv(os.path.join(OUTPUT_DIR, "sw_dea_scores_biascorrected.csv"))
sw = sw[["iso3c", "year", "theta_bc"]].rename(columns={"theta_bc": "dea_bc"})
panel = panel.merge(sw, on=["iso3c", "year"], how="left")

countries = sorted(panel["iso3c"].unique())
N = len(countries)
print(f"Panel: N={N}, T_periods={panel['year'].nunique()}, obs={len(panel)}")

# ═══════════════════════════════════════════════════════════════════════════════
# CS-ARDL ESTIMATOR
# ═══════════════════════════════════════════════════════════════════════════════

def cs_ardl_country(y_i: np.ndarray,
                     X_i: np.ndarray,
                     y_bar: np.ndarray,
                     X_bar: np.ndarray,
                     p: int = 1,
                     q: int = 1) -> dict:
    """
    CS-ARDL(p,q) for a single country i.

    ECM reparametrisation:
      Δy_t = φ_i·[y_{t-1} − θ_i·x_{t-1}]
             + Σ_{j=0}^{q-1} δ_j·Δx_{t-j}
             + Σ_{j=1}^{p-1} ρ_j·Δy_{t-j}
             + Σ_{j=0}^{p} [ψ_j·ȳ_{t-j} + Σ_l ξ_{jl}·x̄_{l,t-j}]
             + c_i + ε_{it}

    Long-run: θ̂_i = −(Σ β̂_{x,j}) / φ̂_i   [ratio of ARDL coefficients]
    ECT speed: φ̂_i (should be < 0 for cointegration)

    Returns dict with: phi (ECT speed), phi_se, theta (long-run by var),
                       theta_se, n_obs, converged
    """
    T_  = len(y_i)
    k   = X_i.shape[1]
    dy  = np.diff(y_i)
    dX  = np.diff(X_i, axis=0)
    dyb = np.diff(y_bar)
    dXb = np.diff(X_bar, axis=0)

    # Effective start after lags
    start = max(p, q)
    n_obs = T_ - 1 - start
    if n_obs < k + p + q + 3:
        return {"phi": np.nan, "phi_se": np.nan,
                "theta": [np.nan] * k, "theta_se": [np.nan] * k,
                "n_obs": 0, "converged": False}

    dep = dy[start:]  # Δy_t

    cols = []
    # 1. Intercept
    cols.append(np.ones(n_obs))
    # 2. y_{t-1} (ECT level term)
    cols.append(y_i[start: T_ - 1])
    # 3. X_{t-1} (ECT regressor terms, k columns)
    cols.append(X_i[start: T_ - 1, :])
    # 4. Δx_{t-j}, j=0..q-1
    for j in range(q):
        sl = dX[start - j: start - j + n_obs, :]
        cols.append(sl)
    # 5. Δy_{t-j}, j=1..p-1
    for j in range(1, p):
        cols.append(dy[start - j: start - j + n_obs])
    # 6. CS augmentation: ȳ_{t-j}, j=0..p  (Chudik-Pesaran 2015 rule: p+1 lags)
    for j in range(p + 1):
        s_ = start - j
        e_ = s_ + n_obs
        if e_ <= len(y_bar):
            cols.append(y_bar[s_: e_])
        else:
            cols.append(np.zeros(n_obs))
        # Also include lagged cross-section means of X regressors
        if e_ <= dXb.shape[0] + 1:
            if j == 0:
                # Level of X̄_{t} needed → use X_bar directly
                sl_xb = X_bar[s_: e_, :]
            else:
                sl_xb = X_bar[s_: e_, :]
            cols.append(sl_xb)
        else:
            cols.append(np.zeros((n_obs, k)))

    X_mat = np.column_stack([
        c.reshape(n_obs, -1) if c.ndim == 1 else c for c in cols
    ])

    try:
        beta, _, rank, _ = np.linalg.lstsq(X_mat, dep, rcond=None)
        e   = dep - X_mat @ beta
        s2  = np.sum(e**2) / max(n_obs - X_mat.shape[1], 1)
        # HC1-style covariance (heteroskedasticity-robust)
        XtX_inv = np.linalg.inv(X_mat.T @ X_mat)
        S_meat  = X_mat.T @ np.diag(e**2) @ X_mat
        V_hc1   = (n_obs / (n_obs - X_mat.shape[1])) * XtX_inv @ S_meat @ XtX_inv
    except (np.linalg.LinAlgError, ValueError):
        return {"phi": np.nan, "phi_se": np.nan,
                "theta": [np.nan] * k, "theta_se": [np.nan] * k,
                "n_obs": 0, "converged": False}

    # Extract φ̂_i = beta[1]  (coefficient on y_{t-1})
    phi    = beta[1]
    phi_se = np.sqrt(max(V_hc1[1, 1], 0))

    # Extract long-run coefficients: θ̂ = −β_x / φ̂
    # Coefficients on X_{t-1}: indices 2 through 2+k-1
    beta_x = beta[2: 2 + k]           # k-vector
    # Delta method SEs: SE(θ) ≈ |∂θ/∂β_x|·SE(β_x) + |∂θ/∂φ|·SE(φ)
    theta    = -beta_x / phi if phi != 0 else np.full(k, np.nan)
    # Approximate SEs via delta method
    theta_se = np.zeros(k)
    for j in range(k):
        idx_x  = 2 + j
        if abs(phi) < 1e-10:
            theta_se[j] = np.nan
        else:
            d_bx = -1 / phi
            d_ph = beta_x[j] / (phi**2)
            # Covariance terms
            var_bx = max(V_hc1[idx_x, idx_x], 0)
            var_ph = max(V_hc1[1, 1], 0)
            cov_bx_ph = V_hc1[idx_x, 1]
            var_th = (d_bx**2 * var_bx
                      + d_ph**2 * var_ph
                      + 2 * d_bx * d_ph * cov_bx_ph)
            theta_se[j] = np.sqrt(max(var_th, 0))

    return {"phi": phi, "phi_se": phi_se,
            "theta": list(theta), "theta_se": list(theta_se),
            "n_obs": n_obs, "converged": True,
            "residuals": e, "n_params": X_mat.shape[1]}


def cs_ardl_mg(df: pd.DataFrame,
               dep_var: str,
               x_vars: list[str],
               p: int = 1,
               q: int = 1) -> dict:
    """
    Cross-Sectionally Augmented ARDL Mean Group estimator.
    Computes country-by-country CS-ARDL, then aggregates via MG.
    """
    k = len(x_vars)
    cs_list = sorted(df["iso3c"].unique())
    N_      = len(cs_list)

    # Build balanced panel matrices
    results = {}
    phi_list, phi_se_list = [], []
    theta_list = [[] for _ in range(k)]
    theta_se_list = [[] for _ in range(k)]

    for c in cs_list:
        grp = df.loc[df["iso3c"] == c].sort_values("year")
        data_cols = [dep_var] + x_vars
        sub = grp[data_cols].dropna()
        if len(sub) < max(p, q) + k + 5:
            continue

        y_i = sub[dep_var].values
        X_i = sub[x_vars].values
        Ti  = len(y_i)

        # Cross-section means: align on year
        yrs_i  = grp.loc[sub.index, "year"].values
        y_bar  = np.array([
            df.loc[df["year"] == yr, dep_var].mean() for yr in yrs_i
        ])
        X_bar  = np.column_stack([
            [df.loc[df["year"] == yr, xv].mean() for yr in yrs_i]
            for xv in x_vars
        ])

        res = cs_ardl_country(y_i, X_i, y_bar, X_bar, p=p, q=q)
        results[c] = res

        if res["converged"] and not np.isnan(res["phi"]):
            phi_list.append(res["phi"])
            phi_se_list.append(res["phi_se"])
            for j in range(k):
                if not np.isnan(res["theta"][j]):
                    theta_list[j].append(res["theta"][j])
                    theta_se_list[j].append(res["theta_se"][j])

    N_eff = len(phi_list)
    if N_eff == 0:
        return {"error": "No valid units"}

    # MG estimates
    phi_mg    = np.mean(phi_list)
    phi_mg_se = np.std(phi_list, ddof=1) / np.sqrt(N_eff)  # MG SE

    theta_mg    = [np.mean(tl) if tl else np.nan for tl in theta_list]
    theta_mg_se = [np.std(tl, ddof=1) / np.sqrt(len(tl)) if len(tl) > 1 else np.nan
                   for tl in theta_list]

    def t_stat(est, se): return est / se if se and se > 0 else np.nan
    def sig_stars(t):
        if np.isnan(t): return ""
        p = 2 * (1 - stats.t.cdf(abs(t), df=max(N_eff - 1, 1)))
        return "***" if p < 0.01 else ("**" if p < 0.05 else ("*" if p < 0.10 else ""))

    return {
        "N_eff": N_eff,
        "phi_mg": phi_mg, "phi_mg_se": phi_mg_se,
        "phi_t":  t_stat(phi_mg, phi_mg_se),
        "phi_sig": sig_stars(t_stat(phi_mg, phi_mg_se)),
        "theta_mg": theta_mg,
        "theta_mg_se": theta_mg_se,
        "theta_t": [t_stat(theta_mg[j], theta_mg_se[j]) for j in range(k)],
        "theta_sig": [sig_stars(t_stat(theta_mg[j], theta_mg_se[j])) for j in range(k)],
        "x_vars": x_vars,
        "country_results": results,
        "phi_list": phi_list, "theta_list": theta_list
    }


# ═══════════════════════════════════════════════════════════════════════════════
# WEBB (2023) WILD CLUSTER BOOTSTRAP
# ═══════════════════════════════════════════════════════════════════════════════

WEBB_WEIGHTS = np.array([
    -np.sqrt(3/2), -1.0, -np.sqrt(1/2),
     np.sqrt(1/2),  1.0,  np.sqrt(3/2)
])

def webb_bootstrap_ci(phi_list: list[float],
                       theta_lists: list[list[float]],
                       B: int = 999,
                       alpha: float = 0.05) -> dict:
    """
    Webb (2023) six-point wild cluster bootstrap CIs.
    Treats each country as a cluster; resamples MG estimates.
    N < 30 → six-point discrete distribution mandatory (Cameron et al. 2008).

    phi_list     : list of country-level ECT speeds
    theta_lists  : list of lists (one per X variable) of country-level LR coefficients
    Returns: dict with CI bounds for phi and each theta
    """
    np.random.seed(SEED)
    N_c = len(phi_list)
    k   = len(theta_lists)

    phi_arr    = np.array(phi_list)
    theta_arrs = [np.array(tl) for tl in theta_lists]

    phi_boot   = np.zeros(B)
    theta_boot = [np.zeros(B) for _ in range(k)]

    phi_mg = np.mean(phi_arr)
    phi_c  = phi_arr - phi_mg          # centered (impose H0: φ_MG = 0 for CI)

    theta_mg  = [np.mean(ta) for ta in theta_arrs]
    theta_c   = [ta - tm for ta, tm in zip(theta_arrs, theta_mg)]

    for b in range(B):
        # Draw Webb weights for each cluster
        w = np.random.choice(WEBB_WEIGHTS, size=N_c, replace=True)
        # Perturb centered scores
        phi_star     = phi_mg  + np.mean(phi_c  * w)
        phi_boot[b]  = phi_star
        for j in range(k):
            tc = theta_c[j]
            if len(tc) == N_c:
                theta_boot[j][b] = theta_mg[j] + np.mean(tc * w)
            else:
                theta_boot[j][b] = theta_mg[j]

    alpha_half = alpha / 2
    result = {
        "phi_ci_lo":  np.quantile(phi_boot, alpha_half),
        "phi_ci_hi":  np.quantile(phi_boot, 1 - alpha_half),
        "phi_p_webb": float(np.mean(phi_boot >= 0)),   # H1: φ < 0
    }
    for j, tl in enumerate(theta_lists):
        lo = np.quantile(theta_boot[j], alpha_half)
        hi = np.quantile(theta_boot[j], 1 - alpha_half)
        result[f"theta_{j}_ci_lo"] = lo
        result[f"theta_{j}_ci_hi"] = hi
        result[f"theta_{j}_ci_excludes_zero"] = not (lo <= 0 <= hi)

    return result


# ═══════════════════════════════════════════════════════════════════════════════
# MODEL ESTIMATION
# ═══════════════════════════════════════════════════════════════════════════════

MODELS = {
    "M1": ["ln_gubre", "ln_ticaret", "dea_bc"],
    "M2": ["ln_gubre", "ln_ticaret", "dea_bc", "ln_ekipman"],
}
DEP_VAR = "ln_verim"
B_WEBB  = 999   # Bootstrap replications (increase to 9999 for submission)

all_lr_records  = []
all_ecm_records = []
webb_ci_records = []

for model_name, x_vars in MODELS.items():
    print(f"\n{'='*70}")
    print(f"MODEL {model_name}: {DEP_VAR} ~ {x_vars}")
    print(f"{'='*70}")

    # Drop rows with any missing in dep + regressors
    panel_m = panel.dropna(subset=[DEP_VAR] + x_vars)
    print(f"  N={panel_m['iso3c'].nunique()}, obs={len(panel_m)}")

    # Estimate CS-ARDL MG
    mg = cs_ardl_mg(panel_m, DEP_VAR, x_vars, p=1, q=1)

    if "error" in mg:
        print(f"  ERROR: {mg['error']}")
        continue

    N_e = mg["N_eff"]
    print(f"  N_eff (converged) = {N_e}")
    print(f"\n  ECT speed-of-adjustment (φ̂_MG):")
    print(f"    φ̂ = {mg['phi_mg']:.4f}  SE={mg['phi_mg_se']:.4f}  "
          f"t={mg['phi_t']:.3f}  {mg['phi_sig']}")

    print(f"\n  Long-run MG coefficients (θ̂_MG = −β_x/φ):")
    for j, xv in enumerate(x_vars):
        print(f"    {xv:20s}  θ̂={mg['theta_mg'][j]:8.4f}  "
              f"SE={mg['theta_mg_se'][j]:.4f}  "
              f"t={mg['theta_t'][j]:.3f}  {mg['theta_sig'][j]}")

    # Webb bootstrap CIs
    print(f"\n  Running Webb bootstrap (B={B_WEBB})… ", end="", flush=True)
    k_ = len(x_vars)
    theta_lists_clean = []
    N_min = N_e
    for j in range(k_):
        tl = [r["theta"][j] for r in mg["country_results"].values()
              if r["converged"] and not np.isnan(r["theta"][j])]
        theta_lists_clean.append(tl)
        N_min = min(N_min, len(tl))

    phi_clean = [r["phi"] for r in mg["country_results"].values()
                 if r["converged"] and not np.isnan(r["phi"])]

    if len(phi_clean) >= 6:
        webb = webb_bootstrap_ci(phi_clean, theta_lists_clean,
                                  B=B_WEBB, alpha=0.05)
        print("done.")
        print(f"    φ̂ Webb 95% CI: [{webb['phi_ci_lo']:.4f}, {webb['phi_ci_hi']:.4f}]  "
              f"p_H1 = {webb['phi_p_webb']:.4f}")
        for j, xv in enumerate(x_vars):
            lo = webb.get(f"theta_{j}_ci_lo", np.nan)
            hi = webb.get(f"theta_{j}_ci_hi", np.nan)
            excl = webb.get(f"theta_{j}_ci_excludes_zero", False)
            print(f"    {xv:20s}  CI: [{lo:.4f}, {hi:.4f}]  "
                  f"excl_zero={excl}")
    else:
        webb = {}
        print("skipped (too few valid units)")

    # ── Save long-run table ──────────────────────────────────────────────────
    for j, xv in enumerate(x_vars):
        lo  = webb.get(f"theta_{j}_ci_lo", np.nan)
        hi  = webb.get(f"theta_{j}_ci_hi", np.nan)
        all_lr_records.append({
            "Model": model_name,
            "Variable": xv,
            "theta_MG": round(mg["theta_mg"][j], 4),
            "SE_MG": round(mg["theta_mg_se"][j], 4),
            "t_stat": round(mg["theta_t"][j], 3) if not np.isnan(mg["theta_t"][j]) else np.nan,
            "Sig_MG": mg["theta_sig"][j],
            "Webb_CI_lo": round(lo, 4) if not np.isnan(lo) else np.nan,
            "Webb_CI_hi": round(hi, 4) if not np.isnan(hi) else np.nan,
            "CI_excl_zero": webb.get(f"theta_{j}_ci_excludes_zero", ""),
        })

    # ECT speed row
    all_lr_records.append({
        "Model": model_name,
        "Variable": "ECT_phi",
        "theta_MG": round(mg["phi_mg"], 4),
        "SE_MG":    round(mg["phi_mg_se"], 4),
        "t_stat":   round(mg["phi_t"], 3) if not np.isnan(mg["phi_t"]) else np.nan,
        "Sig_MG":   mg["phi_sig"],
        "Webb_CI_lo": round(webb.get("phi_ci_lo", np.nan), 4) if webb else np.nan,
        "Webb_CI_hi": round(webb.get("phi_ci_hi", np.nan), 4) if webb else np.nan,
        "CI_excl_zero": "",
    })

    # Country-level ECM results
    for c, res in mg["country_results"].items():
        if not res["converged"]:
            continue
        grp_info = panel_m.loc[panel_m["iso3c"] == c, "group"].iloc[0] if len(
            panel_m.loc[panel_m["iso3c"] == c]) > 0 else "NA"
        row = {"Model": model_name, "iso3c": c, "group": grp_info,
               "phi": round(res["phi"], 4),
               "phi_se": round(res["phi_se"], 4),
               "phi_t": round(res["phi"] / res["phi_se"], 3) if res["phi_se"] > 0 else np.nan,
               "n_obs": res["n_obs"]}
        for j, xv in enumerate(x_vars):
            row[f"theta_{xv}"] = round(res["theta"][j], 4) if not np.isnan(res["theta"][j]) else np.nan
            row[f"se_{xv}"]    = round(res["theta_se"][j], 4) if not np.isnan(res["theta_se"][j]) else np.nan
        all_ecm_records.append(row)


# ─── Save outputs ────────────────────────────────────────────────────────────
lr_df  = pd.DataFrame(all_lr_records)
ecm_df = pd.DataFrame(all_ecm_records)

lr_df.to_csv(os.path.join(OUTPUT_DIR, "csardl_long_run.csv"), index=False)
ecm_df.to_csv(os.path.join(OUTPUT_DIR, "csardl_country_ecm.csv"), index=False)

print(f"\n{'='*70}")
print("SAVED:")
print(f"  output/tables/csardl_long_run.csv        ({len(lr_df)} rows)")
print(f"  output/tables/csardl_country_ecm.csv     ({len(ecm_df)} rows)")
print(f"{'='*70}")

# ─── Summary ─────────────────────────────────────────────────────────────────
print(f"\n{'='*70}")
print("CS-ARDL MG SUMMARY")
print(f"{'='*70}")
print(lr_df[lr_df["Variable"] != "ECT_phi"].to_string(index=False))
print(f"\nECT speeds (φ̂_MG):")
print(lr_df[lr_df["Variable"] == "ECT_phi"].to_string(index=False))

# ─── Interpretation note ──────────────────────────────────────────────────────
print(f"""
INTERPRETATION NOTES (Chudik-Pesaran 2015):
─────────────────────────────────────────────────────────────────────────────
1. ECT (φ̂_MG < 0, Webb CI excludes zero) → cointegration confirmed at unit level
2. Long-run θ̂ recovered as −(ARDL-x-coeff) / φ̂ → not directly comparable to CCEMG
   in magnitude; near-zero φ̂_i in some countries inflates MG average (see Webb CI width)
3. Webb CI is the primary inference tool (N=22 < 30 clusters)
4. If Webb CI includes zero: interpret as 'imprecisely estimated at panel level'
   but country-level sign may still be consistent (see csardl_country_ecm.csv)
5. For submission: increase B_WEBB to 9999 and re-run 05_cs_ardl.py locally
─────────────────────────────────────────────────────────────────────────────
""")
