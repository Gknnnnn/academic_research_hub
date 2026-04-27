"""
Paper 1 — Currency Wars Gold Asymmetry
run_paper1_wqr_v1.py — wqr.qq_regression cross-check

Purpose : Replicate QQR results using wqr-1.0.1 (Sim & Zhou 2015)
          and compare against existing scipy implementation (run_paper1_qqr_v1.py)

Cross-check targets:
  DXY: β(τ≤0.3) ≈ −0.763  |  β(τ≥0.7) ≈ −0.312  |  asymmetry 2.4:1
  JPY: β(τ≤0.3) ≈ −0.527  |  β(τ≥0.7) ≈ −0.392  |  asymmetry 1.4:1

Author: Dr. M.G. Ozdemir, Kirikkale University, 2026-04-24
"""
from pathlib import Path
import warnings
warnings.filterwarnings("ignore")

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import wqr

# ── Paths ─────────────────────────────────────────────────────────────────────
ROOT    = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
P1_DIR  = ROOT / "200-Manuscripts/210-Active/2026-Currency-Wars-Gold-Asymmetry"
DATASET = P1_DIR / "03-Results/paper1_gold_currency_wars_dataset_v2.csv"
OUT_DIR = P1_DIR / "03-Results"
FIG_DIR = P1_DIR / "04-Figures"
OLD_BETA = OUT_DIR / "paper1_qqr_v1_beta_surface.csv"

# ── Load & filter (monthly, post-2000) ────────────────────────────────────────
df = pd.read_csv(DATASET, parse_dates=["DATE"])
df = df[df["DATE"] >= "2000-01-01"].copy()

# Resample to monthly (last observation per month)
df.set_index("DATE", inplace=True)
monthly = df[["gold_return", "dxy_return", "usdjpy_return"]].resample("ME").last().dropna()
print(f"Sample: {monthly.index[0].date()} → {monthly.index[-1].date()}, N={len(monthly)}")

y   = monthly["gold_return"].values
dxy = monthly["dxy_return"].values
jpy = monthly["usdjpy_return"].values

# Quantile grid: 0.10 to 0.90 in steps of 0.10 (matches existing results)
TAUS = np.arange(0.10, 0.91, 0.10)

# ── Run wqr QQR ───────────────────────────────────────────────────────────────
print("\n=== DXY → GOLD QQR (wqr) ===")
res_dxy = wqr.qq_regression(
    y=y, x=dxy,
    y_quantiles=TAUS,
    x_quantiles=TAUS,
    n_boot=500,
    se_method="boot",
    verbose=True
)

print("\n=== JPY → GOLD QQR (wqr) ===")
res_jpy = wqr.qq_regression(
    y=y, x=jpy,
    y_quantiles=TAUS,
    x_quantiles=TAUS,
    n_boot=500,
    se_method="boot",
    verbose=True
)

# ── Extract beta matrices ─────────────────────────────────────────────────────
def extract_betas(res, var_name):
    """Convert QQResult to long-format DataFrame matching existing CSV format."""
    df_r = res.to_dataframe()
    df_r = df_r.rename(columns={
        "y_quantile": "theta",
        "x_quantile": "tau",
        "coefficient": "beta"
    })
    df_r["variable"] = var_name
    df_r["theta"] = df_r["theta"].round(2)
    df_r["tau"]   = df_r["tau"].round(2)
    return df_r[["variable", "theta", "tau", "beta", "std_error", "p_value"]]

df_dxy = extract_betas(res_dxy, "DXY")
df_jpy = extract_betas(res_jpy, "JPY")
beta_wqr = pd.concat([df_dxy, df_jpy], ignore_index=True)

# Save wqr beta surface
out_beta = OUT_DIR / "paper1_wqr_v1_beta_surface.csv"
beta_wqr.to_csv(out_beta, index=False)
print(f"\n✅ wqr beta surface saved: {out_beta}")

# ── Cross-check: compare with existing scipy results ─────────────────────────
print("\n=== CROSS-CHECK: wqr vs scipy ===")
old = pd.read_csv(OLD_BETA)

merged = old.merge(beta_wqr, on=["variable","theta","tau"], suffixes=("_scipy","_wqr"))
merged["diff"] = merged["beta_wqr"] - merged["beta_scipy"]
merged["abs_diff"] = merged["diff"].abs()

print(f"Mean |diff|: {merged['abs_diff'].mean():.4f}")
print(f"Max  |diff|: {merged['abs_diff'].max():.4f}")
print(f"Corr(scipy, wqr): {merged['beta_scipy'].corr(merged['beta_wqr']):.4f}")

# Save comparison
out_compare = OUT_DIR / "paper1_wqr_vs_scipy_comparison.csv"
merged.to_csv(out_compare, index=False)
print(f"✅ Comparison saved: {out_compare}")

# ── Key statistics ─────────────────────────────────────────────────────────────
print("\n=== KEY ASYMMETRY STATISTICS (wqr) ===")
for var in ["DXY", "JPY"]:
    sub = beta_wqr[beta_wqr["variable"] == var]
    low  = sub[sub["tau"] <= 0.3]["beta"].mean()
    high = sub[sub["tau"] >= 0.7]["beta"].mean()
    ratio = abs(low / high) if high != 0 else np.nan
    print(f"{var}: β(τ≤0.3)={low:.3f}  β(τ≥0.7)={high:.3f}  ratio={ratio:.2f}:1")

# ── Summary CSV ───────────────────────────────────────────────────────────────
summary_rows = []
for var, res in [("DXY", res_dxy), ("JPY", res_jpy)]:
    sub = beta_wqr[beta_wqr["variable"] == var]
    low  = sub[sub["tau"] <= 0.3]["beta"].mean()
    high = sub[sub["tau"] >= 0.7]["beta"].mean()
    old_sub = old[old["variable"] == var]
    old_low  = old_sub[old_sub["tau"] <= 0.3]["beta"].mean()
    old_high = old_sub[old_sub["tau"] >= 0.7]["beta"].mean()
    summary_rows.append({
        "variable": var,
        "wqr_beta_low_tau": round(low, 4),
        "wqr_beta_high_tau": round(high, 4),
        "wqr_asymmetry": round(abs(low/high), 2) if high != 0 else np.nan,
        "scipy_beta_low_tau": round(old_low, 4),
        "scipy_beta_high_tau": round(old_high, 4),
        "scipy_asymmetry": round(abs(old_low/old_high), 2) if old_high != 0 else np.nan,
    })
summary = pd.DataFrame(summary_rows)
out_summ = OUT_DIR / "paper1_wqr_v1_summary.csv"
summary.to_csv(out_summ, index=False)
print(f"\n✅ Summary saved: {out_summ}")
print(summary.to_string(index=False))

# ── Figures: heatmaps ─────────────────────────────────────────────────────────
def plot_heatmap(beta_df, var, fig_path, title):
    pivot = beta_df[beta_df["variable"] == var].pivot(
        index="theta", columns="tau", values="beta")
    fig, ax = plt.subplots(figsize=(8, 6))
    im = ax.imshow(pivot.values, aspect="auto", origin="lower",
                   extent=[TAUS[0], TAUS[-1], TAUS[0], TAUS[-1]],
                   cmap="RdBu_r", vmin=-1.5, vmax=0.5)
    plt.colorbar(im, ax=ax, label="β(θ,τ)")
    ax.set_xlabel("τ (quantile of FX return)", fontsize=11)
    ax.set_ylabel("θ (quantile of gold return)", fontsize=11)
    ax.set_title(title, fontsize=12)
    ax.set_xticks(TAUS); ax.set_yticks(TAUS)
    fig.tight_layout()
    fig.savefig(fig_path.with_suffix(".png"), dpi=300, bbox_inches="tight")
    fig.savefig(fig_path.with_suffix(".tiff"), dpi=300, bbox_inches="tight")
    plt.close()
    print(f"✅ Figure saved: {fig_path}")

plot_heatmap(beta_wqr, "DXY",
             FIG_DIR / "fig_wqr_dxy",
             "QQR: DXY Return → Gold Return\n(wqr, B=500, 2000–2026 monthly)")

plot_heatmap(beta_wqr, "JPY",
             FIG_DIR / "fig_wqr_jpy",
             "QQR: USD/JPY Return → Gold Return\n(wqr, B=500, 2000–2026 monthly)")

print("\n=== DONE ===")
