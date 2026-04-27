"""
Webb Wild Bootstrap for Toda-Yamamoto Wald Tests
UY-MGO Sustainability Nexus — Migration-Carbon-Growth (N=24, 2000-2023)

Reference: MacKinnon & Webb (2018, CJE); Webb (2023, JBES)
TY setup: k=1 (BIC-optimal), dmax=1 (I(1) variables), VAR order P=2

Bootstrap strategy (VAR system wild bootstrap):
  Wald statistics replicate the statsmodels VAR.test_causality() approach,
  which tests ALL P=2 lags of the cause variable in the effect equation (df=2).
  NOTE: Technically, TY only tests the first k=1 lags; including the dmax lag
  makes this a conservative (df-inflated) test. We match the original script's
  df=2 definition so bootstrap p-values are directly comparable to TY_results_v2.txt.

  Bootstrap procedure (system wild bootstrap):
    1. Fit unrestricted VAR(P=2) on original data.
    2. Compute system residuals (T_eff × n_vars).
    3. For B=999 iterations:
       a. Draw one Webb weight w_t per time-point; apply to all equations.
       b. Bootstrap data = VAR_fitted + diag(w) @ VAR_residuals.
       c. Fit VAR(P=2) to bootstrap data.
       d. Compute Wald statistic via test_causality for each pair.
    4. p_webb = Pr(Wald_boot >= Wald_obs).

Webb 6-point weights: {±√1.5, ±1, ±√0.5} — superior size control vs
Rademacher in small T (Gonçalves & Kilian 2004; Webb 2023).
"""

import numpy as np
import pandas as pd
import os
from statsmodels.tsa.api import VAR

# ── Configuration ────────────────────────────────────────────────────────────
SEED     = 20260407
B        = 999
K        = 1      # structural lag (BIC)
DMAX     = 1      # integration order
P        = K + DMAX   # VAR order = 2

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_PATH  = os.path.join(SCRIPT_DIR, "../03-Results/data_UY_2000_2023.csv")
OUT_TXT    = os.path.join(SCRIPT_DIR, "../03-Results/webb_TY_wald_bootstrap.txt")
OUT_CSV    = os.path.join(SCRIPT_DIR, "../03-Results/webb_TY_wald_bootstrap.csv")

WEBB_WEIGHTS = np.array([
    -np.sqrt(1.5), -1.0, -np.sqrt(0.5),
     np.sqrt(0.5),  1.0,  np.sqrt(1.5)
], dtype=float)

VARNAMES = ["MIG", "CO2", "GDP", "GI"]

# ── Load data ─────────────────────────────────────────────────────────────────
rng = np.random.default_rng(SEED)
df  = pd.read_csv(DATA_PATH).sort_values("year").reset_index(drop=True)
Ydf = df[VARNAMES].copy()
T   = len(Ydf)

# ── Fit unrestricted VAR(P=2) on original data ────────────────────────────────
model = VAR(Ydf)
res   = model.fit(maxlags=P, ic=None, trend="c")

T_eff   = T - P          # effective sample after lags = 22
fitted  = res.fittedvalues.values    # (T_eff, n_vars)
resids  = res.resid.values           # (T_eff, n_vars)

# ── Observed Wald statistics ──────────────────────────────────────────────────
obs_records = {}
pairs = [(c, e) for c in VARNAMES for e in VARNAMES if c != e]

for (cause, effect) in pairs:
    t_res = res.test_causality(effect, [cause], kind="wald")
    obs_records[(cause, effect)] = {
        "Wald": round(float(t_res.test_statistic), 3),
        "df":   int(t_res.df),
        "p_asymp": round(float(t_res.pvalue), 4),
    }

# ── Webb wild bootstrap (system-level) ───────────────────────────────────────
# boot_counts[pair] = number of bootstrap Wald >= observed Wald
boot_counts = {pair: 0 for pair in pairs}

for b in range(B):
    # Single scalar weight per time-point, applied to all equations
    w = rng.choice(WEBB_WEIGHTS, size=T_eff)    # (T_eff,)
    # Bootstrap data: shape (T_eff, n_vars)
    Y_star_eff = fitted + (w[:, np.newaxis] * resids)

    # Rebuild full time-series (prepend first P rows of original for lags)
    Y_star_full = np.vstack([Ydf.values[:P, :], Y_star_eff])
    Ydf_star = pd.DataFrame(Y_star_full, columns=VARNAMES)

    try:
        res_b = VAR(Ydf_star).fit(maxlags=P, ic=None, trend="c")
    except Exception:
        continue

    for (cause, effect) in pairs:
        try:
            tb = res_b.test_causality(effect, [cause], kind="wald")
            wald_b = float(tb.test_statistic)
        except Exception:
            wald_b = 0.0
        if wald_b >= obs_records[(cause, effect)]["Wald"]:
            boot_counts[(cause, effect)] += 1

# ── Compile results ───────────────────────────────────────────────────────────
records = []
for (cause, effect) in pairs:
    wald_obs = obs_records[(cause, effect)]["Wald"]
    df_val   = obs_records[(cause, effect)]["df"]
    p_asymp  = obs_records[(cause, effect)]["p_asymp"]
    p_webb   = round(boot_counts[(cause, effect)] / B, 3)

    stars = ""
    if p_webb < 0.01:  stars = "***"
    elif p_webb < 0.05: stars = "**"
    elif p_webb < 0.10: stars = "*"

    records.append({
        "cause":   cause,
        "effect":  effect,
        "Wald":    wald_obs,
        "df":      df_val,
        "p_asymp": p_asymp,
        "p_webb":  p_webb,
        "sig":     stars,
    })
    print(f"  {cause:>3} → {effect}: Wald={wald_obs:.3f}  "
          f"p_asymp={p_asymp:.4f}  p_webb={p_webb:.3f} {stars}")

# ── Save outputs ──────────────────────────────────────────────────────────────
results_df = pd.DataFrame(records)
results_df.to_csv(OUT_CSV, index=False)

header = (
    "=========================================================================\n"
    " Webb Wild Bootstrap — Toda-Yamamoto Wald Tests  (UY-MGO Nexus)\n"
    "=========================================================================\n"
    f" Sample: 2000-2023  T={T}  T_eff={T_eff}  VAR order P={P} (k={K}+dmax={DMAX})\n"
    f" Bootstrap: B={B}  Webb 6-pt weights  seed={SEED}\n"
    " Wald definition: all P=2 lags of cause in effect eq (df=2); matches\n"
    "   TY_results_v2.txt (statsmodels test_causality). NOTE: standard TY\n"
    "   tests only first k=1 lags; df=2 here is conservative (over-augmented).\n"
    " Bootstrap: system wild bootstrap — single Webb weight per time-point,\n"
    "   applied to all 4 VAR equations simultaneously.\n"
    "-------------------------------------------------------------------------\n"
    f"{'Cause':>5} {'Effect':>6}  {'Wald':>7}  {'df':>2}  "
    f"{'p_asymp':>8}  {'p_webb':>7}  {'sig':>4}\n"
    "-------------------------------------------------------------------------\n"
)

rows = []
for r in records:
    rows.append(
        f"{r['cause']:>5} → {r['effect']:>4}  "
        f"{r['Wald']:>7.3f}  {r['df']:>2}  "
        f"{r['p_asymp']:>8.4f}  {r['p_webb']:>7.3f}  {r['sig']:>4}"
    )

footer = (
    "\n-------------------------------------------------------------------------\n"
    " Significance: * p_webb<0.10  ** p_webb<0.05  *** p_webb<0.01\n"
    " p_asymp: chi-sq(df) asymptotic (unreliable at T=24; report p_webb).\n"
    " p_webb:  Webb wild bootstrap (B=999); correctly sized at small T.\n"
    " Ref: MacKinnon & Webb (2018, CJE); Gonçalves & Kilian (2004, JBES)\n"
    "=========================================================================\n"
)

output_text = header + "\n".join(rows) + footer

with open(OUT_TXT, "w") as f:
    f.write(output_text)

print("\n" + output_text)
print(f"Saved: {OUT_TXT}")
print(f"       {OUT_CSV}")
