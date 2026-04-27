#!/usr/bin/env python3
"""
run_paper6_v12_turkey.py — MC-2: Turkey as second quasi-treated unit.

Tests whether Turkey — which satisfies 2 of 3 institutional conditions for
the absorber mechanism (BDDK capital controls + extreme inflation, but without
Argentina's entrenched informal dollarisation infrastructure) — exhibits a
smaller or absent negative interaction effect relative to Argentina.

Specifications estimated on the v5 panel (2022-2024, 6 countries → N_cl=6):
  M_base_tr    : triple interaction with only AR dummy (baseline replication)
  M_dual_tr    : add TR dummy — tests whether Turkey differential is significant
  M_dual_full  : full four-way decomposition: AR differential + TR differential

Output
------
  03-Results/paper6_v12_turkey.csv
  03-Results/paper6_v12_turkey.md
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path

ROOT    = Path(__file__).resolve().parents[1]
PANEL   = ROOT / "03-Results" / "paper6_em_panel_v5.csv"
GCAI    = ROOT / "03-Results" / "chainalysis" / "chainalysis_gcai_2020_2024.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v12_turkey.csv"
OUT_MD  = ROOT / "03-Results" / "paper6_v12_turkey.md"

RNG  = np.random.default_rng(20260412)
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
    df["year"] = df["DATE"].dt.year

    g = pd.read_csv(GCAI)
    g = g[g["verified"] == "yes"].copy()
    g["gcai_rank_inv"] = 155 - g["gcai_rank"]
    g["gcai_adopt"] = (
        (g["gcai_rank_inv"] - g["gcai_rank_inv"].min())
        / (g["gcai_rank_inv"].max() - g["gcai_rank_inv"].min())
    )
    df = df.merge(g[["country", "year", "gcai_adopt"]],
                  on=["country", "year"], how="left")

    # Interaction terms
    df["gcai_x_inf"]       = df["gcai_adopt"] * df["inflation_monthly"]

    # Argentina dummies
    df["ar_dummy"]         = (df["country"] == "Argentina").astype(float)
    df["ar_x_gcai"]        = df["ar_dummy"] * df["gcai_adopt"]
    df["ar_x_inf"]         = df["ar_dummy"] * df["inflation_monthly"]
    df["ar_x_gcai_x_inf"]  = df["ar_dummy"] * df["gcai_adopt"] * df["inflation_monthly"]

    # Turkey dummies (new for MC-2)
    df["tr_dummy"]         = (df["country"] == "Turkey").astype(float)
    df["tr_x_gcai"]        = df["tr_dummy"] * df["gcai_adopt"]
    df["tr_x_inf"]         = df["tr_dummy"] * df["inflation_monthly"]
    df["tr_x_gcai_x_inf"]  = df["tr_dummy"] * df["gcai_adopt"] * df["inflation_monthly"]

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


# ─── Webb bootstrap ───────────────────────────────────────────────────────────

def webb_bootstrap(df, regressors, label, B=B):
    needed = [DEP] + regressors + ["country"]
    d = df.dropna(subset=needed).copy()
    countries = sorted(d["country"].unique())
    N_c = len(countries)

    if len(d) < 20 or N_c < 3:
        print(f"  [{label}] SKIP — N_obs={len(d)}, N_clust={N_c}")
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
        sig = ("***" if p_boot < 0.01 else "**" if p_boot < 0.05 else
               "*" if p_boot < 0.10 else "")
        print(f"    {r:45s}  β={b0:+.4f}  p={p_boot:.3f}{sig}  CI=[{lo:+.4f},{hi:+.4f}]")
        results.append({
            "model": label, "variable": r,
            "coef": round(b0, 6), "p_webb": round(p_boot, 4),
            "ci_lo": round(lo, 6), "ci_hi": round(hi, 6),
            "sig": sig, "N_obs": len(d), "N_clust": N_c,
        })
    return results


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    df = load_panel()
    sub = subset(df, [2022, 2023, 2024])
    all_results = []

    # ── Model 1: baseline replication (AR dummy only, v5 panel) ──────────────
    print("\n=== M_base_AR (AR dummy only, v5 panel 2022-2024) ===")
    r1 = webb_bootstrap(
        sub,
        MACRO + ["gcai_adopt", "gcai_x_inf",
                 "ar_x_gcai", "ar_x_inf", "ar_x_gcai_x_inf"],
        "M_base_AR | 2022-2024",
    )
    all_results += r1

    # ── Model 2: dual dummy — AR + TR ────────────────────────────────────────
    print("\n=== M_dual (AR + TR dummies, 2022-2024) ===")
    r2 = webb_bootstrap(
        sub,
        MACRO + ["gcai_adopt", "gcai_x_inf",
                 "ar_x_gcai", "ar_x_inf", "ar_x_gcai_x_inf",
                 "tr_x_gcai", "tr_x_inf", "tr_x_gcai_x_inf"],
        "M_dual_TR | 2022-2024",
    )
    all_results += r2

    # ── Save ─────────────────────────────────────────────────────────────────
    if all_results:
        res_df = pd.DataFrame(all_results)
        res_df.to_csv(OUT_CSV, index=False)
        print(f"\n✓ Results → {OUT_CSV}")

        # Markdown summary
        lines = [
            "# Paper 6 v12 — Turkey Extension (MC-2 Response)\n\n",
            f"Generated: 2026-04-09 | B={B} | Panel v5 | seed=20260412\n\n",
            "## Purpose\n\n",
            "Tests whether Turkey (GCAI #11-12; BDDK capital controls; 65%+ CPI 2023)\n",
            "exhibits a statistically distinct interaction effect relative to the base\n",
            "EM group. Unlike Argentina, Turkey lacks a deep informal peso-stablecoin\n",
            "infrastructure, so the absorber effect should be weaker or absent.\n\n",
            "## Hypothesis\n\n",
            "H0: β_TR (tr_x_gcai_x_inf) = 0 (Turkey indistinguishable from base EM)\n",
            "H1: β_TR < 0 (Turkey absorbs, but less than Argentina)\n\n",
            "## Results\n\n",
            res_df.to_markdown(index=False),
            "\n\n## Interpretation\n\n",
            "Compare β_AR (ar_x_gcai_x_inf) vs β_TR (tr_x_gcai_x_inf):\n",
            "- If β_TR = 0: Turkey not distinguishable from base group → AR-specific\n",
            "- If β_TR < 0 but |β_TR| << |β_AR|: partial absorber → depth of informal\n",
            "  market matters (supports institutional explanation)\n",
            "- If β_TR ≈ β_AR: any high-inflation capital-control EM absorbs (stronger claim)\n",
        ]
        OUT_MD.write_text("".join(lines))
        print(f"✓ Report → {OUT_MD}")


if __name__ == "__main__":
    main()
