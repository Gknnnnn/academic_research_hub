"""
Paper 1 — Currency Wars Gold Asymmetry
run_paper1_qqr_v1.py  — Quantile-on-Quantile Regression (QQR)

Method: Sim & Zhou (2015) QQR framework
  For each quantile θ of gold returns AND each quantile τ of DXY/JPY returns:
    y_t = α(θ,τ) + β(θ,τ)·x̃_t(τ) + ε_t^θ
  where x̃_t(τ) = x_t − F_x^{-1}(τ)  (local deviation from τ-th quantile of x)
  Weights: Gaussian kernel  w_t = K((F̂_x(x_t)−τ)/h)  with Silverman bandwidth
  Estimation: weighted quantile regression at level θ

Key contribution: β(θ,τ) surface — asymmetry in gold-DXY/JPY nexus across
  BOTH tails of the gold distribution AND both tails of the FX distribution.

Currency-wars narrative:
  DXY depreciation (τ<0.5) → gold rally? Is this effect larger than DXY
  appreciation (τ>0.5) → gold decline? Asymmetry: β(θ,τ<0.5) ≠ β(θ,τ>0.5)

Sample: post-2000 monthly returns (Jan 2000 – Apr 2026), N≈315
Controls: EPU (Baker-Bloom-Davis), fed_funds_effective

References:
  Sim N, Zhou H (2015) Oil prices, US stock returns, and the dependence between
    their quantiles. J Bank Finance 55:1-8. https://doi.org/10.1016/j.jbankfin.2015.01.013
  Bouri E, Gupta R, Tiwari AK, Roubaud D (2017) Does Bitcoin hedge global
    uncertainty? Evidence from wavelet-based quantile-in-quantile regressions.
    Finance Res Lett 23:87-95.
  Mensi W et al. (2020) Quantile-on-quantile of gold and Brent oil prices.
    Resour Policy 66:101615.

Author: Dr. M.G. Ozdemir, Kirikkale University, 2026-04-07
"""
from __future__ import annotations
import warnings
warnings.filterwarnings("ignore")

from pathlib import Path
import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy.stats import norm
from scipy.optimize import minimize
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

ROOT   = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
P1_DIR = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry"
DATASET = P1_DIR / "03-Results/paper1_gold_currency_wars_dataset_v2.csv"
OUT_DIR = P1_DIR / "03-Results"
FIG_DIR = P1_DIR / "04-Figures"
OUT_DIR.mkdir(exist_ok=True)
FIG_DIR.mkdir(exist_ok=True)

LOG = OUT_DIR / "paper1_qqr_v1_log.txt"
logf = open(LOG, "w", encoding="utf-8")
def log(*a):
    s = " ".join(str(x) for x in a); print(s); logf.write(s + "\n")

SAMPLE_START = "2000-01-01"
QUANTILES    = np.array([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9])
BOOT_N       = 500   # bootstrap replications for significance bands
SEED         = 42

# ─────────────────────────────────────────────────────────────────────────────
# 1. LOAD AND PREPARE
# ─────────────────────────────────────────────────────────────────────────────
log("=== 1. Load and prepare monthly returns ===")
df_daily = pd.read_csv(DATASET, parse_dates=["DATE"]).sort_values("DATE")
df_daily = df_daily.replace([np.inf, -np.inf], np.nan)
df_daily["gold_log"] = np.log(df_daily["GOLD"].replace(0, np.nan))
df_daily["dxy_log"]  = np.log(df_daily["DXY"].replace(0, np.nan))
df_daily["jpy_log"]  = np.log(df_daily["USDJPY"].replace(0, np.nan))
df_daily = df_daily.set_index("DATE")

monthly = pd.DataFrame({
    "gold_log":  df_daily["gold_log"].resample("ME").last(),
    "dxy_log":   df_daily["dxy_log"].resample("ME").last(),
    "jpy_log":   df_daily["jpy_log"].resample("ME").last(),
    "fed_funds": df_daily["fed_funds_effective"].resample("ME").mean(),
    "epu_us":    df_daily["epu_us"].resample("ME").mean(),
}).dropna().loc[SAMPLE_START:]

# Monthly log-returns
ret = monthly.diff().dropna()
log(f"  Monthly returns: {len(ret)} obs  ({ret.index[0].date()} – {ret.index[-1].date()})")

# Standardise controls for inclusion in QQR (mean 0, sd 1)
ret["epu_z"]  = (ret["epu_us"]   - ret["epu_us"].mean())   / ret["epu_us"].std()
ret["ffr_z"]  = (ret["fed_funds"] - ret["fed_funds"].mean()) / ret["fed_funds"].std()

# ─────────────────────────────────────────────────────────────────────────────
# 2. EMPIRICAL CDF TRANSFORM
# ─────────────────────────────────────────────────────────────────────────────
log("\n=== 2. Empirical CDF transform ===")

def ecdf_transform(s: pd.Series) -> pd.Series:
    """Map each observation to its empirical quantile rank ∈ (0,1)."""
    n = len(s)
    ranks = s.rank(method="average") / (n + 1)
    return ranks

ret["F_gold"] = ecdf_transform(ret["gold_log"])
ret["F_dxy"]  = ecdf_transform(ret["dxy_log"])
ret["F_jpy"]  = ecdf_transform(ret["jpy_log"])
log("  ECDF ranks computed for gold, DXY, JPY returns")

# ─────────────────────────────────────────────────────────────────────────────
# 3. QQR ESTIMATION FUNCTION
# ─────────────────────────────────────────────────────────────────────────────
log("\n=== 3. QQR estimation ===")

def silverman_bw(n: int) -> float:
    """Silverman (1986) rule of thumb bandwidth for kernel QQR."""
    return 1.06 * n ** (-0.2)

def fit_kw_qr(y: np.ndarray, X: np.ndarray, theta: float,
              weights: np.ndarray) -> np.ndarray:
    """
    Kernel-weighted quantile regression via direct minimisation of the
    weighted asymmetric (check) loss:
        min_β Σ_i w_i · ρ_θ(y_i − X_i'β)
    where ρ_θ(u) = u(θ − I(u<0)).

    statsmodels QuantReg.fit() ignores a `weights=` argument — scipy
    minimisation is required for proper kernel weighting.
    """
    def obj(beta):
        r = y - X @ beta
        loss = np.where(r >= 0, theta * r, (theta - 1) * r)
        return float(np.dot(weights, loss))

    # Warm start: WLS estimate
    W = np.diag(weights)
    try:
        beta0 = np.linalg.lstsq(X.T @ W @ X, X.T @ W @ y, rcond=None)[0]
    except Exception:
        beta0 = np.zeros(X.shape[1])

    res = minimize(obj, beta0, method="L-BFGS-B",
                   options={"maxiter": 2000, "ftol": 1e-9, "gtol": 1e-7})
    return res.x

def qqr_surface(y: pd.Series, x: pd.Series, F_x: pd.Series,
                controls: pd.DataFrame,
                thetas: np.ndarray, taus: np.ndarray,
                boot_n: int = 500, seed: int = 42) -> dict:
    """
    Estimate QQR β(θ,τ) surface following Sim & Zhou (2015).

    For each τ: Gaussian kernel weights centred at τ in CDF-space.
    For each θ: kernel-weighted quantile regression (scipy L-BFGS-B).
    Bootstrap 95% CIs from B=boot_n paired-resampled replications.

    Returns dict: 'beta', 'beta_lo', 'beta_hi', 'sig'  — each (|θ|×|τ|).
    """
    n = len(y)
    h = silverman_bw(n)
    rng = np.random.default_rng(seed)

    beta   = np.full((len(thetas), len(taus)), np.nan)
    boot_b = np.full((boot_n, len(thetas), len(taus)), np.nan)

    y_arr   = y.values.astype(float)
    x_arr   = x.values.astype(float)
    Fx_arr  = F_x.values.astype(float)
    ctrl_arr = controls.values.astype(float)

    for j, tau in enumerate(taus):
        # Gaussian kernel weights in CDF-space
        u  = (Fx_arr - tau) / h
        kw = norm.pdf(u)
        kw = kw / (kw.sum() + 1e-15)

        # x̃_t(τ): local deviation from τ-th unconditional quantile of x
        x_hat_tau = float(np.quantile(x_arr, tau))
        x_tilde   = x_arr - x_hat_tau

        X = np.column_stack([np.ones(n), x_tilde, ctrl_arr])

        for i, theta in enumerate(thetas):
            try:
                params = fit_kw_qr(y_arr, X, theta, kw)
                beta[i, j] = params[1]   # slope on x̃
            except Exception:
                pass

        # Bootstrap for 95% CI (paired resampling preserves x–y dependence)
        for b in range(boot_n):
            idx_b  = rng.integers(0, n, size=n)
            y_b    = y_arr[idx_b]
            X_b    = X[idx_b]
            kw_b   = kw[idx_b]; kw_b = kw_b / (kw_b.sum() + 1e-15)
            for i, theta in enumerate(thetas):
                try:
                    params_b = fit_kw_qr(y_b, X_b, theta, kw_b)
                    boot_b[b, i, j] = params_b[1]
                except Exception:
                    pass

    beta_lo = np.nanpercentile(boot_b, 2.5,  axis=0)
    beta_hi = np.nanpercentile(boot_b, 97.5, axis=0)
    sig = ((beta_lo > 0) | (beta_hi < 0)).astype(int)

    return {"beta": beta, "beta_lo": beta_lo, "beta_hi": beta_hi, "sig": sig}

# ─────────────────────────────────────────────────────────────────────────────
# 4. ESTIMATE QQR FOR DXY AND JPY
# ─────────────────────────────────────────────────────────────────────────────
controls = ret[["epu_z", "ffr_z"]]

log("\n  Estimating DXY QQR surface (this takes ~2-3 min) ...")
res_dxy = qqr_surface(
    y=ret["gold_log"], x=ret["dxy_log"], F_x=ret["F_dxy"],
    controls=controls, thetas=QUANTILES, taus=QUANTILES,
    boot_n=BOOT_N, seed=SEED
)
log("  DXY QQR done.")

log("\n  Estimating JPY QQR surface (this takes ~2-3 min) ...")
res_jpy = qqr_surface(
    y=ret["gold_log"], x=ret["jpy_log"], F_x=ret["F_jpy"],
    controls=controls, thetas=QUANTILES, taus=QUANTILES,
    boot_n=BOOT_N, seed=SEED
)
log("  JPY QQR done.")

# ─────────────────────────────────────────────────────────────────────────────
# 5. SAVE COEFFICIENT SURFACES TO CSV
# ─────────────────────────────────────────────────────────────────────────────
log("\n=== 5. Save coefficient surfaces ===")

def surface_to_df(beta, taus, thetas, varname):
    rows = []
    for i, th in enumerate(thetas):
        for j, ta in enumerate(taus):
            rows.append({"variable": varname, "theta": th, "tau": ta,
                         "beta": round(beta[i, j], 6)})
    return pd.DataFrame(rows)

df_dxy = surface_to_df(res_dxy["beta"], QUANTILES, QUANTILES, "DXY")
df_jpy = surface_to_df(res_jpy["beta"], QUANTILES, QUANTILES, "JPY")
df_all = pd.concat([df_dxy, df_jpy], ignore_index=True)
df_all.to_csv(OUT_DIR / "paper1_qqr_v1_beta_surface.csv", index=False)
log("  Saved: paper1_qqr_v1_beta_surface.csv")

# ─────────────────────────────────────────────────────────────────────────────
# 6. ASYMMETRY ANALYSIS
# ─────────────────────────────────────────────────────────────────────────────
log("\n=== 6. Asymmetry analysis ===")
# Compare β(θ, τ≤0.3) vs β(θ, τ≥0.7) for each θ
# DXY depreciation (τ≤0.3) vs DXY appreciation (τ≥0.7)

low_taus  = QUANTILES <= 0.3   # depreciation tail (DXY falls = gold-bullish)
high_taus = QUANTILES >= 0.7   # appreciation tail (DXY rises = gold-bearish)

asym_rows = []
for i, th in enumerate(QUANTILES):
    beta_low  = np.nanmean(res_dxy["beta"][i, low_taus])
    beta_high = np.nanmean(res_dxy["beta"][i, high_taus])
    asym_rows.append({
        "theta": th,
        "beta_dxy_depr_avg":  round(beta_low,  5),   # τ ≤ 0.3  (DXY weak)
        "beta_dxy_appr_avg":  round(beta_high, 5),   # τ ≥ 0.7  (DXY strong)
        "asymmetry_diff":     round(beta_low - beta_high, 5)  # >0 → larger depr effect
    })
    log(f"  θ={th:.1f}  β_depr(DXY)={beta_low:+.4f}  "
        f"β_appr(DXY)={beta_high:+.4f}  diff={beta_low-beta_high:+.4f}")

asym_df = pd.DataFrame(asym_rows)
asym_df.to_csv(OUT_DIR / "paper1_qqr_v1_asymmetry.csv", index=False)

# JPY asymmetry: τ≤0.3 (JPY appreciation = yen strengthens = risk-off)
#               τ≥0.7 (JPY depreciation = carry-trade unwind)
log("\n  JPY QQR asymmetry (yen appreciation τ≤0.3 vs depreciation τ≥0.7):")
for i, th in enumerate(QUANTILES):
    beta_low  = np.nanmean(res_jpy["beta"][i, low_taus])
    beta_high = np.nanmean(res_jpy["beta"][i, high_taus])
    log(f"  θ={th:.1f}  β_yen_appr={beta_low:+.4f}  "
        f"β_yen_depr={beta_high:+.4f}  diff={beta_low-beta_high:+.4f}")

# ─────────────────────────────────────────────────────────────────────────────
# 7. VISUALISATION — QQR HEATMAPS
# ─────────────────────────────────────────────────────────────────────────────
log("\n=== 7. Visualisation ===")

tau_labels  = [f"τ={t}" for t in QUANTILES]
theta_labels = [f"θ={t}" for t in QUANTILES]

FONT_TITLE  = 11
FONT_AXIS   = 10
FONT_TICK   = 9
FONT_CBAR   = 9

def plot_qqr_heatmap(beta, sig, title, fname, panel_label="", cmap="RdBu_r"):
    """
    Publication-quality heatmap of β(θ,τ).
    - Color scale anchored to data range (not symmetric ±vmax) to maximise gradient visibility.
    - Significant cells hatched with '///'.
    - Median lines at τ=0.5 and θ=0.5.
    - Panel label (a/b) in upper-left corner.
    """
    fig, ax = plt.subplots(figsize=(7, 5.8))

    # Anchor scale to actual data range for visibility of within-negative gradient
    vmin_data = np.nanmin(beta)
    vmax_data = np.nanmax(beta)
    # Make scale symmetric around 0 only if data spans both signs; else use data range
    if vmin_data < 0 < vmax_data:
        v = max(abs(vmin_data), abs(vmax_data))
        vmin_plot, vmax_plot = -v, v
    else:
        # All negative: centre scale so gradient is visible across τ
        pad = (vmax_data - vmin_data) * 0.05
        vmin_plot = vmin_data - pad
        vmax_plot = vmax_data + pad

    im = ax.imshow(beta, aspect="auto", cmap=cmap,
                   vmin=vmin_plot, vmax=vmax_plot, origin="lower")

    # Annotate each cell with β value (2 d.p.)
    for i in range(len(QUANTILES)):
        for j in range(len(QUANTILES)):
            val = beta[i, j]
            if not np.isnan(val):
                txt_color = "white" if abs(val) > 0.55 * abs(vmin_plot) else "black"
                ax.text(j, i, f"{val:.2f}", ha="center", va="center",
                        fontsize=6.5, color=txt_color, fontweight="normal")

    # Hatch significant cells
    for i in range(len(QUANTILES)):
        for j in range(len(QUANTILES)):
            if sig[i, j]:
                ax.add_patch(plt.Rectangle(
                    (j - 0.5, i - 0.5), 1, 1,
                    fill=False, hatch="///", edgecolor="black", linewidth=0.4, alpha=0.6))

    ax.set_xticks(range(len(QUANTILES)))
    ax.set_xticklabels([f"{t:.1f}" for t in QUANTILES], fontsize=FONT_TICK)
    ax.set_yticks(range(len(QUANTILES)))
    ax.set_yticklabels([f"{t:.1f}" for t in QUANTILES], fontsize=FONT_TICK)
    ax.set_xlabel("τ  (FX return quantile)", fontsize=FONT_AXIS)
    ax.set_ylabel("θ  (Gold return quantile)", fontsize=FONT_AXIS)
    ax.set_title(title, fontsize=FONT_TITLE, fontweight="bold", pad=10)

    cbar = plt.colorbar(im, ax=ax, fraction=0.03, pad=0.04)
    cbar.set_label("β(θ, τ)", fontsize=FONT_CBAR)
    cbar.ax.tick_params(labelsize=FONT_TICK - 1)

    # Median dividers
    ax.axvline(x=3.5, color="black", lw=1.0, ls="--", alpha=0.6)
    ax.axhline(y=3.5, color="black", lw=1.0, ls="--", alpha=0.6)

    # Panel label
    if panel_label:
        ax.text(-0.12, 1.02, panel_label, transform=ax.transAxes,
                fontsize=13, fontweight="bold", va="bottom")

    plt.tight_layout()
    for ext in ("png", "tiff"):
        plt.savefig(FIG_DIR / f"{fname}.{ext}", dpi=300, bbox_inches="tight")
    plt.close()
    log(f"  Saved: {fname}.png / .tiff")

plot_qqr_heatmap(
    res_dxy["beta"], res_dxy["sig"],
    title="(a)  QQR: Gold Returns on DXY Returns (2000–2026)\nβ(θ,τ)  —  hatched cells significant at 95% bootstrap CI",
    fname="fig_qqr_dxy", panel_label="(a)"
)

plot_qqr_heatmap(
    res_jpy["beta"], res_jpy["sig"],
    title="(b)  QQR: Gold Returns on JPY/USD Returns (2000–2026)\nβ(θ,τ)  —  hatched cells significant at 95% bootstrap CI",
    fname="fig_qqr_jpy", panel_label="(b)"
)

# ─────────────────────────────────────────────────────────────────────────────
# 8. ASYMMETRY LINE PLOT — with bootstrap CI bands
# ─────────────────────────────────────────────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(12, 4.5), sharey=False)
panel_labels = ["(c)", "(d)"]

for ax_idx, (ax, res, xvar, tail_labels) in enumerate(zip(
        axes,
        [res_dxy, res_jpy],
        ["DXY", "JPY/USD"],
        [("τ≤0.3  (dollar depreciation)", "τ≥0.7  (dollar appreciation)"),
         ("τ≤0.3  (yen appreciation)",    "τ≥0.7  (yen depreciation)")])):

    # Point estimates
    beta_low_line  = np.array([np.nanmean(res["beta"][i, low_taus])  for i in range(len(QUANTILES))])
    beta_high_line = np.array([np.nanmean(res["beta"][i, high_taus]) for i in range(len(QUANTILES))])

    # Bootstrap CI bands (average bootstrap betas over low/high tau groups)
    # boot_b shape: (B, n_theta, n_tau) — not stored, use beta_lo/hi per cell
    lo_low  = np.array([np.nanmean(res["beta_lo"][i, low_taus])  for i in range(len(QUANTILES))])
    hi_low  = np.array([np.nanmean(res["beta_hi"][i, low_taus])  for i in range(len(QUANTILES))])
    lo_high = np.array([np.nanmean(res["beta_lo"][i, high_taus]) for i in range(len(QUANTILES))])
    hi_high = np.array([np.nanmean(res["beta_hi"][i, high_taus]) for i in range(len(QUANTILES))])

    ax.fill_between(QUANTILES, lo_low,  hi_low,  color="steelblue", alpha=0.15)
    ax.fill_between(QUANTILES, lo_high, hi_high, color="firebrick",  alpha=0.15)
    ax.plot(QUANTILES, beta_low_line,  "o-",  color="steelblue", ms=6, lw=2,   label=tail_labels[0])
    ax.plot(QUANTILES, beta_high_line, "s--", color="firebrick",  ms=6, lw=2,   label=tail_labels[1])
    ax.axhline(0, color="gray", lw=0.8, ls=":")
    ax.axvline(0.5, color="gray", lw=0.6, ls="--", alpha=0.4)

    ax.set_xlabel("θ  (Gold return quantile)", fontsize=FONT_AXIS)
    ax.set_ylabel("Average  β(θ, τ)", fontsize=FONT_AXIS)
    ax.set_title(f"{panel_labels[ax_idx]}  Asymmetry: {xvar} → Gold",
                 fontsize=FONT_TITLE, fontweight="bold", loc="left")
    ax.legend(fontsize=8.5, framealpha=0.7)
    ax.set_xticks(QUANTILES)
    ax.tick_params(labelsize=FONT_TICK)
    ax.grid(axis="y", alpha=0.25)

    # Annotate asymmetry ratio
    ratio = abs(np.nanmean(beta_low_line)) / abs(np.nanmean(beta_high_line))
    ax.text(0.98, 0.04, f"Asymmetry ratio ≈ {ratio:.1f}:1",
            transform=ax.transAxes, ha="right", va="bottom",
            fontsize=8.5, color="black",
            bbox=dict(boxstyle="round,pad=0.3", fc="lightyellow", ec="gray", alpha=0.8))

plt.suptitle("QQR Asymmetry: Gold Returns vs DXY and JPY/USD  (2000–2026)\n"
             "Shaded bands = 95% bootstrap confidence intervals  (B = 500)",
             fontsize=FONT_TITLE, y=1.01)
plt.tight_layout()
for ext in ("png", "tiff"):
    plt.savefig(FIG_DIR / f"fig_qqr_asymmetry_lines.{ext}", dpi=300, bbox_inches="tight")
plt.close()
log("  Saved: fig_qqr_asymmetry_lines.png / .tiff")

# ─────────────────────────────────────────────────────────────────────────────
# 9. SUMMARY STATISTICS TABLE
# ─────────────────────────────────────────────────────────────────────────────
log("\n=== 9. Summary ===")
log(f"  Sample: {ret.index[0].date()} – {ret.index[-1].date()}  (N={len(ret)})")
log(f"  Bootstrap replications: {BOOT_N}  seed={SEED}")
log(f"  Quantile grid: {QUANTILES}")

dxy_sig_pct = res_dxy["sig"].mean() * 100
jpy_sig_pct = res_jpy["sig"].mean() * 100
log(f"  DXY: {dxy_sig_pct:.1f}% of β(θ,τ) cells significant at 95%")
log(f"  JPY: {jpy_sig_pct:.1f}% of β(θ,τ) cells significant at 95%")

dxy_avg_depr = np.nanmean(res_dxy["beta"][:, low_taus])
dxy_avg_appr = np.nanmean(res_dxy["beta"][:, high_taus])
log(f"  DXY avg β (depreciation τ≤0.3): {dxy_avg_depr:+.4f}")
log(f"  DXY avg β (appreciation  τ≥0.7): {dxy_avg_appr:+.4f}")
log(f"  DXY asymmetry (depr − appr):     {dxy_avg_depr - dxy_avg_appr:+.4f}")

summary = {
    "sample_start": str(ret.index[0].date()),
    "sample_end":   str(ret.index[-1].date()),
    "n_obs": len(ret),
    "bootstrap_n": BOOT_N,
    "dxy_sig_pct":  round(dxy_sig_pct, 1),
    "jpy_sig_pct":  round(jpy_sig_pct, 1),
    "dxy_beta_depr_avg": round(dxy_avg_depr, 5),
    "dxy_beta_appr_avg": round(dxy_avg_appr, 5),
    "dxy_asymmetry":     round(dxy_avg_depr - dxy_avg_appr, 5),
}
pd.DataFrame([summary]).to_csv(OUT_DIR / "paper1_qqr_v1_summary.csv", index=False)

log("\n[OK] QQR v1 complete. Outputs in 03-Results/ and 04-Figures/")
logf.close()
