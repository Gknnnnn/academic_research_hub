#!/usr/bin/env python3
"""
run_paper6_v5_break_augmented.py — Pooled country-FE with Bai-Perron
break-regime dummies and inflation × regime interactions.

Motivation:
  v5 Bai-Perron located m̂ ∈ {1,2,3} structural breaks per country. The
  natural follow-up is to re-estimate the M0 baseline allowing each
  country's slope on `inflation_monthly` to differ across its identified
  regimes. This isolates how the inflation-pass-through evolved
  endogenously around the IMF/Naira/Milei episodes documented in the
  break test.

Specification:
    Δfx_it = α_i + Σ_s β_{i,s} · (inflation_it · 1{t ∈ regime s of i})
                  + γ' Z_it + ε_it,
  where Z = [global_dollar_change, fed_change, broad_money_instability,
             reserve_adequacy_change] and {regime s} comes from
  03-Results/paper6_v5_baiperron.md (hard-coded constants below to
  preserve reproducibility — these are the m̂ break dates from the
  preceding script).

Output: 03-Results/paper6_v5_break_augmented.md
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd
import statsmodels.api as sm

ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT = ROOT / "03-Results" / "paper6_v5_break_augmented.md"

DEP = "fx_depreciation"
CTRL = ["global_dollar_change", "fed_change",
        "broad_money_instability", "reserve_adequacy_change"]

# Hard-coded from paper6_v5_baiperron.md (cross-check pending — see
# .auto-memory/paper6_baiperron_caveat.md)
BREAKS = {
    "Argentina":   ["2018-09-01", "2022-07-01", "2024-01-01"],
    "Brazil":      ["2002-09-01"],
    "India":       ["1983-07-01", "1991-07-01"],
    "Mexico":      ["1998-09-01"],
    "Nigeria":     ["2016-05-01"],
    "South Africa":["1993-07-01", "2002-12-01"],
}


def assign_regime(c: str, dt: pd.Timestamp) -> int:
    brks = [pd.Timestamp(b) for b in BREAKS.get(c, [])]
    s = 0
    for b in brks:
        if dt >= b:
            s += 1
    return s


def main() -> int:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    df = df.dropna(subset=[DEP, "inflation_monthly"] + CTRL).copy()
    df["regime"] = df.apply(lambda r: assign_regime(r["country"], r["DATE"]), axis=1)
    df["c_r"] = df["country"] + "__r" + df["regime"].astype(str)

    # interaction: inflation × (country, regime)
    int_dummies = pd.get_dummies(df["c_r"], prefix="inf").astype(float)
    int_dummies = int_dummies.mul(df["inflation_monthly"].astype(float).values, axis=0)

    country_d = pd.get_dummies(df["country"], prefix="c", drop_first=True).astype(float)

    X = pd.concat([df[CTRL].astype(float).reset_index(drop=True),
                   int_dummies.reset_index(drop=True),
                   country_d.reset_index(drop=True)], axis=1)
    X = sm.add_constant(X)
    y = df[DEP].astype(float).reset_index(drop=True)
    groups = df["country"].astype("category").cat.codes
    res = sm.OLS(y, X).fit(cov_type="cluster", cov_kwds={"groups": groups})

    out = ["# Paper 6 v5 — Break-Augmented Pooled FE\n",
           "**Specification:** Δfx_it = α_i + Σ_s β_{i,s}·(inflation × 1{regime s}) + γ'Z_it + ε_it",
           "**Z controls:** " + ", ".join(CTRL),
           f"**N = {int(res.nobs)}, adj-R² = {res.rsquared_adj:.4f}**\n"]

    out.append("\n## Country-regime inflation pass-through coefficients\n")
    out.append("| Country | Regime | Period | β_inflation | SE | t | p | N_regime |")
    out.append("|---|---|---|---|---|---|---|---|")
    for c in sorted(BREAKS.keys()):
        brks = [pd.Timestamp(b) for b in BREAKS[c]]
        regimes = list(range(len(brks) + 1))
        bounds = [None] + brks + [None]
        for s in regimes:
            key = f"inf_{c}__r{s}"
            if key not in res.params.index:
                continue
            beta = res.params[key]
            se = res.bse[key]
            t = res.tvalues[key]
            p = res.pvalues[key]
            lo = bounds[s].strftime("%Y-%m") if bounds[s] is not None else "start"
            hi = (bounds[s + 1] - pd.Timedelta(days=1)).strftime("%Y-%m") if bounds[s + 1] is not None else "end"
            n_r = int(((df["country"] == c) & (df["regime"] == s)).sum())
            star = "***" if p < 0.01 else ("**" if p < 0.05 else ("*" if p < 0.10 else ""))
            out.append(f"| {c} | r{s} | {lo} → {hi} | {beta:+.4f}{star} | {se:.4f} | {t:+.2f} | {p:.3f} | {n_r} |")

    out.append("\n## Global controls\n")
    out.append("| Variable | β | SE | t | p |")
    out.append("|---|---|---|---|---|")
    for v in CTRL:
        if v in res.params.index:
            star = "***" if res.pvalues[v] < 0.01 else ("**" if res.pvalues[v] < 0.05 else ("*" if res.pvalues[v] < 0.10 else ""))
            out.append(f"| {v} | {res.params[v]:+.4f}{star} | {res.bse[v]:.4f} | {res.tvalues[v]:+.2f} | {res.pvalues[v]:.3f} |")

    OUT.write_text("\n".join(out) + "\n")
    print(f"[bp_aug] yazıldı: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
