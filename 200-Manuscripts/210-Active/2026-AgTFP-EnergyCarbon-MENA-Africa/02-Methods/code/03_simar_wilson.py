#!/usr/bin/env python3
"""
Simar-Wilson (2007) Two-Stage DEA Bootstrap Pipeline
═══════════════════════════════════════════════════════
Study : Agricultural TFP, Energy Efficiency, and Yield Dynamics
        Across Climate-Vulnerable and Frontier Economies
Authors: Özdemir + Işık (2026)

Reference
---------
Simar, L. & Wilson, P.W. (2007). Estimation and inference in two-stage,
semi-parametric models of production processes.
Journal of Econometrics, 136(1), 31-64.

Pipeline
--------
Stage 1  : VRS Input-Oriented DEA (scipy HiGHS LP)
Algorithm 1: Bias correction for DEA scores (B1=300 bootstrap)
Algorithm 2: Truncated MLE + double bootstrap CIs for second-stage
             regression (B2=200 bootstrap)

DEA specification
-----------------
  Inputs  : emek (labour, M persons), toprak (land, M ha),
            gubre (fertiliser, kg/ha), ekipman (tractors per 100 km²)
  Output  : tarim_gsyh (agricultural GDP % of total GDP)
  Returns : Farrell input-oriented efficiency score θ ∈ (0, 1]
            (θ=1 → frontier; θ<1 → inefficient)

Second-stage covariates (z)
---------------------------
  ticaret (trade openness, % GDP)
  MENA dummy
  SSA  dummy
  year (linear trend, centred at 2010)
"""

import numpy as np
import pandas as pd
from scipy.optimize import linprog, minimize
from scipy.stats import norm
import warnings, time, sys, os

warnings.filterwarnings("ignore")
np.random.seed(2026)

# ── Paths ──────────────────────────────────────────────────────────────────
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_IN  = os.path.join(BASE, "data",   "panel_main_extended.csv")
OUT_TBL  = os.path.join(BASE, "output", "tables")
os.makedirs(OUT_TBL, exist_ok=True)

# ── Hyper-parameters ───────────────────────────────────────────────────────
B1 = 300   # Algorithm 1 bootstrap replications (bias correction)
B2 = 200   # Algorithm 2 bootstrap replications (second-stage CIs)
           # Increase to B1=2000, B2=2000 for final submission
SEED = 2026


# ══════════════════════════════════════════════════════════════════════════
# 1.  DEA  —  VRS Input-Oriented (Farrell)
# ══════════════════════════════════════════════════════════════════════════

def dea_vrs_input(Y: np.ndarray, X: np.ndarray) -> np.ndarray:
    """
    VRS input-oriented DEA for all n DMUs.

    Parameters
    ----------
    Y : (n,)  output vector
    X : (n,m) input matrix

    Returns
    -------
    theta : (n,) Farrell efficiency scores ∈ (0, 1]
    """
    n, m = X.shape
    scores = np.full(n, np.nan)

    for k in range(n):
        # Decision variables: [theta, λ_1, …, λ_n]
        # minimize theta
        c = np.zeros(1 + n)
        c[0] = 1.0

        A_ub, b_ub = [], []

        # Output constraint: Y @ λ ≥ Y[k]  →  -Y @ λ ≤ -Y[k]
        row = np.zeros(1 + n)
        row[1:] = -Y
        A_ub.append(row)
        b_ub.append(-Y[k])

        # Input constraints: θ·X[k,i] − X[:,i]@λ ≥ 0
        #   →  -X[k,i]·θ + X[:,i]@λ ≤ 0   for each input i
        for i in range(m):
            row = np.zeros(1 + n)
            row[0]  = -X[k, i]
            row[1:] =  X[:, i]
            A_ub.append(row)
            b_ub.append(0.0)

        A_ub = np.array(A_ub)
        b_ub = np.array(b_ub)

        # VRS: Σλ = 1
        A_eq = np.zeros((1, 1 + n))
        A_eq[0, 1:] = 1.0
        b_eq = np.array([1.0])

        # Bounds: θ ∈ [0,1], λ ≥ 0
        bounds = [(0.0, 1.0)] + [(0.0, None)] * n

        res = linprog(c, A_ub=A_ub, b_ub=b_ub,
                      A_eq=A_eq, b_eq=b_eq,
                      bounds=bounds, method="highs",
                      options={"disp": False, "presolve": True})

        scores[k] = res.x[0] if res.success else np.nan

    return scores


# ══════════════════════════════════════════════════════════════════════════
# 2.  Kernel bootstrap with reflection at boundaries
# ══════════════════════════════════════════════════════════════════════════

def _silverman_bw(scores: np.ndarray) -> float:
    """Silverman (1986) rule-of-thumb bandwidth, IQR-corrected."""
    n    = len(scores)
    iqr  = np.percentile(scores, 75) - np.percentile(scores, 25)
    std  = np.std(scores, ddof=1)
    s    = min(std, iqr / 1.349)
    return 0.9 * s * n ** (-0.2)


def _kernel_sample(scores: np.ndarray, bw: float) -> np.ndarray:
    """
    Draw n pseudo-scores from reflected Gaussian kernel density.
    Reflects at upper boundary 1 and lower boundary ε to keep scores
    in (0, 1].
    """
    n   = len(scores)
    idx = np.random.choice(n, size=n, replace=True)
    z   = scores[idx] + bw * np.random.randn(n)

    # Reflect at upper bound 1
    z = np.where(z > 1.0, 2.0 - z, z)
    # Reflect at lower bound 0
    z = np.where(z <= 0.0, -z, z)
    # Clip residual edge cases
    z = np.clip(z, 1e-6, 1.0)
    return z


# ══════════════════════════════════════════════════════════════════════════
# 3.  Algorithm 1  —  Bias correction
# ══════════════════════════════════════════════════════════════════════════

def algorithm1(Y: np.ndarray,
               X: np.ndarray,
               B: int = 300,
               seed: int = 2026):
    """
    Simar-Wilson (2007) Algorithm 1 — bias-corrected efficiency scores.

    Returns
    -------
    theta_hat : (n,)  original DEA scores
    theta_bc  : (n,)  bias-corrected scores
    bias      : (n,)  estimated bias
    ci_lo     : (n,)  bootstrap 95% CI lower bound
    ci_hi     : (n,)  bootstrap 95% CI upper bound
    """
    np.random.seed(seed)
    n   = len(Y)
    bw  = _silverman_bw

    theta_hat = dea_vrs_input(Y, X)
    h         = bw(theta_hat)
    boot      = np.zeros((B, n))

    for b in range(B):
        theta_star  = _kernel_sample(theta_hat, h)
        # Rescale output so pseudo-DMU is efficient at theta_star
        Y_pseudo    = Y * (theta_hat / theta_star)
        boot[b]     = dea_vrs_input(Y_pseudo, X)

    bias      = boot.mean(axis=0) - theta_hat
    theta_bc  = np.clip(theta_hat - bias, 1e-6, 1.0)
    ci_lo     = np.percentile(boot, 2.5,  axis=0)
    ci_hi     = np.percentile(boot, 97.5, axis=0)

    return theta_hat, theta_bc, bias, ci_lo, ci_hi


# ══════════════════════════════════════════════════════════════════════════
# 4.  Truncated Normal MLE  (second-stage regression)
# ══════════════════════════════════════════════════════════════════════════

def _truncated_nll(params: np.ndarray,
                   theta: np.ndarray,
                   Z: np.ndarray) -> float:
    """
    Negative log-likelihood for right-truncated normal regression.

    Model: θ_i = z_i β + ε_i,  ε_i ~ N(0,σ²) truncated at (1 − z_i β).
    θ_i ≤ 1  (input-oriented DEA).

    params = [β_0, β_1, …, β_k, log_sigma]
    """
    k        = Z.shape[1]
    beta     = params[:k]
    sigma    = np.exp(params[k])          # log-parameterisation → σ > 0

    mu       = Z @ beta                   # fitted means
    resid    = (theta - mu) / sigma
    trunc_up = (1.0 - mu) / sigma         # upper truncation point

    # log-likelihood: log N(ε/σ) / σ − log Φ(trunc_up)
    ll = (norm.logpdf(resid) - np.log(sigma)
          - norm.logcdf(trunc_up))

    # Penalise infeasible draws (mu ≥ 1)
    if np.any(trunc_up < -4):
        return 1e12
    return -np.sum(ll)


def truncated_mle(theta: np.ndarray,
                  Z: np.ndarray):
    """
    MLE for right-truncated normal regression.

    Parameters
    ----------
    theta : (n,)   dependent variable (DEA scores, ≤ 1)
    Z     : (n,k)  design matrix (includes intercept)

    Returns
    -------
    beta  : (k,)   coefficient estimates
    sigma : float  residual standard deviation
    """
    k0     = Z.shape[1]
    # Initialise: OLS ignoring truncation
    beta0  = np.linalg.lstsq(Z, theta, rcond=None)[0]
    init   = np.append(beta0, np.log(0.1))

    res    = minimize(_truncated_nll, init,
                      args=(theta, Z),
                      method="Nelder-Mead",
                      options={"maxiter": 50_000, "xatol": 1e-7,
                               "fatol": 1e-7, "adaptive": True})
    if not res.success:
        res = minimize(_truncated_nll, res.x,
                       args=(theta, Z),
                       method="L-BFGS-B",
                       options={"maxiter": 20_000, "ftol": 1e-9})

    beta  = res.x[:k0]
    sigma = np.exp(res.x[k0])
    return beta, sigma


# ══════════════════════════════════════════════════════════════════════════
# 5.  Algorithm 2  —  Double bootstrap (second-stage CIs)
# ══════════════════════════════════════════════════════════════════════════

def algorithm2(panel: pd.DataFrame,
               theta_bc_col: str,
               z_cols: list,
               B: int = 200,
               seed: int = 2026):
    """
    Simar-Wilson (2007) Algorithm 2 — double bootstrap for second-stage
    truncated regression.

    Parameters
    ----------
    panel       : DataFrame with columns [iso3c, year, theta_bc, z_cols]
    theta_bc_col: name of the bias-corrected score column
    z_cols      : list of environmental covariate names
    B           : number of bootstrap replications
    seed        : random seed

    Returns
    -------
    beta_hat  : (k,)    original MLE estimates
    beta_bc   : (k,)    bias-corrected estimates
    ci_lo     : (k,)    95% CI lower bound (percentile)
    ci_hi     : (k,)    95% CI upper bound (percentile)
    sigma_hat : float   estimated residual SD
    col_names : list    coefficient names
    """
    np.random.seed(seed)

    theta = panel[theta_bc_col].values.astype(float)
    Z_raw = panel[z_cols].values.astype(float)
    Z     = np.c_[np.ones(len(theta)), Z_raw]   # add intercept
    col_names = ["const"] + z_cols

    # ── Original MLE ──────────────────────────────────────────────────────
    beta_hat, sigma_hat = truncated_mle(theta, Z)

    # ── Bootstrap loop ────────────────────────────────────────────────────
    years     = panel["year"].unique()
    iso_list  = panel["iso3c"].unique()
    n_total   = len(panel)

    beta_boot = np.zeros((B, len(beta_hat)))

    for b in range(B):
        # --- Step 1: generate pseudo-scores from truncated regression -----
        mu_hat  = Z @ beta_hat
        # truncated normal draw: N(mu_hat, sigma²) right-truncated at 1
        trunc_z = (1.0 - mu_hat) / sigma_hat
        # inverse CDF method: draw u ~ Uniform(0, Φ(trunc_z))
        u       = np.random.uniform(0.0, norm.cdf(trunc_z))
        # clip to avoid numerical instability
        u       = np.clip(u, 1e-9, 1 - 1e-9)
        theta_star = mu_hat + sigma_hat * norm.ppf(u)
        theta_star = np.clip(theta_star, 1e-6, 1.0)

        # --- Step 2: re-run year-by-year DEA on pseudo-data ---------------
        theta_hat_boot = np.zeros(n_total)
        for yr in years:
            mask    = panel["year"].values == yr
            idx     = np.where(mask)[0]
            p       = panel.iloc[idx]
            Y_yr    = p["tarim_gsyh"].values.astype(float)
            X_yr    = p[["emek","toprak","gubre","ekipman"]].values.astype(float)
            t_orig  = p[theta_bc_col].values.astype(float)
            t_ps    = theta_star[idx]

            # Rescale output proportionally
            ratio   = np.where(t_ps > 0, t_orig / t_ps, 1.0)
            Y_pseudo = Y_yr * ratio
            Y_pseudo = np.clip(Y_pseudo, 1e-6, None)

            scores_b = dea_vrs_input(Y_pseudo, X_yr)
            # Algorithm-1-style bias correction (single pass, light)
            h_b      = _silverman_bw(scores_b[np.isfinite(scores_b)])
            bts_b    = np.zeros((50, len(scores_b)))
            for bb in range(50):
                ts   = _kernel_sample(scores_b, h_b)
                Yp   = Y_pseudo * (scores_b / ts)
                bts_b[bb] = dea_vrs_input(Yp, X_yr)
            bc_b     = np.clip(scores_b - (bts_b.mean(0) - scores_b),
                               1e-6, 1.0)
            theta_hat_boot[idx] = bc_b

        # --- Step 3: re-estimate truncated regression on pseudo-scores ----
        try:
            beta_b, _ = truncated_mle(theta_hat_boot, Z)
            beta_boot[b] = beta_b
        except Exception:
            beta_boot[b] = np.nan

    # Drop failed bootstrap replications
    valid       = ~np.any(np.isnan(beta_boot), axis=1)
    beta_boot   = beta_boot[valid]
    n_valid     = valid.sum()
    if n_valid < 50:
        print(f"  WARNING: only {n_valid}/{B} valid bootstrap replicates")

    # ── Bias correction & CIs ─────────────────────────────────────────────
    bias_b   = beta_boot.mean(axis=0) - beta_hat
    beta_bc  = beta_hat - bias_b
    ci_lo    = np.percentile(beta_boot, 2.5,  axis=0)
    ci_hi    = np.percentile(beta_boot, 97.5, axis=0)

    return beta_hat, beta_bc, ci_lo, ci_hi, sigma_hat, col_names, n_valid


# ══════════════════════════════════════════════════════════════════════════
# 6.  MAIN
# ══════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 65)
    print("  Simar-Wilson DEA Pipeline — AgTFP MENA-Africa")
    print(f"  B1={B1} (bias correction)  B2={B2} (second stage)")
    print("=" * 65)

    # ── Load data ──────────────────────────────────────────────────────────
    df = pd.read_csv(DATA_IN)

    # Clean: replace near-zero inputs with small positive value
    inp_cols = ["emek", "toprak", "gubre", "ekipman"]
    out_col  = "tarim_gsyh"
    for col in inp_cols + [out_col]:
        df[col] = df[col].clip(lower=1e-6)

    years    = sorted(df["year"].unique())
    iso_list = sorted(df["iso3c"].unique())
    print(f"  N={len(iso_list)} countries  |  T={len(years)} years  "
          f"|  obs={len(df)}")

    # ═══════════════════════════════════════════════════════════════════════
    # STAGE 1 — Algorithm 1, year-by-year
    # ═══════════════════════════════════════════════════════════════════════
    print("\n── Stage 1: Algorithm 1 (bias correction) ──────────────────")
    t0 = time.time()

    records = []
    for yr in years:
        sub  = df[df["year"] == yr].copy().reset_index(drop=True)
        Y_yr = sub[out_col].values.astype(float)
        X_yr = sub[inp_cols].values.astype(float)

        theta_hat, theta_bc, bias, ci_lo, ci_hi = algorithm1(
            Y_yr, X_yr, B=B1, seed=SEED + yr)

        for i, row in sub.iterrows():
            records.append({
                "iso3c"     : row["iso3c"],
                "country"   : row["country"],
                "year"      : row["year"],
                "group"     : row["group"],
                "theta_hat" : theta_hat[i],
                "theta_bc"  : theta_bc[i],
                "bias"      : bias[i],
                "ci_lo_95"  : ci_lo[i],
                "ci_hi_95"  : ci_hi[i],
            })

        print(f"  {yr}: mean θ̂={theta_hat.mean():.4f}  "
              f"mean θ̃={theta_bc.mean():.4f}  "
              f"mean bias={bias.mean():.4f}")

    scores_df = pd.DataFrame(records)
    elapsed1  = time.time() - t0
    print(f"\n  Algorithm 1 complete in {elapsed1:.1f}s")

    # Group-level summary
    print("\n  Bias-corrected scores by group:")
    grp = scores_df.groupby("group")[["theta_hat","theta_bc"]].mean()
    print(grp.round(4).to_string())

    # ═══════════════════════════════════════════════════════════════════════
    # STAGE 2 — Truncated regression + Algorithm 2
    # ═══════════════════════════════════════════════════════════════════════
    print("\n── Stage 2: Algorithm 2 (double bootstrap) ──────────────────")
    t1 = time.time()

    # Merge back trade openness and build design matrix
    panel = scores_df.merge(
        df[["iso3c","year","ticaret"]],
        on=["iso3c","year"], how="left"
    )
    panel["mena"]      = (panel["group"] == "MENA").astype(float)
    panel["ssa"]       = (panel["group"] == "SSA").astype(float)
    panel["year_c"]    = panel["year"] - 2010   # centred trend
    panel["ln_trade"]  = np.log(panel["ticaret"].clip(lower=1e-6))

    z_cols = ["ln_trade", "mena", "ssa", "year_c"]

    # Drop any rows with NaN in theta_bc or z_cols
    panel = panel.dropna(subset=["theta_bc"] + z_cols).reset_index(drop=True)

    beta_hat, beta_bc, ci_lo, ci_hi, sigma_hat, col_names, n_valid = \
        algorithm2(panel, "theta_bc", z_cols, B=B2, seed=SEED)

    elapsed2 = time.time() - t1
    print(f"\n  Algorithm 2 complete in {elapsed2:.1f}s  "
          f"(valid replicates: {n_valid}/{B2})")

    # ═══════════════════════════════════════════════════════════════════════
    # RESULTS TABLES
    # ═══════════════════════════════════════════════════════════════════════

    # ── Table A: Bias-corrected DEA scores ─────────────────────────────────
    out_a = os.path.join(OUT_TBL, "sw_dea_scores_biascorrected.csv")
    scores_df.to_csv(out_a, index=False, float_format="%.6f")
    print(f"\n  → Table saved: {os.path.basename(out_a)}")

    # Country mean scores (publishable)
    country_avg = (scores_df.groupby(["iso3c","country","group"])
                   [["theta_hat","theta_bc","ci_lo_95","ci_hi_95"]]
                   .mean().round(4).reset_index())
    country_avg.columns = ["ISO","Country","Group",
                           "θ̂ (original)","θ̃ (bias-corrected)",
                           "95% CI lower","95% CI upper"]
    out_b = os.path.join(OUT_TBL, "sw_country_avg_scores.csv")
    country_avg.to_csv(out_b, index=False, float_format="%.4f")
    print(f"  → Table saved: {os.path.basename(out_b)}")
    print("\n  Country-level bias-corrected efficiency (period mean):")
    print(country_avg.sort_values("θ̃ (bias-corrected)",
                                   ascending=False).to_string(index=False))

    # ── Table B: Second-stage regression (Algorithm 2) ──────────────────────
    reg_rows = []
    for j, name in enumerate(col_names):
        pval_approx = 2 * (1 - norm.cdf(
            abs(beta_bc[j]) / max(
                (ci_hi[j] - ci_lo[j]) / (2 * 1.96), 1e-9)))
        sig = ("***" if pval_approx < 0.01 else
               "**"  if pval_approx < 0.05 else
               "*"   if pval_approx < 0.10 else "")
        reg_rows.append({
            "Variable"      : name,
            "β (MLE)"       : round(beta_hat[j], 4),
            "β (bias-corr)" : round(beta_bc[j], 4),
            "CI lower 95%"  : round(ci_lo[j], 4),
            "CI upper 95%"  : round(ci_hi[j], 4),
            "Sig."          : sig,
        })
    reg_df = pd.DataFrame(reg_rows)
    reg_df.loc[len(reg_df)] = {
        "Variable": "σ̂ (residual SD)", "β (MLE)": round(sigma_hat,4),
        "β (bias-corr)": "", "CI lower 95%": "", "CI upper 95%": "",
        "Sig.": ""
    }
    reg_df.loc[len(reg_df)] = {
        "Variable": "N (obs)", "β (MLE)": len(panel),
        "β (bias-corr)": "", "CI lower 95%": "", "CI upper 95%": "",
        "Sig.": ""
    }
    reg_df.loc[len(reg_df)] = {
        "Variable": "Bootstrap replicates (valid)",
        "β (MLE)": f"{n_valid}/{B2}",
        "β (bias-corr)": "", "CI lower 95%": "", "CI upper 95%": "",
        "Sig.": ""
    }

    out_c = os.path.join(OUT_TBL, "sw_second_stage_regression.csv")
    reg_df.to_csv(out_c, index=False)
    print(f"\n  → Table saved: {os.path.basename(out_c)}")
    print("\n  Second-stage truncated regression results (Algorithm 2):")
    print(reg_df.to_string(index=False))

    # ── Table C: Annual group-level means ──────────────────────────────────
    annual_grp = (scores_df.groupby(["year","group"])["theta_bc"]
                  .agg(["mean","std","min","max"])
                  .round(4).reset_index())
    out_d = os.path.join(OUT_TBL, "sw_annual_group_scores.csv")
    annual_grp.to_csv(out_d, index=False, float_format="%.4f")
    print(f"  → Table saved: {os.path.basename(out_d)}")

    # ── Summary ────────────────────────────────────────────────────────────
    print("\n" + "=" * 65)
    print("  PIPELINE COMPLETE")
    print(f"  Total elapsed: {(elapsed1+elapsed2):.1f}s")
    print(f"  Outputs in: {OUT_TBL}")
    print("=" * 65)


if __name__ == "__main__":
    main()
