#!/usr/bin/env python3
"""
run_paper6_v13_kaopen.py — Chinn-Ito KAOPEN as continuous moderator.

Tests whether replacing the binary AR_i dummy with a continuous capital-account
openness measure (ka_closed = -KAOPEN, Chinn-Ito 2022) can capture the
heterogeneous absorber effect.

The key question: does a more closed capital account (higher ka_closed)
predict a stronger absorber effect, or does the binary Argentina dummy
capture something ka_closed cannot?

Theory predicts: ka_closed alone is insufficient, because Turkey and India
also have ka_closed ≈ 1.25 (same as Argentina 2022) but show amplification
rather than absorption. The informal monetary-substitution infrastructure
(proxied by AR_i) is the missing variable.

Output
------
  03-Results/paper6_v13_kaopen.csv
  03-Results/paper6_v13_kaopen.md
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path

ROOT    = Path(__file__).resolve().parents[1]
PANEL   = ROOT / "03-Results" / "paper6_em_panel_v5.csv"
GCAI    = ROOT / "03-Results" / "chainalysis" / "chainalysis_gcai_2020_2024.csv"
KAOPEN  = ROOT / "03-Results" / "kaopen_em6.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v13_kaopen.csv"
OUT_MD  = ROOT / "03-Results" / "paper6_v13_kaopen.md"

RNG  = np.random.default_rng(20260413)
B    = 999
WEBB_WEIGHTS = np.array([
    -np.sqrt(3/2), -1.0, -np.sqrt(1/2),
     np.sqrt(1/2),  1.0,  np.sqrt(3/2)
])

DEP   = "fx_depreciation"
MACRO = ["inflation_monthly", "broad_money_instability", "reserve_adequacy_change"]


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

    # Merge Chinn-Ito KAOPEN
    ka = pd.read_csv(KAOPEN)[["country", "year", "ka_closed"]]
    # Forward-fill KAOPEN to 2023-2024 (data ends 2022; hold last value)
    all_years = pd.DataFrame({
        "year": range(2017, 2025),
    })
    ka_ext = []
    for ctry in ka["country"].unique():
        c = ka[ka["country"] == ctry].copy()
        c = all_years.merge(c, on="year", how="left")
        c["country"] = ctry
        c["ka_closed"] = c["ka_closed"].ffill().bfill()
        ka_ext.append(c)
    ka_full = pd.concat(ka_ext, ignore_index=True)
    df = df.merge(ka_full[["country", "year", "ka_closed"]],
                  on=["country", "year"], how="left")

    df["gcai_x_inf"]    = df["gcai_adopt"] * df["inflation_monthly"]
    # Continuous interaction with KAOPEN
    df["ka_x_gcai"]     = df["ka_closed"] * df["gcai_adopt"]
    df["ka_x_inf"]      = df["ka_closed"] * df["inflation_monthly"]
    df["ka_x_gcai_x_inf"] = df["ka_closed"] * df["gcai_adopt"] * df["inflation_monthly"]

    # Still include AR dummy for comparison
    df["ar_dummy"]       = (df["country"] == "Argentina").astype(float)
    df["ar_x_gcai_x_inf"] = df["ar_dummy"] * df["gcai_adopt"] * df["inflation_monthly"]

    return df


def subset(df, years):
    return df[df["year"].isin(years)].copy()


def add_country_fe(df):
    dummies = pd.get_dummies(df["country"], prefix="c", drop_first=True).astype(float)
    return pd.concat([df.reset_index(drop=True), dummies.reset_index(drop=True)], axis=1)


def fit_ols(y, X):
    beta, *_ = np.linalg.lstsq(X, y, rcond=None)
    return beta, y - X @ beta


def webb_bootstrap(df, regressors, label, B=B):
    needed = [DEP] + regressors + ["country"]
    d = df.dropna(subset=needed).copy()
    countries = sorted(d["country"].unique())
    N_c = len(countries)
    if len(d) < 20 or N_c < 3:
        print(f"  [{label}] SKIP")
        return []
    print(f"  [{label}] N_obs={len(d)}, N_clust={N_c}, B={B}")
    d = add_country_fe(d)
    fe_cols = [c for c in d.columns if c.startswith("c_")]
    all_X = regressors + fe_cols
    X = sm.add_constant(d[all_X].astype(float)).values
    y = d[DEP].astype(float).values
    ctry = d["country"].values
    beta_hat, resid_hat = fit_ols(y, X)
    x_names = ["const"] + all_X
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
        b0 = beta_hat[target_idx[r]]
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


def main():
    df = load_panel()
    sub = subset(df, [2022, 2023, 2024])
    all_results = []

    # ── M1: Continuous KAOPEN interaction (replaces binary AR dummy) ──────────
    print("\n=== M_kaopen: continuous ka_closed × gcai × π (2022-2024) ===")
    r1 = webb_bootstrap(
        sub,
        MACRO + ["gcai_adopt", "gcai_x_inf",
                 "ka_x_gcai", "ka_x_inf", "ka_x_gcai_x_inf"],
        "M_kaopen_continuous | 2022-2024",
    )
    all_results += r1

    # ── M2: Horse race — kaopen continuous vs AR binary ───────────────────────
    print("\n=== M_horserace: ka_closed + AR dummy joint (2022-2024) ===")
    r2 = webb_bootstrap(
        sub,
        MACRO + ["gcai_adopt", "gcai_x_inf",
                 "ka_x_gcai_x_inf", "ar_x_gcai_x_inf"],
        "M_horserace_KA_AR | 2022-2024",
    )
    all_results += r2

    if all_results:
        res_df = pd.DataFrame(all_results)
        res_df.to_csv(OUT_CSV, index=False)
        print(f"\n✓ Results → {OUT_CSV}")

        # Print KAOPEN values for reference
        ka = pd.read_csv(KAOPEN)
        print("\nKAOPEN summary (ka_closed = -KAOPEN) for reference:")
        print(ka[ka["year"] == 2022][["country", "kaopen", "ka_closed"]].to_string(index=False))

        lines = [
            "# Paper 6 v13 — Chinn-Ito KAOPEN Continuous Moderator\n\n",
            "**Purpose:** Test whether ka_closed (−KAOPEN) can substitute for AR_i binary dummy.\n",
            "If ka_closed × gcai × π is insignificant while AR_i × gcai × π remains significant,\n",
            "the absorber mechanism is specific to Argentina's informal infrastructure,\n",
            "not reducible to capital-account openness alone.\n\n",
            "**KAOPEN 2022 values (ka_closed = −KAOPEN):**\n\n",
            ka[ka["year"] == 2022][["country", "kaopen", "ka_closed"]].to_markdown(index=False),
            "\n\n**Results:**\n\n",
            res_df.to_markdown(index=False),
            "\n\n**Interpretation:**\n",
            "- If ka_closed × gcai × π is n.s. → KAOPEN does not capture the absorber\n",
            "- If AR × gcai × π remains significant in horse-race → informal infrastructure matters\n",
            "- This supports the three-condition institutional story\n",
        ]
        OUT_MD.write_text("".join(lines))
        print(f"✓ Report → {OUT_MD}")


if __name__ == "__main__":
    main()
