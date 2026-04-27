#!/usr/bin/env python3
"""
run_paper6_v5_gfe.py — Bonhomme & Manresa (2015) Grouped Fixed Effects.

Motivation:
  Pesaran-Yamagata (v4) decisively rejected slope homogeneity (Δ̃ ≈ 19),
  and CCEMG / AMG (v4-v5) confirmed that pooled FE distorts the inflation
  pass-through. A natural data-driven response — instead of imposing
  ad-hoc groupings (e.g. IRR FX-regime, which the v5 interaction test
  found insignificant) — is the Bonhomme-Manresa (2015) Grouped FE
  estimator, which simultaneously partitions countries into G groups
  and estimates group-specific time effects.

Specification (Bonhomme-Manresa 2015, Eq. 2):
    y_it = β' X_it + α_{g_i, t} + ε_it,    g_i ∈ {1,...,G}

  - β is common across all units (homogeneous slopes given groups)
  - α_{g,t} is a group-time effect that absorbs group-specific common
    factors (a generalisation of two-way FE)
  - g_i is unknown and estimated by minimising the SSR over assignments

Algorithm: iterative k-means-like procedure (Bonhomme-Manresa 2015,
Algorithm 1):
  Step 0. Random initial assignment of countries to G groups
  Step 1. Given groups, estimate β and {α_{g,t}} via OLS with
          group×time dummies
  Step 2. Reassign each country to the group minimising its SSR
          contribution given current (β, α)
  Step 3. Iterate until assignments stabilise. Repeat with multiple
          random starts; keep the global minimum.

Reference: Bonhomme, S. & Manresa, E. (2015). "Grouped Patterns of
Heterogeneity in Panel Data." Econometrica 83(3): 1147-1184.

Output: 03-Results/paper6_v5_gfe.md
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd
import statsmodels.api as sm

ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT = ROOT / "03-Results" / "paper6_v5_gfe.md"

DEP = "fx_depreciation"
## NB: time-only regressors (global_dollar_change, fed_change) are
## perfectly collinear with the group×time dummies α_{g,t} and must be
## dropped from the slope vector — they are absorbed by α_{g,t} itself.
X_COLS = ["inflation_monthly", "broad_money_instability", "reserve_adequacy_change"]

RNG = np.random.default_rng(20260406)
N_STARTS = 25
MAX_ITER = 50


def _fit_given_groups(d: pd.DataFrame, groups: dict) -> tuple[float, np.ndarray, pd.DataFrame]:
    """OLS of y on X + group×time dummies. Returns (SSR, β̂, α̂_panel)."""
    d = d.copy()
    d["g"] = d["country"].map(groups)
    d["gt"] = d["g"].astype(str) + "_" + d["DATE"].dt.strftime("%Y-%m-%d")
    gt_d = pd.get_dummies(d["gt"], prefix="gt", drop_first=True).astype(float)
    X = pd.concat([d[X_COLS].astype(float).reset_index(drop=True),
                   gt_d.reset_index(drop=True)], axis=1)
    X = sm.add_constant(X)
    y = d[DEP].astype(float).reset_index(drop=True)
    res = sm.OLS(y, X).fit()
    beta = np.array([res.params[v] for v in X_COLS])
    fitted_alpha = res.fittedvalues - X[X_COLS].values @ beta - res.params["const"]
    alpha_df = pd.DataFrame({
        "country": d["country"].values,
        "DATE": d["DATE"].values,
        "g": d["g"].values,
        "alpha_gt": fitted_alpha.values,
        "y": y.values,
        "Xb": X[X_COLS].values @ beta + res.params["const"],
    })
    return float(res.ssr), beta, alpha_df


def _reassign(d: pd.DataFrame, beta: np.ndarray, alpha_df: pd.DataFrame, G: int) -> dict:
    """For each country, pick group g that minimises SSR contribution."""
    # Build {(g, DATE) → α_gt} lookup
    alpha_lookup = (alpha_df.drop_duplicates(["g", "DATE"])
                            .set_index(["g", "DATE"])["alpha_gt"])
    new_groups = {}
    for c, gc in d.groupby("country"):
        Xb_const = (gc[X_COLS].astype(float).values @ beta)
        y = gc[DEP].astype(float).values
        dates = gc["DATE"].values
        best_g, best_ssr = 0, np.inf
        for g in range(G):
            try:
                a = alpha_lookup.loc[g].reindex(dates).values
            except KeyError:
                continue
            mask = ~np.isnan(a)
            if mask.sum() == 0:
                continue
            ssr_g = float(np.sum((y[mask] - Xb_const[mask] - a[mask]) ** 2))
            if ssr_g < best_ssr:
                best_ssr, best_g = ssr_g, g
        new_groups[c] = best_g
    return new_groups


def grouped_fe(df: pd.DataFrame, G: int) -> dict:
    d = df.dropna(subset=[DEP] + X_COLS).copy()
    d["DATE"] = pd.to_datetime(d["DATE"])
    countries = sorted(d["country"].unique())
    N = len(countries)
    if G > N:
        return {"available": False}

    best = {"ssr": np.inf}
    for start in range(N_STARTS):
        # random initial assignment, ensuring each group is non-empty
        while True:
            init = {c: int(RNG.integers(0, G)) for c in countries}
            if len(set(init.values())) == G:
                break
        groups = init
        ssr = np.inf
        beta = None
        for it in range(MAX_ITER):
            try:
                ssr, beta, alpha_df = _fit_given_groups(d, groups)
            except (np.linalg.LinAlgError, ValueError):
                break
            new_groups = _reassign(d, beta, alpha_df, G)
            # safeguard: if reassignment empties a group, keep old
            if len(set(new_groups.values())) < G:
                break
            if new_groups == groups:
                break
            groups = new_groups
        if beta is not None and ssr < best["ssr"]:
            best = {"ssr": ssr, "beta": beta, "groups": groups, "iters": it + 1}

    if "beta" not in best:
        return {"available": False}

    # final fit for inference
    d["g"] = d["country"].map(best["groups"])
    d["gt"] = d["g"].astype(str) + "_" + d["DATE"].dt.strftime("%Y-%m-%d")
    gt_d = pd.get_dummies(d["gt"], prefix="gt", drop_first=True).astype(float)
    X = pd.concat([d[X_COLS].astype(float).reset_index(drop=True),
                   gt_d.reset_index(drop=True)], axis=1)
    X = sm.add_constant(X)
    y = d[DEP].astype(float).reset_index(drop=True)
    groups_codes = d["country"].astype("category").cat.codes
    res = sm.OLS(y, X).fit(cov_type="cluster", cov_kwds={"groups": groups_codes})
    beta_se = pd.DataFrame({
        "β": [res.params[v] for v in X_COLS],
        "SE": [res.bse[v] for v in X_COLS],
        "t": [res.tvalues[v] for v in X_COLS],
        "p": [res.pvalues[v] for v in X_COLS],
    }, index=X_COLS)

    # BIC for group-count selection (Bonhomme-Manresa 2015, Eq. 17)
    NT = int(res.nobs)
    k_eff = len(X_COLS) + 1 + (G * d["DATE"].nunique() - 1)
    sigma2 = res.ssr / NT
    bic = np.log(sigma2) + k_eff * np.log(NT) / NT
    return {
        "available": True,
        "G": G,
        "SSR": best["ssr"],
        "BIC": float(bic),
        "groups": best["groups"],
        "coef": beta_se,
        "N": NT,
        "adjR2": res.rsquared_adj,
    }


def main() -> int:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    print(f"[v5_gfe] panel: {df.shape}, ülkeler: {sorted(df['country'].unique())}")

    out = ["# Paper 6 v5 — Bonhomme-Manresa (2015) Grouped Fixed Effects\n",
           "**Specification:** y_it = β'X_it + α_{g_i, t} + ε_it\n",
           f"**Regressors:** {', '.join(X_COLS)}\n",
           f"**Algorithm:** iterative k-means assignment, {N_STARTS} random starts, max {MAX_ITER} iterations\n"]

    results = {}
    for G in (2, 3):
        print(f"[v5_gfe] G={G}...")
        r = grouped_fe(df, G)
        results[G] = r
        if not r["available"]:
            out.append(f"\n## G = {G}\n- Not available")
            continue
        out.append(f"\n## G = {G}\n")
        out.append(f"- N = {r['N']}, adj-R² = {r['adjR2']:.4f}, SSR = {r['SSR']:.4f}, BIC = {r['BIC']:.4f}")
        out.append(f"\n### Group assignment\n")
        groups_inv = {}
        for c, g in r["groups"].items():
            groups_inv.setdefault(g, []).append(c)
        for g, cs in sorted(groups_inv.items()):
            out.append(f"- **Group {g}:** {', '.join(sorted(cs))}")
        out.append("\n### Slope coefficients (cluster-robust SE)\n")
        tbl = r["coef"].round(4)
        out.append(tbl.to_markdown())

    if all(results[g]["available"] for g in (2, 3)):
        chosen = min((2, 3), key=lambda g: results[g]["BIC"])
        out.append(f"\n## Model selection\n")
        out.append(f"- BIC(G=2) = {results[2]['BIC']:.4f}, BIC(G=3) = {results[3]['BIC']:.4f}")
        out.append(f"- **Preferred G = {chosen}** (lower BIC)")

    OUT.write_text("\n".join(out) + "\n")
    print(f"[v5_gfe] yazıldı: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
