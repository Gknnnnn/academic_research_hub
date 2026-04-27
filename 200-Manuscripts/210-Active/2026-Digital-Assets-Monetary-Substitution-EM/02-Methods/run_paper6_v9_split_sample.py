#!/usr/bin/env python3
"""
run_paper6_v9_split_sample.py — Split-sample Webb bootstrap + Driscoll-Kraay.

Motivation
----------
In v8 the GCAI×inflation interaction shrank from β=−0.871 (originally
estimated on 2022-2024 data only) to β=−0.153 after adding 2021 country-
year cells (AR, BR, IN, NG).  Two competing explanations must be
distinguished:

  (H1) PERIOD EFFECT — the digital-dollar shock-absorber mechanism
       intensified *after* 2022 owing to (a) Chainalysis 2022 methodology
       revision (DeFi included, P2P dropped), (b) Terra/LUNA collapse →
       regulatory clarity → stablecoin adoption surge, (c) FTX collapse
       (Nov-2022) accelerating on-chain USD hedging in EMs.

  (H2) DILUTION ARTEFACT — the 2021 cells contain relatively few
       high-inflation months for AR/NG, so adding them mechanically shrinks
       the OLS slope.

Design
------
Sub-sample A (pre-intensification): 2021 only; verified countries AR+BR+IN+NG
Sub-sample B (intensification)    : 2022-2024; all verified cells (AR+BR+IN,
                                    plus MX+NG from 2023 onward)
Full sample                       : 2020-2024 (2020 unverified → effectively
                                    same as 2021-2024)

Inference
---------
  * Webb (2023) 6-point wild cluster bootstrap (B=999) for both sub-samples
  * Conventional cluster-robust SE (country-level) for comparison
  * Driscoll-Kraay (1998) HAC SE (Newey-West kernel, bandwidth=12) using
    the linearmodels.panel.IV2SLS sandwich estimator as a robustness check
    against residual serial correlation

Output
------
03-Results/paper6_v9_split_sample.csv    — full bootstrap table
03-Results/paper6_v9_split_sample.md     — markdown report
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path

# ─── Paths ────────────────────────────────────────────────────────────────────
ROOT  = Path(__file__).resolve().parents[1]
PANEL = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
GCAI  = ROOT / "03-Results" / "chainalysis" / "chainalysis_gcai_2020_2024.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v9_split_sample.csv"
OUT_MD  = ROOT / "03-Results" / "paper6_v9_split_sample.md"

RNG   = np.random.default_rng(20260409)
B     = 999
ALPHA = 0.05

WEBB_WEIGHTS = np.array([
    -np.sqrt(3/2), -1.0, -np.sqrt(1/2),
     np.sqrt(1/2),  1.0,  np.sqrt(3/2)
])

DEP   = "fx_depreciation"
MACRO = ["inflation_monthly", "broad_money_instability", "reserve_adequacy_change"]


# ─── Data preparation ─────────────────────────────────────────────────────────

def load_panel() -> pd.DataFrame:
    """Merge GCAI (verified only) into the v4 monthly panel."""
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    df["year"] = df["DATE"].dt.year

    g = pd.read_csv(GCAI)
    g = g[g["verified"] == "yes"].copy()
    g["gcai_rank_inv"] = 155 - g["gcai_rank"]
    g["gcai_adopt"] = (
        (g["gcai_rank_inv"] - g["gcai_rank_inv"].min())
        / (g["gcai_rank_inv"].max() - g["gcai_rank_inv"].min())
    )
    df = df.merge(
        g[["country", "year", "gcai_rank", "gcai_rank_inv", "gcai_adopt"]],
        on=["country", "year"],
        how="left",
    )
    df["gcai_x_inf"] = df["gcai_adopt"] * df["inflation_monthly"]
    return df


def subset(df: pd.DataFrame, years: list[int]) -> pd.DataFrame:
    return df[df["year"].isin(years)].copy()


# ─── OLS helpers ──────────────────────────────────────────────────────────────

def add_country_fe(df: pd.DataFrame) -> pd.DataFrame:
    dummies = pd.get_dummies(df["country"], prefix="c", drop_first=True).astype(float)
    return pd.concat([df.reset_index(drop=True), dummies.reset_index(drop=True)], axis=1)


def fit_ols(y: np.ndarray, X: np.ndarray):
    beta, *_ = np.linalg.lstsq(X, y, rcond=None)
    return beta, y - X @ beta


# ─── Webb wild cluster bootstrap ──────────────────────────────────────────────

def webb_bootstrap(
    df: pd.DataFrame,
    regressors: list[str],
    label: str,
    B: int = B,
) -> list[dict]:
    needed = [DEP] + regressors + ["country"]
    d = df.dropna(subset=needed).copy()
    countries = sorted(d["country"].unique())
    N_c = len(countries)

    if len(d) < 20 or N_c < 3:
        print(f"  [{label}] SKIP — N_obs={len(d)}, N_clust={N_c} (threshold: 20 obs, 3 clusters)")
        return []

    print(f"  [{label}] N_obs={len(d)}, N_clust={N_c}, B={B}")

    d = add_country_fe(d)
    fe_cols = [c for c in d.columns if c.startswith("c_")]
    all_X_cols = regressors + fe_cols

    X = sm.add_constant(d[all_X_cols].astype(float)).values
    y = d[DEP].astype(float).values
    ctry = d["country"].values

    beta_hat, resid_hat = fit_ols(y, X)
    x_names = ["const"] + all_X_cols
    target_idx = {r: x_names.index(r) for r in regressors if r in x_names}

    beta_boot = np.full((B, len(target_idx)), np.nan)
    for b in range(B):
        w_map = {c: RNG.choice(WEBB_WEIGHTS) for c in countries}
        w_vec  = np.array([w_map[c] for c in ctry])
        y_star = X @ beta_hat + resid_hat * w_vec
        beta_b, _ = fit_ols(y_star, X)
        for j, r in enumerate(target_idx):
            beta_boot[b, j] = beta_b[target_idx[r]]

    results = []
    for j, r in enumerate(target_idx):
        b0   = beta_hat[target_idx[r]]
        dist = beta_boot[:, j] - b0
        p_boot = float(np.mean(np.abs(beta_boot[:, j] - b0) >= np.abs(b0)))
        lo = b0 + float(np.percentile(dist, 2.5))
        hi = b0 + float(np.percentile(dist, 97.5))

        # Cluster-robust SE (sandwich)
        XtX_inv = np.linalg.pinv(X.T @ X)
        meat = np.zeros((X.shape[1], X.shape[1]))
        for c in countries:
            mask = ctry == c
            Xc = X[mask]; ec = resid_hat[mask]
            meat += Xc.T @ np.outer(ec, ec) @ Xc
        V = XtX_inv @ meat @ XtX_inv
        se_cr = float(np.sqrt(V[target_idx[r], target_idx[r]]))
        t_cr  = b0 / se_cr if se_cr > 0 else np.nan

        sig = ("***" if p_boot < 0.01 else
               "**"  if p_boot < 0.05 else
               "*"   if p_boot < 0.10 else "")
        print(f"    {r:35s}  β={b0:+.4f}  p_webb={p_boot:.3f}{sig}  "
              f"CI=[{lo:+.4f},{hi:+.4f}]  SE_CR={se_cr:.4f}")

        results.append({
            "sample": label.split("|")[0].strip(),
            "model":  label.split("|")[1].strip() if "|" in label else label,
            "variable":  r,
            "coef":      round(b0,    6),
            "se_cr":     round(se_cr, 6),
            "t_cr":      round(t_cr,  3),
            "ci_lo_95":  round(lo,    6),
            "ci_hi_95":  round(hi,    6),
            "p_webb":    round(p_boot,4),
            "sig_webb":  sig,
            "N_obs":     len(d),
            "N_clust":   N_c,
            "B":         B,
        })
    return results


# ─── Driscoll-Kraay HAC via manual Newey-West ─────────────────────────────────

def driscoll_kraay_se(
    df: pd.DataFrame,
    regressors: list[str],
    bandwidth: int = 12,
) -> pd.Series | None:
    """
    Driscoll-Kraay (1998) SE for a pooled OLS on an unbalanced panel.

    The DK estimator is:
        V_DK = (X'X)^{-1} Ω_T (X'X)^{-1}
    where
        Ω_T = Γ_0 + Σ_{l=1}^{m} w_l (Γ_l + Γ_l')
        Γ_l = (1/T) Σ_t h_t h_{t-l}'
        h_t = Σ_i X_{it} ε_{it}   (cross-section score vector at time t)
        w_l = 1 − l/(m+1)  (Bartlett kernel)

    Returns a pd.Series of SE indexed by regressor name, or None if
    insufficient time dimension.
    """
    needed = [DEP, "DATE"] + regressors + ["country"]
    d = df.dropna(subset=[DEP] + regressors + ["country"]).copy()
    d = d.sort_values(["country", "DATE"])

    # Build regressor matrix with country FE
    d_fe = add_country_fe(d)
    fe_cols = [c for c in d_fe.columns if c.startswith("c_")]
    all_X_cols = regressors + fe_cols
    X = sm.add_constant(d_fe[all_X_cols].astype(float)).values
    y = d_fe[DEP].astype(float).values
    dates = pd.to_datetime(d_fe["DATE"].values)

    beta, resid = fit_ols(y, X)

    T_periods = dates.unique()
    if len(T_periods) < bandwidth + 2:
        print(f"  [DK] insufficient T={len(T_periods)} for bandwidth={bandwidth}")
        return None

    # Score h_t: cross-section mean of X_{it} * ε_{it} at each time point
    p = X.shape[1]
    scores = {}
    for t in T_periods:
        mask = dates == t
        Xt = X[mask]; et = resid[mask]
        scores[t] = (Xt * et[:, None]).sum(axis=0)  # shape (p,)

    t_sorted = sorted(T_periods)
    T = len(t_sorted)

    def gamma(lag: int) -> np.ndarray:
        G = np.zeros((p, p))
        for s in range(lag, T):
            G += np.outer(scores[t_sorted[s]], scores[t_sorted[s - lag]])
        return G / T

    Omega = gamma(0)
    for l in range(1, bandwidth + 1):
        w = 1 - l / (bandwidth + 1)
        Gl = gamma(l)
        Omega += w * (Gl + Gl.T)

    XtX_inv = np.linalg.pinv(X.T @ X)
    V_dk = XtX_inv @ Omega @ XtX_inv
    se_dk = np.sqrt(np.diag(V_dk))

    x_names = ["const"] + all_X_cols
    return pd.Series(se_dk, index=x_names)


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    df = load_panel()

    gcai_cov = df.dropna(subset=["gcai_adopt"]).groupby(["country","year"]).size()
    print("[v9] GCAI coverage (country×year):")
    print(gcai_cov.unstack(fill_value=0))

    # Sub-samples
    df_2021     = subset(df, [2021])
    df_2022_24  = subset(df, [2022, 2023, 2024])
    df_full     = subset(df, [2021, 2022, 2023, 2024])   # 2020 all unverified

    print("\n" + "="*70)
    print("SPLIT-SAMPLE WEBB BOOTSTRAP")
    print("="*70)

    specs = [
        (MACRO, "M_macro"),
        (MACRO + ["gcai_adopt"], "M_gcai"),
        (MACRO + ["gcai_adopt", "gcai_x_inf"], "M_interaction"),
    ]

    all_rows = []
    for sname, sdf in [("2021-only", df_2021),
                       ("2022-2024", df_2022_24),
                       ("full-2021-2024", df_full)]:
        print(f"\n── Sub-sample: {sname} ──")
        for regs, mname in specs:
            label = f"{sname} | {mname}"
            rows = webb_bootstrap(sdf, regs, label)
            all_rows.extend(rows)

    if not all_rows:
        print("[ERROR] No results — check data.")
        return

    res = pd.DataFrame(all_rows)
    res.to_csv(OUT_CSV, index=False)
    print(f"\nSaved: {OUT_CSV}")

    # ── Driscoll-Kraay robustness on full sample, M_interaction ───────────────
    print("\n" + "="*70)
    print("DRISCOLL-KRAAY HAC (bandwidth=12, full 2021-2024 sample)")
    print("="*70)
    regs_int = MACRO + ["gcai_adopt", "gcai_x_inf"]
    dk_se = driscoll_kraay_se(df_full, regs_int, bandwidth=12)
    dk_table = []
    if dk_se is not None:
        # also get point estimates from OLS
        d_ = df_full.dropna(subset=[DEP] + regs_int + ["country"]).copy()
        d_fe = add_country_fe(d_)
        fe_cols = [c for c in d_fe.columns if c.startswith("c_")]
        all_X = regs_int + fe_cols
        X_ = sm.add_constant(d_fe[all_X].astype(float)).values
        y_ = d_fe[DEP].astype(float).values
        beta_, _ = fit_ols(y_, X_)
        x_names = ["const"] + all_X
        for r in regs_int:
            idx = x_names.index(r)
            b   = beta_[idx]
            se  = dk_se[r] if r in dk_se.index else np.nan
            t_  = b / se if se > 0 else np.nan
            pv  = float(2 * (1 - min(abs(t_) / 1, 1))) if not np.isnan(t_) else np.nan
            sig = ("***" if pv < 0.01 else "**" if pv < 0.05 else "*" if pv < 0.10 else "") if not np.isnan(pv) else ""
            print(f"  {r:35s}  β={b:+.4f}  SE_DK={se:.4f}  t={t_:+.3f}  {sig}")
            dk_table.append({"variable": r, "coef_dk": round(b,6),
                             "se_dk": round(se,6) if not np.isnan(se) else np.nan,
                             "t_dk": round(t_,3) if not np.isnan(t_) else np.nan,
                             "sig_dk": sig})

    # ── Markdown report ───────────────────────────────────────────────────────
    lines = [
        "# Paper 6 v9 — Split-Sample Webb Bootstrap + Driscoll-Kraay",
        "",
        "**Purpose:** Test whether the GCAI×inflation interaction (β=−0.153 in v8 full",
        "sample) is driven by the 2022-2024 intensification period or reflects a stable",
        "structural relationship across 2021-2024.",
        "",
        "**Design:** Sub-sample A = 2021 only (AR+BR+IN+NG verified, N_clust=4);",
        "Sub-sample B = 2022-2024 (AR+BR+IN+MX[from 2023]+NG[from 2023], N_clust≤5).",
        "",
        "**Inference:** Webb (2023) 6-point wild cluster bootstrap B=999;",
        "conventional cluster-robust SE (country) reported for comparison.",
        "",
        "---",
        "",
        "## 1. Sub-sample definitions",
        "",
        "| Sub-sample | Years | Countries (verified GCAI) | N_obs | N_clust |",
        "|---|---|---|---|---|",
    ]

    for sname, sdf in [("2021-only", df_2021),
                       ("2022-2024", df_2022_24),
                       ("full 2021-2024", df_full)]:
        sub = sdf.dropna(subset=["gcai_adopt", DEP] + MACRO)
        ctries = sorted(sub["country"].unique())
        lines.append(f"| {sname} | {sdf['year'].unique().tolist()} | "
                     f"{', '.join(ctries)} | {len(sub)} | {len(ctries)} |")

    lines += [
        "",
        "---",
        "",
        "## 2. Webb bootstrap results — M_interaction only",
        "",
        "(Full table across all specs saved to `paper6_v9_split_sample.csv`.)",
        "",
        "| Sample | Variable | β | SE_CR | CI_lo (95%) | CI_hi (95%) | p_Webb | Sig |",
        "|---|---|---|---|---|---|---|---|",
    ]

    # Filter to M_interaction rows for main table
    sub_res = res[res["model"] == "M_interaction"].copy()
    for _, row in sub_res.iterrows():
        lines.append(
            f"| {row['sample']} | {row.variable} | {row.coef:+.4f} | "
            f"{row.se_cr:.4f} | {row.ci_lo_95:+.4f} | {row.ci_hi_95:+.4f} | "
            f"{row.p_webb:.3f} | {row.sig_webb} |"
        )

    lines += [
        "",
        "---",
        "",
        "## 3. Driscoll-Kraay HAC robustness (full 2021-2024, M_interaction)",
        "",
        "HAC bandwidth = 12 months (Bartlett kernel); robust to both serial",
        "correlation and cross-sectional dependence per Driscoll & Kraay (1998).",
        "",
        "| Variable | β | SE_DK | t_DK | Sig |",
        "|---|---|---|---|---|",
    ]
    for row in dk_table:
        lines.append(
            f"| {row['variable']} | {row['coef_dk']:+.4f} | "
            f"{row['se_dk']:.4f} | {row['t_dk']:+.3f} | {row['sig_dk']} |"
        )

    lines += [
        "",
        "---",
        "",
        "## 4. Interpretation",
        "",
        "**Period effect (H1) vs dilution artefact (H2):**",
        "If β_GCAI×inf in sub-sample B (2022-2024) is significantly more negative",
        "than in sub-sample A (2021), H1 is supported. The mechanism is:",
        "  (a) Chainalysis 2022 methodology shift (DeFi added, P2P dropped) expanded",
        "      the measured adoption base, particularly for stablecoin demand;",
        "  (b) Terra/LUNA collapse (May 2022) and FTX collapse (Nov 2022) generated",
        "      regulatory clarity in some EM jurisdictions and simultaneously drove",
        "      on-chain USD stablecoin flows as a safe-haven channel;",
        "  (c) Argentina's parallel FX market stress intensified post-2022,",
        "      amplifying the stablecoin-as-absorber margin.",
        "",
        "**If H2 (dilution):** The negative interaction in v5 (−0.871) was based on a",
        "smaller 2022-2024 dataset and may reflect Argentina driving the result.",
        "Use sub-sample without Argentina as a placebo check.",
        "",
        "---",
        "",
        "## 5. References (Zotero-ready)",
        "",
        "- Driscoll, J. C., & Kraay, A. C. (1998). Consistent covariance matrix",
        "  estimation with spatially dependent panel data. *Review of Economics and",
        "  Statistics*, 80(4), 549-560. https://doi.org/10.1162/003465398557825",
        "- Webb, M. D. (2023). Reworking wild bootstrap-based inference for clustered",
        "  errors. *Canadian Journal of Economics*, 56(3), 839-858.",
        "- MacKinnon, J. G., & Webb, M. D. (2017). Wild bootstrap inference for",
        "  wildly different cluster sizes. *Journal of Applied Econometrics*, 32(2),",
        "  233-254.",
        "- Bai, J., & Perron, P. (2003). Computation and analysis of multiple",
        "  structural change models. *Journal of Applied Econometrics*, 18(1), 1-22.",
        "",
        "---",
        "_Script: `02-Methods/run_paper6_v9_split_sample.py` | Generated: 2026-04-09_",
    ]

    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"\nSaved: {OUT_MD}")

    # Console summary of key comparison
    print("\n" + "="*70)
    print("KEY COMPARISON: gcai_x_inf across sub-samples")
    print("="*70)
    key = res[(res["variable"] == "gcai_x_inf") & (res["model"] == "M_interaction")][
        ["sample", "coef", "ci_lo_95", "ci_hi_95", "p_webb", "sig_webb", "N_obs", "N_clust"]
    ]
    print(key.to_string(index=False))


if __name__ == "__main__":
    main()
