#!/usr/bin/env python3
"""
run_paper6_models_v4.py — Multi-proxy horse-race for crypto-substitution paper.

Strategy: Estimate the same FX-depreciation equation under competing crypto
proxies (currently only Google-Trends; v4 will add CoinGecko exchange volume
and Chainalysis adoption rank once fetch_p6_extra_countries.py runs locally).

Specifications:
  M0  Macro-only baseline (country FE)
  M1  + Google Trends BTC interest
  M2  + Google Trends Stablecoin interest
  M3  + Both Trends proxies
  [v4 reserved]
  M4  + CoinGecko exchange volume
  M5  + Chainalysis adoption rank
  M6  Joint horse race (all proxies)

Output: 03-Results/paper6_v4_horse_race.csv + paper6_v4_summary.md
"""
import pandas as pd
import numpy as np
import statsmodels.api as sm
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v4_horse_race.csv"
OUT_MD = ROOT / "03-Results" / "paper6_v4_summary.md"

DEP = "fx_depreciation"
MACRO = ["global_dollar_change", "fed_change", "inflation_monthly",
         "broad_money_instability", "reserve_adequacy_change"]


def standardize(df, cols):
    out = df.copy()
    for c in cols:
        s = out[c].std()
        if s and s > 0:
            out[c] = (out[c] - out[c].mean()) / s
    return out


def fit_fe(df, regressors):
    """Country-FE OLS with cluster-robust SE (clustered by country)."""
    d = df.dropna(subset=[DEP] + regressors).copy()
    if d.empty or len(d) < 30:
        return None
    # Country dummies (drop one for identification)
    dummies = pd.get_dummies(d["country"], prefix="c", drop_first=True).astype(float)
    X = pd.concat([d[regressors], dummies], axis=1)
    X = sm.add_constant(X)
    y = d[DEP].astype(float)
    groups = d["country"].astype("category").cat.codes
    model = sm.OLS(y, X, missing="drop")
    res = model.fit(cov_type="cluster", cov_kwds={"groups": groups})
    return res, d


def extract(res, regressors, label):
    out = []
    for r in regressors:
        if r in res.params.index:
            out.append({
                "model": label,
                "variable": r,
                "coef": res.params[r],
                "std_err": res.bse[r],
                "t": res.tvalues[r],
                "p": res.pvalues[r],
            })
    return out


def main():
    df = pd.read_csv(PANEL)
    print(f"[p6_v4] panel: {df.shape}, countries: {df['country'].unique().tolist()}")

    # Standardise continuous regressors for cross-spec comparability
    candidate = MACRO + [
        "country_btc_interest_chg", "country_stablecoin_interest_chg",
        "crypto_premium", "log_crypto_volume",
    ]
    available = [c for c in candidate if c in df.columns]
    df = standardize(df, available)

    specs = {
        "M0_macro_only":         MACRO,
        "M1_btc_trends":         MACRO + ["country_btc_interest_chg"],
        "M2_stable_trends":      MACRO + ["country_stablecoin_interest_chg"],
        "M3_both_trends":        MACRO + ["country_btc_interest_chg", "country_stablecoin_interest_chg"],
        "M4_crypto_premium":     MACRO + ["crypto_premium"],
        "M5_crypto_volume":      MACRO + ["log_crypto_volume"],
        "M6_crypto_joint":       MACRO + ["crypto_premium", "log_crypto_volume"],
        "M7_horse_race_full":    MACRO + ["country_btc_interest_chg", "country_stablecoin_interest_chg",
                                          "crypto_premium", "log_crypto_volume"],
    }

    rows = []
    summary_md = ["# Paper 6 — v4 Multi-Proxy Horse Race\n",
                  "**Model:** country-FE OLS, cluster-robust SE (by country)\n",
                  "**Standardised regressors** (β = effect of 1-SD shock).\n"]

    for label, regs in specs.items():
        out = fit_fe(df, regs)
        if out is None:
            print(f"[p6_v4] {label}: SKIP (insufficient obs)")
            continue
        res, d = out
        rows.extend(extract(res, regs, label))
        summary_md.append(f"\n## {label}\n")
        summary_md.append(f"- N = {int(res.nobs)}, adj_R² = {res.rsquared_adj:.4f}, AIC = {res.aic:.1f}, BIC = {res.bic:.1f}")
        summary_md.append(f"\n| Variable | β | SE | t | p |")
        summary_md.append("|---|---|---|---|---|")
        for r in regs:
            if r in res.params.index:
                star = "***" if res.pvalues[r] < 0.01 else ("**" if res.pvalues[r] < 0.05 else ("*" if res.pvalues[r] < 0.1 else ""))
                summary_md.append(f"| {r} | {res.params[r]:+.4f}{star} | {res.bse[r]:.4f} | {res.tvalues[r]:+.2f} | {res.pvalues[r]:.3f} |")
        print(f"[p6_v4] {label}: N={int(res.nobs)} adjR2={res.rsquared_adj:.4f} AIC={res.aic:.1f}")

    pd.DataFrame(rows).to_csv(OUT_CSV, index=False)
    OUT_MD.write_text("\n".join(summary_md) + "\n")
    print(f"\n[p6_v4] yazıldı: {OUT_CSV}")
    print(f"[p6_v4] yazıldı: {OUT_MD}")


if __name__ == "__main__":
    main()
