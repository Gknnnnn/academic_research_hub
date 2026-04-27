#!/usr/bin/env python3
"""
run_paper6_v11_iv_lagged.py — IV robustness using 12-month lagged gcai_adopt.

Motivation (MC-1 from referee report)
--------------------------------------
gcai_adopt is endogenous: countries with depreciating currencies attract more
crypto users, raising the GCAI rank.  The causal language in the abstract
requires a credible identification strategy.

Instrument: gcai_adopt_{i,t-12} (12-month lag).
Exclusion restriction: annual rank changes propagate slowly; a 12-month lag
breaks the contemporaneous simultaneity between adoption and depreciation.
The lagged adoption level is plausibly uncorrelated with the current month's
depreciation shock (ε_{it}) once country FE and macro controls are included.

Approach
---------
We implement a two-stage approach manually (to remain compatible with the
Webb bootstrap cluster-resampling infrastructure):
  Stage 1: Regress endogenous variable on instrument + controls → fitted values
  Stage 2: Replace endogenous variable with Stage-1 fitted values in main model
  Bootstrap: Resample Stage-2 residuals using Webb weights

We test two endogenous terms:
  (a) gcai_adopt  → instrument: L12.gcai_adopt (single-endogenous)
  (b) gcai_x_inf  → instrument: L12.gcai_adopt × inflation_monthly
      (single endogenous interaction, inflation treated as exogenous)

For the triple interaction, both gcai_x_inf AND ar_x_gcai_x_inf are
endogenous → instrument both with lagged counterparts.

First-stage diagnostics:
  - F-statistic on excluded instrument (should exceed 10)
  - Partial R² of instrument

Output
------
  03-Results/paper6_v11_iv_lagged.csv
  03-Results/paper6_v11_iv_lagged.md
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path

ROOT    = Path(__file__).resolve().parents[1]
PANEL   = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
GCAI    = ROOT / "03-Results" / "chainalysis" / "chainalysis_gcai_2020_2024.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v11_iv_lagged.csv"
OUT_MD  = ROOT / "03-Results" / "paper6_v11_iv_lagged.md"

RNG  = np.random.default_rng(20260411)
B    = 999
WEBB_WEIGHTS = np.array([
    -np.sqrt(3/2), -1.0, -np.sqrt(1/2),
     np.sqrt(1/2),  1.0,  np.sqrt(3/2)
])

DEP   = "fx_depreciation"
MACRO = ["inflation_monthly", "broad_money_instability", "reserve_adequacy_change"]


# ─── Data ─────────────────────────────────────────────────────────────────────

def load_panel() -> pd.DataFrame:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    df["year"]  = df["DATE"].dt.year
    df["month"] = df["DATE"].dt.month

    g = pd.read_csv(GCAI)
    g = g[g["verified"] == "yes"].copy()
    g["gcai_rank_inv"] = 155 - g["gcai_rank"]
    g["gcai_adopt"] = (
        (g["gcai_rank_inv"] - g["gcai_rank_inv"].min())
        / (g["gcai_rank_inv"].max() - g["gcai_rank_inv"].min())
    )
    df = df.merge(
        g[["country", "year", "gcai_adopt"]],
        on=["country", "year"], how="left",
    )
    # Sort for lag construction
    df = df.sort_values(["country", "DATE"]).reset_index(drop=True)

    # 12-month lag of gcai_adopt (within country)
    df["gcai_adopt_L12"] = df.groupby("country")["gcai_adopt"].shift(12)

    # Interaction terms (contemporaneous)
    df["gcai_x_inf"]     = df["gcai_adopt"]     * df["inflation_monthly"]
    df["gcai_x_inf_L12"] = df["gcai_adopt_L12"] * df["inflation_monthly"]

    # Argentina interactions
    df["ar_dummy"]           = (df["country"] == "Argentina").astype(float)
    df["ar_x_gcai"]          = df["ar_dummy"] * df["gcai_adopt"]
    df["ar_x_inf"]           = df["ar_dummy"] * df["inflation_monthly"]
    df["ar_x_gcai_x_inf"]    = df["ar_dummy"] * df["gcai_adopt"] * df["inflation_monthly"]
    df["ar_x_gcai_x_inf_L12"]= df["ar_dummy"] * df["gcai_adopt_L12"] * df["inflation_monthly"]

    return df


def subset(df, years):
    return df[df["year"].isin(years)].copy()


# ─── FE helpers ───────────────────────────────────────────────────────────────

def add_country_fe(df):
    dummies = pd.get_dummies(df["country"], prefix="c", drop_first=True).astype(float)
    return pd.concat([df.reset_index(drop=True), dummies.reset_index(drop=True)], axis=1)


def fit_ols(y, X):
    beta, *_ = np.linalg.lstsq(X, y, rcond=None)
    return beta, y - X @ beta


def first_stage_fstat(y_endog, Z_instr, X_exog):
    """F-stat on excluded instruments in first stage."""
    X_full = np.hstack([Z_instr, X_exog])
    X_rest = X_exog
    beta_f, res_f = fit_ols(y_endog, X_full)
    beta_r, res_r = fit_ols(y_endog, X_rest)
    n, k = X_full.shape
    q = Z_instr.shape[1]
    RSS_r = res_r @ res_r
    RSS_f = res_f @ res_f
    F = ((RSS_r - RSS_f) / q) / (RSS_f / (n - k))
    partial_r2 = (RSS_r - RSS_f) / RSS_r
    return float(F), float(partial_r2), res_f  # residuals from first stage


# ─── 2SLS Webb bootstrap ──────────────────────────────────────────────────────

def iv_webb_bootstrap(
    df: pd.DataFrame,
    endog_vars: list[str],          # endogenous regressors
    instrument_vars: list[str],     # instruments (parallel list)
    exog_vars: list[str],           # exogenous regressors (including controls)
    label: str,
    B: int = B,
) -> tuple[list[dict], list[dict]]:
    """Two-stage Webb bootstrap for IV endogenous vars."""
    needed = [DEP] + endog_vars + instrument_vars + exog_vars + ["country"]
    d = df.dropna(subset=needed).copy()
    countries = sorted(d["country"].unique())
    N_c = len(countries)

    if len(d) < 20 or N_c < 3:
        print(f"  [{label}] SKIP — N_obs={len(d)}, N_clust={N_c}")
        return [], []

    print(f"  [{label}] N_obs={len(d)}, N_clust={N_c}, B={B}")
    d = add_country_fe(d)
    fe_cols = [c for c in d.columns if c.startswith("c_")]

    # Exogenous regressors including country FE
    X_exog = sm.add_constant(
        d[exog_vars + fe_cols].astype(float)
    ).values

    # Stage 1 — predict each endogenous variable
    fitted_endog = {}
    fs_stats = []
    for ev, iv in zip(endog_vars, instrument_vars):
        Z = d[[iv]].astype(float).values
        F, pr2, fs_resid = first_stage_fstat(
            d[ev].astype(float).values, Z, X_exog
        )
        beta_fs, _ = fit_ols(d[ev].astype(float).values, np.hstack([Z, X_exog]))
        fitted_endog[ev] = np.hstack([Z, X_exog]) @ beta_fs
        print(f"    FS [{ev}]  F={F:.1f}  partial-R²={pr2:.3f}")
        fs_stats.append({"label": label, "endog": ev, "instrument": iv,
                         "F_first_stage": round(F, 2), "partial_R2": round(pr2, 4),
                         "N_obs": len(d), "N_clust": N_c})

    # Stage 2 — replace endogenous vars with fitted values
    for ev in endog_vars:
        d[ev + "_hat"] = fitted_endog[ev]
    endog_hat_cols = [ev + "_hat" for ev in endog_vars]
    all_X_cols_2s = endog_hat_cols + exog_vars + fe_cols

    X2 = sm.add_constant(d[all_X_cols_2s].astype(float)).values
    y  = d[DEP].astype(float).values
    ctry = d["country"].values

    beta_hat, resid_hat = fit_ols(y, X2)
    x_names = ["const"] + all_X_cols_2s
    # Report coefficients for endog and key exog vars
    target_cols = endog_hat_cols + [v for v in exog_vars if "gcai" in v or "inf" in v]
    target_idx  = {r: x_names.index(r) for r in target_cols if r in x_names}

    # Webb bootstrap on Stage-2 residuals
    beta_boot = np.full((B, len(target_idx)), np.nan)
    for b in range(B):
        w_map = {c: RNG.choice(WEBB_WEIGHTS) for c in countries}
        w_vec = np.array([w_map[c] for c in ctry])
        y_star = X2 @ beta_hat + resid_hat * w_vec
        beta_b, _ = fit_ols(y_star, X2)
        for j, r in enumerate(target_idx):
            beta_boot[b, j] = beta_b[target_idx[r]]

    iv_results = []
    for j, r in enumerate(target_idx):
        b0   = beta_hat[target_idx[r]]
        dist = beta_boot[:, j] - b0
        p_boot = float(np.mean(np.abs(beta_boot[:, j] - b0) >= np.abs(b0)))
        lo = b0 + float(np.percentile(dist, 2.5))
        hi = b0 + float(np.percentile(dist, 97.5))
        sig = ("***" if p_boot < 0.01 else "**" if p_boot < 0.05 else
               "*" if p_boot < 0.10 else "")
        print(f"    {r:45s}  β={b0:+.4f}  p={p_boot:.3f}{sig}  CI=[{lo:+.4f},{hi:+.4f}]")
        iv_results.append({
            "sample":   label,
            "estimator":"IV-2SLS (L12 instrument)",
            "variable":  r.replace("_hat", " [instrumented]"),
            "coef":      round(b0, 6), "p_webb": round(p_boot, 4),
            "ci_lo":     round(lo, 6), "ci_hi": round(hi, 6),
            "sig":       sig, "N_obs": len(d), "N_clust": N_c,
        })
    return iv_results, fs_stats


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    df = load_panel()
    all_iv    = []
    all_fs    = []

    # ── 1. M_interaction with IV for gcai_x_inf ───────────────────────────────
    # Instrument: gcai_x_inf_L12 = L12(gcai_adopt) × inflation
    print("\n=== IV M_interaction (2022-2024) — endog: gcai_x_inf ===")
    sub = subset(df, [2022, 2023, 2024])
    iv_res, fs_res = iv_webb_bootstrap(
        sub,
        endog_vars     = ["gcai_x_inf"],
        instrument_vars= ["gcai_x_inf_L12"],
        exog_vars      = MACRO + ["gcai_adopt"],
        label          = "IV M_interaction | 2022-2024",
    )
    all_iv += iv_res; all_fs += fs_res

    # ── 2. Full triple-interaction with IV for gcai_x_inf + ar_x_gcai_x_inf ──
    print("\n=== IV Triple (2022-2024) — endog: gcai_x_inf + ar_x_gcai_x_inf ===")
    iv_res, fs_res = iv_webb_bootstrap(
        sub,
        endog_vars     = ["gcai_x_inf", "ar_x_gcai_x_inf"],
        instrument_vars= ["gcai_x_inf_L12", "ar_x_gcai_x_inf_L12"],
        exog_vars      = MACRO + ["gcai_adopt", "ar_x_gcai", "ar_x_inf"],
        label          = "IV Triple | 2022-2024",
    )
    all_iv += iv_res; all_fs += fs_res

    # ── 3. Save ───────────────────────────────────────────────────────────────
    if all_iv:
        pd.DataFrame(all_iv).to_csv(OUT_CSV, index=False)
        print(f"\n✓ IV results → {OUT_CSV}")

    if all_fs:
        fs_df = pd.DataFrame(all_fs)
        lines = [
            "# Paper 6 v11 — IV-2SLS Robustness (MC-1 Response)\n\n",
            "## First-Stage Diagnostics\n\n",
            fs_df.to_markdown(index=False), "\n\n",
            "**Rule of thumb:** F > 10 → instrument is not weak.\n\n",
            "## IV Coefficient Estimates (Webb Bootstrap, B=999)\n\n",
            pd.DataFrame(all_iv).to_markdown(index=False), "\n\n",
            "## Interpretation\n\n",
            "If IV coefficients are close to OLS (β_5 ≈ +0.68, β_8 ≈ −10.96), ",
            "the endogeneity concern is empirically modest and the OLS results are reliable.\n",
            "If they diverge substantially, endogeneity bias is present and the IV estimates ",
            "are preferred.\n",
        ]
        OUT_MD.write_text("".join(lines))
        print(f"✓ IV report → {OUT_MD}")


if __name__ == "__main__":
    main()
