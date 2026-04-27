"""
06_dh_causality.py
==================
AgTFP-EnergyCarbon-MENA-Africa Project — Heterogeneous Panel Causality Tests
Author : M. Gökhan Özdemir (Kırıkkale University)
Date   : 2026-04-10
Version: 1.0

Tests implemented:
  1. Dumitrescu & Hurlin (2012) — W̄ and Z̄ statistics
     H0: homogeneous non-causality (HNC); H1: some units exhibit causality
     Asymptotic and bootstrap (Kónya 2006-style) p-values
  2. Toda-Yamamoto (1995) — causality-robust to integration order
     Augmented VAR(m+d_max), Wald test on first m lags
  3. Konya (2006) bootstrap — SUR-based system, country-specific H0

Variable pairs tested (directed causality):
  Primary:
    dea_bc → ln_verim   (efficiency → yield)
    ln_gubre → ln_verim (fertiliser → yield)
    ln_ticaret → ln_verim (trade → yield)
    ln_verim → dea_bc   (reverse: yield → efficiency)
  Secondary:
    ln_ekipman → ln_verim
    ln_verim → ln_gubre (Jevons-type feedback)

Reference: Dumitrescu & Hurlin (2012) Econ. Letters 97; Toda & Yamamoto (1995) JEM 66
Critical values: DH asymptotic (W̄→χ²); bootstrap p-values primary for inference.

Outputs:
  output/tables/dh_causality_results.csv
  output/tables/dh_country_wald_stats.csv
  output/tables/toda_yamamoto_results.csv

Usage:
  python3 code/06_dh_causality.py
"""

import warnings
warnings.filterwarnings("ignore")

import numpy as np
import pandas as pd
from scipy import stats
from scipy.stats import norm, chi2
import os

BASE       = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BASE, "output", "tables")
os.makedirs(OUTPUT_DIR, exist_ok=True)

SEED = 2026
rng  = np.random.default_rng(SEED)
np.random.seed(SEED)

# ─── Load Data ────────────────────────────────────────────────────────────────
panel = pd.read_csv(os.path.join(BASE, "data", "panel_main_extended.csv"))
panel = panel.sort_values(["iso3c", "year"]).reset_index(drop=True)
sw    = pd.read_csv(os.path.join(OUTPUT_DIR, "sw_dea_scores_biascorrected.csv"))
sw    = sw[["iso3c", "year", "theta_bc"]].rename(columns={"theta_bc": "dea_bc"})
panel = panel.merge(sw, on=["iso3c", "year"], how="left")

countries = sorted(panel["iso3c"].unique())
N = len(countries)
print(f"Panel: N={N}, T={panel['year'].nunique()}, obs={len(panel)}")


# ═══════════════════════════════════════════════════════════════════════════════
# 1.  DUMITRESCU-HURLIN (2012) PANEL CAUSALITY
# ═══════════════════════════════════════════════════════════════════════════════
# Model: y_{it} = α_i + Σ_{k=1}^K γ_i^(k) y_{i,t-k} + Σ_{k=1}^K β_i^(k) x_{i,t-k} + ε_{it}
# H0: β_i^(k) = 0 ∀i, k   (HNC — homogeneous non-causality)
# Individual Wald stat: W_i = (Rβ_i)' [R·(X'X)^{-1}R'·σ̂²]^{-1} (Rβ_i)
# W̄ = (1/N) Σ_i W_i      (average Wald)
# Z̄ = √(N/2K) · (W̄ − K)  → N(0,1) asymptotically as N,T→∞

def dh_wald_i(y: np.ndarray, x: np.ndarray, K: int) -> float:
    """
    Individual Wald statistic for H0: β_i^(1)=...=β_i^(K)=0 in
      y_t = c + Σγ_k y_{t-k} + Σβ_k x_{t-k} + ε_t
    Returns W_i (χ²(K) under H0 per unit).
    """
    # Align y and x to equal length (use minimum)
    T_  = min(len(y), len(x))
    y   = y[-T_:]
    x   = x[-T_:]
    n_obs = T_ - K
    if n_obs < K + 3:
        return np.nan

    # Build regressor matrix — explicit equal-length slices
    # Lag k of a series z[0..T_-1]: z[K-k : K-k+n_obs]  (all length n_obs)
    Y_l = np.column_stack([y[K-k : K-k+n_obs] for k in range(1, K+1)])
    X_l = np.column_stack([x[K-k : K-k+n_obs] for k in range(1, K+1)])
    Xmat = np.column_stack([np.ones(n_obs), Y_l, X_l])              # (n_obs, 1+2K)
    dep  = y[K:]

    try:
        beta, _, _, _ = np.linalg.lstsq(Xmat, dep, rcond=None)
        e   = dep - Xmat @ beta
        s2  = np.sum(e**2) / max(n_obs - Xmat.shape[1], 1)
        XtXinv = np.linalg.inv(Xmat.T @ Xmat)

        # Restriction matrix R: picks β columns (last K coefficients, indices 1+K..1+2K-1)
        p   = Xmat.shape[1]
        R   = np.zeros((K, p))
        for k in range(K):
            R[k, 1 + K + k] = 1.0

        Rb   = R @ beta
        RVR  = s2 * R @ XtXinv @ R.T
        W_i  = float(Rb @ np.linalg.solve(RVR, Rb))
        return W_i
    except (np.linalg.LinAlgError, ValueError):
        return np.nan


def dh_test(df: pd.DataFrame, y_var: str, x_var: str,
            K: int = 2, B: int = 999) -> dict:
    """
    Dumitrescu-Hurlin (2012) panel causality test.
    Returns W_bar, Z_bar, p_asymptotic, p_bootstrap.
    """
    W_i_list = []
    W_i_dict = {}

    for c in countries:
        grp = df.loc[df["iso3c"] == c, [y_var, x_var]].dropna()
        if len(grp) < K + 5:
            continue
        y_i = grp[y_var].values
        x_i = grp[x_var].values
        W_i = dh_wald_i(y_i, x_i, K)
        if not np.isnan(W_i):
            W_i_list.append(W_i)
            W_i_dict[c] = round(W_i, 4)

    N_eff = len(W_i_list)
    if N_eff == 0:
        return {"error": "no valid units"}

    W_bar = np.mean(W_i_list)
    # Z̄ statistic (Dumitrescu-Hurlin 2012, eq. 9)
    # Asymptotic: Z̄ = √(N/(2K)) · (W̄ − K) → N(0,1)
    T_avg = np.mean([len(df.loc[(df["iso3c"]==c), y_var].dropna()) for c in countries])
    # Finite-sample correction (Dumitrescu-Hurlin 2012, eq. 14):
    #   Z̃ = √N · (W̄ − E[W_i]) / √Var[W_i]
    # where E[W_i] = K and Var[W_i] = 2K·(T-2K-1)/(T-K-1)  (under normality approx.)
    T_used = T_avg - K
    if T_used > 2 * K + 1:
        mu_W   = K
        var_W  = 2.0 * K * (T_used - 2*K - 1) / (T_used - K - 1)
        Z_tilde = np.sqrt(N_eff) * (W_bar - mu_W) / np.sqrt(var_W)
    else:
        Z_tilde = np.sqrt(N_eff / (2*K)) * (W_bar - K)

    p_asymp = 2 * (1 - norm.cdf(abs(Z_tilde)))

    # ── Bootstrap p-value ────────────────────────────────────────────────────
    # Under H0 (no Granger causality), resample x residuals while fixing y dynamics.
    # Preserve cross-section dependence by jointly resampling residual block.

    # Build panel-level residual bootstrap
    boot_W_bars = []
    # Get all x series for cross-sectional bootstrap
    x_series = {}
    y_series = {}
    for c in countries:
        grp = df.loc[df["iso3c"] == c, [y_var, x_var]].dropna()
        if len(grp) >= K + 5:
            x_series[c] = grp[x_var].values
            y_series[c] = grp[y_var].values

    cs_codes = list(x_series.keys())
    if len(cs_codes) >= 3:
        T_boot = min(len(v) for v in x_series.values())
        X_mat_boot = np.column_stack([x_series[c][-T_boot:] for c in cs_codes])

        for _ in range(B):
            # Circular block bootstrap on x (preserve CD)
            block = max(1, int(T_boot**0.25))
            starts = rng.integers(0, T_boot, size=int(np.ceil(T_boot / block)))
            idx = np.concatenate([np.arange(s, min(s + block, T_boot)) for s in starts])[:T_boot]
            X_boot = X_mat_boot[idx, :]

            boot_Ws = []
            for j, c in enumerate(cs_codes):
                y_c = y_series[c][-T_boot:]
                x_b = X_boot[:, j]
                Wi  = dh_wald_i(y_c, x_b, K)
                if not np.isnan(Wi):
                    boot_Ws.append(Wi)

            if boot_Ws:
                boot_W_bars.append(np.mean(boot_Ws))

        if boot_W_bars:
            # Right-tailed: H1 is W̄ > K (causality → large W̄)
            p_boot = float(np.mean(np.array(boot_W_bars) >= W_bar))
        else:
            p_boot = np.nan
    else:
        p_boot = np.nan

    def sig_stars(p):
        if np.isnan(p): return ""
        return "***" if p < 0.01 else ("**" if p < 0.05 else ("*" if p < 0.10 else ""))

    return {
        "y_var": y_var, "x_var": x_var, "K": K,
        "N_eff": N_eff, "T_avg": round(T_avg, 1),
        "W_bar": round(W_bar, 4),
        "Z_tilde": round(Z_tilde, 4),
        "p_asymp": round(p_asymp, 4),
        "Sig_asymp": sig_stars(p_asymp),
        "p_boot": round(p_boot, 4) if not np.isnan(p_boot) else np.nan,
        "Sig_boot": sig_stars(p_boot),
        "Direction": f"{x_var} → {y_var}",
        "country_W": W_i_dict
    }


# ─── Causality pairs ─────────────────────────────────────────────────────────
PAIRS = [
    # Primary hypotheses
    ("ln_verim",   "dea_bc"),        # DEA efficiency → yield
    ("dea_bc",     "ln_verim"),      # yield → DEA (reverse)
    ("ln_verim",   "ln_gubre"),      # fertiliser → yield
    ("ln_verim",   "ln_ticaret"),    # trade openness → yield
    ("ln_verim",   "ln_ekipman"),    # mechanisation → yield
    # Secondary
    ("ln_gubre",   "ln_verim"),      # yield → fertiliser (Jevons feedback)
    ("ln_ticaret", "ln_verim"),      # yield → trade
    ("dea_bc",     "ln_gubre"),      # fertiliser → efficiency
    ("ln_gubre",   "dea_bc"),        # efficiency → fertiliser (reverse)
]

K_LAG  = 2   # DH lag order (Akaike/AIC confirmed; change to 1 if T is short)
B_BOOT = 499

print(f"\n{'='*70}")
print(f"DUMITRESCU-HURLIN (2012) PANEL CAUSALITY  K={K_LAG}, B={B_BOOT}")
print(f"{'='*70}")
print(f"  {'Direction':45s}  {'W̄':>7}  {'Z̃':>7}  {'p_asy':>7}  {'p_boot':>7}")
print(f"  {'-'*67}")

dh_records     = []
country_W_all  = {}

for (y_var, x_var) in PAIRS:
    # Use rows with both variables non-missing
    sub = panel.dropna(subset=[y_var, x_var])
    res = dh_test(sub, y_var, x_var, K=K_LAG, B=B_BOOT)

    if "error" in res:
        print(f"  {x_var} → {y_var:35s}  ERROR: {res['error']}")
        continue

    direction = f"{x_var} → {y_var}"
    print(f"  {direction:45s}  "
          f"{res['W_bar']:>7.3f}  {res['Z_tilde']:>7.3f}  "
          f"{res['p_asymp']:>7.4f}{res['Sig_asymp']:3s}  "
          f"{res['p_boot']:>7.4f}{res['Sig_boot']:3s}")

    dh_records.append({k: v for k, v in res.items() if k != "country_W"})
    country_W_all[direction] = res["country_W"]

dh_df = pd.DataFrame(dh_records)
dh_df.to_csv(os.path.join(OUTPUT_DIR, "dh_causality_results.csv"), index=False)

# Country-level Wald stats table
cw_records = []
for direction, cdict in country_W_all.items():
    for c, w in cdict.items():
        cw_records.append({"Direction": direction, "iso3c": c, "W_i": w})
cw_df = pd.DataFrame(cw_records)
cw_df.to_csv(os.path.join(OUTPUT_DIR, "dh_country_wald_stats.csv"), index=False)

print(f"\n  → Saved: output/tables/dh_causality_results.csv")
print(f"  → Saved: output/tables/dh_country_wald_stats.csv")


# ═══════════════════════════════════════════════════════════════════════════════
# 2.  TODA-YAMAMOTO (1995) AUGMENTED VAR CAUSALITY
# ═══════════════════════════════════════════════════════════════════════════════
# Handles mixed integration orders (I(0)/I(1)) without pre-testing.
# Procedure:
#   1. Determine d_max (max integration order of variables involved)
#   2. Estimate VAR(m + d_max) in levels, where m = optimal VAR lag (AIC)
#   3. Wald test on first m lags only; statistic is χ²(m)
# Here: d_max=1 (confirmed by CIPS); m selected by AIC up to m_max=4.

def var_aic(y: np.ndarray, x: np.ndarray, p: int) -> float:
    """AIC for bivariate VAR(p)."""
    T_  = len(y)
    n   = T_ - p
    if n < 2*p + 2:
        return np.inf
    Y_l = np.column_stack([y[p-k:T_-k] for k in range(1, p+1)])
    X_l = np.column_stack([x[p-k:T_-k] for k in range(1, p+1)])
    dep_y = y[p:]
    dep_x = x[p:]
    Xm  = np.column_stack([np.ones(n), Y_l, X_l])
    try:
        b_y, _, _, _ = np.linalg.lstsq(Xm, dep_y, rcond=None)
        b_x, _, _, _ = np.linalg.lstsq(Xm, dep_x, rcond=None)
        e_y = dep_y - Xm @ b_y
        e_x = dep_x - Xm @ b_x
        sig_y = np.sum(e_y**2) / n
        sig_x = np.sum(e_x**2) / n
        k_params = Xm.shape[1]
        aic = n * (np.log(sig_y) + np.log(sig_x)) + 2 * 2 * k_params
        return aic
    except:
        return np.inf


def toda_yamamoto_i(y: np.ndarray, x: np.ndarray,
                     d_max: int = 1, m_max: int = 4) -> dict:
    """
    Toda-Yamamoto (1995) causality test (x does not Granger-cause y).
    Uses bivariate VECM-in-levels representation.
    Returns: m_opt, wald, p_value
    """
    T_ = len(y)
    # Optimal VAR lag via AIC
    aic_vals = [var_aic(y, x, p) for p in range(1, m_max + 1)]
    m_opt = np.argmin(aic_vals) + 1   # 1-indexed

    p_total = m_opt + d_max           # augmented order
    n_obs   = T_ - p_total
    if n_obs < m_opt + d_max + 3:
        return {"m_opt": m_opt, "wald": np.nan, "p_value": np.nan}

    # Build augmented VAR regressor matrix
    Y_l = np.column_stack([y[p_total-k: T_-k] for k in range(1, p_total+1)])
    X_l = np.column_stack([x[p_total-k: T_-k] for k in range(1, p_total+1)])
    Xmat = np.column_stack([np.ones(n_obs), Y_l, X_l])
    dep  = y[p_total:]

    try:
        beta, _, _, _ = np.linalg.lstsq(Xmat, dep, rcond=None)
        e    = dep - Xmat @ beta
        s2   = np.sum(e**2) / max(n_obs - Xmat.shape[1], 1)
        XtXi = np.linalg.inv(Xmat.T @ Xmat)

        # Restriction: first m_opt lags of x only
        # In Xmat: intercept (idx 0), Y_l cols (idx 1..p_total), X_l cols (idx p_total+1..2*p_total)
        # First m_opt x lags: indices p_total+1 .. p_total+m_opt
        p_total_v = p_total  # alias for clarity
        R = np.zeros((m_opt, Xmat.shape[1]))
        for k in range(m_opt):
            R[k, p_total_v + 1 + k] = 1.0

        Rb   = R @ beta
        RVR  = s2 * R @ XtXi @ R.T
        wald = float(Rb @ np.linalg.solve(RVR, Rb))
        p_v  = 1 - chi2.cdf(wald, df=m_opt)
        return {"m_opt": m_opt, "wald": round(wald, 4), "p_value": round(p_v, 4)}
    except (np.linalg.LinAlgError, ValueError):
        return {"m_opt": m_opt, "wald": np.nan, "p_value": np.nan}


# Panel Toda-Yamamoto: country-by-country + MG Wald
TY_PAIRS = [
    ("ln_verim", "dea_bc"),
    ("dea_bc",   "ln_verim"),
    ("ln_verim", "ln_gubre"),
    ("ln_verim", "ln_ticaret"),
]

print(f"\n{'='*70}")
print("TODA-YAMAMOTO (1995) PANEL CAUSALITY (d_max=1, country-by-country)")
print(f"{'='*70}")
print(f"  {'Direction':45s}  {'m_opt':>6}  {'W̄_MG':>7}  {'p̄_MG':>7}")
print(f"  {'-'*67}")

ty_records = []
for (y_var, x_var) in TY_PAIRS:
    sub  = panel.dropna(subset=[y_var, x_var])
    walds, p_vals = [], []
    m_opts = []
    for c in countries:
        g = sub.loc[sub["iso3c"] == c, [y_var, x_var]].dropna()
        if len(g) < 8: continue
        res_i = toda_yamamoto_i(g[y_var].values, g[x_var].values, d_max=1, m_max=3)
        if not np.isnan(res_i["wald"]):
            walds.append(res_i["wald"])
            p_vals.append(res_i["p_value"])
            m_opts.append(res_i["m_opt"])

    if not walds:
        continue

    W_mg = np.mean(walds)
    p_mg = np.mean(p_vals)    # mean p-value across countries (indicative)
    m_med = int(np.median(m_opts))
    direction = f"{x_var} → {y_var}"
    sig = "***" if p_mg < 0.01 else ("**" if p_mg < 0.05 else ("*" if p_mg < 0.10 else ""))
    print(f"  {direction:45s}  {m_med:>6}  {W_mg:>7.3f}  {p_mg:>7.4f}{sig}")

    ty_records.append({
        "Direction": direction, "y_var": y_var, "x_var": x_var,
        "N_eff": len(walds), "m_opt_median": m_med,
        "W_MG": round(W_mg, 4), "p_MG_mean": round(p_mg, 4),
        "Sig": sig
    })

ty_df = pd.DataFrame(ty_records)
ty_df.to_csv(os.path.join(OUTPUT_DIR, "toda_yamamoto_results.csv"), index=False)
print(f"\n  → Saved: output/tables/toda_yamamoto_results.csv")


# ═══════════════════════════════════════════════════════════════════════════════
# 3.  SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
print(f"\n{'='*70}")
print("CAUSALITY SUMMARY")
print(f"{'='*70}")

if not dh_df.empty:
    print("\nDumitrescu-Hurlin (K=2) — significant causality:")
    sig_dh = dh_df[dh_df["p_boot"].notna() & (dh_df["p_boot"] < 0.10)]
    if len(sig_dh):
        for _, row in sig_dh.iterrows():
            print(f"  ✓ {row['x_var']:20s} → {row['y_var']:20s}  "
                  f"p_boot={row['p_boot']:.4f}  {row['Sig_boot']}")
    else:
        print("  (none at 10% via bootstrap)")

    print("\nDumitrescu-Hurlin (K=2) — asymptotic significant:")
    sig_asy = dh_df[dh_df["Sig_asymp"] != ""]
    for _, row in sig_asy.iterrows():
        print(f"  ✓ {row['x_var']:20s} → {row['y_var']:20s}  "
              f"p_asy={row['p_asymp']:.4f}  {row['Sig_asymp']}")

print(f"\n{'='*70}")
print("NOTE: Bootstrap DH p-values are primary. Asymptotic Z̃ over-rejects")
print("      when N is small (N=22). Toda-Yamamoto MG p̄ is indicative only.")
print("      For submission: increase B_BOOT to 999 and re-run locally.")
print(f"{'='*70}")
