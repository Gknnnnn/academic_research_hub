"""
WQR P2 — EKC NP Quantile Causality, BRICS-T 1995-2021
Analysis script — 2026-04-25
Author: Res. Asst. Dr. M. Gökhan Özdemir

Requires:
  - wqr==1.0.1 (bug fix at causality.py:238 applied — see project_wqr_paper_pipeline.md)
  - statsmodels, matplotlib, pandas, numpy

Data source:
  - EKC BRICST panel: 200-Manuscripts/210-Active/EKC_BRICST/02-Methods/400-Data/processed/ekc_bricst_9country_panel.csv
  - Variables used: iso3, year, ln_ef, ln_gdp
"""

import pandas as pd
import numpy as np
import wqr
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
from statsmodels.tsa.stattools import adfuller
import warnings
warnings.filterwarnings('ignore')

# ─── Paths ────────────────────────────────────────────────────────────
DATA_PATH = '../../EKC_BRICST/02-Methods/400-Data/processed/ekc_bricst_9country_panel.csv'
OUTDIR = '../03-Results'

# ─── Data ─────────────────────────────────────────────────────────────
df = pd.read_csv(DATA_PATH)
countries = sorted(df['iso3'].unique())  # ['BRA','CHN','IDN','IND','MEX','NGA','RUS','TUR','ZAF']
country_labels = {
    'BRA': 'Brazil', 'CHN': 'China', 'IDN': 'Indonesia',
    'IND': 'India',  'MEX': 'Mexico', 'NGA': 'Nigeria',
    'RUS': 'Russia', 'TUR': 'Türkiye', 'ZAF': 'South Africa'
}

# ─── 1. ADF Unit Root Tests ────────────────────────────────────────────
print("=== ADF Unit Root Tests ===")
for iso in countries:
    sub = df[df['iso3'] == iso].sort_values('year')
    for varname, series in [('ln_ef', sub['ln_ef'].values), ('ln_gdp', sub['ln_gdp'].values)]:
        res = adfuller(series, maxlag=4, autolag='AIC', regression='ct')
        order = 'I(0)' if res[1] < 0.05 else 'I(1)'
        print(f"  {iso} {varname}: ADF={res[0]:.2f} p={res[1]:.3f} lags={res[2]} [{order}]")

# ─── 2. Country-level NP Quantile Causality ───────────────────────────
quantiles_main = [0.10, 0.25, 0.50, 0.75, 0.90]
quantiles_full = [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95]

print("\n=== Country-level NP Quantile Causality ===")
country_rows = []

for iso in countries:
    sub = df[df['iso3'] == iso].sort_values('year')
    ef = sub['ln_ef'].values
    gdp = sub['ln_gdp'].values

    for direction, x, y in [('GDP→EF', gdp, ef), ('EF→GDP', ef, gdp)]:
        res = wqr.np_quantile_causality(x, y, test_type='quantile', q=quantiles_main)
        dfr = res.to_dataframe()
        dfr['direction'] = direction
        dfr['level'] = 'country'
        dfr['iso3'] = iso
        country_rows.append(dfr)

country_df = pd.concat(country_rows, ignore_index=True)
country_df.to_csv(f'{OUTDIR}/country_np_causality.csv', index=False)
print(f"  Saved: {OUTDIR}/country_np_causality.csv")

# ─── 3. Within-demeaned Panel NP Causality ────────────────────────────
print("\n=== Within-Demeaned Panel NP Causality ===")
df2 = df.copy().sort_values(['iso3', 'year'])
df2['ln_ef_dm']  = df2.groupby('iso3')['ln_ef'].transform(lambda x: x - x.mean())
df2['ln_gdp_dm'] = df2.groupby('iso3')['ln_gdp'].transform(lambda x: x - x.mean())

ef_dm = df2['ln_ef_dm'].values
gdp_dm = df2['ln_gdp_dm'].values

panel_rows = []
for direction, x, y in [('GDP→EF', gdp_dm, ef_dm), ('EF→GDP', ef_dm, gdp_dm)]:
    res = wqr.np_quantile_causality(x, y, test_type='quantile', q=quantiles_full)
    dfr = res.to_dataframe()
    dfr['direction'] = direction
    dfr['level'] = 'panel'
    dfr['iso3'] = 'ALL'
    panel_rows.append(dfr)

panel_df = pd.concat(panel_rows, ignore_index=True)
panel_df.to_csv(f'{OUTDIR}/panel_np_causality.csv', index=False)
print(f"  Saved: {OUTDIR}/panel_np_causality.csv")

# ─── 4. Figure: Heatmap ────────────────────────────────────────────────
directions = ['EF→GDP', 'GDP→EF']
dir_labels = ['EF → GDP\n(Ecological Constraint)', 'GDP → EF\n(EKC Hypothesis)']

fig, axes = plt.subplots(1, 2, figsize=(13, 5.5), sharey=True)

for ax_idx, (direction, dir_label) in enumerate(zip(directions, dir_labels)):
    ax = axes[ax_idx]
    sub = country_df[country_df['direction'] == direction]

    stats_matrix = np.zeros((len(countries), len(quantiles_main)))
    sig5_matrix  = np.zeros((len(countries), len(quantiles_main)), dtype=bool)
    sig10_matrix = np.zeros((len(countries), len(quantiles_main)), dtype=bool)

    for i, iso in enumerate(countries):
        for j, q in enumerate(quantiles_main):
            row = sub[(sub['iso3'] == iso) & (sub['quantile'] == q)]
            if len(row) > 0:
                r = row.iloc[0]
                stats_matrix[i, j] = r['statistic']
                sig5_matrix[i, j]  = r['significant_5pct']
                sig10_matrix[i, j] = r['significant_10pct']

    cmap = LinearSegmentedColormap.from_list('custom', ['#f8f9fa', '#2c7bb6', '#01665e'])
    im = ax.imshow(stats_matrix, cmap=cmap, aspect='auto', vmin=0, vmax=3.5, interpolation='nearest')

    for i in range(len(countries)):
        for j in range(len(quantiles_main)):
            s = stats_matrix[i, j]
            if sig5_matrix[i, j]:
                ax.text(j, i, f'{s:.2f}**', ha='center', va='center', fontsize=8.5, fontweight='bold', color='white')
            elif sig10_matrix[i, j]:
                ax.text(j, i, f'{s:.2f}*',  ha='center', va='center', fontsize=8.5, fontweight='bold', color='white')
            else:
                color = 'black' if s < 1.5 else 'white'
                ax.text(j, i, f'{s:.2f}',   ha='center', va='center', fontsize=8,   color=color)

    ax.set_xticks(range(len(quantiles_main)))
    ax.set_xticklabels([f'τ={q:.2f}' for q in quantiles_main], fontsize=9)
    ax.set_xlabel('Quantile', fontsize=9)
    if ax_idx == 0:
        ax.set_yticks(range(len(countries)))
        ax.set_yticklabels([country_labels[c] for c in countries], fontsize=9)
    ax.set_title(dir_label, fontsize=10, fontweight='bold', pad=8)
    for i in range(len(countries) + 1):
        ax.axhline(y=i - 0.5, color='grey', lw=0.3, alpha=0.5)
    for j in range(len(quantiles_main) + 1):
        ax.axvline(x=j - 0.5, color='grey', lw=0.3, alpha=0.5)
    plt.colorbar(im, ax=ax, label='Test statistic', shrink=0.75)

fig.suptitle('Nonparametric Quantile Causality — BRICS-T, 1995–2021\nCritical value = 1.96 (**p<5%, *p<10%)', fontsize=10, y=1.02)
plt.tight_layout()
fig.savefig(f'{OUTDIR}/fig1_np_causality_heatmap.png', dpi=300, bbox_inches='tight')
plt.close()
print(f"\nFigure saved: {OUTDIR}/fig1_np_causality_heatmap.png")
print("\nDone.")
