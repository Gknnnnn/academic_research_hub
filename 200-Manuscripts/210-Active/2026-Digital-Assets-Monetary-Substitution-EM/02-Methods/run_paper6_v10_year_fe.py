#!/usr/bin/env python3
"""
run_paper6_v10_year_fe.py — GCAI specifications WITH year fixed effects.

Motivation (MC-3 from referee report)
--------------------------------------
The GCAI sample spans 2021-2024 — the most volatile global crypto cycle in
history.  Without year FE, the interaction coefficients may absorb common
global crypto-cycle shocks (2021 boom, 2022 LUNA/FTX crash, 2023-24 recovery)
that co-move with EM macro conditions.  Adding year FE tests whether the
headline results survive the removal of this confounding.

Note: With year FE added, the DXY term (which is common across countries in
the same month) absorbs the same variation as year dummies only approximately
— we drop DXY from the GCAI-year-FE specifications to avoid near-perfect
multicollinearity between year dummies and the global dollar time series.

Specifications
--------------
  M_macro_yfe     : macro controls + country FE + year FE  (no DXY)
  M_gcai_yfe      : + gcai_adopt
  M_interaction_yfe: + gcai_adopt × inflation
  M_triple_yfe    : full triple-interaction with AR dummy (2022-2024 preferred)

Output
------
  03-Results/paper6_v10_year_fe.csv
  03-Results/paper6_v10_year_fe.md
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path

ROOT    = Path(__file__).resolve().parents[1]
PANEL   = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
GCAI    = ROOT / "03-Results" / "chainalysis" / "chainalysis_gcai_2020_2024.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v10_year_fe.csv"
OUT_MD  = ROOT / "03-Results" / "paper6_v10_year_fe.md"

RNG  = np.random.default_rng(20260410)
B    = 999
ALPHA = 0.05

WEBB_WEIGHTS = np.array([
    -np.sqrt(3/2), -1.0, -np.sqrt(1/2),
     np.sqrt(1/2),  1.0,  np.sqrt(3/2)
])

DEP   = "fx_depreciation"
# Note: DXY dropped from GCAI-year-FE specs (near-collinear with year dummies)
MACRO_YFE = ["inflation_monthly", "broad_money_instability", "reserve_adequacy_change"]


# ─── Data loading ─────────────────────────────────────────────────────────────

def load_panel() -> pd.DataFrame:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    df["year"] = df["DATE"].dt.year
    df["month"] = df["DATE"].dt.month

    g = pd.read_csv(GCAI)
    g = g[g["verified"] == "yes"].copy()
    g["gcai_rank_inv"] = 155 - g["gcai_rank"]
    g["gcai_adopt"] = (
        (g["gcai_rank_inv"] - g["gcai_rank_inv"].min())
        / (g["gcai_rank_inv"].max() - g["gcai_rank_inv"].min())
    )
    df = df.merge(
        g[["country", "year", "gcai_rank", "gcai_adopt"]],
        on=["country", "year"],
        how="left",
    )
    df["gcai_x_inf"] = df["gcai_adopt"] * df["inflation_monthly"]
    df["ar_dummy"]   = (df["country"] == "Argentina").astype(float)
    df["ar_x_gcai"]  = df["ar_dummy"] * df["gcai_adopt"]
    df["ar_x_inf"]   = df["ar_dummy"] * df["inflation_monthly"]
    df["ar_x_gcai_x_inf"] = df["ar_dummy"] * df["gcai_adopt"] * df["inflation_monthly"]
    return df


def subset(df: pd.DataFrame, years: list[int]) -> pd.DataFrame:
    return df[df["year"].isin(years)].copy()


# ─── FE helpers ───────────────────────────────────────────────────────────────

def add_country_fe(df: pd.DataFrame) -> pd.DataFrame:
    dummies = pd.get_dummies(df["country"], prefix="c", drop_first=True).astype(float)
    return pd.concat([df.reset_index(drop=True), dummies.reset_index(drop=True)], axis=1)


def add_year_fe(df: pd.DataFrame) -> pd.DataFrame:
    dummies = pd.get_dummies(df["year"], prefix="yr", drop_first=True).astype(float)
    return pd.concat([df.reset_index(drop=True), dummies.reset_index(drop=True)], axis=1)


def fit_ols(y: np.ndarray, X: np.ndarray):
    beta, *_ = np.linalg.lstsq(X, y, rcond=None)
    return beta, y - X @ beta


# ─── Webb bootstrap ───────────────────────────────────────────────────────────

def webb_bootstrap(
    df: pd.DataFrame,
    regressors: list[str],
    label: str,
    use_year_fe: bool = True,
    B: int = B,
) -> list[dict]:
    needed = [DEP] + regressors + ["country", "year"]
    d = df.dropna(subset=needed).copy()
    countries = sorted(d["country"].unique())
    N_c = len(countries)

    if len(d) < 20 or N_c < 3:
        print(f"  [{label}] SKIP — N_obs={len(d)}, N_clust={N_c}")
        return []

    print(f"  [{label}] N_obs={len(d)}, N_clust={N_c}, year_FE={use_year_fe}, B={B}")

    d = add_country_fe(d)
    if use_year_fe:
        d = add_year_fe(d)

    fe_cols  = [c for c in d.columns if c.startswith("c_")]
    yr_cols  = [c for c in d.columns if c.startswith("yr_")] if use_year_fe else []
    all_X_cols = regressors + fe_cols + yr_cols

    X = sm.add_constant(d[all_X_cols].astype(float)).values
    y = d[DEP].astype(float).values
    ctry = d["country"].values

    beta_hat, resid_hat = fit_ols(y, X)
    x_names = ["const"] + all_X_cols
    target_idx = {r: x_names.index(r) for r in regressors if r in x_names}

    beta_boot = np.full((B, len(target_idx)), np.nan)
    for b in range(B):
        w_map = {c: RNG.choice(WEBB_WEIGHTS) for c in countries}
        w_vec = np.array([w_map[c] for c in ctry])
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

        XtX_inv = np.linalg.pinv(X.T @ X)
        meat = np.zeros((X.shape[1], X.shape[1]))
        for c in countries:
            mask = ctry == c
            Xc, ec = X[mask], resid_hat[mask]
            meat += Xc.T @ np.outer(ec, ec) @ Xc
        V = XtX_inv @ meat @ XtX_inv
        se_cr = float(np.sqrt(max(V[target_idx[r], target_idx[r]], 0)))
        t_cr  = b0 / se_cr if se_cr > 0 else np.nan

        sig = ("***" if p_boot < 0.01 else
               "**"  if p_boot < 0.05 else
               "*"   if p_boot < 0.10 else "")
        print(f"    {r:40s}  β={b0:+.4f}  p_webb={p_boot:.3f}{sig}  "
              f"CI=[{lo:+.4f},{hi:+.4f}]  t_CR={t_cr:.2f}")

        results.append({
            "sample":    label.split("|")[0].strip(),
            "model":     label.split("|")[1].strip() if "|" in label else label,
            "year_fe":   use_year_fe,
            "variable":  r,
            "coef":      round(b0, 6),
            "se_cr":     round(se_cr, 6),
            "t_cr":      round(t_cr, 3) if not np.isnan(t_cr) else None,
            "p_webb":    round(p_boot, 4),
            "ci_lo":     round(lo, 6),
            "ci_hi":     round(hi, 6),
            "sig":       sig,
            "N_obs":     len(d),
            "N_clust":   N_c,
        })
    return results


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    df = load_panel()
    all_results = []

    # ── 1. GCAI horse-race: without year FE (baseline) vs with year FE ────────
    gcai_sub = subset(df, [2021, 2022, 2023, 2024])

    for yfe, tag in [(False, "no_yfe"), (True, "with_yfe")]:
        print(f"\n=== GCAI Horse-Race | year_FE={yfe} ===")

        # M_macro_yfe
        r1 = webb_bootstrap(
            gcai_sub, MACRO_YFE,
            f"GCAI 2021-24 {tag} | M_macro",
            use_year_fe=yfe,
        )
        all_results += r1

        # M_gcai_yfe
        r2 = webb_bootstrap(
            gcai_sub, MACRO_YFE + ["gcai_adopt"],
            f"GCAI 2021-24 {tag} | M_gcai",
            use_year_fe=yfe,
        )
        all_results += r2

        # M_interaction_yfe
        r3 = webb_bootstrap(
            gcai_sub, MACRO_YFE + ["gcai_adopt", "gcai_x_inf"],
            f"GCAI 2021-24 {tag} | M_interaction",
            use_year_fe=yfe,
        )
        all_results += r3

    # ── 2. Triple-interaction: 2022-2024, without and with year FE ────────────
    triple_sub = subset(df, [2022, 2023, 2024])

    TRIPLE_REGS = MACRO_YFE + [
        "gcai_adopt", "gcai_x_inf",
        "ar_x_gcai", "ar_x_inf", "ar_x_gcai_x_inf"
    ]

    for yfe, tag in [(False, "no_yfe"), (True, "with_yfe")]:
        print(f"\n=== Triple Interaction 2022-24 | year_FE={yfe} ===")
        r4 = webb_bootstrap(
            triple_sub, TRIPLE_REGS,
            f"Triple 2022-24 {tag} | M_triple",
            use_year_fe=yfe,
        )
        all_results += r4

    # ── 3. Save ───────────────────────────────────────────────────────────────
    if all_results:
        res_df = pd.DataFrame(all_results)
        res_df.to_csv(OUT_CSV, index=False)
        print(f"\n✓ Results saved → {OUT_CSV}")

        # Markdown report
        lines = [
            "# Paper 6 v10 — Year FE Sensitivity (MC-3 Response)\n",
            f"Generated: 2026-04-09 | B={B} | seed=20260410\n",
            "\n## Purpose\n",
            "Tests whether GCAI headline results survive addition of year fixed effects,\n",
            "which absorb global crypto-cycle confounders (2021 boom, 2022 crash, 2023-24 recovery).\n",
            "DXY dropped from year-FE specifications to avoid near-collinearity with year dummies.\n\n",
            "## Results\n\n",
            res_df.to_markdown(index=False),
            "\n\n## Interpretation\n",
            "- If β_5 (gcai_x_inf, base group) and β_8 (ar_x_gcai_x_inf) remain stable across\n",
            "  no_yfe vs with_yfe columns, the crypto-cycle confounding concern is resolved.\n",
            "- If they change sign or lose significance, the no-year-FE model is unreliable.\n",
        ]
        OUT_MD.write_text("".join(lines))
        print(f"✓ Markdown saved → {OUT_MD}")
    else:
        print("No results produced — check data paths.")


if __name__ == "__main__":
    main()
