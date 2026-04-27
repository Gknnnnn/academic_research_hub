#!/usr/bin/env python3
"""
run_paper6_robustness_v4.py — Heterogeneity & cross-section dependence diagnostics.

Tests added in v4:
  (1) Country-by-country OLS slopes (visual heterogeneity check)
  (2) Pesaran-Yamagata (2008) Δ̃ slope-homogeneity test
  (3) Pesaran (2004) CD test for cross-sectional dependence in residuals
  (4) Pesaran (2006) Common Correlated Effects Mean Group (CCEMG) estimator
      compared against pooled FE.

Reference equation (M0_macro_only):
    fx_dep_{it} = α_i + β'X_{it} + ε_{it}
where X = [global_dollar_change, fed_change, inflation_monthly,
           broad_money_instability, reserve_adequacy_change]

Output: 03-Results/paper6_v4_robustness.md
"""
from __future__ import annotations
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy import stats

ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT = ROOT / "03-Results" / "paper6_v4_robustness.md"

DEP = "fx_depreciation"
X_COLS = ["global_dollar_change", "fed_change", "inflation_monthly",
          "broad_money_instability", "reserve_adequacy_change"]
# CCE-only subset: drop time-only / cross-section-invariant regressors
# (global_dollar_change and fed_change are common to all countries by construction
#  and cause perfect collinearity with their cross-section averages).
X_COLS_CCE = ["inflation_monthly", "broad_money_instability", "reserve_adequacy_change"]


def country_slopes(df: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for c, g in df.groupby("country"):
        d = g.dropna(subset=[DEP] + X_COLS).copy()
        if len(d) < 30:
            continue
        X = sm.add_constant(d[X_COLS].astype(float))
        y = d[DEP].astype(float)
        res = sm.OLS(y, X).fit(cov_type="HC1")
        rec = {"country": c, "N": int(res.nobs), "adjR2": res.rsquared_adj}
        for v in X_COLS:
            rec[f"β_{v}"] = res.params[v]
            rec[f"se_{v}"] = res.bse[v]
        rows.append(rec)
    return pd.DataFrame(rows)


def pesaran_yamagata_delta(df: pd.DataFrame) -> dict:
    """
    Pesaran & Yamagata (2008) Δ̃ test of slope homogeneity.
    H0: β_i = β for all i (homogeneous slopes).

    Implementation follows the standardised Δ̃_adj from
    Pesaran & Yamagata (2008, JoE), Eq. (44):

        S̃ = Σ_i (β̂_i − β̂_WFE)' (X_i' M_τ X_i / σ̂_i²) (β̂_i − β̂_WFE)
        Δ̃ = √N · ((S̃/N − k) / √(2k))
        Δ̃_adj = √N · ((S̃/N − k) / √(2k(T−k−1)/(T+1)))
    where M_τ demeans within country.
    """
    panel = df.dropna(subset=[DEP] + X_COLS).copy()
    countries = sorted(panel["country"].unique())
    k = len(X_COLS)

    # within-country demeaning (FE transformation)
    def demean(grp):
        for c in [DEP] + X_COLS:
            grp[c] = grp[c] - grp[c].mean()
        return grp

    panel_dm = panel.groupby("country", group_keys=False).apply(demean)

    # Pooled within-FE estimate β̂_WFE
    Xp = panel_dm[X_COLS].astype(float).values
    yp = panel_dm[DEP].astype(float).values
    beta_wfe, *_ = np.linalg.lstsq(Xp, yp, rcond=None)

    # Per-country OLS on demeaned data + σ̂_i²
    S_tilde = 0.0
    Ns = []
    for c in countries:
        g = panel_dm[panel_dm["country"] == c]
        Xi = g[X_COLS].astype(float).values
        yi = g[DEP].astype(float).values
        if len(yi) <= k + 5:
            continue
        bi, *_ = np.linalg.lstsq(Xi, yi, rcond=None)
        resid_i = yi - Xi @ bi
        sigma2_i = (resid_i @ resid_i) / (len(yi) - k)
        if sigma2_i <= 0:
            continue
        diff = (bi - beta_wfe).reshape(-1, 1)
        XtX = Xi.T @ Xi
        S_tilde += float(diff.T @ XtX @ diff / sigma2_i)
        Ns.append(len(yi))

    N = len(Ns)
    T_bar = float(np.mean(Ns))
    delta = np.sqrt(N) * ((S_tilde / N - k) / np.sqrt(2 * k))
    var_adj = 2 * k * (T_bar - k - 1) / (T_bar + 1)
    delta_adj = np.sqrt(N) * ((S_tilde / N - k) / np.sqrt(var_adj))
    p_delta = 2 * (1 - stats.norm.cdf(abs(delta)))
    p_delta_adj = 2 * (1 - stats.norm.cdf(abs(delta_adj)))
    return {
        "N_countries": N,
        "T_bar": T_bar,
        "k": k,
        "S_tilde": S_tilde,
        "Delta": delta,
        "p_Delta": p_delta,
        "Delta_adj": delta_adj,
        "p_Delta_adj": p_delta_adj,
    }


def pesaran_cd(residuals_by_country: dict) -> dict:
    """
    Pesaran (2004) CD test for cross-sectional dependence.
    CD = √(2T / (N(N-1))) · Σ_{i<j} ρ̂_ij  ~ N(0,1) under H0.
    """
    countries = sorted(residuals_by_country.keys())
    N = len(countries)
    # Build a wide matrix: rows = common dates, cols = country residuals
    series = {c: residuals_by_country[c] for c in countries}
    wide = pd.concat(series, axis=1).dropna()
    if wide.shape[0] < 10 or wide.shape[1] < 2:
        return {"N": N, "T_common": int(wide.shape[0]), "CD": np.nan, "p": np.nan}
    T = wide.shape[0]
    corr = wide.corr().values
    iu = np.triu_indices_from(corr, k=1)
    cd = np.sqrt(2 * T / (N * (N - 1))) * corr[iu].sum()
    p = 2 * (1 - stats.norm.cdf(abs(cd)))
    return {"N": N, "T_common": int(T), "CD": float(cd), "p": float(p)}


def fit_pooled_fe(df: pd.DataFrame) -> tuple:
    d = df.dropna(subset=[DEP] + X_COLS).copy()
    dummies = pd.get_dummies(d["country"], prefix="c", drop_first=True).astype(float)
    X = pd.concat([d[X_COLS], dummies], axis=1)
    X = sm.add_constant(X)
    y = d[DEP].astype(float)
    groups = d["country"].astype("category").cat.codes
    res = sm.OLS(y, X).fit(cov_type="cluster", cov_kwds={"groups": groups})
    # collect residuals per country with DATE index
    d["_resid"] = res.resid.values
    res_by_c = {c: g.set_index("DATE")["_resid"] for c, g in d.groupby("country")}
    return res, res_by_c


def ccemg(df: pd.DataFrame) -> dict:
    """
    Pesaran (2006) CCE Mean Group: per-country OLS where regressors and
    dependent variable are augmented with cross-section averages of
    [y, X_country_specific] (the 'common factors' proxy). MG coefficient
    is the mean over country slopes; SE follows Pesaran (2006, Eq. 67).

    Important: only country-specific regressors are CCE-augmented.
    Strictly time-only regressors (global_dollar_change, fed_change) are
    dropped from the CCE spec because their cross-section averages equal
    the regressors themselves (perfect collinearity / rank deficiency).
    """
    d = df.dropna(subset=[DEP] + X_COLS_CCE).copy()
    d["DATE"] = pd.to_datetime(d["DATE"])
    cs = d.groupby("DATE")[[DEP] + X_COLS_CCE].mean().add_suffix("_csa")
    d = d.merge(cs, on="DATE", how="left")
    cs_cols = [f"{c}_csa" for c in [DEP] + X_COLS_CCE]

    coefs = []
    countries = []
    for c, g in d.groupby("country"):
        g2 = g.dropna(subset=cs_cols + [DEP] + X_COLS_CCE)
        if len(g2) < 30:
            continue
        X = sm.add_constant(g2[X_COLS_CCE + cs_cols].astype(float))
        y = g2[DEP].astype(float)
        try:
            res = sm.OLS(y, X).fit()
        except Exception:
            continue
        coefs.append([res.params.get(v, np.nan) for v in X_COLS_CCE])
        countries.append(c)

    coefs = np.array(coefs, dtype=float)
    if coefs.shape[0] < 2:
        return {"available": False}

    mg = np.nanmean(coefs, axis=0)
    Nc = coefs.shape[0]
    centered = coefs - mg
    var_mg = (centered.T @ centered) / (Nc * (Nc - 1))
    se_mg = np.sqrt(np.diag(var_mg))
    t_mg = mg / se_mg
    p_mg = 2 * (1 - stats.norm.cdf(np.abs(t_mg)))
    return {
        "available": True,
        "N_countries": Nc,
        "countries": countries,
        "vars": X_COLS_CCE,
        "mg_coef": mg.tolist(),
        "mg_se": se_mg.tolist(),
        "mg_t": t_mg.tolist(),
        "mg_p": p_mg.tolist(),
    }


def main() -> int:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    print(f"[robust] panel: {df.shape}, ülkeler: {sorted(df['country'].unique())}")

    out_lines = ["# Paper 6 v4 — Heterogeneity & Cross-Section Dependence\n",
                 "**Reference spec:** M0_macro_only (country-FE OLS, cluster-robust SE)\n",
                 f"**Regressors:** {', '.join(X_COLS)}\n"]

    # 1) Country slopes
    print("[robust] (1) country-by-country slopes...")
    cs = country_slopes(df)
    out_lines.append("\n## 1. Country-by-country OLS slopes (HC1 SE)\n")
    out_lines.append(cs.round(4).to_markdown(index=False))

    # 2) Pesaran-Yamagata Δ̃
    print("[robust] (2) Pesaran-Yamagata Δ̃ test...")
    py = pesaran_yamagata_delta(df)
    out_lines.append("\n\n## 2. Pesaran-Yamagata (2008) slope-homogeneity test\n")
    out_lines.append(f"- N countries = {py['N_countries']}, T̄ = {py['T_bar']:.1f}, k = {py['k']}")
    out_lines.append(f"- S̃ = {py['S_tilde']:.3f}")
    out_lines.append(f"- **Δ̃ = {py['Delta']:.3f}, p = {py['p_Delta']:.4f}**")
    out_lines.append(f"- **Δ̃_adj = {py['Delta_adj']:.3f}, p = {py['p_Delta_adj']:.4f}**")
    out_lines.append("- H0: slope homogeneity. p < 0.05 ⇒ heterojen eğimler ⇒ pooled FE yanlı.")

    # 3) Cross-section dependence
    print("[robust] (3) Pesaran (2004) CD test...")
    pooled_res, resid_by_c = fit_pooled_fe(df)
    cd = pesaran_cd(resid_by_c)
    out_lines.append("\n## 3. Pesaran (2004) CD test (residuals from pooled FE)\n")
    out_lines.append(f"- N = {cd['N']}, T_common = {cd['T_common']}")
    out_lines.append(f"- **CD = {cd['CD']:.3f}, p = {cd['p']:.4f}**")
    out_lines.append("- H0: cross-section bağımsızlık. p < 0.05 ⇒ küresel ortak faktörler var ⇒ CCE gerek.")

    # 4) CCEMG
    print("[robust] (4) Pesaran (2006) CCE Mean Group...")
    cce = ccemg(df)
    out_lines.append("\n## 4. Pesaran (2006) Common Correlated Effects Mean Group (CCEMG)\n")
    out_lines.append(f"**CCE-augmented regressors (country-specific only):** {', '.join(X_COLS_CCE)}")
    out_lines.append("> Note: `global_dollar_change` and `fed_change` are dropped from the CCE")
    out_lines.append("> spec because they are time-only variables (identical across countries by")
    out_lines.append("> construction); their cross-section averages are perfectly collinear with")
    out_lines.append("> the regressors themselves and produce rank-deficient design matrices.")
    out_lines.append("> Common global shocks are still absorbed via the cross-section averages of")
    out_lines.append("> the dependent variable and the country-specific regressors (Pesaran 2006).\n")
    if not cce["available"]:
        out_lines.append("- Not enough observations to estimate CCEMG.")
    else:
        out_lines.append(f"- N countries = {cce['N_countries']} ({', '.join(cce['countries'])})")
        out_lines.append("\n| Variable | β_MG | SE_MG | t | p |")
        out_lines.append("|---|---|---|---|---|")
        for v, b, s, t, p in zip(cce["vars"], cce["mg_coef"], cce["mg_se"], cce["mg_t"], cce["mg_p"]):
            star = "***" if p < 0.01 else ("**" if p < 0.05 else ("*" if p < 0.10 else ""))
            out_lines.append(f"| {v} | {b:+.4f}{star} | {s:.4f} | {t:+.2f} | {p:.3f} |")

    # 5) Pooled FE comparison
    out_lines.append("\n## 5. Comparison: Pooled FE vs CCEMG (β coefficients)\n")
    out_lines.append("| Variable | β_FE_pooled | β_CCEMG |")
    out_lines.append("|---|---|---|")
    if cce["available"]:
        for v, b in zip(cce["vars"], cce["mg_coef"]):
            fe_b = pooled_res.params.get(v, np.nan)
            out_lines.append(f"| {v} | {fe_b:+.4f} | {b:+.4f} |")

    OUT.write_text("\n".join(out_lines) + "\n")
    print(f"[robust] yazıldı: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
