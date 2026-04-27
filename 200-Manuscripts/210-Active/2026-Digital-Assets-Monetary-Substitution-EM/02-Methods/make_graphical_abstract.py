#!/usr/bin/env python3
"""
make_graphical_abstract.py — JIMF graphical abstract for P6
2026-04-09

Two-panel design:
  Left:  Conceptual flow diagram (fragility → adoption → regime split)
  Right: Coefficient bar chart showing the two-regime structure

Output: 03-Results/graphical_abstract.tiff (300 DPI, ~500×167 mm → JIMF spec)
        03-Results/graphical_abstract.png  (web preview)
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.patheffects as pe
import numpy as np

# ─── palette ──────────────────────────────────────────────────────────────────
DARK   = "#1a1a2e"
BLUE   = "#16213e"
TEAL   = "#0f3460"
GOLD   = "#e94560"
GREEN  = "#457b9d"
AMBER  = "#f4a261"
WHITE  = "#f8f9fa"
GREY   = "#adb5bd"

fig = plt.figure(figsize=(14, 6), facecolor=WHITE)
fig.patch.set_facecolor(WHITE)

# ─── LEFT PANEL: conceptual flow ─────────────────────────────────────────────
ax1 = fig.add_axes([0.01, 0.05, 0.44, 0.90])
ax1.set_xlim(0, 10)
ax1.set_ylim(0, 10)
ax1.axis("off")
ax1.set_facecolor(WHITE)

def box(ax, x, y, w, h, label, sublabel="", color=TEAL, fontsize=9):
    rect = mpatches.FancyBboxPatch(
        (x - w/2, y - h/2), w, h,
        boxstyle="round,pad=0.15", linewidth=1.5,
        edgecolor=color, facecolor=color + "22",
        zorder=3
    )
    ax.add_patch(rect)
    ax.text(x, y + (0.18 if sublabel else 0), label, ha="center", va="center",
            fontsize=fontsize, fontweight="bold", color=DARK, zorder=4)
    if sublabel:
        ax.text(x, y - 0.30, sublabel, ha="center", va="center",
                fontsize=7, color=GREY, zorder=4, style="italic")

def arrow(ax, x1, y1, x2, y2, color=GREY, label="", lw=1.5):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle="-|>", color=color,
                                lw=lw, mutation_scale=14), zorder=2)
    if label:
        mx, my = (x1+x2)/2, (y1+y2)/2
        ax.text(mx + 0.15, my, label, fontsize=7.5, color=color,
                va="center", ha="left", style="italic")

# ── title
ax1.text(5, 9.5, "Crypto Adoption as Monetary Absorber: A Contingent Equilibrium",
         ha="center", va="center", fontsize=10, fontweight="bold", color=DARK)

# ── input boxes
box(ax1, 2.5, 8.0, 3.5, 0.85, "EM Macro Fragility",
    "inflation · broad-money instability · reserves", GOLD)
box(ax1, 7.5, 8.0, 3.5, 0.85, "Global Dollar Shock",
    "DXY change · VIX risk appetite", GREEN)

# ── channel boxes
box(ax1, 5.0, 6.3, 3.8, 0.85, "Crypto Adoption Channel",
    "Chainalysis GCAI · crypto premium", TEAL)

# ── regime split
box(ax1, 2.2, 4.4, 4.0, 1.0,
    "Open-EM Amplification",
    "BRA · IND · MEX · NGA\nβ₅ = +0.676*** (Webb p<0.001)", GREEN)
box(ax1, 7.8, 4.4, 4.0, 1.0,
    "Argentina Absorber",
    "Capital controls + P2P USDT\nnet β = −10.284*** (p<0.001)", GOLD)

# ── arrows: inputs → channel
arrow(ax1, 2.5, 7.58, 4.0, 6.75, color=GREY)
arrow(ax1, 7.5, 7.58, 6.0, 6.75, color=GREY)

# ── channel → regimes
arrow(ax1, 3.6, 5.88, 2.8, 4.90, color=GREEN, lw=2)
arrow(ax1, 6.4, 5.88, 7.2, 4.90, color=GOLD, lw=2)

# ── outcome label
ax1.text(2.2, 3.4, "Crypto deepens FX stress", ha="center",
         fontsize=7.5, color=GREEN, fontweight="bold")
ax1.text(7.8, 3.4, "Crypto dampens FX pressure", ha="center",
         fontsize=7.5, color="#c1440e", fontweight="bold")

# ── DH Granger note
ax1.text(5.0, 2.5, "Dumitrescu-Hurlin Granger: dep → crypto (p=0.098*); crypto → dep (p=0.448 NS)",
         ha="center", fontsize=7.5, color=GREY, style="italic")

# ── Webb note
ax1.text(5.0, 1.8, "Webb (2023) wild cluster bootstrap · B=999 · N=6 clusters · 2022–2024",
         ha="center", fontsize=7.5, color=GREY, style="italic")

ax1.text(5.0, 0.9, "Six emerging markets: Argentina · Brazil · India · Mexico · Nigeria · South Africa",
         ha="center", fontsize=8.0, color=DARK)

# ─── RIGHT PANEL: bar chart of key coefficients ───────────────────────────────
ax2 = fig.add_axes([0.51, 0.12, 0.47, 0.80])
ax2.set_facecolor(WHITE)

# Data: LOO drop results + triple full
labels = [
    "Full sample\n(BRA+IND+MEX+NGA)",
    "Drop Brazil",
    "Drop India",
    "Drop Nigeria",
    "Drop Mexico\n(⚠ identification)",
    "Argentina\n(net: β₅+β₈)",
]
betas = [0.676, 1.379, 1.232, 0.443, -0.346, -10.284]
ci_lo = [0.676 - 0.214, 1.379 - 0.3, 1.232 - 0.3, 0.443 - 0.2, -0.346 - 0.2, -11.32]
ci_hi = [0.676 + 0.214, 1.379 + 0.3, 1.232 + 0.3, 0.443 + 0.2, -0.346 + 0.2, -9.19]

colors_bar = [GREEN, GREEN, GREEN, GREEN, AMBER, GOLD]
y_pos = np.arange(len(labels))

bars = ax2.barh(y_pos, betas, color=colors_bar, alpha=0.85,
                height=0.55, zorder=3)

# Error bars
for i, (lo, hi, b) in enumerate(zip(ci_lo, ci_hi, betas)):
    ax2.plot([lo, hi], [y_pos[i], y_pos[i]],
             color=DARK, lw=1.5, zorder=4)
    ax2.plot([lo, lo], [y_pos[i]-0.12, y_pos[i]+0.12],
             color=DARK, lw=1.5, zorder=4)
    ax2.plot([hi, hi], [y_pos[i]-0.12, y_pos[i]+0.12],
             color=DARK, lw=1.5, zorder=4)

ax2.axvline(0, color=DARK, lw=1.2, zorder=5)
ax2.set_yticks(y_pos)
ax2.set_yticklabels(labels, fontsize=8.5)
ax2.set_xlabel("β (GCAI × Monthly Inflation)", fontsize=9, color=DARK)
ax2.set_title("Leave-One-Out Robustness: GCAI × Inflation Coefficients\n"
              "(2022–2024, Webb bootstrap, B=999)",
              fontsize=9.5, fontweight="bold", color=DARK, pad=8)

ax2.spines[["top", "right"]].set_visible(False)
ax2.spines[["left", "bottom"]].set_color(GREY)
ax2.tick_params(colors=DARK)
ax2.xaxis.label.set_color(DARK)
ax2.set_xlim(-12.5, 3.5)
ax2.grid(axis="x", color=GREY, alpha=0.3, lw=0.7, zorder=1)

# Annotations
ax2.annotate("Amplification regime\n(crypto deepens stress)",
             xy=(0.67, 0), xytext=(1.5, 1.0),
             arrowprops=dict(arrowstyle="->", color=GREEN, lw=1.2),
             fontsize=7.5, color=GREEN, ha="center",
             bbox=dict(boxstyle="round,pad=0.2", fc=WHITE, ec=GREEN, lw=0.8))

ax2.annotate("Mexico drives\nidentification",
             xy=(-0.346, 3), xytext=(-5.5, 3.6),
             arrowprops=dict(arrowstyle="->", color=AMBER, lw=1.2),
             fontsize=7.5, color=AMBER, ha="center",
             bbox=dict(boxstyle="round,pad=0.2", fc=WHITE, ec=AMBER, lw=0.8))

ax2.annotate("Absorber regime\n(net β₅+β₈ = −10.28***)",
             xy=(-10.284, 5), xytext=(-9.0, 4.3),
             arrowprops=dict(arrowstyle="->", color="#c1440e", lw=1.2),
             fontsize=7.5, color="#c1440e", ha="center",
             bbox=dict(boxstyle="round,pad=0.2", fc=WHITE, ec=GOLD, lw=0.8))

# ─── save ─────────────────────────────────────────────────────────────────────
ROOT = "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-Digital-Assets-Monetary-Substitution-EM/03-Results"

fig.savefig(f"{ROOT}/graphical_abstract.tiff", dpi=300,
            bbox_inches="tight", facecolor=WHITE)
fig.savefig(f"{ROOT}/graphical_abstract.png", dpi=150,
            bbox_inches="tight", facecolor=WHITE)

print("Saved: graphical_abstract.tiff (300 DPI) + .png")
