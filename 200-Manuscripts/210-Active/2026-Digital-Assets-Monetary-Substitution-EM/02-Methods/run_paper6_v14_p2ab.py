#!/usr/bin/env python3
"""
run_paper6_v14_p2ab.py — P2a + P2b from academic sparring (2026-04-09)

P2a — Chinn-Ito KAOPEN as continuous moderator
      Theory: if the Argentina absorber is driven by capital-account closure,
      ka_closed × GCAI × π should be negative and significant in a pooled
      model that replaces the binary AR dummy.
      Test also whether continuous KAOPEN supersedes the binary dummy or
      merely complements it.

P2b — Leave-one-out country robustness table
      Drop each of the 5 GCAI countries in turn and re-run the
      triple-interaction (base EM β5 + AR differential β8).
      Addresses the specification-search concern: if Argentina drives
      everything, β5 for the remaining 4 countries should still be positive.

Output
------
  03-Results/paper6_v14_p2ab.csv   — full Webb bootstrap table
  03-Results/paper6_v14_p2ab.md    — markdown report for manuscript
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path

ROOT    = Path(__file__).resolve().parents[1]
PANEL   = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
GCAI    = ROOT / "03-Results" / "chainalysis" / "chainalysis_gcai_2020_2024.csv"
KAOPEN  = ROOT / "03-Results" / "kaopen_em6.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v14_p2ab.csv"
OUT_MD  = ROOT / "03-Results" / "paper6_v14_p2ab.md"

RNG  = np.random.default_rng(20260409)
B    = 999
WEBB = np.array([-np.sqrt(3/2), -1.0, -np.sqrt(1/2),
                  np.sqrt(1/2),  1.0,  np.sqrt(3/2)])
DEP  = "fx_depreciation"
MACRO = ["global_dollar_change", "inflation_monthly",
         "broad_money_instability", "reserve_adequacy_change"]
GCAI_COUNTRIES = ["Argentina", "Brazil", "India", "Mexico", "Nigeria"]


# ─── helpers ─────────────────────────────────────────────────────────────────

def winsorise(df: pd.DataFrame) -> pd.DataFrame:
    def wins(s, lo=0.05, hi=0.95):
        return s.clip(s.quantile(lo), s.quantile(hi))
    df = df.copy()
    df[DEP] = df.groupby("country")[DEP].transform(wins)
    return df


def add_country_fe(df: pd.DataFrame,
                   extra_dummies: list[str] | None = None) -> tuple[pd.DataFrame, list[str]]:
    fe = pd.get_dummies(df["country"], prefix="c", drop_first=True).astype(float)
    out = pd.concat([df.reset_index(drop=True), fe.reset_index(drop=True)], axis=1)
    fe_cols = list(fe.columns)
    if extra_dummies:
        for col in extra_dummies:
            d = pd.get_dummies(df[col], prefix=col, drop_first=True).astype(float)
            out = pd.concat([out.reset_index(drop=True), d.reset_index(drop=True)], axis=1)
            fe_cols += list(d.columns)
    return out, fe_cols


def webb_ols(df: pd.DataFrame, regressors: list[str], label: str,
             extra_dummies: list[str] | None = None) -> list[dict]:
    needed = [DEP] + regressors + ["country"]
    d = df.dropna(subset=needed).copy()
    d, fe_cols = add_country_fe(d, extra_dummies)
    all_x = regressors + fe_cols

    countries = sorted(d["country"].unique())
    N_c = len(countries)
    if len(d) < 10 or N_c < 2:
        print(f"  [{label}] skipped — N={len(d)}, N_cl={N_c}")
        return []
    print(f"  [{label}] N_obs={len(d)}, N_clust={N_c}, B={B}")

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
        dist = boot[:, j] - b0
        p  = float(np.mean(np.abs(boot[:, j] - b0) >= np.abs(b0)))
        lo = b0 + float(np.percentile(dist, 2.5))
        hi = b0 + float(np.percentile(dist, 97.5))
        # CR-SE
        XtX_inv = np.linalg.pinv(X.T @ X)
        meat = sum(
            X[ctry == c].T @ np.outer(resid[ctry == c], resid[ctry == c]) @ X[ctry == c]
            for c in countries
        )
        V = XtX_inv @ meat @ XtX_inv
        se = float(np.sqrt(max(V[tgt[r], tgt[r]], 0)))
        t  = b0 / se if se > 0 else np.nan
        sig = "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""
        print(f"    {r:45s}  β={b0:+.4f}  p={p:.3f}{sig}  [{lo:+.4f},{hi:+.4f}]")
        results.append(dict(
            model=label, variable=r, coef=round(b0, 6),
            se_cr=round(se, 6), t_cr=round(t, 3),
            ci_lo=round(lo, 6), ci_hi=round(hi, 6),
            p_webb=round(p, 4), sig=sig,
            N_obs=len(d), N_clust=N_c, B=B,
            countries="|".join(countries),
        ))
    return results


# ─── data loading ────────────────────────────────────────────────────────────

def load_base() -> pd.DataFrame:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    df = df[df["country"].isin(GCAI_COUNTRIES)].copy()
    df = winsorise(df)
    return df


def load_gcai() -> pd.DataFrame:
    gcai = pd.read_csv(GCAI)
    country_col = next(c for c in gcai.columns if c.lower() in ("country", "economy"))
    year_col    = next((c for c in gcai.columns if c.lower() == "year"), None)
    rank_col    = next((c for c in gcai.columns if "rank" in c.lower()), None)
    if year_col and rank_col:
        gcai = gcai[[country_col, year_col, rank_col]].rename(
            columns={country_col: "country", year_col: "year", rank_col: "gcai_rank"})
        gcai["gcai_rank"] = pd.to_numeric(gcai["gcai_rank"], errors="coerce")
        gcai = gcai.dropna(subset=["gcai_rank"])
        gcai["rank_inv"]   = 155 - gcai["gcai_rank"]
        gcai["gcai_adopt"] = gcai.groupby("year")["rank_inv"].transform(
            lambda x: (x - x.min()) / (x.max() - x.min()) if x.max() > x.min() else 0.0)
    return gcai[["country", "year", "gcai_adopt", "gcai_rank"]]


def load_kaopen() -> pd.DataFrame:
    ka = pd.read_csv(KAOPEN)
    return ka[["country", "year", "kaopen", "ka_closed"]]


def build_gcai_panel(df: pd.DataFrame, gcai: pd.DataFrame,
                     ka: pd.DataFrame, years: tuple) -> pd.DataFrame:
    d = df[(df["DATE"].dt.year >= years[0]) &
           (df["DATE"].dt.year <= years[1])].copy()
    d["year"] = d["DATE"].dt.year
    d = d.merge(gcai, on=["country", "year"], how="left")
    d = d.merge(ka,   on=["country", "year"], how="left")
    d = d.dropna(subset=["gcai_adopt"]).copy()

    # Interaction terms
    d["gcai_x_inf"]      = d["gcai_adopt"] * d["inflation_monthly"]
    d["ar_dummy"]        = (d["country"] == "Argentina").astype(float)
    d["ar_x_gcai"]       = d["ar_dummy"]  * d["gcai_adopt"]
    d["ar_x_inf"]        = d["ar_dummy"]  * d["inflation_monthly"]
    d["ar_x_gcai_x_inf"] = d["ar_dummy"]  * d["gcai_adopt"] * d["inflation_monthly"]

    # Chinn-Ito interactions (P2a)
    # ka_closed is sign-inverted kaopen: larger = more restricted
    if "ka_closed" in d.columns:
        d["ka_x_gcai"]       = d["ka_closed"] * d["gcai_adopt"]
        d["ka_x_inf"]        = d["ka_closed"] * d["inflation_monthly"]
        d["ka_x_gcai_x_inf"] = d["ka_closed"] * d["gcai_adopt"] * d["inflation_monthly"]

    print(f"  Panel built: N={len(d)}, "
          f"countries={sorted(d['country'].unique())}, "
          f"years={d['year'].min()}-{d['year'].max()}")
    return d


# ─── main ────────────────────────────────────────────────────────────────────

def main():
    df   = load_base()
    gcai = load_gcai()
    ka   = load_kaopen()
    all_results: list[dict] = []

    # ── BUILD 2022-2024 GCAI PANEL ──────────────────────────────────────────
    print("\n[GCAI panel] building 2022-2024 ...")
    d22 = build_gcai_panel(df, gcai, ka, (2022, 2024))

    # ── P2a-0: ORIGINAL TRIPLE (replication baseline) ──────────────────────
    print("\n[P2a-0] Original triple-interaction (baseline replication)")
    base_regs = MACRO + ["gcai_adopt", "gcai_x_inf",
                          "ar_x_gcai", "ar_x_inf", "ar_x_gcai_x_inf"]
    all_results += webb_ols(d22, base_regs, "P2a_triple_orig")

    # ── P2a-1: KAOPEN CONTINUOUS TRIPLE (replaces AR dummy) ─────────────────
    print("\n[P2a-1] Continuous KAOPEN triple: ka_closed × GCAI × π")
    ka_regs = MACRO + ["gcai_adopt", "gcai_x_inf",
                        "ka_x_gcai", "ka_x_inf", "ka_x_gcai_x_inf"]
    all_results += webb_ols(d22, ka_regs, "P2a_kaopen_triple")

    # ── P2a-2: BOTH AR DUMMY AND KAOPEN (complementarity test) ─────────────
    print("\n[P2a-2] Dual spec: AR dummy + KAOPEN continuous moderator")
    dual_regs = MACRO + ["gcai_adopt", "gcai_x_inf",
                          "ar_x_gcai", "ar_x_inf", "ar_x_gcai_x_inf",
                          "ka_x_gcai", "ka_x_inf", "ka_x_gcai_x_inf"]
    all_results += webb_ols(d22, dual_regs, "P2a_dual")

    # ── P2b: LEAVE-ONE-OUT ──────────────────────────────────────────────────
    print("\n[P2b] Leave-one-out robustness")
    loo_countries = sorted(d22["country"].unique())
    for drop_c in loo_countries:
        d_loo = d22[d22["country"] != drop_c].copy()
        label = f"P2b_drop_{drop_c[:3].upper()}"
        print(f"\n  Dropping {drop_c}:")
        if drop_c == "Argentina":
            # No AR dummy — just run base EM amplification
            loo_regs = MACRO + ["gcai_adopt", "gcai_x_inf"]
            all_results += webb_ols(d_loo, loo_regs, label)
        else:
            # Keep AR dummy (Argentina still in sample)
            all_results += webb_ols(d_loo, base_regs, label)

    # ── SAVE ─────────────────────────────────────────────────────────────────
    out = pd.DataFrame(all_results)
    out.to_csv(OUT_CSV, index=False)
    print(f"\n[done] {OUT_CSV.name}")

    # ── MARKDOWN REPORT ───────────────────────────────────────────────────────
    lines = [
        "# P6 v14 — P2a (Chinn-Ito) + P2b (Leave-One-Out) — 2026-04-09",
        "",
        "## P2a: Chinn-Ito KAOPEN as Continuous Moderator",
        "",
        "**Motivation**: The binary Argentina dummy has been criticised as theoretically",
        "ad hoc. KAOPEN provides a theoretically grounded continuous measure of capital",
        "account openness. ka_closed = −KAOPEN; higher values = tighter restrictions.",
        "",
        "**Key KAOPEN values in 2022 (GCAI window):**",
        "",
        "| Country | KAOPEN 2022 | ka_closed | Interpretation |",
        "|---|---|---|---|",
    ]

    ka22 = ka[ka["year"] == 2022].set_index("country")
    for c in GCAI_COUNTRIES:
        if c in ka22.index:
            row = ka22.loc[c]
            interp = "Open" if row["kaopen"] > 0 else "Restricted"
            lines.append(f"| {c} | {row['kaopen']:.3f} | {row['ka_closed']:.3f} | {interp} |")
    lines.append("")

    # Results tables
    for model in out["model"].unique():
        sub = out[out["model"] == model]
        n_obs  = sub["N_obs"].iloc[0]
        n_clst = sub["N_clust"].iloc[0]
        ctries = sub["countries"].iloc[0]
        lines += [f"## {model} (N={n_obs}, N_cl={n_clst})",
                  f"*Countries*: {ctries}", "",
                  "| Variable | β | p_Webb | CI 95% | Sig |",
                  "|---|---|---|---|---|"]
        for _, row in sub.iterrows():
            lines.append(
                f"| {row['variable']} | {row['coef']:+.4f} "
                f"| {row['p_webb']:.3f} "
                f"| [{row['ci_lo']:+.4f}, {row['ci_hi']:+.4f}] "
                f"| {row['sig']} |"
            )
        lines.append("")

    lines += [
        "## Interpretation Notes",
        "",
        "### P2a: What the KAOPEN triple reveals",
        "- If ka_x_gcai_x_inf is **negative and significant**: capital-account",
        "  closure drives absorber effect generically (KAOPEN captures the mechanism)",
        "- If ka_x_gcai_x_inf is **not significant**: KAOPEN does not capture what",
        "  makes Argentina special — the absorber requires something beyond formal",
        "  capital-account restrictions (enforcement stringency, P2P USDT market,",
        "  hyperinflation threshold). The binary dummy outperforms the continuous index.",
        "",
        "### P2b: What leave-one-out shows",
        "- P2b_drop_ARG: does base EM β(gcai_x_inf) stay positive and significant?",
        "  If yes: amplification for open EMs is not an Argentina artefact",
        "- P2b_drop_{BRA,IND,MEX,NGA}: does β8(ar_x_gcai_x_inf) stay negative/sig?",
        "  If yes: Argentina differential is robust to each individual country dropped",
    ]

    OUT_MD.write_text("\n".join(lines))
    print(f"[done] {OUT_MD.name}")


if __name__ == "__main__":
    main()
