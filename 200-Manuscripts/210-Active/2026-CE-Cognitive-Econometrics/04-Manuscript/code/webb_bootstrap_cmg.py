"""
Webb Wild Cluster Bootstrap — Common Correlated Effects MG (CE-CogEcon)
EU-27 macro panel: ln_cmu ~ CBI_eq_interp + ln_gdp + ln_educ + ln_prod

N = 27 clusters (EU countries), T = 15 years (2010-2024), NT = 405 obs.
Webb 6-point weights mandatory: N=27 is below the N=30 threshold for
conventional cluster-robust SEs (MacKinnon & Webb 2018, CJE).

CMG (Common Correlated Effects Mean Group) estimator:
  For each country i: OLS of ln_cmu on X + cross-section means (Ȳ, X̄)
  MG estimate = simple average of country-level coefficients

Bootstrap procedure (cross-sectional wild bootstrap):
  1. Fit CMG on original data; collect country residuals.
  2. For B iterations:
     a. Draw one Webb weight w_i per country.
     b. y*_{it} = ŷ_{it} + w_i * ê_{it} for all t.
     c. Re-estimate CMG on bootstrap data.
     d. Record bootstrap CMG coefficients.
  3. Bootstrap p-values: Pr(|β_b| ≥ |β_obs|)

Reference: MacKinnon & Webb (2018, CJE); Webb (2023, JBES)
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from pathlib import Path
from numpy.linalg import lstsq

SEED = 20260408
B    = 999
VARS = ["CBI_eq_interp", "ln_gdp", "ln_educ", "ln_prod"]
DEP  = "ln_cmu"

ROOT    = Path(__file__).resolve().parent.parent.parent
DATA    = ROOT / "400-Data/processed/macro_CBI_panel_full.csv"
OUT_CSV = ROOT / "600-Results/CE_pilot_v3/webb_cmg_bootstrap.csv"
OUT_TXT = ROOT / "600-Results/CE_pilot_v3/webb_cmg_bootstrap.txt"

WEBB_WEIGHTS = np.array([
    -np.sqrt(1.5), -1.0, -np.sqrt(0.5),
     np.sqrt(0.5),  1.0,  np.sqrt(1.5)
], dtype=float)

# ── Load data ──────────────────────────────────────────────────────────────────
rng = np.random.default_rng(SEED)
df  = pd.read_csv(DATA).sort_values(["country","year"]).dropna(subset=[DEP]+VARS)
countries = sorted(df["country"].unique())
N = len(countries)
print(f"N = {N} countries | NT = {len(df)} obs")

# ── CMG estimator ──────────────────────────────────────────────────────────────
def compute_cross_means(panel: pd.DataFrame, year_col: str,
                        vars_: list[str], dep: str) -> pd.DataFrame:
    """Compute cross-section averages for each year (Pesaran 2006 CCE)."""
    means = panel.groupby(year_col)[[dep] + vars_].mean()
    means.columns = [f"mean_{c}" for c in means.columns]
    return panel.merge(means.reset_index(), on=year_col, how="left")

def fit_cmg(panel: pd.DataFrame) -> tuple[pd.Series, pd.DataFrame]:
    """Fit CMG: country-by-country OLS with cross-section averages appended."""
    panel = compute_cross_means(panel, "year", VARS, DEP)
    aug_cols = VARS + [f"mean_{DEP}"] + [f"mean_{v}" for v in VARS]

    coef_list = []
    resid_dict = {}

    for country in countries:
        sub = panel[panel["country"] == country].copy()
        if len(sub) < len(aug_cols) + 2:
            continue
        y = sub[DEP].values
        X = np.column_stack([np.ones(len(sub))] + [sub[c].values for c in aug_cols])
        b, _, _, _ = lstsq(X, y, rcond=None)
        resid = y - X @ b
        coef_list.append(pd.Series(b[1: 1+len(VARS)], index=VARS, name=country))
        resid_dict[country] = resid

    coef_df = pd.DataFrame(coef_list)
    mg = coef_df.mean()   # MG average
    return mg, resid_dict, panel

# Observed CMG coefficients
obs_mg, obs_resid, panel_aug = fit_cmg(df)
print("Observed CMG estimates:")
for v in VARS:
    print(f"  {v}: {obs_mg[v]:.4f}")

# ── Webb wild cluster bootstrap ────────────────────────────────────────────────
# Pre-compute fitted values per country
fitted_dict = {}
panel_aug2 = compute_cross_means(df, "year", VARS, DEP)
aug_cols_global = VARS + [f"mean_{DEP}"] + [f"mean_{v}" for v in VARS]

for country in countries:
    sub = panel_aug2[panel_aug2["country"] == country]
    y = sub[DEP].values
    X = np.column_stack([np.ones(len(sub))] + [sub[c].values for c in aug_cols_global])
    b, _, _, _ = lstsq(X, y, rcond=None)
    fitted_dict[country] = X @ b

boot_coefs = {v: np.zeros(B) for v in VARS}

for b_iter in range(B):
    # Draw one Webb weight per country (cluster)
    weights = {c: rng.choice(WEBB_WEIGHTS) for c in countries}

    # Build bootstrap dataset
    df_b = df.copy()
    for country in countries:
        mask = df_b["country"] == country
        T_c  = mask.sum()
        resid_c = obs_resid.get(country, np.zeros(T_c))
        if len(resid_c) != T_c:
            continue
        df_b.loc[mask, DEP] = fitted_dict[country] + weights[country] * resid_c

    # Re-estimate CMG on bootstrap data
    mg_b, _, _ = fit_cmg(df_b)
    for v in VARS:
        boot_coefs[v][b_iter] = mg_b[v]

# ── Bootstrap p-values and CIs ─────────────────────────────────────────────────
records = []
for v in VARS:
    obs_val = float(obs_mg[v])
    boots   = boot_coefs[v]
    # Symmetric p-value: Pr(|β_b| ≥ |β_obs|)
    p_webb  = float(np.mean(np.abs(boots) >= abs(obs_val)))
    ci_lo   = float(np.percentile(boots, 2.5))
    ci_hi   = float(np.percentile(boots, 97.5))
    sig     = ("***" if p_webb < 0.01 else
               "**"  if p_webb < 0.05 else
               "*"   if p_webb < 0.10 else "")
    records.append({
        "variable": v,
        "coef":    round(obs_val, 4),
        "p_webb":  round(p_webb, 3),
        "ci_lo":   round(ci_lo, 4),
        "ci_hi":   round(ci_hi, 4),
        "sig":     sig,
    })
    print(f"  {v}: coef={obs_val:.4f}  p_webb={p_webb:.3f} {sig}  "
          f"95%CI=[{ci_lo:.4f}, {ci_hi:.4f}]")

results = pd.DataFrame(records)
results.to_csv(OUT_CSV, index=False)

# ── Write text report ──────────────────────────────────────────────────────────
header = (
    "=========================================================================\n"
    " Webb Wild Cluster Bootstrap — CMG Long-Run Estimates (CE-CogEcon)\n"
    "=========================================================================\n"
    f" EU-27 macro panel | N={N} clusters | NT={len(df)} obs\n"
    f" Bootstrap: B={B}  Webb 6-pt weights  seed={SEED}\n"
    " Estimator: CMG (Common Correlated Effects Mean Group)\n"
    " Dep. var: ln_cmu | Regressors: CBI + ln_gdp + ln_educ + ln_prod\n"
    "-------------------------------------------------------------------------\n"
    f"{'Variable':>18}  {'coef':>8}  {'p_webb':>7}  {'sig':>4}  "
    f"{'CI_lo':>8}  {'CI_hi':>8}\n"
    "-------------------------------------------------------------------------\n"
)
rows = []
for r in records:
    rows.append(
        f"{r['variable']:>18}  {r['coef']:>8.4f}  {r['p_webb']:>7.3f}  "
        f"{r['sig']:>4}  {r['ci_lo']:>8.4f}  {r['ci_hi']:>8.4f}"
    )
footer = (
    "\n-------------------------------------------------------------------------\n"
    " Significance: * p_webb<0.10  ** p_webb<0.05  *** p_webb<0.01\n"
    " p_webb: Webb wild cluster bootstrap (symmetric, |β_b|≥|β_obs|)\n"
    " 95% CI: percentile bootstrap interval\n"
    " Note: CBI long-run coefficient directionally negative but NS across\n"
    "   all methods; DH causality (Zbar=11.46, p<0.001) is the primary\n"
    "   CBI contribution in the macro arm.\n"
    "=========================================================================\n"
)
output_text = header + "\n".join(rows) + footer
with open(OUT_TXT, "w") as f:
    f.write(output_text)

print(f"\n✅ Saved: {OUT_CSV.name}, {OUT_TXT.name}")
print(output_text)
