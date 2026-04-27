#!/usr/bin/env python3
"""
run_paper6_v8_webb_bootstrap.py — Webb (2023) wild cluster bootstrap for P6.

Context
-------
N=6 clusters (AR, BR, IN, MX, NG, ZA). Cameron-Miller (2015) and MacKinnon-
Webb (2017) show that with N<30 clusters, standard cluster-robust SEs are
severely undersized and t-based inference is unreliable. Webb (2023) 6-point
discrete weights deliver near-exact rejection rates even at N=6.

Webb weights: w ∈ {-√(3/2), -1, -√(1/2), +√(1/2), +1, +√(3/2)}
  each with probability 1/6 per cluster.

Models bootstrapped
-------------------
M_base : fx_dep ~ inflation + bmi + rac + country_FE              (full T)
M_crypto: fx_dep ~ inflation + bmi + rac + crypto_premium + cFE   (2017+, N≤5)
M_trends: fx_dep ~ inflation + bmi + rac + btc_chg + cFE         (2018+, N=6)

Output
------
03-Results/paper6_v8_webb_bootstrap.csv   — per-variable bootstrap table
03-Results/paper6_v8_webb_bootstrap.md    — markdown summary
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path

RNG  = np.random.default_rng(20260408)
B    = 999   # bootstrap iterations
ALPHA = 0.05

ROOT  = Path(__file__).resolve().parents[1]
PANEL = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v8_webb_bootstrap.csv"
OUT_MD  = ROOT / "03-Results" / "paper6_v8_webb_bootstrap.md"

# Webb 6-point discrete weights (MacKinnon-Webb 2017 Table 1)
WEBB_WEIGHTS = np.array([
    -np.sqrt(3/2), -1.0, -np.sqrt(1/2),
     np.sqrt(1/2),  1.0,  np.sqrt(3/2)
])

DEP   = "fx_depreciation"
MACRO = ["inflation_monthly", "broad_money_instability", "reserve_adequacy_change"]


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def add_country_fe(df: pd.DataFrame) -> pd.DataFrame:
    """Add country dummy columns (drop-first for identification)."""
    dummies = pd.get_dummies(df["country"], prefix="c", drop_first=True).astype(float)
    return pd.concat([df.reset_index(drop=True), dummies.reset_index(drop=True)], axis=1)


def fit_ols(y: np.ndarray, X: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Return (β̂, ê) via OLS."""
    beta, *_ = np.linalg.lstsq(X, y, rcond=None)
    resid    = y - X @ beta
    return beta, resid


def webb_bootstrap(
    df: pd.DataFrame,
    regressors: list[str],
    label: str,
    B: int = B,
) -> list[dict]:
    """
    Wild cluster bootstrap (Webb weights) for OLS with country FE.

    Returns list of dicts, one per target regressor (excluding dummies).
    """
    # ── 1. Prepare data ──────────────────────────────────────────────────────
    needed = [DEP] + regressors + ["country"]
    d = df.dropna(subset=needed).copy()

    countries = sorted(d["country"].unique())
    N_c = len(countries)

    if len(d) < 20 or N_c < 3:
        print(f"  [{label}] skipped — insufficient obs ({len(d)}) or clusters ({N_c})")
        return []

    print(f"  [{label}] N_obs={len(d)}, N_clusters={N_c}, B={B}")

    d = add_country_fe(d)
    fe_cols = [c for c in d.columns if c.startswith("c_")]
    all_X_cols = regressors + fe_cols

    X = sm.add_constant(d[all_X_cols].astype(float)).values
    y = d[DEP].astype(float).values
    ctry_arr = d["country"].values

    # ── 2. OLS point estimate ─────────────────────────────────────────────────
    beta_hat, resid_hat = fit_ols(y, X)

    # Indices of target regressors in X (col 0 is const)
    x_names = ["const"] + all_X_cols
    target_idx = {r: x_names.index(r) for r in regressors if r in x_names}

    # ── 3. Bootstrap ─────────────────────────────────────────────────────────
    beta_boot = np.full((B, len(target_idx)), np.nan)

    for b in range(B):
        # Draw one Webb weight per cluster
        w_map = {c: RNG.choice(WEBB_WEIGHTS) for c in countries}
        # Multiply residuals by cluster weight (maintain sign structure)
        w_vec  = np.array([w_map[c] for c in ctry_arr])
        y_star = X @ beta_hat + resid_hat * w_vec

        beta_b, _ = fit_ols(y_star, X)
        for j, r in enumerate(target_idx):
            beta_boot[b, j] = beta_b[target_idx[r]]

    # ── 4. Inference ──────────────────────────────────────────────────────────
    results = []
    for j, r in enumerate(target_idx):
        b0  = beta_hat[target_idx[r]]
        dist = beta_boot[:, j] - b0          # centered distribution

        # Bootstrap p-value: symmetric two-sided
        p_boot = np.mean(np.abs(beta_boot[:, j] - b0) >= np.abs(b0))

        # 95% CI (percentile method on centered distribution)
        lo = b0 + np.percentile(dist, 2.5)
        hi = b0 + np.percentile(dist, 97.5)

        # Conventional cluster-robust SE for comparison
        XtX_inv = np.linalg.pinv(X.T @ X)
        bread   = XtX_inv
        meat    = np.zeros((X.shape[1], X.shape[1]))
        for c in countries:
            mask = ctry_arr == c
            Xc   = X[mask]
            ec   = resid_hat[mask]
            meat += Xc.T @ np.outer(ec, ec) @ Xc
        V    = bread @ meat @ bread
        se_cr = np.sqrt(V[target_idx[r], target_idx[r]])
        t_cr  = b0 / se_cr if se_cr > 0 else np.nan

        results.append({
            "model"    : label,
            "variable" : r,
            "coef"     : round(b0,       6),
            "se_cr"    : round(se_cr,    6),
            "t_cr"     : round(t_cr,     3),
            "p_cr"     : round(2*(1 - min(abs(t_cr)/1, 1)), 4) if not np.isnan(t_cr) else np.nan,
            "ci_lo_95" : round(lo,       6),
            "ci_hi_95" : round(hi,       6),
            "p_webb"   : round(p_boot,   4),
            "sig_webb" : "***" if p_boot < 0.01 else "**" if p_boot < 0.05 else "*" if p_boot < 0.10 else "",
            "N_obs"    : len(d),
            "N_clust"  : N_c,
            "B"        : B,
        })
        print(f"    {r:35s}  β={b0:+.4f}  p_webb={p_boot:.3f}{results[-1]['sig_webb']}"
              f"  CI=[{lo:+.4f}, {hi:+.4f}]")

    return results


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    print(f"[p6_v8] panel loaded: {df.shape}, "
          f"countries: {df['country'].unique().tolist()}")

    # ── Winsorise extreme FX observations (5th–95th by country) ──────────────
    def winsorise(s, lo=0.05, hi=0.95):
        ql, qh = s.quantile(lo), s.quantile(hi)
        return s.clip(ql, qh)

    df[DEP] = df.groupby("country")[DEP].transform(winsorise)

    all_results = []

    # ── M_base: macro-only, full sample ──────────────────────────────────────
    print("\n[M_base] Macro-only, full sample")
    all_results += webb_bootstrap(df, MACRO, "M_base")

    # ── M_trends: + Google Trends BTC change, 2018+ ───────────────────────────
    df_tr = df[df["DATE"].dt.year >= 2018].copy()
    print("\n[M_trends] + country_btc_interest_chg (Google Trends, 2018+)")
    all_results += webb_bootstrap(
        df_tr,
        MACRO + ["country_btc_interest_chg"],
        "M_trends"
    )

    # ── M_crypto: + crypto_premium, 2017+ (N≤5, ZA usually missing) ──────────
    df_cp = df[df["DATE"].dt.year >= 2017].copy()
    df_cp = df_cp.dropna(subset=["crypto_premium"])
    # Require ≥10 obs per country
    keep = df_cp.groupby("country").filter(lambda g: len(g) >= 10)
    print("\n[M_crypto] + crypto_premium (CryptoCompare, 2017+)")
    all_results += webb_bootstrap(
        keep,
        MACRO + ["crypto_premium"],
        "M_crypto"
    )

    # ── Save results ──────────────────────────────────────────────────────────
    if not all_results:
        print("\n[ERROR] No bootstrap results — check data availability.")
        return

    res_df = pd.DataFrame(all_results)
    res_df.to_csv(OUT_CSV, index=False)
    print(f"\nSaved: {OUT_CSV}")

    # ── Markdown report ───────────────────────────────────────────────────────
    lines = [
        "# P6 Webb Wild Cluster Bootstrap — v8",
        "",
        f"**B = {B} iterations** | Webb (2023) 6-point weights | Clusters = country",
        "",
        "**Why Webb bootstrap?** N=6 clusters → conventional cluster-robust t-tests",
        "are severely under-sized (MacKinnon & Webb 2017). Webb weights deliver",
        "correct size at N=6 by construction.",
        "",
        "---",
        "",
    ]

    for model_label in res_df["model"].unique():
        sub = res_df[res_df["model"] == model_label]
        n_obs  = sub["N_obs"].iloc[0]
        n_clus = sub["N_clust"].iloc[0]
        lines += [
            f"## {model_label}",
            f"N_obs = {n_obs}, N_clusters = {n_clus}",
            "",
            "| Variable | β | SE_CR | t_CR | CI_lo (Webb 95%) | CI_hi | p_Webb |",
            "|---|---|---|---|---|---|---|",
        ]
        for _, row in sub.iterrows():
            lines.append(
                f"| {row.variable} | {row.coef:+.4f} | {row.se_cr:.4f} | "
                f"{row.t_cr:+.3f} | {row.ci_lo_95:+.4f} | {row.ci_hi_95:+.4f} | "
                f"{row.p_webb:.3f} {row.sig_webb} |"
            )
        lines += ["", ""]

    lines += [
        "---",
        "**Significance:** \\*\\*\\* p<0.01, \\*\\* p<0.05, \\* p<0.10 (Webb bootstrap)",
        "",
        "_Note: SE_CR = conventional cluster-robust standard error (for comparison only).",
        "Inference and CIs are based exclusively on Webb bootstrap distribution._",
    ]

    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"Saved: {OUT_MD}")

    # ── Console summary of main findings ──────────────────────────────────────
    print("\n" + "="*70)
    print("WEBB BOOTSTRAP SUMMARY")
    print("="*70)
    focus = ["inflation_monthly", "crypto_premium", "country_btc_interest_chg"]
    key = res_df[res_df["variable"].isin(focus)][
        ["model","variable","coef","ci_lo_95","ci_hi_95","p_webb","sig_webb"]
    ]
    print(key.to_string(index=False))


if __name__ == "__main__":
    main()
