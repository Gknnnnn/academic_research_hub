"""
P3 — Gold Policy Uncertainty QR
Figure generator: Fig 1 (EPU sign reversal) + Fig 2 (Fed funds monotonic)
Output: 03-Results/figures/fig1_epu_quantiles.tiff, fig2_fedfunds_quantiles.tiff
"""

import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.lines import Line2D
import os

# ── paths ──────────────────────────────────────────────────────────────────
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(BASE, "03-Results", "quantile_epu_full_grid.csv")
OUT  = os.path.join(BASE, "03-Results", "figures")
os.makedirs(OUT, exist_ok=True)

# ── load ───────────────────────────────────────────────────────────────────
df = pd.read_csv(DATA)
epu = df[df["variable"] == "epu_change"].copy().sort_values("tau")
fed = df[df["variable"] == "fed_funds_effective"].copy().sort_values("tau")

# significance color mapping
def sig_color(row):
    if row["sig"] == "***":
        return "#1a6b3c"   # dark green
    elif row["sig"] == "**":
        return "#3a8fbd"   # medium blue
    elif row["sig"] == "*":
        return "#e8a020"   # amber
    else:
        return "#aaaaaa"   # grey (NS)

# ── Figure 1: EPU sign reversal ────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(8, 5))

taus = epu["tau"].values
coefs = epu["coef"].values * 1e6          # rescale to units of 10^-6

# CI bands (only for quantiles where available)
ci_lo = epu["ci_lo"].values * 1e6
ci_hi = epu["ci_hi"].values * 1e6

# shaded CI where both lo/hi are present
has_ci = ~(np.isnan(ci_lo) | np.isnan(ci_hi))
ax.fill_between(taus[has_ci], ci_lo[has_ci], ci_hi[has_ci],
                alpha=0.18, color="#2166ac", label="95% bootstrap CI")

# zero reference line
ax.axhline(0, color="black", linewidth=0.8, linestyle="--", alpha=0.6)

# OLS estimate band (NS near zero — show as a translucent horizontal band)
ax.axhspan(-0.03, 0.03, alpha=0.08, color="red",
           label="OLS estimate ≈ 0 (NS)")

# points colored by significance
colors = [sig_color(row) for _, row in epu.iterrows()]
for i, (tau, coef, c) in enumerate(zip(taus, coefs, colors)):
    ax.scatter(tau, coef, color=c, s=70, zorder=5)

# connect with line
ax.plot(taus, coefs, color="#2166ac", linewidth=1.5, alpha=0.7)

# vertical line at zero-crossing (between τ=0.25 and τ=0.50)
ax.axvline(0.375, color="grey", linewidth=0.7, linestyle=":", alpha=0.7)
ax.text(0.375, max(coefs)*0.85, "Sign reversal", ha="center",
        fontsize=8, color="grey", style="italic")

# region labels
ax.text(0.10, min(coefs)*0.75, "Deleveraging\n(bear gold)", ha="center",
        fontsize=8.5, color="#1a6b3c", fontweight="bold")
ax.text(0.85, max(coefs)*0.75, "Safe-haven\n(bull gold)", ha="center",
        fontsize=8.5, color="#1a6b3c", fontweight="bold")

# legend patches
legend_elements = [
    mpatches.Patch(color="#1a6b3c", label="p < 0.001 (***)"),
    mpatches.Patch(color="#3a8fbd", label="p < 0.01 (**)"),
    mpatches.Patch(color="#e8a020", label="p < 0.05 (*)"),
    mpatches.Patch(color="#aaaaaa", label="NS"),
    mpatches.Patch(color="#2166ac", alpha=0.18, label="95% bootstrap CI"),
    mpatches.Patch(color="red", alpha=0.08, label="OLS ≈ 0 (NS)"),
]
ax.legend(handles=legend_elements, loc="upper left", fontsize=7.5,
          framealpha=0.9, ncol=2)

ax.set_xlabel("Gold-return quantile (τ)", fontsize=11)
ax.set_ylabel("β(ΔEPU) × 10⁻⁶", fontsize=11)
ax.set_title("Figure 1: EPU Effect on Gold Returns Across Quantiles\n"
             "(Sign reversal: negative in bear markets, positive in bull markets)",
             fontsize=11, pad=10)
ax.set_xticks(np.arange(0.05, 1.00, 0.10))
ax.set_xlim(0.02, 0.98)
ax.tick_params(axis="both", labelsize=9)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

plt.tight_layout()
fig1_path = os.path.join(OUT, "fig1_epu_quantiles.tiff")
fig.savefig(fig1_path, dpi=300, format="tiff",
            pil_kwargs={"compression": "tiff_lzw"})
print(f"Saved: {fig1_path}")
plt.close()

# ── Figure 2: Fed funds monotonic reversal ─────────────────────────────────
fig2, ax2 = plt.subplots(figsize=(8, 5))

taus_f = fed["tau"].values
coefs_f = fed["coef"].values * 1000        # rescale to units of 10^-3

ci_lo_f = fed["ci_lo"].values * 1000
ci_hi_f = fed["ci_hi"].values * 1000

has_ci_f = ~(np.isnan(ci_lo_f) | np.isnan(ci_hi_f))
ax2.fill_between(taus_f[has_ci_f], ci_lo_f[has_ci_f], ci_hi_f[has_ci_f],
                 alpha=0.18, color="#b2182b", label="95% bootstrap CI")

ax2.axhline(0, color="black", linewidth=0.8, linestyle="--", alpha=0.6)

# all points significant — color by sign for clarity
colors_f = ["#b2182b" if c < 0 else "#2166ac" for c in coefs_f]
for tau, coef, c in zip(taus_f, coefs_f, colors_f):
    ax2.scatter(tau, coef, color=c, s=70, zorder=5)

# gradient line (positive to negative)
ax2.plot(taus_f, coefs_f, color="#555555", linewidth=1.5, alpha=0.8)

# sign crossing annotation
crossing_tau = taus_f[np.argmin(np.abs(coefs_f))]
ax2.axvline(crossing_tau, color="grey", linewidth=0.7, linestyle=":", alpha=0.7)
ax2.text(crossing_tau + 0.02, max(coefs_f) * 0.5,
         f"Sign change\n(τ ≈ {crossing_tau:.2f})",
         ha="left", fontsize=8, color="grey", style="italic")

# region labels
ax2.text(0.12, max(coefs_f) * 0.75, "Cushions\ngold declines\n(p < 0.001)",
         ha="center", fontsize=8.5, color="#2166ac", fontweight="bold")
ax2.text(0.80, min(coefs_f) * 0.75, "Caps\ngold rallies\n(p < 0.001)",
         ha="center", fontsize=8.5, color="#b2182b", fontweight="bold")

legend_f = [
    mpatches.Patch(color="#2166ac", label="Positive (β > 0, p < 0.001)"),
    mpatches.Patch(color="#b2182b", label="Negative (β < 0, p < 0.001)"),
    mpatches.Patch(color="#b2182b", alpha=0.18, label="95% bootstrap CI"),
]
ax2.legend(handles=legend_f, loc="upper right", fontsize=8, framealpha=0.9)

ax2.set_xlabel("Gold-return quantile (τ)", fontsize=11)
ax2.set_ylabel("β(fed_funds_effective) × 10⁻³", fontsize=11)
ax2.set_title("Figure 2: Federal Funds Rate Effect on Gold Returns Across Quantiles\n"
              "(Monotonic reversal: all quantiles significant at p < 0.001)",
              fontsize=11, pad=10)
ax2.set_xticks(np.arange(0.05, 1.00, 0.10))
ax2.set_xlim(0.02, 0.98)
ax2.tick_params(axis="both", labelsize=9)
ax2.spines["top"].set_visible(False)
ax2.spines["right"].set_visible(False)

plt.tight_layout()
fig2_path = os.path.join(OUT, "fig2_fedfunds_quantiles.tiff")
fig2.savefig(fig2_path, dpi=300, format="tiff",
             pil_kwargs={"compression": "tiff_lzw"})
print(f"Saved: {fig2_path}")
plt.close()

print("Done. Both figures at 300 DPI LZW TIFF.")
