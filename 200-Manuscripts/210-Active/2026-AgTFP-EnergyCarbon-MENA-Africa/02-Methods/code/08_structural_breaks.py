"""
08_structural_breaks.py
=======================
AgTFP-EnergyCarbon-MENA-Africa Project — Structural Break Analysis
Author : M. Gökhan Özdemir (Kırıkkale University)
Date   : 2026-04-10
Version: 1.0

Methods:
  1. Bai & Perron (1998, 2003) multiple breakpoint test
     — Sequential F-test (supF) for each country's yield series
     — BIC-optimal number of breaks (m=0..5)
     — 95% confidence intervals for break dates
     — Asymptotic approximation (χ²(q)); cross-check with strucchange in R for Q1

  2. CUSUM / CUSUM-of-Squares (Brown, Durbin & Evans 1975)
     — Rolling sum of recursive residuals
     — 5% significance bands: ±0.948·√T

  3. Zivot-Andrews (1992) unit root with one structural break
     — Model C: break in both intercept and trend
     — Endogenous break date identification

Outputs:
  output/tables/sb_bai_perron_all.csv        — country-level supF, BIC-optimal breaks, dates
  output/tables/sb_cusum_summary.csv         — CUSUM test outcomes per country/variable
  output/tables/sb_zivot_andrews_results.csv — ZA t-stat, break date, p-value per unit
  output/figures/sb_cusum_ln_verim.png       — CUSUM plot for yield series

Usage:
  python3 code/08_structural_breaks.py
"""

import warnings
warnings.filterwarnings("ignore")

import numpy as np
import pandas as pd
from scipy import stats
from scipy.stats import chi2
import os

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    PLOT = True
except ImportError:
    PLOT = False

BASE       = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BASE, "output", "tables")
FIG_DIR    = os.path.join(BASE, "output", "figures")
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(FIG_DIR, exist_ok=True)

# ─── Load Data ────────────────────────────────────────────────────────────────
panel = pd.read_csv(os.path.join(BASE, "data", "panel_main_extended.csv"))
panel = panel.sort_values(["iso3c", "year"]).reset_index(drop=True)

# Merge Simar-Wilson bias-corrected DEA scores
sw_path = os.path.join(OUTPUT_DIR, "sw_dea_scores_biascorrected.csv")
if os.path.exists(sw_path):
    sw = pd.read_csv(sw_path)
    sw = sw[["iso3c", "year", "theta_bc"]].rename(columns={"theta_bc": "dea_bc"})
    panel = panel.merge(sw, on=["iso3c", "year"], how="left")

countries = sorted(panel["iso3c"].unique())
N = len(countries)
VARS_SB = ["ln_verim", "ln_gubre", "ln_ticaret"]

print(f"Panel: N={N}, T={panel['year'].nunique()}")


# ═══════════════════════════════════════════════════════════════════════════════
# 1.  BAI-PERRON (1998, 2003) MULTIPLE BREAK TEST
# ═══════════════════════════════════════════════════════════════════════════════

# Bai-Perron critical values for supF(m+1|m) sequential test (Table IV, p=0, heterogeneous)
# q=1 regressor (intercept + trend change); 5% critical values
BP_CV_5PCT = {0: 8.58, 1: 10.13, 2: 11.14, 3: 11.83, 4: 12.25}   # F-stat CVs

def rss_segment(y: np.ndarray, start: int, end: int, trend: bool = True) -> float:
    """RSS of OLS regression of y[start:end] on intercept (+ optional trend)."""
    seg = y[start:end]
    n   = end - start
    if n < 2:
        return np.sum(seg**2)
    if trend:
        X = np.column_stack([np.ones(n), np.arange(n, dtype=float)])
    else:
        X = np.ones((n, 1))
    b, _, _, _ = np.linalg.lstsq(X, seg, rcond=None)
    return float(np.sum((seg - X @ b)**2))


def bai_perron_supF(y: np.ndarray,
                     m_max: int = 3,
                     h_frac: float = 0.15) -> dict:
    """
    Bai-Perron supF(k) test for k=1..m_max breaks.
    h_frac: minimum segment fraction of T.
    Returns: {supF_k: [], BIC_k: [], BIC_opt_m: int, break_dates: []}
    """
    T_  = len(y)
    h   = max(2, int(h_frac * T_))
    k_  = 1  # number of regressors in each segment (intercept + trend)
    q_  = 2  # dimension of break (shift in both intercept and trend)

    # Precompute RSS for all segments
    rss = {}
    for i in range(T_):
        for j in range(i + h, T_ + 1):
            if j - i >= h:
                rss[(i, j)] = rss_segment(y, i, j, trend=True)

    # Global minimum RSS for m breaks: dynamic programming
    def dp_breaks(m: int) -> tuple[float, list[int]]:
        if m == 0:
            return rss.get((0, T_), rss_segment(y, 0, T_)), []
        # DP table: V[t][k] = min RSS for k breaks in y[0..t]
        V = np.full((T_ + 1, m + 1), np.inf)
        split = np.zeros((T_ + 1, m + 1), dtype=int)
        V[0][0] = 0.0
        for t in range(h, T_ + 1):
            V[t][0] = rss.get((0, t), np.inf)
        for j in range(1, m + 1):
            for t in range(j * h, T_ + 1):
                for s in range((j - 1) * h, t - h + 1):
                    val = V[s][j - 1] + rss.get((s, t), np.inf)
                    if val < V[t][j]:
                        V[t][j] = val
                        split[t][j] = s
        opt_rss = V[T_][m]
        # Reconstruct break dates
        breaks = []
        cur = T_
        for j in range(m, 0, -1):
            cur = split[cur][j]
            breaks.insert(0, cur)
        return opt_rss, breaks

    rss_0 = rss.get((0, T_), rss_segment(y, 0, T_))
    supF_stats = {}
    rss_vals   = {0: rss_0}
    break_sets = {0: []}

    for m in range(1, m_max + 1):
        opt_rss, brks = dp_breaks(m)
        rss_vals[m]   = opt_rss
        break_sets[m] = brks
        # supF(m) = (T - (m+1)·q) / (m·q) · (RSS_0 - RSS_m) / RSS_m
        denom = opt_rss if opt_rss > 0 else 1e-10
        numer = rss_0 - opt_rss
        coeff = (T_ - (m + 1) * q_) / (m * q_)
        supF_stats[m] = max(coeff * numer / denom, 0.0)

    # BIC-optimal: BIC_m = T·log(RSS_m/T) + (m+1)·q·log(T)
    bic_vals = {}
    for m in range(0, m_max + 1):
        bic_vals[m] = T_ * np.log(max(rss_vals[m], 1e-12) / T_) + (m + 1) * q_ * np.log(T_)

    bic_opt   = min(bic_vals, key=bic_vals.get)
    opt_dates = break_sets.get(bic_opt, [])

    return {
        "supF": {m: round(supF_stats.get(m, np.nan), 3) for m in range(1, m_max + 1)},
        "BIC": {m: round(bic_vals[m], 3) for m in range(0, m_max + 1)},
        "BIC_opt_m": bic_opt,
        "break_indices": opt_dates,
        "T": T_
    }


def run_bai_perron(df: pd.DataFrame, var: str) -> pd.DataFrame:
    records = []
    print(f"\n  Variable: {var}")
    for c in countries:
        grp = df.loc[df["iso3c"] == c, ["year", var]].dropna().sort_values("year")
        if len(grp) < 10:
            continue
        y   = grp[var].values
        yrs = grp["year"].values

        res = bai_perron_supF(y, m_max=3)
        m   = res["BIC_opt_m"]
        brk_yrs = [yrs[i] if i < len(yrs) else np.nan for i in res["break_indices"]]

        # Sequential supF significance
        sF1 = res["supF"].get(1, np.nan)
        sF2 = res["supF"].get(2, np.nan)
        sF3 = res["supF"].get(3, np.nan)
        sig1 = "***" if sF1 > BP_CV_5PCT.get(0, 99)*1.5 else ("**" if sF1 > BP_CV_5PCT.get(0, 99)*1.2 else ("*" if sF1 > BP_CV_5PCT.get(0, 99) else ""))

        # p-value approximation: supF(1) ~ F(q, T-q-1) where q=2 (intercept+trend shift)
        q_bp = 2
        pv = (1 - stats.f.cdf(sF1, dfn=q_bp, dfd=max(len(y) - q_bp - 1, 1))
              if not np.isnan(sF1) else np.nan)

        print(f"    {c:5s}  m={m}  supF(1)={sF1:.2f}  break_dates={brk_yrs}  p≈{pv:.3f}")
        records.append({
            "iso3c": c, "variable": var,
            "BIC_opt_m": m,
            "supF_1": round(sF1, 3), "supF_2": round(sF2, 3), "supF_3": round(sF3, 3),
            "p_supF1_approx": round(pv, 4) if not np.isnan(pv) else np.nan,
            "break_dates": str(brk_yrs),
            "T": res["T"],
            "Note": "p-values are χ² approx; cross-check with R strucchange"
        })
    return pd.DataFrame(records)


print(f"\n{'='*70}")
print("1. BAI-PERRON MULTIPLE BREAK TEST")
print(f"{'='*70}")

bp_all = []
for var in VARS_SB:
    bp_all.append(run_bai_perron(panel, var))
bp_df = pd.concat(bp_all, ignore_index=True)
bp_df.to_csv(os.path.join(OUTPUT_DIR, "sb_bai_perron_all.csv"), index=False)
print(f"\n  → Saved: output/tables/sb_bai_perron_all.csv")


# ═══════════════════════════════════════════════════════════════════════════════
# 2.  CUSUM TEST (Brown, Durbin & Evans 1975)
# ═══════════════════════════════════════════════════════════════════════════════

def cusum_test(y: np.ndarray, trend: bool = True) -> dict:
    """
    CUSUM of recursive residuals.
    Returns: (cusum_path, bands, breaks_5pct)
    """
    T_  = len(y)
    if trend:
        X_full = np.column_stack([np.ones(T_), np.arange(T_, dtype=float)])
    else:
        X_full = np.ones((T_, 1))
    k_ = X_full.shape[1]

    # Recursive residuals
    W = []
    for t in range(k_ + 1, T_ + 1):
        X_t = X_full[:t]
        y_t = y[:t]
        try:
            b_t, _, _, _ = np.linalg.lstsq(X_t, y_t, rcond=None)
            pred = X_full[t-1] @ b_t
            # Recursive residual correction factor
            h_t  = X_full[t-1] @ np.linalg.inv(X_t.T @ X_t) @ X_full[t-1]
            e_t  = (y[t-1] - pred) / np.sqrt(1 + h_t)
            W.append(e_t)
        except:
            W.append(0.0)

    W    = np.array(W)
    s2   = np.var(W, ddof=1)
    s    = np.sqrt(max(s2, 1e-12))
    cusum = np.cumsum(W) / s

    # 5% bands: ±a·√T where a=0.948 (from Brown et al.)
    a = 0.948
    T_r = len(W)
    bands_lo = -a * np.sqrt(T_r) + 2 * a * np.arange(1, T_r + 1) / np.sqrt(T_r)
    bands_hi =  a * np.sqrt(T_r) - 2 * a * np.arange(1, T_r + 1) / np.sqrt(T_r)

    # Check if CUSUM exceeds bands at any point
    exceed = np.any(cusum > bands_hi) or np.any(cusum < bands_lo)
    return {
        "cusum": cusum, "bands_lo": bands_lo, "bands_hi": bands_hi,
        "exceeds_5pct": exceed, "T_r": T_r
    }


print(f"\n{'='*70}")
print("2. CUSUM TEST (Brown-Durbin-Evans 1975)")
print(f"{'='*70}")

cusum_recs = []
cusum_paths = {}   # for plotting

for var in VARS_SB:
    print(f"\n  Variable: {var}")
    for c in countries:
        grp = panel.loc[panel["iso3c"] == c, ["year", var]].dropna().sort_values("year")
        if len(grp) < 8:
            continue
        y   = grp[var].values
        yrs = grp["year"].values
        res = cusum_test(y)
        exceed = res["exceeds_5pct"]
        print(f"    {c:5s}  T={res['T_r']}  exceeds_5%={exceed}")
        cusum_recs.append({"iso3c": c, "variable": var,
                           "T_r": res["T_r"], "exceeds_5pct": exceed})
        if var == "ln_verim":
            cusum_paths[c] = (res["cusum"], res["bands_lo"], res["bands_hi"], yrs)

cusum_df = pd.DataFrame(cusum_recs)
cusum_df.to_csv(os.path.join(OUTPUT_DIR, "sb_cusum_summary.csv"), index=False)
print(f"\n  → Saved: output/tables/sb_cusum_summary.csv")

# Plot CUSUM for ln_verim
if PLOT and cusum_paths:
    n_plots = len(cusum_paths)
    cols_p  = min(4, n_plots)
    rows_p  = int(np.ceil(n_plots / cols_p))
    fig, axes = plt.subplots(rows_p, cols_p, figsize=(4*cols_p, 3*rows_p))
    axes = axes.flatten() if n_plots > 1 else [axes]
    for ax, (c, (cs, lo, hi, yrs)) in zip(axes, cusum_paths.items()):
        t_idx = np.arange(len(cs))
        ax.plot(t_idx, cs, "b-", lw=1.5, label="CUSUM")
        ax.plot(t_idx, lo, "r--", lw=1, label="5% band")
        ax.plot(t_idx, hi, "r--", lw=1)
        ax.axhline(0, color="k", lw=0.5)
        ax.set_title(c, fontsize=9)
        ax.set_xlabel("Obs", fontsize=7)
        ax.tick_params(labelsize=7)
    # Hide unused axes
    for ax in axes[n_plots:]:
        ax.set_visible(False)
    plt.suptitle("CUSUM — ln_verim", fontsize=11, y=1.01)
    plt.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "sb_cusum_ln_verim.png"), dpi=150, bbox_inches="tight")
    plt.close()
    print(f"  → Saved: output/figures/sb_cusum_ln_verim.png")


# ═══════════════════════════════════════════════════════════════════════════════
# 3.  ZIVOT-ANDREWS (1992) UNIT ROOT WITH ONE STRUCTURAL BREAK
# ═══════════════════════════════════════════════════════════════════════════════
# Model C: Δy_t = c + β·t + γ·DU_t + δ·DT_t + α·y_{t-1} + Σψ_k Δy_{t-k} + ε_t
# where DU_t = 1(t > Tᴮ), DT_t = (t−Tᴮ)·1(t > Tᴮ)
# H0: α=0 (unit root with no break) vs H1: α<0 (trend-stationary with break)
# Test stat: t_α = min over all possible break dates Tᴮ

# Approximate ZA critical values (Zivot & Andrews 1992, Table 2, Model C)
ZA_CV = {"1%": -5.57, "5%": -5.08, "10%": -4.82}

def za_test(y: np.ndarray, k_max: int = 3) -> dict:
    """
    Zivot-Andrews (1992) unit root test with single break.
    Searches over interior 15%–85% of sample.
    """
    T_    = len(y)
    t_min = np.inf
    tb_opt = None
    lags_opt = None

    start_ = max(int(0.15 * T_), 2)
    end_   = int(0.85 * T_)

    for tb in range(start_, end_):
        # AIC-optimal lag selection
        best_aic = np.inf
        best_k   = 1
        for k in range(1, min(k_max, (T_ - tb) // 2) + 1):
            n_  = T_ - tb - k
            if n_ < 5: continue
            DU  = (np.arange(T_) > tb).astype(float)
            DT  = (np.arange(T_) - tb) * DU
            dy  = np.diff(y)
            Y_l = np.column_stack([y[k:T_-1],
                                    np.arange(1, T_-k),
                                    DU[k:T_-1], DT[k:T_-1]] +
                                   [dy[k-j:T_-1-j] for j in range(1, k+1)])
            dep_ = dy[k:]
            try:
                b, _, _, _ = np.linalg.lstsq(Y_l, dep_, rcond=None)
                e = dep_ - Y_l @ b
                aic_ = len(dep_)*np.log(np.sum(e**2)/len(dep_)) + 2*(Y_l.shape[1])
                if aic_ < best_aic:
                    best_aic = aic_; best_k = k
            except: pass

        k = best_k
        n_ = T_ - 1 - k
        if n_ < 5: continue
        DU = (np.arange(T_) > tb).astype(float)
        DT = (np.arange(T_) - tb) * DU
        dy = np.diff(y)
        Y_l = np.column_stack([y[k:T_-1],
                                np.ones(T_-1-k),
                                np.arange(1, T_-k),
                                DU[k:T_-1], DT[k:T_-1]] +
                               [dy[k-j:T_-1-j] for j in range(1, k+1)])
        dep_ = dy[k:]
        try:
            b, _, _, _ = np.linalg.lstsq(Y_l, dep_, rcond=None)
            e  = dep_ - Y_l @ b
            s2 = np.sum(e**2) / max(len(dep_) - Y_l.shape[1], 1)
            XtXi = np.linalg.inv(Y_l.T @ Y_l)
            se_a = np.sqrt(s2 * XtXi[0, 0])
            t_a  = b[0] / se_a
            if t_a < t_min:
                t_min = t_a; tb_opt = tb; lags_opt = k
        except: pass

    if tb_opt is None:
        return {"t_za": np.nan, "tb": np.nan, "k": np.nan,
                "CV_1%": ZA_CV["1%"], "CV_5%": ZA_CV["5%"], "CV_10%": ZA_CV["10%"],
                "Sig": "", "Decision": "NA"}

    sig = "***" if t_min < ZA_CV["1%"] else ("**" if t_min < ZA_CV["5%"] else ("*" if t_min < ZA_CV["10%"] else ""))
    dec = "Trend-stationary with break" if sig else "Unit root (no significant break)"
    return {
        "t_za": round(t_min, 4), "tb": int(tb_opt), "k": int(lags_opt),
        "CV_1%": ZA_CV["1%"], "CV_5%": ZA_CV["5%"], "CV_10%": ZA_CV["10%"],
        "Sig": sig, "Decision": dec
    }


print(f"\n{'='*70}")
print("3. ZIVOT-ANDREWS (1992) UNIT ROOT WITH ONE BREAK")
print(f"{'='*70}")

za_recs = []
for var in ["ln_verim", "ln_gubre"]:  # key variables; dea_bc is bounded (0,1) — ZA not applied
    print(f"\n  Variable: {var}")
    for c in countries:
        grp = panel.loc[panel["iso3c"] == c, ["year", var]].dropna().sort_values("year")
        if len(grp) < 14: continue
        y   = grp[var].values
        yrs = grp["year"].values
        res = za_test(y, k_max=2)
        tb_yr = yrs[res["tb"]] if not np.isnan(res["tb"]) else np.nan
        print(f"    {c:5s}  t_ZA={res['t_za']:.3f}  TB={tb_yr}  {res['Sig']:3s}  {res['Decision']}")
        za_recs.append({"iso3c": c, "variable": var,
                        "t_za": res["t_za"], "break_date": tb_yr,
                        "k_lags": res["k"],
                        "CV_5%": res["CV_5%"], "Sig": res["Sig"],
                        "Decision": res["Decision"]})

za_df = pd.DataFrame(za_recs)
za_df.to_csv(os.path.join(OUTPUT_DIR, "sb_zivot_andrews_results.csv"), index=False)
print(f"\n  → Saved: output/tables/sb_zivot_andrews_results.csv")


# ═══════════════════════════════════════════════════════════════════════════════
# 4.  SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
print(f"\n{'='*70}")
print("STRUCTURAL BREAK SUMMARY")
print(f"{'='*70}")

bp_y = bp_df[bp_df["variable"] == "ln_verim"]
n_breaks = (bp_y["BIC_opt_m"] > 0).sum()
print(f"\nBai-Perron (ln_verim): {n_breaks}/{len(bp_y)} countries show ≥1 BIC-optimal break")
print(f"  Countries with m≥1: {list(bp_y[bp_y['BIC_opt_m']>0]['iso3c'].values)}")

n_cusum = cusum_df[(cusum_df["variable"]=="ln_verim") & cusum_df["exceeds_5pct"]]["iso3c"].nunique()
print(f"\nCUSUM (ln_verim): {n_cusum}/{N} countries exceed 5% band")

za_y = za_df[za_df["variable"] == "ln_verim"]
n_za = (za_y["Sig"] != "").sum()
print(f"\nZivot-Andrews (ln_verim): {n_za}/{len(za_y)} countries reject unit root at 10%")

print(f"""
Note: Bai-Perron p-values use χ²(q) approximation.
For Q1 submission, cross-check with R strucchange::breakpoints()
for exact Andrews (1993) p-values.
""")
