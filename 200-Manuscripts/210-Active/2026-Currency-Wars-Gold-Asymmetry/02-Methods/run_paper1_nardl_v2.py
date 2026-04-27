"""
Paper 1 — Currency Wars Gold Asymmetry
run_paper1_nardl_v2.py

Proper NARDL(p,q) implementation following Shin, Yu & Greenwood-Nimmo (2014):

Pipeline:
  1. Resample daily → monthly (last-price convention)
  2. ADF + PP + KPSS unit root pre-tests (all in levels and first differences)
  3. Lag-order search: ARDL(p, q+, q-) via AIC, max p=q=6
  4. PSS F-bounds test (Pesaran-Shin-Smith 2001 critical values)
  5. NARDL long-run coefficients + Wald asymmetry test (LR and SR)
  6. CUSUM stability test
  7. Save all outputs to 03-Results/

Why monthly: daily gold returns have adj R²≈0.03 (signal drowned by microstructure
noise); monthly NARDL is the Q1 standard (e.g., Baur & McDermott 2010 JBF;
Reboredo & Rivera-Castro 2014 EE; Fasanya et al. 2024 FRL).

Author: Dr. M.G. Ozdemir, Kirikkale University, 2026-04-07
"""
from __future__ import annotations
import warnings
warnings.filterwarnings("ignore")

from pathlib import Path
import itertools
import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy import stats
from statsmodels.tsa.stattools import adfuller, kpss
from statsmodels.stats.stattools import durbin_watson

ROOT    = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
P1_DIR  = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry"
DATASET = P1_DIR / "03-Results/paper1_gold_currency_wars_dataset_v2.csv"
OUT_DIR = P1_DIR / "03-Results"
OUT_DIR.mkdir(exist_ok=True)

LOG = OUT_DIR / "paper1_nardl_v2_log.txt"
logf = open(LOG, "w", encoding="utf-8")
def log(*a):
    s = " ".join(str(x) for x in a); print(s); logf.write(s + "\n")

# ── 1. Load and resample to monthly ──────────────────────────────────────────
log("=== 1. Load and resample to monthly ===")
df_daily = pd.read_csv(DATASET, parse_dates=["DATE"]).sort_values("DATE")
df_daily = df_daily.replace([np.inf, -np.inf], np.nan)

df_daily["gold_log"] = np.log(df_daily["GOLD"].replace(0, np.nan))
df_daily["dxy_log"]  = np.log(df_daily["DXY"].replace(0, np.nan))
df_daily["jpy_log"]  = np.log(df_daily["USDJPY"].replace(0, np.nan))

df_daily = df_daily.set_index("DATE")

# Last-price of the month for levels; mean for flow/rate variables
monthly = pd.DataFrame({
    "gold_log":           df_daily["gold_log"].resample("ME").last(),
    "dxy_log":            df_daily["dxy_log"].resample("ME").last(),
    "jpy_log":            df_daily["jpy_log"].resample("ME").last(),
    "fed_funds":          df_daily["fed_funds_effective"].resample("ME").mean(),
    "epu_us":             df_daily["epu_us"].resample("ME").mean(),
}).dropna()

log(f"  Monthly obs: {len(monthly)}  ({monthly.index[0].date()} – {monthly.index[-1].date()})")

# ── 2. Partial-sum decomposition (Shin et al. 2014) ──────────────────────────
log("\n=== 2. Partial-sum decomposition ===")
def partial_sums(series: pd.Series, name: str):
    d = series.diff()
    pos = d.clip(lower=0).cumsum().rename(f"{name}_pos")
    neg = d.clip(upper=0).cumsum().rename(f"{name}_neg")
    return pos, neg

dxy_pos, dxy_neg = partial_sums(monthly["dxy_log"], "dxy")
jpy_pos, jpy_neg = partial_sums(monthly["jpy_log"], "jpy")

data = pd.concat([monthly, dxy_pos, dxy_neg, jpy_pos, jpy_neg], axis=1).dropna()
log(f"  Working dataset: {len(data)} months after differencing")

# ── 3. Unit root pre-tests ────────────────────────────────────────────────────
log("\n=== 3. Unit root pre-tests (ADF + KPSS) ===")
VARS_UR = ["gold_log", "dxy_pos", "dxy_neg", "jpy_pos", "jpy_neg", "fed_funds", "epu_us"]

ur_rows = []
for v in VARS_UR:
    s = data[v].dropna()
    # ADF: H0 = unit root
    adf_lv = adfuller(s, autolag="AIC", regression="c")
    adf_df = adfuller(s.diff().dropna(), autolag="AIC", regression="c")
    # KPSS: H0 = stationary
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        kpss_lv = kpss(s, regression="c", nlags="auto")
    order = "I(1)" if (adf_lv[1] > 0.05 and adf_df[1] < 0.05) else \
            "I(0)" if adf_lv[1] < 0.05 else "?"
    ur_rows.append({
        "variable": v,
        "ADF_level_p": round(float(adf_lv[1]), 4),
        "ADF_diff_p":  round(float(adf_df[1]), 4),
        "KPSS_level_p": round(float(kpss_lv[1]), 4),
        "order": order
    })
    log(f"  {v:14s}  ADF_lv p={adf_lv[1]:.4f}  ADF_1d p={adf_df[1]:.4f}  "
        f"KPSS p={kpss_lv[1]:.4f}  → {order}")

pd.DataFrame(ur_rows).to_csv(OUT_DIR / "paper1_nardl_v2_unit_roots.csv", index=False)

# ── 4. Lag-order search: NARDL(p, q+dxy, q-dxy, q+jpy, q-jpy) ───────────────
log("\n=== 4. Lag-order search (AIC, p=1..6, q=0..4) ===")
MAX_P = 6; MAX_Q = 4
y_full = data["gold_log"]

def build_nardl(data, p, q, extra_regs=("fed_funds", "epu_us")):
    """
    Construct NARDL(p,q) design matrix.
    Level regressors: y_{t-1}, dxy_pos_{t-1}, dxy_neg_{t-1}, jpy_pos_{t-1}, jpy_neg_{t-1}
    Short-run: Δy_{t-1..p-1}, Δdxy+_{t-0..q-1}, Δdxy-_{t-0..q-1},
                               Δjpy+_{t-0..q-1}, Δjpy-_{t-0..q-1}
    """
    T = len(data)
    cols = {}
    # level terms (lagged 1)
    cols["y_lag1"]       = data["gold_log"].shift(1)
    cols["dxy_pos_lag1"] = data["dxy_pos"].shift(1)
    cols["dxy_neg_lag1"] = data["dxy_neg"].shift(1)
    cols["jpy_pos_lag1"] = data["jpy_pos"].shift(1)
    cols["jpy_neg_lag1"] = data["jpy_neg"].shift(1)
    # short-run: Δy lags 1..p-1
    dy = data["gold_log"].diff()
    for i in range(1, p):
        cols[f"dy_lag{i}"] = dy.shift(i)
    # short-run: Δdxy+, Δdxy-, Δjpy+, Δjpy- lags 0..q-1
    for ch in ["dxy_pos", "dxy_neg", "jpy_pos", "jpy_neg"]:
        dch = data[ch].diff()
        for i in range(q):
            cols[f"d{ch}_lag{i}"] = dch.shift(i)
    # extra controls
    for r in extra_regs:
        cols[r] = data[r]
    df_reg = pd.DataFrame(cols, index=data.index)
    y = dy
    Xy = pd.concat([y.rename("y"), df_reg], axis=1).dropna()
    return Xy["y"], sm.add_constant(Xy.drop(columns="y"), has_constant="add")

best_aic = np.inf; best_p = 1; best_q = 1
aic_grid = []
for p, q in itertools.product(range(1, MAX_P+1), range(0, MAX_Q+1)):
    try:
        y_m, X_m = build_nardl(data, p, q)
        res = sm.OLS(y_m, X_m).fit()
        aic_grid.append({"p": p, "q": q, "AIC": res.aic, "n": len(y_m), "k": X_m.shape[1]})
        if res.aic < best_aic:
            best_aic = res.aic; best_p = p; best_q = q
    except Exception:
        pass

aic_df = pd.DataFrame(aic_grid).sort_values("AIC")
aic_df.to_csv(OUT_DIR / "paper1_nardl_v2_lag_search.csv", index=False)
log(f"  Optimal: p={best_p}, q={best_q}  AIC={best_aic:.4f}")

# ── 5. Estimate final NARDL ───────────────────────────────────────────────────
log(f"\n=== 5. Final NARDL(p={best_p}, q={best_q}) ===")
y_est, X_est = build_nardl(data, best_p, best_q)
model = sm.OLS(y_est, X_est).fit(cov_type="HC3")

log(f"  Obs={len(y_est)}  adj R²={model.rsquared_adj:.4f}  DW={durbin_watson(model.resid):.3f}")
log(f"  ECM (y_lag1): β={model.params['y_lag1']:.6f}  p={model.pvalues['y_lag1']:.4f}")

# Save coefficients
coef_df = pd.DataFrame({
    "term":  model.params.index,
    "coef":  model.params.values.round(6),
    "se":    model.bse.values.round(6),
    "t":     model.tvalues.values.round(4),
    "p":     model.pvalues.values.round(4)
})
coef_df.to_csv(OUT_DIR / "paper1_nardl_v2_coefficients.csv", index=False)

# ── 6. Long-run coefficients ──────────────────────────────────────────────────
log("\n=== 6. Long-run coefficients ===")
rho = float(model.params["y_lag1"])
lr_rows = []
for ch in ["dxy_pos", "dxy_neg", "jpy_pos", "jpy_neg"]:
    key = f"{ch}_lag1"
    if key in model.params and rho != 0:
        b_lr = -float(model.params[key]) / rho
        lr_rows.append({"channel": ch, "LR_coef": round(b_lr, 5)})
        log(f"  LR {ch}: β={b_lr:.4f}  (level coef={model.params[key]:.6f}, ρ={rho:.6f})")
pd.DataFrame(lr_rows).to_csv(OUT_DIR / "paper1_nardl_v2_longrun.csv", index=False)

# ── 7. PSS F-bounds test ──────────────────────────────────────────────────────
log("\n=== 7. PSS F-bounds test (Pesaran-Shin-Smith 2001) ===")
# Joint test: H0: y_lag1 = dxy_pos_lag1 = dxy_neg_lag1 = jpy_pos_lag1 = jpy_neg_lag1 = 0
# k = number of long-run regressors (excluding intercept and ECM)
level_terms = ["y_lag1", "dxy_pos_lag1", "dxy_neg_lag1", "jpy_pos_lag1", "jpy_neg_lag1"]
level_terms = [t for t in level_terms if t in model.params.index]
k_lr = len(level_terms) - 1  # k = regressors (excl. y_lag1)

R = np.zeros((len(level_terms), len(model.params)))
for i, t in enumerate(level_terms):
    R[i, list(model.params.index).index(t)] = 1.0

f_stat = model.f_test(R).fvalue
log(f"  F-stat (joint level terms) = {float(f_stat):.4f}  k={k_lr}")

# PSS (2001) Table CI(iii) critical values, k=4, unrestricted intercept no trend
# k=4:  I(0)/I(1) bounds
#  10%:  2.45 / 3.52
#   5%:  2.86 / 4.01
#   1%:  3.74 / 5.06
PSS_CV = {
    "10%": (2.45, 3.52),
    "5%":  (2.86, 4.01),
    "1%":  (3.74, 5.06)
}
f_val = float(f_stat)
for lv, (lb, ub) in PSS_CV.items():
    if f_val > ub:
        verdict = f"COINTEGRATED (above I(1) {lv} upper bound {ub})"
    elif f_val < lb:
        verdict = f"NO cointegration (below I(0) {lv} lower bound {lb})"
    else:
        verdict = f"inconclusive ({lb} < F < {ub})"
    log(f"  {lv}: [{lb}, {ub}]  F={f_val:.3f}  → {verdict}")

pss_rows = [{"level": lv, "I0_lower": lb, "I1_upper": ub,
             "F_stat": round(f_val, 4),
             "verdict": "cointegrated" if f_val > ub else "no" if f_val < lb else "inconclusive"}
            for lv, (lb, ub) in PSS_CV.items()]
pd.DataFrame(pss_rows).to_csv(OUT_DIR / "paper1_nardl_v2_pss_bounds.csv", index=False)

# ── 8. Wald asymmetry tests ───────────────────────────────────────────────────
log("\n=== 8. Wald asymmetry tests ===")

def wald_test(model, term1, term2, label):
    if term1 not in model.params.index or term2 not in model.params.index:
        log(f"  {label}: terms not found"); return np.nan, np.nan
    idx = list(model.params.index)
    R = np.zeros((1, len(model.params)))
    R[0, idx.index(term1)] =  1.0
    R[0, idx.index(term2)] = -1.0
    test = model.f_test(R)
    f, p = float(test.fvalue), float(test.pvalue)
    sig = "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""
    log(f"  {label}: F={f:.3f}  p={p:.4f}{sig}")
    return f, p

wald_rows = []
# Short-run asymmetry: Δdxy+_lag0 vs Δdxy-_lag0
sr_dxy_f, sr_dxy_p = wald_test(model, "ddxy_pos_lag0", "ddxy_neg_lag0",
                                 "SR asymmetry Δdxy+ vs Δdxy-")
sr_jpy_f, sr_jpy_p = wald_test(model, "djpy_pos_lag0", "djpy_neg_lag0",
                                 "SR asymmetry Δjpy+ vs Δjpy-")
# Long-run asymmetry via level terms
lr_dxy_f, lr_dxy_p = wald_test(model, "dxy_pos_lag1", "dxy_neg_lag1",
                                 "LR asymmetry dxy+ vs dxy-")
lr_jpy_f, lr_jpy_p = wald_test(model, "jpy_pos_lag1", "jpy_neg_lag1",
                                 "LR asymmetry jpy+ vs jpy-")

wald_df = pd.DataFrame([
    {"test": "SR_DXY", "F": sr_dxy_f, "p": sr_dxy_p},
    {"test": "SR_JPY", "F": sr_jpy_f, "p": sr_jpy_p},
    {"test": "LR_DXY", "F": lr_dxy_f, "p": lr_dxy_p},
    {"test": "LR_JPY", "F": lr_jpy_f, "p": lr_jpy_p},
])
wald_df.to_csv(OUT_DIR / "paper1_nardl_v2_wald_asymmetry.csv", index=False)

# ── 9. CUSUM stability ────────────────────────────────────────────────────────
log("\n=== 9. CUSUM parameter stability ===")
from statsmodels.stats.diagnostic import recursive_olsresiduals
stable = None
try:
    n_regressors = len(model.model.exog[0])
    skip_val = max(n_regressors * 2 + 5, 50)
    rr = recursive_olsresiduals(model, skip=skip_val)
    cusum = np.cumsum(rr[0] / (rr[0].std() + 1e-12))
    T_c = len(cusum)
    cv_cusum = 0.948 * np.sqrt(T_c)  # 5% critical value
    log(f"  CUSUM max |stat| = {np.max(np.abs(cusum)):.3f}  5% CV = {cv_cusum:.3f}")
    stable = bool(np.max(np.abs(cusum)) < cv_cusum)
    log(f"  Parameter stability: {'STABLE' if stable else 'UNSTABLE'}")
except Exception as e:
    log(f"  CUSUM skipped: {e}")
    stable = "N/A"

# ── 10. Summary ───────────────────────────────────────────────────────────────
log("\n=== 10. Summary ===")
log(f"  Frequency:     Monthly  (N={len(y_est)})")
log(f"  Optimal lags:  p={best_p}, q={best_q}")
log(f"  Adj R²:        {model.rsquared_adj:.4f}")
log(f"  ECM coef:      {float(model.params['y_lag1']):.6f}  "
    f"p={float(model.pvalues['y_lag1']):.4f}")
log(f"  PSS F-stat:    {f_val:.4f}")
log(f"  CUSUM stable:  {stable}")

summary = {
    "frequency": "monthly",
    "p_lags": best_p, "q_lags": best_q,
    "n_obs": len(y_est),
    "adj_r2": round(model.rsquared_adj, 4),
    "ecm_coef": round(float(model.params["y_lag1"]), 6),
    "ecm_pval": round(float(model.pvalues["y_lag1"]), 4),
    "pss_f": round(f_val, 4),
    "cusum_stable": stable,
    "sr_dxy_asym_p": round(sr_dxy_p, 4) if not np.isnan(sr_dxy_p) else None,
    "sr_jpy_asym_p": round(sr_jpy_p, 4) if not np.isnan(sr_jpy_p) else None,
    "lr_dxy_asym_p": round(lr_dxy_p, 4) if not np.isnan(lr_dxy_p) else None,
    "lr_jpy_asym_p": round(lr_jpy_p, 4) if not np.isnan(lr_jpy_p) else None,
}
pd.DataFrame([summary]).to_csv(OUT_DIR / "paper1_nardl_v2_summary.csv", index=False)
log("\n[OK] All NARDL v2 outputs written to 03-Results/")
logf.close()
