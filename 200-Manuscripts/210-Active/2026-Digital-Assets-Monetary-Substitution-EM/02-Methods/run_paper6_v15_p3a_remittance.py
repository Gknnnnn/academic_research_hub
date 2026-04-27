#!/usr/bin/env python3
"""
run_paper6_v15_p3a_remittance.py — P3a: Remittance/GDP control robustness
2026-04-09

Test whether the crypto-premium safety-valve finding survives when
remittances/GDP (BX.TRF.PWKR.DT.GD.ZS) is added as a control.

Motivation (referee P3a): In high-remittance EM countries (India, Mexico, Nigeria),
foreign-currency inflows from diaspora may partially absorb FX pressure
independently of crypto, confounding the crypto-premium coefficient.

Argentina note: WB indicator BX.TRF.PWKR.DT.GD.ZS unavailable for ARG.
We set ARG remittances = 0 (defensible: ARG documented remittances ~0.1-0.2%
GDP, lowest in sample; treating as 0 biases the control downward for ARG
but does not affect the primary identification which is cross-country).

Outputs:
  03-Results/paper6_v15_p3a_remittance.csv
  03-Results/paper6_v15_p3a_remittance.md
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path

ROOT    = Path(__file__).resolve().parents[1]
PANEL   = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v15_p3a_remittance.csv"
OUT_MD  = ROOT / "03-Results" / "paper6_v15_p3a_remittance.md"

RNG  = np.random.default_rng(20260409)
B    = 999
WEBB = np.array([-np.sqrt(3/2), -1.0, -np.sqrt(1/2),
                  np.sqrt(1/2),  1.0,  np.sqrt(3/2)])
DEP  = "fx_depreciation"
MACRO = ["global_dollar_change", "inflation_monthly",
         "broad_money_instability", "reserve_adequacy_change"]

# WB BX.TRF.PWKR.DT.GD.ZS — remittances received % GDP (annual)
# Values sourced from wbgapi fetch 2026-04-09
# Argentina: unavailable → set to 0 (near-zero historically ~0.1-0.2% GDP)
REMIT_DATA = {
    "Argentina":   {y: 0.0 for y in range(1995, 2025)},
    "Brazil":      {1995: 0.384, 1996: 0.242, 1997: 0.200, 1998: 0.178,
                    1999: 0.170, 2000: 0.208, 2001: 0.233, 2002: 0.274,
                    2003: 0.280, 2004: 0.272, 2005: 0.267, 2006: 0.268,
                    2007: 0.253, 2008: 0.199, 2009: 0.180, 2010: 0.167,
                    2011: 0.155, 2012: 0.153, 2013: 0.150, 2014: 0.156,
                    2015: 0.173, 2016: 0.197, 2017: 0.193, 2018: 0.184,
                    2019: 0.198, 2020: 0.226, 2021: 0.247, 2022: 0.255,
                    2023: 0.202, 2024: 0.224},
    "India":       {1995: 1.727, 1996: 2.231, 1997: 2.427, 1998: 2.548,
                    1999: 2.659, 2000: 2.747, 2001: 2.965, 2002: 3.140,
                    2003: 3.001, 2004: 2.774, 2005: 2.832, 2006: 2.932,
                    2007: 3.184, 2008: 3.734, 2009: 3.600, 2010: 3.168,
                    2011: 3.298, 2012: 3.687, 2013: 3.630, 2014: 3.375,
                    2015: 3.258, 2016: 2.863, 2017: 2.688, 2018: 2.932,
                    2019: 3.375, 2020: 3.139, 2021: 3.079, 2022: 3.324,
                    2023: 3.285, 2024: 3.521},
    "Mexico":      {1995: 1.149, 1996: 1.145, 1997: 1.220, 1998: 1.305,
                    1999: 1.390, 2000: 1.495, 2001: 1.806, 2002: 2.165,
                    2003: 2.345, 2004: 2.626, 2005: 2.688, 2006: 2.735,
                    2007: 2.573, 2008: 2.366, 2009: 2.272, 2010: 2.106,
                    2011: 1.956, 2012: 1.980, 2013: 1.999, 2014: 2.069,
                    2015: 2.350, 2016: 2.688, 2017: 2.766, 2018: 2.938,
                    2019: 3.281, 2020: 3.864, 2021: 3.889, 2022: 4.190,
                    2023: 3.683, 2024: 3.644},
    "Nigeria":     {1995: 0.177, 1996: 0.160, 1997: 0.125, 1998: 0.146,
                    1999: 0.350, 2000: 0.506, 2001: 0.612, 2002: 0.798,
                    2003: 0.903, 2004: 1.003, 2005: 1.034, 2006: 1.032,
                    2007: 1.056, 2008: 0.848, 2009: 0.905, 2010: 0.773,
                    2011: 0.851, 2012: 0.893, 2013: 1.035, 2014: 1.025,
                    2015: 1.184, 2016: 1.423, 2017: 1.300, 2018: 1.212,
                    2019: 1.209, 2020: 1.438, 2021: 2.031, 2022: 3.111,
                    2023: 4.011, 2024: 8.441},
    "South Africa":{1995: 0.048, 1996: 0.046, 1997: 0.042, 1998: 0.046,
                    1999: 0.043, 2000: 0.045, 2001: 0.052, 2002: 0.063,
                    2003: 0.072, 2004: 0.082, 2005: 0.095, 2006: 0.103,
                    2007: 0.114, 2008: 0.112, 2009: 0.112, 2010: 0.104,
                    2011: 0.112, 2012: 0.120, 2013: 0.128, 2014: 0.140,
                    2015: 0.158, 2016: 0.172, 2017: 0.175, 2018: 0.181,
                    2019: 0.196, 2020: 0.202, 2021: 0.208, 2022: 0.214,
                    2023: 0.211, 2024: 0.213},
}


def build_remit_df() -> pd.DataFrame:
    rows = []
    for country, ymap in REMIT_DATA.items():
        for year, val in ymap.items():
            rows.append({"country": country, "year": year,
                         "remit_gdp": val / 100.0})  # convert % → decimal
    return pd.DataFrame(rows)


def winsorise(s, lo=0.05, hi=0.95):
    return s.clip(s.quantile(lo), s.quantile(hi))


def webb_ols(df: pd.DataFrame, regressors: list[str], label: str) -> list[dict]:
    needed = [DEP] + regressors + ["country"]
    d = df.dropna(subset=needed).copy()
    fe = pd.get_dummies(d["country"], prefix="c", drop_first=True).astype(float)
    d = pd.concat([d.reset_index(drop=True), fe.reset_index(drop=True)], axis=1)
    all_x = regressors + list(fe.columns)

    countries = sorted(d["country"].unique())
    N_c = len(countries)
    print(f"  [{label}] N_obs={len(d)}, N_clust={N_c}, B={B}")
    if len(d) < 10 or N_c < 2:
        return []

    X = sm.add_constant(d[all_x].astype(float)).values
    y = d[DEP].astype(float).values
    ctry = d["country"].values
    x_names = ["const"] + all_x
    tgt = {r: x_names.index(r) for r in regressors if r in x_names}

    beta, *_ = np.linalg.lstsq(X, y, rcond=None)
    resid = y - X @ beta

    boot = np.full((B, len(tgt)), np.nan)
    for b in range(B):
        wm = {c: RNG.choice(WEBB) for c in countries}
        wv = np.array([wm[c] for c in ctry])
        ys = X @ beta + resid * wv
        bb, *_ = np.linalg.lstsq(X, ys, rcond=None)
        for j, r in enumerate(tgt):
            boot[b, j] = bb[tgt[r]]

    results = []
    for j, r in enumerate(tgt):
        b0 = beta[tgt[r]]
        p  = float(np.mean(np.abs(boot[:, j] - b0) >= np.abs(b0)))
        dist = boot[:, j] - b0
        lo_ci = b0 + float(np.percentile(dist, 2.5))
        hi_ci = b0 + float(np.percentile(dist, 97.5))
        XtX_inv = np.linalg.pinv(X.T @ X)
        meat = sum(
            X[ctry == c].T @ np.outer(resid[ctry == c], resid[ctry == c]) @ X[ctry == c]
            for c in countries
        )
        V = XtX_inv @ meat @ XtX_inv
        se = float(np.sqrt(max(V[tgt[r], tgt[r]], 0)))
        t  = b0 / se if se > 0 else np.nan
        sig = "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""
        print(f"    {r:40s}  β={b0:+.5f}  p={p:.3f}{sig}  [{lo_ci:+.5f},{hi_ci:+.5f}]")
        results.append(dict(
            model=label, variable=r, coef=round(b0, 6),
            se_cr=round(se, 6), t_cr=round(t, 3),
            ci_lo=round(lo_ci, 6), ci_hi=round(hi_ci, 6),
            p_webb=round(p, 4), sig=sig,
            N_obs=len(d), N_clust=N_c, B=B,
        ))
    return results


def main():
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    df["year"] = df["DATE"].dt.year

    # Winsorise dep var by country
    df[DEP] = df.groupby("country")[DEP].transform(
        lambda s: s.clip(s.quantile(0.05), s.quantile(0.95)))

    # Merge remittances
    remit = build_remit_df()
    df = df.merge(remit, on=["country", "year"], how="left")
    df["remit_gdp"] = df["remit_gdp"].fillna(0.0)  # ARG already 0; any stray NA → 0

    print(f"Panel: N={len(df)}, countries={sorted(df['country'].unique())}")
    print(f"Remit merge: {df['remit_gdp'].isna().sum()} NAs after fill")

    all_results: list[dict] = []

    # ── M_crypto baseline (no remittances) ────────────────────────────────────
    print("\n[P3a-0] M_crypto baseline (no remittance control)")
    crypto_df = df.dropna(subset=["crypto_premium"]).copy()
    all_results += webb_ols(crypto_df, MACRO + ["crypto_premium"], "M_crypto_base")

    # ── M_crypto + remittances ─────────────────────────────────────────────────
    print("\n[P3a-1] M_crypto + remit_gdp control")
    all_results += webb_ols(crypto_df, MACRO + ["crypto_premium", "remit_gdp"],
                            "M_crypto_remit")

    # ── Interaction: crypto_premium × remit_gdp ────────────────────────────────
    print("\n[P3a-2] M_crypto × remit interaction (does high-remittance absorb?)")
    crypto_df["crypto_x_remit"] = crypto_df["crypto_premium"] * crypto_df["remit_gdp"]
    all_results += webb_ols(crypto_df,
                            MACRO + ["crypto_premium", "remit_gdp", "crypto_x_remit"],
                            "M_crypto_remit_interact")

    # ── SAVE ──────────────────────────────────────────────────────────────────
    out = pd.DataFrame(all_results)
    out.to_csv(OUT_CSV, index=False)
    print(f"\n[done] {OUT_CSV.name}")

    lines = [
        "# P6 v15 — P3a: Remittance/GDP Control Robustness — 2026-04-09",
        "",
        "**Motivation**: High-remittance countries (India, Mexico, Nigeria) receive",
        "foreign-currency inflows that may absorb FX pressure independently of crypto.",
        "Adding remittances/GDP as a control tests whether the crypto-premium finding",
        "is confounded by diaspora FX inflows.",
        "",
        "**Data**: WB BX.TRF.PWKR.DT.GD.ZS (% GDP, annual), wbgapi fetch 2026-04-09.",
        "Argentina: unavailable from WB → treated as 0 (historically ~0.1-0.2% GDP,",
        "lowest in sample).",
        "",
        "| Country | Remit/GDP 2022 | Role |",
        "|---|---|---|",
        "| Mexico | 4.19% | Primary identification (open capital account) |",
        "| India | 3.32% | Large diaspora, moderate capital controls |",
        "| Nigeria | 3.11% | Rising remittances 2020-2024 |",
        "| Brazil | 0.26% | Low remittances |",
        "| South Africa | 0.21% | Near-zero |",
        "| Argentina | ~0% (WB NA → 0) | Capital controls, near-zero official remittances |",
        "",
    ]

    for model in out["model"].unique():
        sub = out[out["model"] == model]
        n_obs  = sub["N_obs"].iloc[0]
        n_clst = sub["N_clust"].iloc[0]
        lines += [f"## {model} (N={n_obs}, N_cl={n_clst})",
                  "",
                  "| Variable | β | p_Webb | CI 95% | Sig |",
                  "|---|---|---|---|---|"]
        for _, row in sub.iterrows():
            lines.append(
                f"| {row['variable']} | {row['coef']:+.5f} "
                f"| {row['p_webb']:.3f} "
                f"| [{row['ci_lo']:+.5f}, {row['ci_hi']:+.5f}] "
                f"| {row['sig']} |"
            )
        lines.append("")

    lines += [
        "## Interpretation",
        "",
        "- If crypto_premium **retains sign and significance** with remit_gdp added:",
        "  remittance confound ruled out; result is robust.",
        "- If crypto_x_remit **significant and negative**: high-remittance countries",
        "  show stronger absorption (complementarity hypothesis).",
        "- If crypto_x_remit **positive** or NS: crypto premium operates independently",
        "  of diaspora channel.",
    ]

    OUT_MD.write_text("\n".join(lines))
    print(f"[done] {OUT_MD.name}")


if __name__ == "__main__":
    main()
