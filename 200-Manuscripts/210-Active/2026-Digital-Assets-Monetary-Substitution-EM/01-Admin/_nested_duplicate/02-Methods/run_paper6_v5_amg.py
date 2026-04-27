#!/usr/bin/env python3
"""
run_paper6_v5_amg.py — Augmented Mean Group (Eberhardt & Bond, 2009)
estimator and FX-regime interaction extension.

Why AMG (v5 over v4 CCEMG):
  Pesaran (2006) CCEMG proxies unobserved common factors with the
  contemporaneous cross-section averages of y and X. Eberhardt & Bond
  (2009) propose the AMG, which extracts a "common dynamic process" (CDP)
  from a pooled FE-with-time-dummies first-differenced regression and
  re-introduces it as an explicit regressor in the per-country equations.
  AMG is more robust when the common factors are non-stationary or have
  heterogeneous loadings, which is plausible for the EM monetary
  substitution panel (USD strength, Fed cycles, global liquidity).

Procedure (Eberhardt-Bond 2009, Eq. 3-5):
  Step 1. Δy_it = b' ΔX_it + Σ_t c_t · D_t + Δε_it   (pooled FD-OLS)
          The estimated time dummies {ĉ_t} are the Common Dynamic Process.
  Step 2. y_it = α_i + β_i' X_it + d_i · CDP_t + ε_it    (per-country OLS)
  Step 3. β̂_AMG = N⁻¹ Σ β̂_i ; SE per Pesaran (2006) Eq. 67.

Reference: Eberhardt, M. & Bond, S. (2009). "Cross-section dependence in
nonstationary panel models: a novel estimator." MPRA Paper 17692.

Output: 03-Results/paper6_v5_amg.md
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy import stats

ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT = ROOT / "03-Results" / "paper6_v5_amg.md"

DEP = "fx_depreciation"
# country-specific regressors (time-only variables excluded — captured by CDP)
X_COLS = ["inflation_monthly", "broad_money_instability", "reserve_adequacy_change"]

# IMF de-facto FX-regime classification (Ilzetzki-Reinhart-Rogoff 2019, updated):
#   1 = hard peg / pre-announced crawl
#   2 = managed float / de-facto crawling band
#   3 = freely floating
FX_REGIME = {
    "Argentina":   2,   # crawling peg / multi-tier (2016-2025)
    "Brazil":      3,   # free float since 1999
    "India":       2,   # managed float (RBI heavy intervention)
    "Mexico":      3,   # free float since 1995
    "Nigeria":     2,   # managed float, multi-window unification 2023
    "South Africa":3,   # free float
}


def common_dynamic_process(df: pd.DataFrame) -> pd.Series:
    """
    Step 1 of AMG: pooled FD-OLS with time dummies.
    Returns the estimated time-dummy series (CDP_t) indexed by DATE.
    """
    d = df.dropna(subset=[DEP] + X_COLS).copy().sort_values(["country", "DATE"])
    d["DATE"] = pd.to_datetime(d["DATE"])

    # within-country first differences
    grp = d.groupby("country")
    d_y = grp[DEP].diff()
    d_X = grp[X_COLS].diff()
    fd = pd.concat([d[["DATE", "country"]], d_y.rename("dY"), d_X.add_prefix("d_")], axis=1).dropna()

    # time dummies on DATE — use string keys to avoid timestamp formatting issues
    fd["_dt"] = fd["DATE"].dt.strftime("%Y-%m-%d")
    time_d = pd.get_dummies(fd["_dt"], prefix="t", drop_first=True).astype(float)
    X = pd.concat([fd[[f"d_{c}" for c in X_COLS]].reset_index(drop=True),
                   time_d.reset_index(drop=True)], axis=1)
    X = sm.add_constant(X)
    y = fd["dY"].astype(float).reset_index(drop=True)
    res = sm.OLS(y, X).fit()

    dates_sorted = sorted(fd["_dt"].unique())
    cdp = {dates_sorted[0]: 0.0}
    for dt in dates_sorted[1:]:
        cdp[dt] = float(res.params.get(f"t_{dt}", np.nan))
    cdp_s = pd.Series(cdp)
    cdp_s.index = pd.to_datetime(cdp_s.index)
    cdp_s = cdp_s.sort_index()
    cdp_s.index.name = "DATE"
    return cdp_s.rename("CDP")


def amg(df: pd.DataFrame, cdp: pd.Series) -> dict:
    """
    Step 2-3 of AMG: per-country OLS with CDP_t as additional regressor;
    MG mean and SE.
    """
    d = df.dropna(subset=[DEP] + X_COLS).copy()
    d["DATE"] = pd.to_datetime(d["DATE"])
    cdp_df = cdp.reset_index()
    d = d.merge(cdp_df, on="DATE", how="left").dropna(subset=["CDP"])

    coefs, cdp_loadings, countries = [], [], []
    for c, g in d.groupby("country"):
        if len(g) < 30:
            continue
        X = sm.add_constant(g[X_COLS + ["CDP"]].astype(float))
        y = g[DEP].astype(float)
        try:
            res = sm.OLS(y, X).fit()
        except Exception:
            continue
        coefs.append([res.params.get(v, np.nan) for v in X_COLS])
        cdp_loadings.append(float(res.params.get("CDP", np.nan)))
        countries.append(c)

    coefs = np.array(coefs, dtype=float)
    if coefs.shape[0] < 2:
        return {"available": False}
    mg = np.nanmean(coefs, axis=0)
    Nc = coefs.shape[0]
    centered = coefs - mg
    var_mg = (centered.T @ centered) / (Nc * (Nc - 1))
    se = np.sqrt(np.diag(var_mg))
    t = mg / se
    p = 2 * (1 - stats.norm.cdf(np.abs(t)))
    return {
        "available": True,
        "N_countries": Nc,
        "countries": countries,
        "vars": X_COLS,
        "mg_coef": mg.tolist(),
        "mg_se": se.tolist(),
        "mg_t": t.tolist(),
        "mg_p": p.tolist(),
        "cdp_loadings": cdp_loadings,
    }


def fx_regime_interaction(df: pd.DataFrame) -> sm.regression.linear_model.RegressionResultsWrapper:
    """
    Pooled FE with FX-regime × inflation interaction.
    Tests H0: pass-through of inflation to FX depreciation is identical
    across managed-float and free-float regimes.
    """
    d = df.dropna(subset=[DEP] + X_COLS).copy()
    d["fx_regime"] = d["country"].map(FX_REGIME)
    d["managed"] = (d["fx_regime"] == 2).astype(float)
    d["inf_x_managed"] = d["inflation_monthly"].astype(float) * d["managed"]
    d["bmi_x_managed"] = d["broad_money_instability"].astype(float) * d["managed"]

    dummies = pd.get_dummies(d["country"], prefix="c", drop_first=True).astype(float)
    X = pd.concat(
        [d[X_COLS + ["inf_x_managed", "bmi_x_managed",
                     "global_dollar_change", "fed_change"]], dummies],
        axis=1,
    )
    X = sm.add_constant(X)
    y = d[DEP].astype(float)
    groups = d["country"].astype("category").cat.codes
    return sm.OLS(y, X).fit(cov_type="cluster", cov_kwds={"groups": groups})


def main() -> int:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    print(f"[v5_amg] panel: {df.shape}, ülkeler: {sorted(df['country'].unique())}")

    out = ["# Paper 6 v5 — Augmented Mean Group (Eberhardt-Bond 2009) & FX-Regime Heterogeneity\n",
           "**Reference spec:** M0_macro_only (country-FE)\n",
           f"**Country-specific regressors:** {', '.join(X_COLS)}\n",
           "**Time-only regressors** (`global_dollar_change`, `fed_change`) **are absorbed by the Common Dynamic Process / time dummies in Step 1**, consistent with Eberhardt-Bond (2009).\n"]

    print("[v5_amg] (1) common dynamic process from FD-OLS with time dummies...")
    cdp = common_dynamic_process(df)
    out.append("\n## 1. Common Dynamic Process (CDP) summary\n")
    out.append(f"- Periods (T) extracted: {len(cdp)}")
    out.append(f"- Mean CDP = {cdp.mean():+.4f}, SD = {cdp.std():.4f}")
    out.append(f"- Range: [{cdp.min():+.4f}, {cdp.max():+.4f}]")

    print("[v5_amg] (2-3) per-country OLS + AMG aggregation...")
    res = amg(df, cdp)
    out.append("\n## 2. AMG estimates\n")
    if not res["available"]:
        out.append("- Not enough observations to estimate AMG.")
    else:
        out.append(f"- N countries = {res['N_countries']} ({', '.join(res['countries'])})\n")
        out.append("| Variable | β_AMG | SE | t | p |")
        out.append("|---|---|---|---|---|")
        for v, b, s, t, p in zip(res["vars"], res["mg_coef"], res["mg_se"], res["mg_t"], res["mg_p"]):
            star = "***" if p < 0.01 else ("**" if p < 0.05 else ("*" if p < 0.10 else ""))
            out.append(f"| {v} | {b:+.4f}{star} | {s:.4f} | {t:+.2f} | {p:.3f} |")
        out.append("\n### CDP loadings per country (d_i)\n")
        out.append("| Country | d_i (CDP loading) |")
        out.append("|---|---|")
        for c, d in zip(res["countries"], res["cdp_loadings"]):
            out.append(f"| {c} | {d:+.4f} |")

    print("[v5_amg] (4) FX-regime × inflation interaction (pooled FE)...")
    fxi = fx_regime_interaction(df)
    out.append("\n## 3. FX-regime interaction (pooled country-FE, cluster-robust SE)\n")
    out.append("**Spec:** Δfx_it = α_i + β·X_it + γ·(managed_i × inflation_it) + δ·(managed_i × M2_instab_it) + ε_it")
    out.append("**Managed-float dummy** (Ilzetzki-Reinhart-Rogoff 2019): Argentina, India, Nigeria = 1; Brazil, Mexico, South Africa = 0\n")
    coef_table = pd.DataFrame({
        "β": fxi.params,
        "SE": fxi.bse,
        "t": fxi.tvalues,
        "p": fxi.pvalues,
    }).round(4)
    keep = ["inflation_monthly", "broad_money_instability", "reserve_adequacy_change",
            "inf_x_managed", "bmi_x_managed", "global_dollar_change", "fed_change"]
    out.append(coef_table.loc[[k for k in keep if k in coef_table.index]].to_markdown())
    out.append(f"\n- N = {int(fxi.nobs)}, adj-R² = {fxi.rsquared_adj:.4f}")
    ftest = fxi.f_test("inf_x_managed = 0, bmi_x_managed = 0")
    out.append(f"- **Wald F (joint γ = δ = 0):** {float(ftest.fvalue):.3f}, p = {float(ftest.pvalue):.4f}")

    OUT.write_text("\n".join(out) + "\n")
    print(f"[v5_amg] yazıldı: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
