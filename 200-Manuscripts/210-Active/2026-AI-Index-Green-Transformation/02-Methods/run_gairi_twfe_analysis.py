#!/usr/bin/env python3
"""
run_gairi_twfe_analysis.py — Oxford GAIRI × Green Transformation TWFE + bootstrap.

Data:
  master  : 400-Data/Global-Panels/Clean/panel_master_v1.csv
  GAIRI   : 03-Data/ai_indices/oxford_gairi_panel.csv  (built by build_oxford_gairi_panel.py)

Specifications:
  M1 TWFE baseline:   ln_DEP ~ ai_readiness + ln_gdp + controls + cFE + yFE
  M2 TWFE EKC int:    M1 + ai_readiness × ln_gdp  (EKC channel: does AI shift turning pt?)
  M3 Income-group:    M1 separately for high vs low-income countries

Outcomes: ln_ecological_footprint, ln_carbon_intensity_gdp, renewable_energy
Controls: trade_openness, urbanization, fdi, eci

Output:
  03-Data/ai_results/gairi_twfe_results.csv
  03-Data/ai_results/gairi_twfe_summary.md
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path

ROOT   = Path(__file__).resolve().parents[1]
MASTER = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/"
              "Akademik_Arastirma/400-Data/Global-Panels/Clean/panel_master_v1.csv")
GAIRI  = ROOT / "03-Data" / "ai_indices" / "oxford_gairi_panel.csv"
OUT    = ROOT / "03-Data" / "ai_results"
OUT.mkdir(parents=True, exist_ok=True)

OUTCOMES = {
    "ln_ecological_footprint" : "Ecological Footprint (log)",
    "ln_carbon_intensity_gdp" : "Carbon Intensity/GDP (log)",
    "renewable_energy"        : "Renewable Energy Share (%)",
}
CONTROLS = ["trade_openness", "urbanization", "fdi", "eci"]
AI_VAR   = "ai_readiness"
RNG      = np.random.default_rng(20260408)
WEBB_W   = np.array([-np.sqrt(1.5), -1.0, -np.sqrt(0.5),
                      np.sqrt(0.5),  1.0,  np.sqrt(1.5)])


# ─────────────────────────────────────────────────────────────────────────────

def load_panel():
    master = pd.read_csv(MASTER)
    master = master[master["year"].between(2019, 2025)].copy()

    for v in ["gdp_per_capita", "ecological_footprint", "carbon_intensity_gdp"]:
        if v in master.columns:
            master[f"ln_{v}"] = np.log(master[v].replace({0: np.nan}))

    gairi = pd.read_csv(GAIRI)
    gairi[AI_VAR] = gairi[AI_VAR] / 100          # normalise to [0,1] range
    gairi[f"ln_{AI_VAR}"] = np.log(gairi[AI_VAR].replace({0: np.nan}))

    iso_col = "iso3" if "iso3" in master.columns else "country_code"
    panel = master.merge(gairi, left_on=[iso_col, "year"],
                         right_on=["iso3", "year"], how="inner")
    print(f"[merge] {len(panel)} obs, {panel[iso_col].nunique()} countries, "
          f"years {panel['year'].min()}-{panel['year'].max()}")
    return panel, iso_col


def twfe_fit(df: pd.DataFrame, dep: str, regressors: list[str],
             iso_col: str, label: str) -> pd.DataFrame:
    """TWFE with country + year FE, cluster-robust SE by country."""
    needed = [dep] + regressors + [iso_col, "year"]
    d = df.dropna(subset=needed).copy().reset_index(drop=True)
    if len(d) < 30 or d[iso_col].nunique() < 5:
        print(f"  [{label}] skipped — N={len(d)}, countries={d[iso_col].nunique()}")
        return pd.DataFrame()

    c_dum = pd.get_dummies(d[iso_col], prefix="c", drop_first=True).astype(float)
    y_dum = pd.get_dummies(d["year"],  prefix="y", drop_first=True).astype(float)
    X = sm.add_constant(
        pd.concat([d[regressors].reset_index(drop=True),
                   c_dum.reset_index(drop=True),
                   y_dum.reset_index(drop=True)], axis=1)
    )
    y      = d[dep].astype(float)
    groups = d[iso_col].astype("category").cat.codes
    res    = sm.OLS(y, X).fit(cov_type="cluster", cov_kwds={"groups": groups})

    rows = []
    for r in regressors:
        if r in res.params.index:
            p = res.pvalues[r]
            rows.append({
                "model": label, "outcome": dep, "variable": r,
                "coef":  round(res.params[r], 5),
                "se_cr": round(res.bse[r],    5),
                "t":     round(res.tvalues[r], 3),
                "p":     round(p, 4),
                "sig":   "***" if p<0.01 else "**" if p<0.05 else "*" if p<0.10 else "",
                "N":     len(d), "N_c": d[iso_col].nunique(),
                "R2_within": round(res.rsquared, 4),
            })
    print(f"  [{label}] {dep[:25]:25s}  N={len(d)}, countries={d[iso_col].nunique()}")
    for r in rows:
        if AI_VAR in r["variable"]:
            print(f"    {r['variable']:35s} β={r['coef']:+.4f}  p={r['p']:.3f} {r['sig']}")
    return pd.DataFrame(rows)


def webb_bootstrap(df: pd.DataFrame, dep: str, regressors: list[str],
                   iso_col: str, target: list[str], B: int = 499) -> pd.DataFrame:
    """Webb wild cluster bootstrap for small-N subsamples."""
    needed = [dep] + regressors + [iso_col, "year"]
    d = df.dropna(subset=needed).copy().reset_index(drop=True)
    if len(d) < 20:
        return pd.DataFrame()
    countries = sorted(d[iso_col].unique())
    N_c = len(countries)

    c_dum = pd.get_dummies(d[iso_col], prefix="c", drop_first=True).astype(float)
    y_dum = pd.get_dummies(d["year"],  prefix="y", drop_first=True).astype(float)
    X = sm.add_constant(
        pd.concat([d[regressors].reset_index(drop=True),
                   c_dum.reset_index(drop=True),
                   y_dum.reset_index(drop=True)], axis=1)
    ).values
    y    = d[dep].astype(float).values
    ctry = d[iso_col].values
    x_names = list(sm.add_constant(
        pd.concat([d[regressors].reset_index(drop=True),
                   c_dum.reset_index(drop=True),
                   y_dum.reset_index(drop=True)], axis=1)
    ).columns)
    t_idx = {v: x_names.index(v) for v in target if v in x_names}
    if not t_idx:
        return pd.DataFrame()

    beta_hat, *_ = np.linalg.lstsq(X, y, rcond=None)
    resid = y - X @ beta_hat
    boot  = np.full((B, len(t_idx)), np.nan)
    for b in range(B):
        w_map = {c: RNG.choice(WEBB_W) for c in countries}
        w_vec = np.array([w_map[c] for c in ctry])
        y_s   = X @ beta_hat + resid * w_vec
        b_hat, *_ = np.linalg.lstsq(X, y_s, rcond=None)
        for j, v in enumerate(t_idx):
            boot[b, j] = b_hat[t_idx[v]]

    rows = []
    for j, v in enumerate(t_idx):
        b0   = beta_hat[t_idx[v]]
        dist = boot[:, j] - b0
        p_wb = np.mean(np.abs(boot[:, j] - b0) >= np.abs(b0))
        lo = b0 + np.percentile(dist, 2.5)
        hi = b0 + np.percentile(dist, 97.5)
        rows.append({
            "outcome": dep, "variable": v,
            "coef": round(b0, 5), "ci_lo_95": round(lo, 5), "ci_hi_95": round(hi, 5),
            "p_webb": round(p_wb, 4),
            "sig_webb": "***" if p_wb<0.01 else "**" if p_wb<0.05 else "*" if p_wb<0.10 else "",
            "N_c": N_c, "B": B,
        })
    return pd.DataFrame(rows)


# ─────────────────────────────────────────────────────────────────────────────

def main():
    panel, iso_col = load_panel()

    # Descriptive check for AI readiness
    print(f"\n[GAIRI] Score range: {panel[AI_VAR].min():.3f} – {panel[AI_VAR].max():.3f} (normalised 0-1)")
    print(panel.groupby("year")[AI_VAR].agg(["mean","std","count"]).round(3))

    all_twfe, all_webb = [], []
    base_regs = ["ln_gdp_per_capita"] + CONTROLS + [AI_VAR]
    ekc_regs  = base_regs + [f"{AI_VAR}_x_gdp"]
    panel[f"{AI_VAR}_x_gdp"] = panel[AI_VAR] * panel["ln_gdp_per_capita"]

    print("\n─── M1: TWFE Baseline ───")
    for dep in OUTCOMES:
        all_twfe.append(twfe_fit(panel, dep, base_regs, iso_col, "M1_baseline"))

    print("\n─── M2: TWFE + AI×GDP (EKC channel) ───")
    for dep in OUTCOMES:
        all_twfe.append(twfe_fit(panel, dep, ekc_regs, iso_col, "M2_ekc_interact"))

    # Income-group subsamples
    if "income_group" in panel.columns:
        print("\n─── M3: Income subsamples ───")
        for grp in ["High income", "Low income", "Lower middle income", "Upper middle income"]:
            sub = panel[panel["income_group"] == grp]
            if sub[iso_col].nunique() >= 5:
                for dep in OUTCOMES:
                    all_twfe.append(twfe_fit(sub, dep, base_regs, iso_col,
                                             f"M3_{grp[:3].strip()}"))

    # Webb bootstrap for full sample (cluster by country)
    print("\n─── Webb Bootstrap (B=499, full sample) ───")
    for dep in OUTCOMES:
        wb = webb_bootstrap(panel, dep, base_regs, iso_col,
                            [AI_VAR, "ln_gdp_per_capita"])
        if len(wb) > 0:
            all_webb.append(wb)
            for _, row in wb[wb["variable"]==AI_VAR].iterrows():
                print(f"  {dep[:30]:30s}  β={row.coef:+.4f}  "
                      f"p_webb={row.p_webb:.3f}{row.sig_webb}  "
                      f"CI=[{row.ci_lo_95:+.4f},{row.ci_hi_95:+.4f}]")

    # ── Save ──────────────────────────────────────────────────────────────────
    twfe_df = pd.concat([d for d in all_twfe if len(d) > 0], ignore_index=True)
    twfe_df.to_csv(OUT / "gairi_twfe_results.csv", index=False)
    print(f"\nSaved: {OUT / 'gairi_twfe_results.csv'}")

    if all_webb:
        webb_df = pd.concat(all_webb, ignore_index=True)
        webb_df.to_csv(OUT / "gairi_webb_bootstrap.csv", index=False)
        print(f"Saved: {OUT / 'gairi_webb_bootstrap.csv'}")

    # ── Markdown summary ──────────────────────────────────────────────────────
    lines = [
        "# Oxford GAIRI × Green Transformation — TWFE Results",
        "",
        f"**Sample**: {panel['year'].min()}-{panel['year'].max()} | "
        f"N_obs={len(panel)}, N_countries={panel[iso_col].nunique()}",
        "**Treatment**: Oxford Government AI Readiness Index (GAIRI, normalised 0-1)",
        "**Estimator**: TWFE (country + year FE, cluster-robust SE by country)",
        "",
        "## M1 — Baseline TWFE (key AI coefficient)",
        "",
        "| Outcome | β(AI readiness) | SE | p | Sig |",
        "|---|---|---|---|---|",
    ]
    m1 = twfe_df[(twfe_df["model"]=="M1_baseline") & (twfe_df["variable"]==AI_VAR)]
    for _, r in m1.iterrows():
        lines.append(f"| {OUTCOMES.get(r.outcome, r.outcome)} | {r.coef:+.4f} | "
                     f"{r.se_cr:.4f} | {r.p:.3f} | {r.sig} |")

    lines += ["", "## M2 — TWFE + AI×GDP Interaction (EKC channel)", "",
              "| Outcome | β(AI) | β(AI×GDP) | p(AI) | p(AI×GDP) |",
              "|---|---|---|---|---|"]
    m2 = twfe_df[twfe_df["model"]=="M2_ekc_interact"]
    for dep in OUTCOMES:
        sub = m2[m2["outcome"]==dep]
        ai_row  = sub[sub["variable"]==AI_VAR]
        int_row = sub[sub["variable"]==f"{AI_VAR}_x_gdp"]
        if len(ai_row) and len(int_row):
            lines.append(
                f"| {OUTCOMES[dep]} | {ai_row.iloc[0].coef:+.4f} | "
                f"{int_row.iloc[0].coef:+.4f} | {ai_row.iloc[0].p:.3f} | "
                f"{int_row.iloc[0].p:.3f} |"
            )

    if all_webb:
        lines += ["", "## Webb Bootstrap (B=499)", "",
                  "| Outcome | β(AI readiness) | CI 95% | p_Webb | Sig |",
                  "|---|---|---|---|---|"]
        for _, r in webb_df[webb_df["variable"]==AI_VAR].iterrows():
            lines.append(
                f"| {OUTCOMES.get(r.outcome, r.outcome)} | {r.coef:+.4f} | "
                f"[{r.ci_lo_95:+.4f}, {r.ci_hi_95:+.4f}] | {r.p_webb:.3f} | {r.sig_webb} |"
            )

    lines += ["", "---",
              "*Significance: \\*\\*\\* p<0.01, \\*\\* p<0.05, \\* p<0.10 (cluster-robust or Webb)*"]

    (OUT / "gairi_twfe_summary.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Saved: {OUT / 'gairi_twfe_summary.md'}")
    print("\n" + "\n".join(lines[:40]))


if __name__ == "__main__":
    main()
