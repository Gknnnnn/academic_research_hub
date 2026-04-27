"""
P1: EPU → INR/USD Quantile-on-Quantile Analysis
Author: Res. Asst. Dr. M. Gökhan Özdemir, Kırıkkale University
ORCID: 0000-0002-6756-7285
Email: mgozdemirera@kku.edu.tr
Date: 2026-04-25
Package: wqr v1.0.1 (Roudane 2026)

NOTE: Requires bug patch on wqr/causality.py:238
  float(numerator * denominator)  →  float(np.asarray(numerator * denominator).item())

Data source: FRED API (public, no key required)
  USEPUINDXD — Baker, Bloom & Davis EPU Daily Index
  DEXINUS    — Indian Rupees per U.S. Dollar (USD/INR)
  DFF        — Federal Funds Effective Rate
  DEXUSEU    — U.S. Dollars per Euro (USD/EUR)
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import sys, os
for mod in list(sys.modules.keys()):
    if 'wqr' in mod:
        del sys.modules[mod]
import wqr

# ── 1. DATA ─────────────────────────────────────────────────────────────────

DATA_CACHE = os.path.join(
    os.path.expanduser("~"),
    "Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma",
    "200-Manuscripts/210-Active/2026-Research-Portfolio-Currency-Wars",
    "00-Infrastructure/data-cache"
)

def load_monthly(fname, col, start='2000-01-01', end='2026-01-01'):
    df = pd.read_csv(os.path.join(DATA_CACHE, fname))
    df.columns = [c.lower() for c in df.columns]
    dcol = [c for c in df.columns if 'date' in c or 'observation' in c][0]
    df[dcol] = pd.to_datetime(df[dcol], errors='coerce')
    df = df.dropna().rename(columns={dcol: 'date', col.lower(): col})
    series = df.set_index('date').resample('ME').mean()[col]
    # Replace . (missing) with NaN
    series = series.replace('.', np.nan).astype(float)
    return series.loc[start:end]

inr_raw  = load_monthly('DEXINUS.csv', 'dexinus')    # INR per USD (higher = weaker INR)
epu_raw  = load_monthly('USEPUINDXD.csv', 'usepuindxd')
dff_raw  = load_monthly('DFF.csv', 'dff')
eur_raw  = load_monthly('DEXUSEU.csv', 'dexuseu')    # USD per EUR

joint = pd.concat([inr_raw, epu_raw, dff_raw, eur_raw], axis=1).dropna()
joint.columns = ['inr_usd', 'epu', 'fed_rate', 'usd_eur']
T = len(joint)
print(f"Dataset: T={T} monthly observations ({joint.index[0].date()} – {joint.index[-1].date()})")

# Log-transform all series
log_joint = np.log(joint)
print("\nDescriptive statistics (log-transformed):")
print(log_joint.describe().round(4))

# ── 2. MAIN QQR: EPU → INR/USD ───────────────────────────────────────────────

print("\n" + "="*60)
print("QQR: EPU (x) → INR/USD (y) | n_boot=500")
print("="*60)

x_epu = log_joint['epu'].values
y_inr = log_joint['inr_usd'].values

result_main = wqr.qq_regression(y_inr, x_epu, n_boot=500, verbose=True)
print(result_main.summary() if hasattr(result_main, 'summary') else result_main)

# Save significant cells
df_main = result_main.results
sig = df_main[df_main['p_value'] < 0.05]
print(f"\nSignificant cells: {len(sig)}/{len(df_main)} ({100*len(sig)/len(df_main):.0f}%)")
print(f"All β > 0 (depreciation): {(sig['coefficient'] > 0).all()}")

sig.to_csv('../03-Results/qqr_epu_inr_significant_cells.csv', index=False)
df_main.to_csv('../03-Results/qqr_epu_inr_full_grid.csv', index=False)

# ── 3. FIGURES ────────────────────────────────────────────────────────────────

# 3a. 3D surface
fig3d, ax3d = wqr.plot_qq_3d(result_main, colormap='RdYlGn_r',
                               title='EPU → INR/USD: QQR Coefficient Surface')
fig3d.savefig('../03-Results/figures/fig_qqr_3d_surface.png', dpi=300, bbox_inches='tight')
plt.close(fig3d)

# 3b. Heatmap
fig_hm, ax_hm = wqr.plot_qq_heatmap(result_main,
                                      title='QQR Coefficient Grid: EPU → INR/USD\n(T=312 monthly, 2000–2025)',
                                      colormap='YlOrRd', annotate=False)
fig_hm.savefig('../03-Results/figures/fig_qqr_heatmap.png', dpi=300, bbox_inches='tight')
plt.close(fig_hm)

print("\n✓ Figures saved to 03-Results/figures/")

# ── 4. ROBUSTNESS: EUR/USD ──────────────────────────────────────────────────

print("\n" + "="*60)
print("ROBUSTNESS: EPU → USD/EUR | Hard currency safe-haven check")
print("="*60)

y_eur = log_joint['usd_eur'].values
result_eur = wqr.qq_regression(y_eur, x_epu, n_boot=300, verbose=False)
df_eur = result_eur.results
sig_eur = df_eur[df_eur['p_value'] < 0.05]
print(f"EUR/USD — Significant cells: {len(sig_eur)}/{len(df_eur)} ({100*len(sig_eur)/len(df_eur):.0f}%)")
print(f"β > 0 (EUR appreciation = USD weakness): {(sig_eur['coefficient'] > 0).sum()}")
print(f"β < 0 (EUR depreciation = USD strength): {(sig_eur['coefficient'] < 0).sum()}")
df_eur.to_csv('../03-Results/qqr_epu_eur_full_grid.csv', index=False)

# ── 5. LaTeX TABLE ────────────────────────────────────────────────────────────

print("\n" + "="*60)
print("Key QQR coefficient table (selected quantile pairs)")
print("="*60)
# Representative tau_x × tau_y grid (every 0.25)
key_pairs = [(0.25, q) for q in [0.25, 0.50, 0.75]] + \
            [(0.50, q) for q in [0.25, 0.50, 0.75]] + \
            [(0.75, q) for q in [0.25, 0.50, 0.75]]
tbl = []
for xq, yq in key_pairs:
    row = df_main[(df_main['x_quantile'].round(2)==round(xq,2)) &
                  (df_main['y_quantile'].round(2)==round(yq,2))]
    if len(row) > 0:
        r = row.iloc[0]
        tbl.append({'τ_EPU': xq, 'τ_INR': yq,
                    'β': round(r['coefficient'],3),
                    't': round(r['t_value'],2),
                    'p': round(r['p_value'],3)})
tbl_df = pd.DataFrame(tbl)
print(tbl_df.to_string(index=False))
tbl_df.to_csv('../03-Results/qqr_key_pairs_table.csv', index=False)

print("\n✓ P1 analysis complete. All outputs in 03-Results/")
print("Next: Write manuscript draft in 04-Manuscript/P1_EPU_INR_QQR_v01.qmd")
