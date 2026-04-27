"""
Paper 1 — Currency Wars Gold Asymmetry
run_paper1_nardl_v3.py  (post-2000 currency-wars era subsample)

Motivation for sample restriction:
  - "Currency wars" term coined by Mantega (2010); conceptually post-2000 phenomenon
  - Gold market liberalisation: CBGAs (1999, 2004) ended central-bank selling overhang
  - USD-gold negative correlation structurally stronger post-gold-liberalisation
  - JPY carry-trade / gold hedge nexus emerged post-2001 (BOJ ZIRP → carry unwind)
  - Full 1980-2026 sample: PSS F=2.94 (inconclusive), ECM p=0.19 → structural instability

Pipeline:
  0. Restrict sample to Jan-2000 onward (main) + Jan-2008 robustness subsample
  1. Monthly last-price resampling
  2. Zivot-Andrews (1992) structural break unit root (accounts for level/trend break)
  3. ADF + KPSS confirmation
  4. Partial-sum decomposition (Shin et al. 2014)
  5. AIC lag-order search: NARDL(p=1..6, q=0..4)
  6. Final NARDL estimation with HC3 standard errors
  7. Long-run coefficients (Shin 2014 eq.5)
  8. PSS F-bounds test (Pesaran-Shin-Smith 2001, k=4 or k=6)
  9. Wald asymmetry tests (SR and LR, DXY and JPY)
 10. CUSUM / CUSUM-SQ parameter stability (via OLS recursive residuals)
 11. Subsample robustness (2008-2026)
 12. Summary CSV

References:
  Shin Y, Yu B, Greenwood-Nimmo M (2014) Modelling asymmetric cointegration and
    dynamic multipliers in a nonlinear ARDL framework. In: Sickles R, Horrace W (eds)
    Festschrift in Honor of Peter Schmidt. Springer, New York, pp 281-314.
  Pesaran MH, Shin Y, Smith RJ (2001) Bounds testing approaches to the analysis of
    level relationships. J Appl Econom 16(3):289-326.
  Zivot E, Andrews DWK (1992) Further evidence on the great crash, the oil price shock,
    and the unit root hypothesis. J Bus Econ Stat 10(3):251-270.

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
from statsmodels.tsa.stattools import adfuller, kpss, zivot_andrews
from statsmodels.stats.stattools import durbin_watson

ROOT    = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
P1_DIR  = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry"
DATASET = P1_DIR / "03-Results/paper1_gold_currency_wars_dataset_v2.csv"
OUT_DIR = P1_DIR / "03-Results"
OUT_DIR.mkdir(exist_ok=True)

# ── Sample windows ────────────────────────────────────────────────────────────
SAMPLE_MAIN   = ("2000-01-01", None)   # post-gold-liberalisation / currency-wars era
SAMPLE_ROBUST = ("2008-01-01", None)   # GFC + ZLB + QE era robustness check

LOG = OUT_DIR / "paper1_nardl_v3_log.txt"
logf = open(LOG, "w", encoding="utf-8")
def log(*a):
    s = " ".join(str(x) for x in a); print(s); logf.write(s + "\n")

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: build NARDL(p,q) design matrix
# ─────────────────────────────────────────────────────────────────────────────
def build_nardl(data: pd.DataFrame, p: int, q: int,
                extra_regs: tuple = ("fed_funds", "epu_us")):
    """
    Constructs NARDL(p,q) ECM representation.
    Level terms (t-1): y, dxy_pos, dxy_neg, jpy_pos, jpy_neg + extras
    Short-run: Δy_{t-1..p-1}, Δdxy±_{t-0..q-1}, Δjpy±_{t-0..q-1}
    """
    cols = {}
    cols["y_lag1"]       = data["gold_log"].shift(1)
    cols["dxy_pos_lag1"] = data["dxy_pos"].shift(1)
    cols["dxy_neg_lag1"] = data["dxy_neg"].shift(1)
    cols["jpy_pos_lag1"] = data["jpy_pos"].shift(1)
    cols["jpy_neg_lag1"] = data["jpy_neg"].shift(1)
    for r in extra_regs:
        if r in data.columns:
            cols[f"{r}_lag1"] = data[r].shift(1)

    dy = data["gold_log"].diff()
    for i in range(1, p):
        cols[f"dy_lag{i}"] = dy.shift(i)

    for ch in ["dxy_pos", "dxy_neg", "jpy_pos", "jpy_neg"]:
        dch = data[ch].diff()
        for i in range(q):
            cols[f"d{ch}_lag{i}"] = dch.shift(i)

    df_reg = pd.DataFrame(cols, index=data.index)
    Xy = pd.concat([dy.rename("y"), df_reg], axis=1).dropna()
    return Xy["y"], sm.add_constant(Xy.drop(columns="y"), has_constant="add")

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: PSS F-bounds critical values
# ─────────────────────────────────────────────────────────────────────────────
# Pesaran-Shin-Smith (2001) Table CI(iii): unrestricted intercept, no trend
PSS_CV = {
    4: {"10%": (2.45, 3.52), "5%": (2.86, 4.01), "1%": (3.74, 5.06)},
    6: {"10%": (2.17, 3.19), "5%": (2.45, 3.61), "1%": (3.07, 4.44)},
}

def pss_test(model, level_terms: list[str], k: int) -> tuple[float, dict]:
    """Joint PSS F-test on level terms; returns (F, verdicts_dict)."""
    terms = [t for t in level_terms if t in model.params.index]
    R = np.zeros((len(terms), len(model.params)))
    idx = list(model.params.index)
    for i, t in enumerate(terms):
        R[i, idx.index(t)] = 1.0
    f_val = float(model.f_test(R).fvalue)
    cv = PSS_CV.get(k, PSS_CV[4])
    verdicts = {}
    for lv, (lb, ub) in cv.items():
        if f_val > ub:
            verdicts[lv] = f"COINTEGRATED (F={f_val:.3f} > I(1) upper {ub})"
        elif f_val < lb:
            verdicts[lv] = f"NO cointegration (F={f_val:.3f} < I(0) lower {lb})"
        else:
            verdicts[lv] = f"inconclusive ({lb} < F={f_val:.3f} < {ub})"
    return f_val, verdicts

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: Wald test β1 = β2
# ─────────────────────────────────────────────────────────────────────────────
def wald_test(model, term1: str, term2: str, label: str) -> tuple[float, float]:
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

# ─────────────────────────────────────────────────────────────────────────────
# CORE ESTIMATION FUNCTION
# ─────────────────────────────────────────────────────────────────────────────
def run_nardl(data: pd.DataFrame, label: str, max_p: int = 6, max_q: int = 4) -> dict:
    log(f"\n{'='*70}")
    log(f"  SAMPLE: {label}  ({data.index[0].date()} – {data.index[-1].date()}, N={len(data)})")
    log(f"{'='*70}")

    # ── Partial-sum decomposition ────────────────────────────────────────────
    log("\n── Partial-sum decomposition ──")
    def partial_sums(series, name):
        d = series.diff()
        return d.clip(lower=0).cumsum().rename(f"{name}_pos"), \
               d.clip(upper=0).cumsum().rename(f"{name}_neg")

    dxy_pos, dxy_neg = partial_sums(data["dxy_log"], "dxy")
    jpy_pos, jpy_neg = partial_sums(data["jpy_log"], "jpy")
    df = pd.concat([data, dxy_pos, dxy_neg, jpy_pos, jpy_neg], axis=1).dropna()
    log(f"  After differencing: {len(df)} obs")

    # ── Unit roots ───────────────────────────────────────────────────────────
    log("\n── Unit root tests ──")
    VARS_UR = ["gold_log", "dxy_pos", "dxy_neg", "jpy_pos", "jpy_neg", "fed_funds", "epu_us"]
    ur_rows = []
    for v in VARS_UR:
        s = df[v].dropna()
        adf_lv  = adfuller(s, autolag="AIC", regression="c")
        adf_df_ = adfuller(s.diff().dropna(), autolag="AIC", regression="c")
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            kpss_lv = kpss(s, regression="c", nlags="auto")
        # Zivot-Andrews (level, break in intercept+trend)
        try:
            za = zivot_andrews(s, maxlag=12, regression="ct", autolag="AIC")
            za_p   = round(float(za[1]), 4)
            za_bp  = int(za[2]) if za[2] is not None else None
            za_yr  = str(df.index[za_bp].year) if za_bp is not None and za_bp < len(df) else "—"
        except Exception:
            za_p, za_yr = np.nan, "—"
        order = "I(1)" if (adf_lv[1] > 0.05 and adf_df_[1] < 0.05) else \
                "I(0)" if adf_lv[1] < 0.05 else "?"
        ur_rows.append({
            "variable": v,
            "ADF_level_p": round(float(adf_lv[1]), 4),
            "ADF_diff_p":  round(float(adf_df_[1]), 4),
            "KPSS_level_p": round(float(kpss_lv[1]), 4),
            "ZA_level_p":  za_p, "ZA_break_year": za_yr,
            "order": order
        })
        log(f"  {v:14s}  ADF_lv p={adf_lv[1]:.4f}  ADF_1d p={adf_df_[1]:.4f}"
            f"  KPSS p={kpss_lv[1]:.4f}  ZA p={za_p:.4f}(break={za_yr})  → {order}")

    ur_df = pd.DataFrame(ur_rows)
    ur_df.to_csv(OUT_DIR / f"paper1_nardl_v3_{label}_unit_roots.csv", index=False)

    # ── Lag-order search ─────────────────────────────────────────────────────
    log("\n── Lag-order search (AIC) ──")
    best_aic = np.inf; best_p = 1; best_q = 1
    aic_grid = []
    for p, q in itertools.product(range(1, max_p+1), range(0, max_q+1)):
        try:
            y_m, X_m = build_nardl(df, p, q)
            if len(y_m) < X_m.shape[1] + 10:
                continue
            res = sm.OLS(y_m, X_m).fit()
            aic_grid.append({"p": p, "q": q, "AIC": res.aic, "n": len(y_m)})
            if res.aic < best_aic:
                best_aic = res.aic; best_p = p; best_q = q
        except Exception:
            pass
    pd.DataFrame(aic_grid).sort_values("AIC").to_csv(
        OUT_DIR / f"paper1_nardl_v3_{label}_lag_search.csv", index=False)
    log(f"  Optimal: p={best_p}, q={best_q}  AIC={best_aic:.4f}")

    # ── Final NARDL estimation ───────────────────────────────────────────────
    log(f"\n── Final NARDL(p={best_p}, q={best_q}) ──")
    y_est, X_est = build_nardl(df, best_p, best_q)
    model = sm.OLS(y_est, X_est).fit(cov_type="HC3")

    dw_stat = durbin_watson(model.resid)
    log(f"  Obs={len(y_est)}  adj R²={model.rsquared_adj:.4f}  DW={dw_stat:.3f}")
    log(f"  ECM (y_lag1): β={model.params['y_lag1']:.6f}  p={model.pvalues['y_lag1']:.4f}")

    coef_df = pd.DataFrame({
        "term": model.params.index,
        "coef": model.params.values.round(6),
        "se":   model.bse.values.round(6),
        "t":    model.tvalues.values.round(4),
        "p":    model.pvalues.values.round(4)
    })
    coef_df.to_csv(OUT_DIR / f"paper1_nardl_v3_{label}_coefficients.csv", index=False)

    # ── Long-run coefficients ────────────────────────────────────────────────
    log("\n── Long-run coefficients ──")
    rho = float(model.params["y_lag1"])
    lr_rows = []
    for ch in ["dxy_pos", "dxy_neg", "jpy_pos", "jpy_neg"]:
        key = f"{ch}_lag1"
        if key in model.params and rho != 0:
            b_lr = -float(model.params[key]) / rho
            lr_rows.append({"channel": ch, "LR_coef": round(b_lr, 5)})
            log(f"  LR {ch}: β={b_lr:.4f}  (level={model.params[key]:.6f}, ρ={rho:.6f})")
    pd.DataFrame(lr_rows).to_csv(
        OUT_DIR / f"paper1_nardl_v3_{label}_longrun.csv", index=False)

    # ── PSS F-bounds ─────────────────────────────────────────────────────────
    log("\n── PSS F-bounds test (Pesaran-Shin-Smith 2001) ──")
    level_terms_all = ["y_lag1", "dxy_pos_lag1", "dxy_neg_lag1",
                       "jpy_pos_lag1", "jpy_neg_lag1",
                       "fed_funds_lag1", "epu_us_lag1"]
    level_terms = [t for t in level_terms_all if t in model.params.index]
    k_lr = len(level_terms) - 1  # exclude y_lag1 (k = number of I(1) regressors)
    k_pss = min(k_lr, max(PSS_CV.keys()))  # cap at available CVs
    f_val, verdicts = pss_test(model, level_terms, k_pss)
    log(f"  F-stat = {f_val:.4f}  k={k_lr} (using k={k_pss} CV table)")
    for lv, vdict in verdicts.items():
        log(f"  {lv}: {vdict}")
    pss_rows = [{"level": lv, "I0_lower": PSS_CV[k_pss][lv][0],
                 "I1_upper": PSS_CV[k_pss][lv][1], "F_stat": round(f_val, 4),
                 "verdict": vdict}
                for lv, vdict in verdicts.items()]
    pd.DataFrame(pss_rows).to_csv(
        OUT_DIR / f"paper1_nardl_v3_{label}_pss_bounds.csv", index=False)

    # ── Wald asymmetry tests ─────────────────────────────────────────────────
    log("\n── Wald asymmetry tests ──")
    sr_dxy_f, sr_dxy_p = wald_test(model, "ddxy_pos_lag0", "ddxy_neg_lag0",
                                    "SR Δdxy+ vs Δdxy-")
    sr_jpy_f, sr_jpy_p = wald_test(model, "djpy_pos_lag0", "djpy_neg_lag0",
                                    "SR Δjpy+ vs Δjpy-")
    lr_dxy_f, lr_dxy_p = wald_test(model, "dxy_pos_lag1", "dxy_neg_lag1",
                                    "LR dxy+ vs dxy-")
    lr_jpy_f, lr_jpy_p = wald_test(model, "jpy_pos_lag1", "jpy_neg_lag1",
                                    "LR jpy+ vs jpy-")
    wald_df = pd.DataFrame([
        {"test": "SR_DXY", "F": sr_dxy_f, "p": sr_dxy_p},
        {"test": "SR_JPY", "F": sr_jpy_f, "p": sr_jpy_p},
        {"test": "LR_DXY", "F": lr_dxy_f, "p": lr_dxy_p},
        {"test": "LR_JPY", "F": lr_jpy_f, "p": lr_jpy_p},
    ])
    wald_df.to_csv(OUT_DIR / f"paper1_nardl_v3_{label}_wald_asymmetry.csv", index=False)

    # ── CUSUM / CUSUM-SQ stability ───────────────────────────────────────────
    log("\n── CUSUM parameter stability (OLS recursive) ──")
    from statsmodels.stats.diagnostic import recursive_olsresiduals
    stable = "N/A"
    try:
        # Use OLS (no HC3) for recursive residuals — equivalent model
        model_ols = sm.OLS(y_est, X_est).fit()
        n_k = X_est.shape[1]
        skip_val = max(n_k + 10, 40)
        rr_obj = recursive_olsresiduals(model_ols, skip=skip_val, alpha=0.05,
                                        order_by=None)
        cusum = np.cumsum(rr_obj[0] / (rr_obj[0].std() + 1e-12))
        T_c = len(cusum)
        cv_cusum = 0.948 * np.sqrt(T_c)
        log(f"  CUSUM max|stat|={np.max(np.abs(cusum)):.3f}  5% CV={cv_cusum:.3f}")
        stable = bool(np.max(np.abs(cusum)) < cv_cusum)
        log(f"  Parameter stability: {'STABLE' if stable else 'UNSTABLE'}")
    except Exception as e:
        log(f"  CUSUM skipped ({type(e).__name__}: {str(e)[:80]})")

    # ── Summary ──────────────────────────────────────────────────────────────
    summary = {
        "sample": label,
        "start": str(data.index[0].date()),
        "end":   str(data.index[-1].date()),
        "n_obs": len(y_est),
        "p_lags": best_p, "q_lags": best_q,
        "adj_r2": round(model.rsquared_adj, 4),
        "dw":     round(dw_stat, 3),
        "ecm_coef": round(float(model.params["y_lag1"]), 6),
        "ecm_pval": round(float(model.pvalues["y_lag1"]), 4),
        "pss_f":    round(f_val, 4),
        "k_pss":    k_pss,
        "pss_verdict_5pct": verdicts.get("5%", "—"),
        "cusum_stable": stable,
        "sr_dxy_asym_p": round(sr_dxy_p, 4) if not np.isnan(sr_dxy_p) else None,
        "sr_jpy_asym_p": round(sr_jpy_p, 4) if not np.isnan(sr_jpy_p) else None,
        "lr_dxy_asym_p": round(lr_dxy_p, 4) if not np.isnan(lr_dxy_p) else None,
        "lr_jpy_asym_p": round(lr_jpy_p, 4) if not np.isnan(lr_jpy_p) else None,
    }
    return summary

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
log("=== Paper 1 NARDL v3 — Post-2000 Currency-Wars-Era Estimation ===\n")

# Load raw daily data
df_daily = pd.read_csv(DATASET, parse_dates=["DATE"]).sort_values("DATE")
df_daily = df_daily.replace([np.inf, -np.inf], np.nan)
df_daily["gold_log"] = np.log(df_daily["GOLD"].replace(0, np.nan))
df_daily["dxy_log"]  = np.log(df_daily["DXY"].replace(0, np.nan))
df_daily["jpy_log"]  = np.log(df_daily["USDJPY"].replace(0, np.nan))
df_daily = df_daily.set_index("DATE")

monthly_full = pd.DataFrame({
    "gold_log":  df_daily["gold_log"].resample("ME").last(),
    "dxy_log":   df_daily["dxy_log"].resample("ME").last(),
    "jpy_log":   df_daily["jpy_log"].resample("ME").last(),
    "fed_funds": df_daily["fed_funds_effective"].resample("ME").mean(),
    "epu_us":    df_daily["epu_us"].resample("ME").mean(),
}).dropna()

log(f"Full dataset: {len(monthly_full)} monthly obs  "
    f"({monthly_full.index[0].date()} – {monthly_full.index[-1].date()})")

summaries = []

# Main estimation: 2000-2026
start_main, end_main = SAMPLE_MAIN
monthly_main = monthly_full.loc[start_main:]
log(f"\nMain sample (post-2000): {len(monthly_main)} obs")
s1 = run_nardl(monthly_main, label="post2000")
summaries.append(s1)

# Robustness: 2008-2026 (GFC + ZLB era)
start_rob, end_rob = SAMPLE_ROBUST
monthly_rob = monthly_full.loc[start_rob:]
log(f"\nRobustness sample (post-2008): {len(monthly_rob)} obs")
s2 = run_nardl(monthly_rob, label="post2008")
summaries.append(s2)

# Combined summary
log("\n" + "="*70)
log("COMBINED SUMMARY")
log("="*70)
summary_df = pd.DataFrame(summaries)
log(summary_df[["sample", "n_obs", "adj_r2", "ecm_coef", "ecm_pval",
                "pss_f", "pss_verdict_5pct",
                "lr_dxy_asym_p", "lr_jpy_asym_p", "cusum_stable"]].to_string(index=False))
summary_df.to_csv(OUT_DIR / "paper1_nardl_v3_summary.csv", index=False)

log("\n[OK] All NARDL v3 outputs written to 03-Results/")
logf.close()
