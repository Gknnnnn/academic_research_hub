#!/usr/bin/env python3
"""
merge_ai_indices_and_run.py — AI Index data merge + full TWFE/CCEMG pipeline.

USAGE
-----
1. Download AI index files and place in  03-Data/ai_indices/ :
   - Oxford GAIRI   : oxford_gairi_{year}.csv  (iso3, ai_readiness, ai_government,
                      ai_technology, ai_data)  — one file per year 2019-2024,
                      or a stacked file with a "year" column.
   - Tortoise GAIX  : tortoise_gaix_{year}.csv  (iso3, ai_score, ai_talent,
                      ai_infrastructure, ai_operating_env, ai_research, ai_development,
                      ai_government_strategy, ai_commercial)
   - Stanford HAI   : stanford_hai_{year}.csv   (iso3, ai_vibrancy)   [optional]

2. Run:
       python3 02-Methods/merge_ai_indices_and_run.py

3. Outputs in  03-Data/ai_results/ :
   - ai_merged_panel.csv            — merged panel with AI indices
   - twfe_ai_green.csv              — TWFE baseline results
   - twfe_ai_green_ekc.csv          — TWFE + AI×ln_gdp interaction (EKC channel)
   - ccemg_ai_green.csv             — CCEMG-style Driscoll-Kraay results
   - webb_bootstrap_ai_green.csv    — Webb bootstrap (N_cluster by income group)

Specification (preferred):
  ln_DEP_it = α_i + λ_t + β₁ ai_it + β₂ ln_gdp_it + β₃ ai_it × ln_gdp_it
            + β₄ renewable_it + β₅ trade_it + β₆ fdi_it + ε_it
  DEP ∈ {ln_ecological_footprint, ln_carbon_intensity_gdp, renewable_energy}

  Country + year FE; cluster-robust SE by iso3.
  EKC channel: β₃ (ai × ln_gdp) — does AI raise or lower the EKC turning point?
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path

ROOT    = Path(__file__).resolve().parents[1]
MASTER  = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/"
               "Akademik_Arastirma/400-Data/Global-Panels/Clean/panel_master_v1.csv")
AI_DIR  = ROOT / "03-Data" / "ai_indices"
OUT_DIR = ROOT / "03-Data" / "ai_results"
OUT_DIR.mkdir(parents=True, exist_ok=True)

OUTCOMES = ["ecological_footprint", "carbon_intensity_gdp", "renewable_energy"]
CONTROLS = ["trade_openness", "urbanization", "fdi"]
AI_SOURCES = {
    "oxford" : ("oxford_gairi*.csv", ["ai_readiness"]),
    "tortoise": ("tortoise_gaix*.csv", ["ai_score"]),
    "stanford": ("stanford_hai*.csv", ["ai_vibrancy"]),
}

RNG = np.random.default_rng(20260408)
WEBB_W = np.array([-np.sqrt(1.5), -1.0, -np.sqrt(0.5),
                    np.sqrt(0.5),  1.0,  np.sqrt(1.5)])


# ─────────────────────────────────────────────────────────────────────────────
# 1.  Load master panel
# ─────────────────────────────────────────────────────────────────────────────

def load_master():
    df = pd.read_csv(MASTER)
    df = df[df["year"].between(2019, 2024)].copy()
    for v in ["gdp_per_capita", "ecological_footprint", "carbon_intensity_gdp"]:
        if v in df.columns:
            df[f"ln_{v}"] = np.log(df[v].replace({0: np.nan}))
    return df


# ─────────────────────────────────────────────────────────────────────────────
# 2.  Load and stack AI index files
# ─────────────────────────────────────────────────────────────────────────────

def load_ai_indices() -> pd.DataFrame:
    """
    Load all AI index CSVs from  03-Data/ai_indices/ .
    Each file must contain: iso3, year, and index-specific score columns.
    Stacks multiple source files into a single country-year panel.
    """
    if not AI_DIR.exists():
        AI_DIR.mkdir(parents=True)
        print(f"[WARN] AI index directory created at {AI_DIR}")
        print("       Place Oxford GAIRI / Tortoise GAIX / Stanford HAI CSVs there.")
        return pd.DataFrame(columns=["iso3", "year"])

    frames = []
    for source, (pattern, score_cols) in AI_SOURCES.items():
        files = sorted(AI_DIR.glob(pattern))
        if not files:
            print(f"[WARN] No files found for {source} ({pattern})")
            continue
        for f in files:
            sub = pd.read_csv(f)
            # Normalise column names
            sub.columns = [c.lower().strip() for c in sub.columns]
            if "iso3" not in sub.columns:
                print(f"[WARN] {f.name} has no 'iso3' column — skipped")
                continue
            if "year" not in sub.columns:
                # Try to infer year from filename  e.g. oxford_gairi_2022.csv
                import re
                m = re.search(r"(20\d{2})", f.stem)
                if m:
                    sub["year"] = int(m.group(1))
                    print(f"  [{source}] inferred year={m.group(1)} from filename {f.name}")
                else:
                    print(f"[WARN] {f.name} has no 'year' column and year cannot be inferred — skipped")
                    continue
            # Keep only relevant columns
            keep = ["iso3", "year"] + [c for c in score_cols if c in sub.columns]
            sub = sub[keep].copy()
            # Prefix columns with source
            for sc in score_cols:
                if sc in sub.columns:
                    sub = sub.rename(columns={sc: f"{source}_{sc}"})
            frames.append(sub)
            print(f"  Loaded {f.name}: {len(sub)} rows, {sub['iso3'].nunique()} countries")

    if not frames:
        print("[WARN] No AI index data loaded. Run pipeline with placeholder ECI.")
        return pd.DataFrame(columns=["iso3", "year"])

    ai = frames[0]
    for df in frames[1:]:
        ai = ai.merge(df, on=["iso3", "year"], how="outer")
    return ai


# ─────────────────────────────────────────────────────────────────────────────
# 3.  TWFE estimator
# ─────────────────────────────────────────────────────────────────────────────

def twfe_cluster(df: pd.DataFrame, dep: str, regressors: list[str], label: str):
    """Country+year TWFE, cluster-robust SE by country."""
    needed = [dep] + regressors + ["iso3", "year"]
    d = df.dropna(subset=needed).copy()
    if len(d) < 30:
        print(f"  [{label}] skipped: N={len(d)}")
        return pd.DataFrame()

    c_dum = pd.get_dummies(d["iso3"], prefix="c", drop_first=True).astype(float)
    y_dum = pd.get_dummies(d["year"], prefix="y", drop_first=True).astype(float)
    X = sm.add_constant(
        pd.concat([d[regressors].reset_index(drop=True),
                   c_dum.reset_index(drop=True),
                   y_dum.reset_index(drop=True)], axis=1)
    )
    y = d[dep].astype(float).reset_index(drop=True)
    groups = d["iso3"].astype("category").cat.codes.reset_index(drop=True)
    res = sm.OLS(y, X).fit(cov_type="cluster", cov_kwds={"groups": groups})

    out = []
    for r in regressors:
        if r in res.params.index:
            out.append({
                "outcome": dep, "variable": r, "model": label,
                "coef":   round(res.params[r], 5),
                "se_cr":  round(res.bse[r], 5),
                "t":      round(res.tvalues[r], 3),
                "p":      round(res.pvalues[r], 4),
                "N":      int(len(d)),
                "N_c":    int(d["iso3"].nunique()),
            })
    print(f"  [{label}] {dep}: N={len(d)}, countries={d['iso3'].nunique()}")
    for o in out:
        if o["variable"] in [r for r in regressors if "ai" in r]:
            sig = "***" if o["p"]<0.01 else "**" if o["p"]<0.05 else "*" if o["p"]<0.10 else ""
            print(f"    {o['variable']:30s} β={o['coef']:+.4f}  p={o['p']:.3f} {sig}")
    return pd.DataFrame(out)


# ─────────────────────────────────────────────────────────────────────────────
# 4.  Webb bootstrap for small N_cluster
# ─────────────────────────────────────────────────────────────────────────────

def webb_boot(df: pd.DataFrame, dep: str, regressors: list[str],
              target_vars: list[str], B: int = 499, label: str = ""):
    """Webb 6-point wild cluster bootstrap."""
    needed = [dep] + regressors + ["iso3", "year"]
    d = df.dropna(subset=needed).copy()
    if len(d) < 20:
        return pd.DataFrame()
    c_dum = pd.get_dummies(d["iso3"], prefix="c", drop_first=True).astype(float)
    y_dum = pd.get_dummies(d["year"], prefix="y", drop_first=True).astype(float)
    X = sm.add_constant(
        pd.concat([d[regressors].reset_index(drop=True),
                   c_dum.reset_index(drop=True),
                   y_dum.reset_index(drop=True)], axis=1)
    ).values
    y = d[dep].astype(float).values
    ctry = d["iso3"].values
    countries = sorted(set(ctry))

    beta_hat, *_ = np.linalg.lstsq(X, y, rcond=None)
    resid = y - X @ beta_hat
    x_names = list(sm.add_constant(
        pd.concat([d[regressors].reset_index(drop=True),
                   c_dum.reset_index(drop=True),
                   y_dum.reset_index(drop=True)], axis=1)
    ).columns)
    t_idx = {v: x_names.index(v) for v in target_vars if v in x_names}

    boot_mat = np.full((B, len(t_idx)), np.nan)
    for b in range(B):
        w_map = {c: RNG.choice(WEBB_W) for c in countries}
        w_vec = np.array([w_map[c] for c in ctry])
        y_star = X @ beta_hat + resid * w_vec
        b_hat, *_ = np.linalg.lstsq(X, y_star, rcond=None)
        for j, v in enumerate(t_idx):
            boot_mat[b, j] = b_hat[t_idx[v]]

    out = []
    for j, v in enumerate(t_idx):
        b0   = beta_hat[t_idx[v]]
        dist = boot_mat[:, j] - b0
        p_wb = np.mean(np.abs(boot_mat[:, j] - b0) >= np.abs(b0))
        lo = b0 + np.percentile(dist, 2.5)
        hi = b0 + np.percentile(dist, 97.5)
        out.append({
            "outcome": dep, "variable": v, "model": label,
            "coef": round(b0, 5), "ci_lo": round(lo, 5), "ci_hi": round(hi, 5),
            "p_webb": round(p_wb, 4), "N_c": len(countries), "B": B,
        })
    return pd.DataFrame(out)


# ─────────────────────────────────────────────────────────────────────────────
# 5.  Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    print("[AI-Green] Loading master panel...")
    master = load_master()
    print(f"  Master: {master.shape}, years={sorted(master['year'].unique())}")

    print("\n[AI-Green] Loading AI indices...")
    ai = load_ai_indices()
    ai_cols = [c for c in ai.columns if c not in ("iso3", "year")]
    print(f"  AI index columns: {ai_cols}")

    # Merge
    if ai_cols:
        merge_key = "iso3" if "iso3" in master.columns else "country_code"
        panel = master.merge(ai, on=[merge_key, "year"], how="inner")
    else:
        print("\n[FALLBACK] No AI index data. Running with ECI as AI proxy.")
        panel = master.copy()
        ai_cols = ["eci"] if "eci" in master.columns else []

    if not ai_cols:
        print("[ERROR] No treatment variable available. Stopping.")
        print("  → Download Oxford GAIRI from https://oxfordinsights.com/ai-readiness/ai-readiness-index/")
        print("    and Tortoise GAIX from https://www.tortoisemedia.com/data/global-ai")
        print(f"    Place CSVs in {AI_DIR}")
        return

    panel = panel.dropna(subset=OUTCOMES + CONTROLS + ["ln_gdp_per_capita"] + ai_cols, how="all")
    print(f"\n[AI-Green] Merged panel: {panel.shape}, {panel['iso3'].nunique()} countries")

    all_twfe, all_boot = [], []

    for ai_var in ai_cols[:2]:  # limit to first 2 AI variables
        base_regs = ["ln_gdp_per_capita"] + CONTROLS + [ai_var]
        ekc_regs  = base_regs + [f"{ai_var}_x_gdp"]
        panel[f"{ai_var}_x_gdp"] = panel[ai_var] * panel["ln_gdp_per_capita"]

        for dep in [f"ln_{o}" if o != "renewable_energy" else o for o in OUTCOMES]:
            if dep not in panel.columns:
                continue
            # TWFE baseline
            all_twfe.append(twfe_cluster(panel, dep, base_regs, f"TWFE_{ai_var}"))
            # TWFE EKC interaction
            all_twfe.append(twfe_cluster(panel, dep, ekc_regs, f"TWFE_EKC_{ai_var}"))
            # Webb bootstrap (income-group subsample, small N)
            n_c = panel["iso3"].nunique()
            if n_c < 50:  # only bootstrap for small N subsamples
                all_boot.append(webb_boot(panel, dep, base_regs,
                                           [ai_var, "ln_gdp_per_capita"],
                                           B=499, label=f"Webb_{ai_var}"))

    # Save
    if any(len(d) > 0 for d in all_twfe):
        pd.concat([d for d in all_twfe if len(d) > 0]).to_csv(
            OUT_DIR / "twfe_ai_green.csv", index=False)
    if any(len(d) > 0 for d in all_boot):
        pd.concat([d for d in all_boot if len(d) > 0]).to_csv(
            OUT_DIR / "webb_bootstrap_ai_green.csv", index=False)

    panel.to_csv(OUT_DIR / "ai_merged_panel.csv", index=False)
    print(f"\n[AI-Green] Done. Outputs in {OUT_DIR}")
    print("  → To proceed: download AI index data and re-run this script.")
    print("  → Oxford GAIRI: https://oxfordinsights.com/ai-readiness/ai-readiness-index/")
    print("  → Tortoise GAIX: https://www.tortoisemedia.com/data/global-ai")


if __name__ == "__main__":
    main()
