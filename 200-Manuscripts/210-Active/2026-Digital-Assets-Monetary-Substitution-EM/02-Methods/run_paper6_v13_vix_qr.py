#!/usr/bin/env python3
"""
run_paper6_v13_vix_qr.py — P1 fixes from academic sparring (2026-04-09)

Two referee-level issues addressed:

  P1a — Omitted variable: VIX / global risk appetite
        Add CBOE VIX monthly close to all specifications.
        Rationale: VIX spikes drive simultaneous EM currency depreciation AND
        crypto liquidation, confounding the safety-valve interpretation of the
        crypto premium and the GCAI interaction.  Without VIX, β(crypto_premium)
        could reflect risk-off compression, not substitution.

        New models produced:
          M_base_vix     — baseline + VIX
          M_crypto_vix   — crypto premium + VIX
          M_triple_vix   — 2022-2024 triple-interaction + VIX + year FE
          M_placebo_vix  — GCAI×VIX interaction: if significant, absorber
                           result is a crypto-cycle artefact, not substitution

  P1b — Quantile regression uses wrong inference (Table 2 uses conventional
        iid bootstrap; with N=6 clusters this is severely undersized).
        Fix: rerun QR at q∈{0.25,0.50,0.75,0.90} with Webb wild cluster
        bootstrap (same 6-point weights, adapted for QR).

Output
------
  03-Results/paper6_v13_vix_qr.csv    — Webb bootstrap table (OLS + QR)
  03-Results/paper6_v13_vix_qr.md     — markdown report for manuscript update
  03-Results/paper6_em_panel_v5_vix.csv — panel with VIX merged

References
----------
  Webb (2023) CJE 56(3): 839-858
  MacKinnon & Webb (2017) JAE 32(2): 233-254
  CBOE VIX: FRED series VIXCLS (monthly close, 2000-01 to present)
"""
from __future__ import annotations
import io
import sys
import urllib.request
import numpy as np
import pandas as pd
import statsmodels.api as sm
from statsmodels.regression.quantile_regression import QuantReg
from pathlib import Path

# ─── Paths ────────────────────────────────────────────────────────────────────
ROOT    = Path(__file__).resolve().parents[1]
PANEL   = ROOT / "03-Results" / "paper6_em_panel_v5.csv"
GCAI    = ROOT / "03-Results" / "chainalysis" / "chainalysis_gcai_2020_2024.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v13_vix_qr.csv"
OUT_MD  = ROOT / "03-Results" / "paper6_v13_vix_qr.md"
PANEL_VIX = ROOT / "03-Results" / "paper6_em_panel_v5_vix.csv"

RNG  = np.random.default_rng(20260409)
B    = 999
ALPHA = 0.05

WEBB_WEIGHTS = np.array([
    -np.sqrt(3/2), -1.0, -np.sqrt(1/2),
     np.sqrt(1/2),  1.0,  np.sqrt(3/2)
])

DEP   = "fx_depreciation"
MACRO = ["global_dollar_change", "inflation_monthly",
         "broad_money_instability", "reserve_adequacy_change"]
MACRO_VIX = MACRO + ["vix"]


# ─── 1. Fetch VIX from FRED ───────────────────────────────────────────────────

def fetch_vix_fred() -> pd.Series:
    """
    Download VIXCLS from FRED as monthly data.
    Falls back to pandas_datareader if direct URL fails.
    Returns a monthly Series indexed to month-start dates.
    """
    url = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=VIXCLS"
    print("[VIX] fetching VIXCLS from FRED ...", end=" ", flush=True)
    try:
        with urllib.request.urlopen(url, timeout=15) as r:
            raw = r.read().decode()
        df = pd.read_csv(io.StringIO(raw), parse_dates=["DATE"], index_col="DATE")
        df.columns = ["vix"]
        df["vix"] = pd.to_numeric(df["vix"], errors="coerce")
        df = df.dropna()
        # Resample to month-start mean
        vix_m = df["vix"].resample("MS").mean()
        print(f"ok ({len(vix_m)} monthly obs, "
              f"{vix_m.index.min().date()} – {vix_m.index.max().date()})")
        return vix_m
    except Exception as e:
        print(f"\n[VIX] direct FRED failed ({e}), trying pandas_datareader ...")
        try:
            import pandas_datareader.data as web
            import datetime as dt
            vix = web.DataReader("VIXCLS", "fred",
                                 start=dt.date(1990, 1, 1),
                                 end=dt.date(2026, 3, 31))
            vix_m = vix["VIXCLS"].resample("MS").mean().dropna()
            print(f"ok via datareader ({len(vix_m)} monthly obs)")
            return vix_m
        except Exception as e2:
            sys.exit(f"[VIX] both fetch methods failed: {e2}")


# ─── 2. Panel preparation ─────────────────────────────────────────────────────

def load_panel_with_vix(vix_series: pd.Series) -> pd.DataFrame:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])

    # Exclude Turkey (not in paper's N=6 focus countries)
    EM6 = ["Argentina", "Brazil", "India", "Mexico", "Nigeria", "South Africa"]
    df = df[df["country"].isin(EM6)].copy()

    # Merge VIX
    vix_df = vix_series.rename("vix").reset_index().rename(columns={"DATE": "DATE"})
    df = df.merge(vix_df, on="DATE", how="left")

    # Normalise VIX to [0,1] scale for interpretability (optional: use log or raw)
    df["vix_norm"] = (df["vix"] - df["vix"].min()) / (df["vix"].max() - df["vix"].min())

    # Winsorise extreme FX observations (5th–95th by country)
    def wins(s, lo=0.05, hi=0.95):
        ql, qh = s.quantile(lo), s.quantile(hi)
        return s.clip(ql, qh)
    df[DEP] = df.groupby("country")[DEP].transform(wins)

    print(f"[panel] N={len(df)}, countries={sorted(df['country'].unique())}, "
          f"VIX missing={df['vix'].isna().sum()}")
    return df


def add_fe(df: pd.DataFrame, fe_col: str = "country",
           extra_fe_cols: list[str] | None = None) -> tuple[pd.DataFrame, list[str]]:
    dummies = pd.get_dummies(df[fe_col], prefix="c", drop_first=True).astype(float)
    out = pd.concat([df.reset_index(drop=True), dummies.reset_index(drop=True)], axis=1)
    fe_cols = list(dummies.columns)
    if extra_fe_cols:
        for col in extra_fe_cols:
            d2 = pd.get_dummies(df[col], prefix=col, drop_first=True).astype(float)
            out = pd.concat([out.reset_index(drop=True),
                             d2.reset_index(drop=True)], axis=1)
            fe_cols += list(d2.columns)
    return out, fe_cols


# ─── 3. OLS Webb bootstrap (reusable) ────────────────────────────────────────

def fit_ols(y: np.ndarray, X: np.ndarray):
    beta, *_ = np.linalg.lstsq(X, y, rcond=None)
    return beta, y - X @ beta


def webb_ols(df: pd.DataFrame, regressors: list[str], label: str,
             extra_fe_cols: list[str] | None = None) -> list[dict]:
    needed = [DEP] + regressors + ["country"]
    d = df.dropna(subset=needed).copy()
    d, fe_cols = add_fe(d, extra_fe_cols=extra_fe_cols)
    all_X = regressors + fe_cols

    countries = sorted(d["country"].unique())
    N_c = len(countries)
    if len(d) < 20 or N_c < 3:
        print(f"  [{label}] skipped (N_obs={len(d)}, N_clust={N_c})")
        return []
    print(f"  [{label}] N_obs={len(d)}, N_clust={N_c}, B={B}")

    X = sm.add_constant(d[all_X].astype(float)).values
    y = d[DEP].astype(float).values
    ctry = d["country"].values

    beta_hat, resid = fit_ols(y, X)
    x_names = ["const"] + all_X
    tgt = {r: x_names.index(r) for r in regressors if r in x_names}

    boot = np.full((B, len(tgt)), np.nan)
    for b in range(B):
        w_map = {c: RNG.choice(WEBB_WEIGHTS) for c in countries}
        w_vec = np.array([w_map[c] for c in ctry])
        y_star = X @ beta_hat + resid * w_vec
        beta_b, _ = fit_ols(y_star, X)
        for j, r in enumerate(tgt):
            boot[b, j] = beta_b[tgt[r]]

    results = []
    for j, r in enumerate(tgt):
        b0 = beta_hat[tgt[r]]
        dist = boot[:, j] - b0
        p = float(np.mean(np.abs(boot[:, j] - b0) >= np.abs(b0)))
        lo = b0 + float(np.percentile(dist, 2.5))
        hi = b0 + float(np.percentile(dist, 97.5))
        # Cluster-robust SE for reporting
        XtX_inv = np.linalg.pinv(X.T @ X)
        meat = sum(X[ctry == c].T @ np.outer(resid[ctry == c], resid[ctry == c])
                   @ X[ctry == c] for c in countries)
        V = XtX_inv @ meat @ XtX_inv
        se_cr = float(np.sqrt(max(V[tgt[r], tgt[r]], 0)))
        t_cr  = b0 / se_cr if se_cr > 0 else np.nan

        sig = "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""
        print(f"    {r:40s}  β={b0:+.4f}  p_webb={p:.3f}{sig}  CI=[{lo:+.4f},{hi:+.4f}]")
        results.append(dict(model=label, variable=r, coef=round(b0, 6),
                            se_cr=round(se_cr, 6), t_cr=round(t_cr, 3),
                            ci_lo_95=round(lo, 6), ci_hi_95=round(hi, 6),
                            p_webb=round(p, 4), sig_webb=sig,
                            N_obs=len(d), N_clust=N_c, B=B, spec="OLS"))
    return results


# ─── 4. QR Webb cluster bootstrap (P1b fix) ──────────────────────────────────

def fit_qr(y: np.ndarray, X: np.ndarray, q: float):
    """Return QR coefficients at quantile q."""
    model = QuantReg(y, X)
    res   = model.fit(q=q, max_iter=5000)
    beta  = res.params
    return beta, y - X @ beta


def webb_qr(df: pd.DataFrame, regressors: list[str], label: str,
            quantiles: list[float] = (0.25, 0.50, 0.75, 0.90)) -> list[dict]:
    """
    QR with Webb wild cluster bootstrap.
    Adapts the OLS Webb procedure for quantile regression:
      1. Fit QR at q → β̂(q), ê(q)
      2. Bootstrap: y* = Xβ̂ + ê·w_cluster  (same as OLS Webb)
      3. Refit QR on y* to get β̂*(q)
      4. p-value = P(|β̂*(q) − β̂(q)| ≥ |β̂(q)|)
    Note: restricted residuals (imposing H0: β_k=0) not used here because
    QR restricted estimation requires iterative solution; unrestricted
    residuals are standard in cluster-QR practice (Hagemann 2017, Econometrica).
    """
    needed = [DEP] + regressors + ["country"]
    d = df.dropna(subset=needed).copy()
    d, fe_cols = add_fe(d)
    all_X = regressors + fe_cols

    countries = sorted(d["country"].unique())
    N_c = len(countries)
    if len(d) < 20 or N_c < 3:
        print(f"  [{label}] skipped (N_obs={len(d)}, N_clust={N_c})")
        return []

    X = sm.add_constant(d[all_X].astype(float)).values
    y = d[DEP].astype(float).values
    ctry = d["country"].values
    x_names = ["const"] + all_X
    tgt = {r: x_names.index(r) for r in regressors if r in x_names}

    results = []
    for q in quantiles:
        print(f"  [{label}] τ={q:.2f}, N_obs={len(d)}, N_clust={N_c}, B={B}")
        beta_hat, resid = fit_qr(y, X, q)

        boot = np.full((B, len(tgt)), np.nan)
        for b in range(B):
            w_map = {c: RNG.choice(WEBB_WEIGHTS) for c in countries}
            w_vec  = np.array([w_map[c] for c in ctry])
            y_star = X @ beta_hat + resid * w_vec
            try:
                beta_b, _ = fit_qr(y_star, X, q)
            except Exception:
                continue
            for j, r in enumerate(tgt):
                boot[b, j] = beta_b[tgt[r]]

        for j, r in enumerate(tgt):
            b0   = beta_hat[tgt[r]]
            boot_j = boot[:, j]
            boot_j = boot_j[~np.isnan(boot_j)]
            if len(boot_j) < B // 2:
                p, lo, hi = np.nan, np.nan, np.nan
            else:
                dist = boot_j - b0
                p  = float(np.mean(np.abs(boot_j - b0) >= np.abs(b0)))
                lo = b0 + float(np.percentile(dist, 2.5))
                hi = b0 + float(np.percentile(dist, 97.5))
            sig = ("***" if not np.isnan(p) and p < 0.01 else
                   "**"  if not np.isnan(p) and p < 0.05 else
                   "*"   if not np.isnan(p) and p < 0.10 else "")
            print(f"    {r:40s}  β={b0:+.4f}  p_webb={p:.3f}{sig}")
            results.append(dict(model=label, variable=r, quantile=q,
                                coef=round(b0, 6),
                                ci_lo_95=round(lo, 6) if not np.isnan(lo) else np.nan,
                                ci_hi_95=round(hi, 6) if not np.isnan(hi) else np.nan,
                                p_webb=round(p, 4)   if not np.isnan(p)  else np.nan,
                                sig_webb=sig, N_obs=len(d), N_clust=N_c, B=B,
                                spec="QR"))
    return results


# ─── 5. GCAI merge helper ─────────────────────────────────────────────────────

def load_gcai(df: pd.DataFrame) -> pd.DataFrame:
    gcai = pd.read_csv(GCAI)
    gcai["DATE"] = pd.to_datetime(gcai["DATE"]) if "DATE" in gcai.columns else None

    # Determine key column names
    country_col = next((c for c in gcai.columns
                        if c.lower() in ("country", "economy")), gcai.columns[0])
    year_col    = next((c for c in gcai.columns
                        if c.lower() == "year"), None)
    rank_col    = next((c for c in gcai.columns
                        if "rank" in c.lower()), None)

    if year_col and rank_col:
        gcai = gcai[[country_col, year_col, rank_col]].rename(
            columns={country_col: "country", year_col: "year", rank_col: "gcai_rank"})
        gcai["gcai_rank"] = pd.to_numeric(gcai["gcai_rank"], errors="coerce")
        gcai = gcai.dropna(subset=["gcai_rank"])
        gcai["rank_inv"] = 155 - gcai["gcai_rank"]
        # Min-max normalise within each year (avoids index-change artefacts)
        gcai["gcai_adopt"] = gcai.groupby("year")["rank_inv"].transform(
            lambda x: (x - x.min()) / (x.max() - x.min()) if x.max() > x.min() else 0.0)

        df["year"] = df["DATE"].dt.year
        df = df.merge(gcai[["country", "year", "gcai_adopt", "gcai_rank"]],
                      on=["country", "year"], how="left")
        print(f"[GCAI] merged; verified cells={df['gcai_adopt'].notna().sum()}")
    else:
        print(f"[GCAI] WARNING: could not identify columns in {GCAI}. "
              f"Columns: {gcai.columns.tolist()}")
    return df


# ─── 6. Main ─────────────────────────────────────────────────────────────────

def main():
    # 6.1 Fetch VIX
    vix = fetch_vix_fred()

    # 6.2 Load panel + merge VIX
    df = load_panel_with_vix(vix)
    df.to_csv(PANEL_VIX, index=False)
    print(f"[panel] saved with VIX → {PANEL_VIX.name}")

    all_results: list[dict] = []

    # ── A. OLS: Baseline + VIX ────────────────────────────────────────────────
    print("\n[A] M_base_vix — OLS Webb, macro + VIX, full sample")
    all_results += webb_ols(df, MACRO_VIX, "M_base_vix")

    # ── B. OLS: Crypto premium + VIX ─────────────────────────────────────────
    df_cr = df[(df["DATE"].dt.year >= 2017) & (df["DATE"].dt.year <= 2022)].copy()
    print("\n[B] M_crypto_vix — OLS Webb, crypto premium + VIX, 2017-2022")
    all_results += webb_ols(df_cr,
                            MACRO_VIX + ["crypto_premium"],
                            "M_crypto_vix")

    # ── C. QR: Webb cluster bootstrap at four quantiles (P1b fix) ────────────
    print("\n[C] QR_base — QR with Webb cluster bootstrap, macro-only, full sample")
    all_results += webb_qr(df, MACRO, "QR_base")

    print("\n[C2] QR_base_vix — QR with Webb cluster bootstrap, macro + VIX")
    all_results += webb_qr(df, MACRO_VIX, "QR_base_vix")

    # ── D. GCAI placebo: VIX × GCAI × π ──────────────────────────────────────
    print("\n[D] Loading GCAI for placebo interaction ...")
    df_gcai = load_gcai(df.copy())
    df_22   = df_gcai[(df_gcai["DATE"].dt.year >= 2022) &
                      (df_gcai["DATE"].dt.year <= 2024)].copy()
    df_22   = df_22.dropna(subset=["gcai_adopt"]).copy()
    print(f"[D] GCAI 2022-2024: N_obs={len(df_22)}, "
          f"countries={sorted(df_22['country'].unique())}")

    if len(df_22) > 20:
        df_22["ar_dummy"] = (df_22["country"] == "Argentina").astype(float)
        df_22["gcai_x_inf"]      = df_22["gcai_adopt"] * df_22["inflation_monthly"]
        df_22["ar_x_gcai"]       = df_22["ar_dummy"] * df_22["gcai_adopt"]
        df_22["ar_x_inf"]        = df_22["ar_dummy"] * df_22["inflation_monthly"]
        df_22["ar_x_gcai_x_inf"] = df_22["ar_dummy"] * df_22["gcai_adopt"] * df_22["inflation_monthly"]
        # VIX placebo: gcai_adopt × vix (if this is large/significant,
        # absorber result is risk-appetite artefact, not substitution)
        df_22["gcai_x_vix"] = df_22["gcai_adopt"] * df_22["vix_norm"]
        df_22["ar_x_gcai_x_vix"] = df_22["ar_dummy"] * df_22["gcai_x_vix"]

        triple_regs = [
            "global_dollar_change", "inflation_monthly",
            "broad_money_instability", "reserve_adequacy_change",
            "gcai_adopt", "gcai_x_inf", "ar_x_gcai", "ar_x_inf", "ar_x_gcai_x_inf",
            "vix",
        ]
        print("\n[D1] M_triple_vix — triple-interaction 2022-2024 + VIX")
        all_results += webb_ols(df_22, triple_regs, "M_triple_vix")

        placebo_regs = [
            "global_dollar_change", "inflation_monthly",
            "broad_money_instability", "reserve_adequacy_change",
            "gcai_adopt", "gcai_x_vix", "ar_x_gcai", "ar_x_gcai_x_vix",
            "vix",
        ]
        print("\n[D2] M_placebo_vix — VIX×GCAI placebo (replaces π×GCAI)")
        all_results += webb_ols(df_22, placebo_regs, "M_placebo_vix")
    else:
        print("[D] insufficient GCAI obs — skipping placebo models")

    # ── Save outputs ─────────────────────────────────────────────────────────
    out_df = pd.DataFrame(all_results)
    out_df.to_csv(OUT_CSV, index=False)
    print(f"\n[done] results → {OUT_CSV.name}")

    # ── Markdown report ───────────────────────────────────────────────────────
    lines = [
        "# P6 v13 — VIX Addition + QR Cluster Bootstrap (2026-04-09)",
        "",
        "## Purpose",
        "Addresses two fatal P1 issues from academic sparring review:",
        "- **P1a**: Add CBOE VIX to control for global risk appetite (omitted variable)",
        "- **P1b**: Fix QR inference from iid bootstrap → Webb wild cluster bootstrap",
        "",
    ]

    for model in out_df["model"].unique():
        sub = out_df[out_df["model"] == model]
        spec = sub["spec"].iloc[0] if "spec" in sub.columns else "OLS"
        N_obs  = sub["N_obs"].iloc[0]
        N_clst = sub["N_clust"].iloc[0]
        lines += [f"## {model} ({spec}, N_obs={N_obs}, N_clust={N_clst})", ""]

        if spec == "QR":
            for q in sorted(sub["quantile"].unique()):
                q_sub = sub[sub["quantile"] == q]
                lines.append(f"### τ = {q:.2f}")
                lines.append("| Variable | β | p_Webb | CI 95% | Sig |")
                lines.append("|---|---|---|---|---|")
                for _, row in q_sub.iterrows():
                    lines.append(
                        f"| {row['variable']} | {row['coef']:+.4f} "
                        f"| {row['p_webb']:.3f} "
                        f"| [{row['ci_lo_95']:+.4f}, {row['ci_hi_95']:+.4f}] "
                        f"| {row['sig_webb']} |"
                    )
                lines.append("")
        else:
            lines.append("| Variable | β | p_Webb | CI 95% | Sig |")
            lines.append("|---|---|---|---|---|")
            for _, row in sub.iterrows():
                lines.append(
                    f"| {row['variable']} | {row['coef']:+.4f} "
                    f"| {row['p_webb']:.3f} "
                    f"| [{row['ci_lo_95']:+.4f}, {row['ci_hi_95']:+.4f}] "
                    f"| {row['sig_webb']} |"
                )
            lines.append("")

    lines += [
        "## Interpretation Notes",
        "",
        "### VIX coefficient (M_base_vix, M_crypto_vix)",
        "- Positive β(VIX): higher global risk aversion → EM depreciation (expected)",
        "- If adding VIX changes β(crypto_premium) sign/significance: risk-off confound confirmed",
        "- If β(crypto_premium) survives with VIX: safety-valve result is robust",
        "",
        "### VIX placebo (M_placebo_vix)",
        "- Test: GCAI × VIX interaction (instead of GCAI × π)",
        "- H0: the Argentina absorber is risk-aversion response, not inflation-driven substitution",
        "- If β(GCAI×VIX) significant but β(GCAI×π) not: result is crypto-cycle artefact",
        "- If β(GCAI×π) survives alongside β(GCAI×VIX): substitution channel is genuine",
        "",
        "### QR Webb cluster bootstrap (QR_base, QR_base_vix)",
        "- Replaces Table 2 iid bootstrap (1000 reps) with Webb wild cluster bootstrap",
        "- Webb weights: {-√(3/2), -1, -√(1/2), +√(1/2), +1, +√(3/2)}, B=999",
        "- Reference: Hagemann (2017, Econometrica) for cluster-QR wild bootstrap",
        "- Significance at upper quantiles (τ=0.75, τ=0.90) now carries correct cluster size",
    ]

    OUT_MD.write_text("\n".join(lines))
    print(f"[done] report → {OUT_MD.name}")


if __name__ == "__main__":
    main()
