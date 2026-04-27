#!/usr/bin/env python3
"""
run_paper6_v17_cd_ccemg_fi.py — Three research-gap extensions
2026-04-09

GAP 1: Pesaran (2004) CD test — cross-sectional dependence in FE residuals
GAP 2: Pesaran-Yamagata (2008) Δ̃ slope-homogeneity test
        + MG (Mean Group) estimator
        + CCEMG (Common Correlated Effects Mean Group, Pesaran 2006)
GAP 3: Financial inclusion as continuous moderator for crypto premium
        Data: WB Findex / GFDD "account.t.d" (% adults with account, 2021 wave)

Outputs:
  03-Results/paper6_v17_cd_ccemg_fi.csv   — coefficient tables
  03-Results/paper6_v17_cd_ccemg_fi.md    — report for manuscript
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy import stats
from pathlib import Path

ROOT    = Path(__file__).resolve().parents[1]
PANEL   = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v17_cd_ccemg_fi.csv"
OUT_MD  = ROOT / "03-Results" / "paper6_v17_cd_ccemg_fi.md"

RNG  = np.random.default_rng(20260409)
B    = 999
WEBB = np.array([-np.sqrt(3/2), -1.0, -np.sqrt(1/2),
                  np.sqrt(1/2),  1.0,  np.sqrt(3/2)])
DEP  = "fx_depreciation"
MACRO = ["global_dollar_change", "inflation_monthly",
         "broad_money_instability", "reserve_adequacy_change"]

# ── WB Findex 2021: % adults (15+) with account at fin. institution or mobile money
# Source: World Bank Global Findex Database 2021 (indicator: account.t.d)
# Argentina: 72.4%, Brazil: 84.0%, India: 77.5%, Mexico: 49.1%,
# Nigeria: 45.3%, South Africa: 85.0%
FINDEX_2021 = {
    "Argentina":   0.724,
    "Brazil":      0.840,
    "India":       0.775,
    "Mexico":      0.491,
    "Nigeria":     0.453,
    "South Africa":0.850,
}

# ─── SECTION 1: DATA PREP ─────────────────────────────────────────────────────

def load_panel() -> pd.DataFrame:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    df = df.sort_values(["country", "DATE"])
    # Winsorise dep var
    df[DEP] = df.groupby("country")[DEP].transform(
        lambda s: s.clip(s.quantile(0.05), s.quantile(0.95)))
    return df


def within_transform(df: pd.DataFrame, cols: list[str]) -> pd.DataFrame:
    """Demean by country mean (within transformation)."""
    d = df.copy()
    for col in cols:
        d[col] = d[col] - d.groupby("country")[col].transform("mean")
    return d


# ─── SECTION 2: PESARAN CD TEST (2004) ────────────────────────────────────────

def pesaran_cd_test(df: pd.DataFrame, regressors: list[str]) -> dict:
    """
    Pesaran (2004) cross-sectional dependence test on FE OLS residuals.
    CD = sqrt(2T / (N*(N-1))) * sum_{i<j} rho_hat_ij
    H0: no cross-sectional dependence  ~ N(0,1) asymptotically.
    """
    countries = sorted(df["country"].unique())
    N = len(countries)
    needed = [DEP] + regressors + ["country"]
    d = df.dropna(subset=needed).copy()

    # Estimate FE OLS country-by-country, collect residuals
    resid_dict = {}
    for c in countries:
        sub = d[d["country"] == c]
        if len(sub) < len(regressors) + 2:
            continue
        X = sm.add_constant(sub[regressors].astype(float))
        y = sub[DEP].astype(float)
        try:
            res = sm.OLS(y, X).fit()
            resid_dict[c] = res.resid.values
        except Exception:
            pass

    # Compute pairwise correlations
    ctries = sorted(resid_dict.keys())
    N_valid = len(ctries)
    rho_sum = 0.0
    pairs = 0
    T_avg = np.mean([len(v) for v in resid_dict.values()])

    for i in range(N_valid):
        for j in range(i + 1, N_valid):
            ri = resid_dict[ctries[i]]
            rj = resid_dict[ctries[j]]
            n = min(len(ri), len(rj))
            if n < 5:
                continue
            rho = np.corrcoef(ri[:n], rj[:n])[0, 1]
            rho_sum += rho
            pairs += 1

    if pairs == 0:
        return {"CD": np.nan, "p_CD": np.nan, "N": N_valid, "T_avg": T_avg,
                "verdict": "insufficient"}

    CD = np.sqrt(2 * T_avg / (N_valid * (N_valid - 1))) * rho_sum
    p_CD = 2 * (1 - stats.norm.cdf(abs(CD)))
    sig = "***" if p_CD < 0.01 else "**" if p_CD < 0.05 else "*" if p_CD < 0.10 else ""
    verdict = "CD present" if p_CD < 0.10 else "No CD"

    print(f"  Pesaran CD = {CD:.3f}, p = {p_CD:.4f}{sig}  [{verdict}]")
    return {"CD": round(CD, 3), "p_CD": round(p_CD, 4), "sig": sig,
            "N": N_valid, "T_avg": round(T_avg, 1), "verdict": verdict}


# ─── SECTION 3: MG ESTIMATOR ─────────────────────────────────────────────────

def mean_group(df: pd.DataFrame, regressors: list[str],
               label: str) -> tuple[pd.DataFrame, dict]:
    """
    Mean Group (MG) estimator: OLS per country, average coefficients.
    Returns (country_coefs DataFrame, avg_dict).
    """
    countries = sorted(df["country"].unique())
    needed = [DEP] + regressors + ["country"]
    d = df.dropna(subset=needed).copy()

    records = []
    for c in countries:
        sub = d[d["country"] == c]
        if len(sub) < len(regressors) + 3:
            continue
        X = sm.add_constant(sub[regressors].astype(float))
        y = sub[DEP].astype(float)
        try:
            res = sm.OLS(y, X).fit()
            row = {"country": c}
            for r in regressors:
                if r in res.params.index:
                    row[f"b_{r}"] = res.params[r]
                    row[f"se_{r}"] = res.bse[r]
            row["N"] = len(sub)
            row["R2"] = res.rsquared
            records.append(row)
        except Exception:
            pass

    cdf = pd.DataFrame(records)
    N_mg = len(cdf)

    # MG averages
    avg = {}
    for r in regressors:
        col = f"b_{r}"
        if col in cdf.columns:
            betas = cdf[col].dropna().values
            avg[r] = {
                "mg_beta": round(float(np.mean(betas)), 6),
                "mg_se":   round(float(np.std(betas) / np.sqrt(len(betas))), 6),
                "mg_t":    round(float(np.mean(betas) / (np.std(betas) / np.sqrt(len(betas))
                                  + 1e-10)), 3),
                "N_countries": N_mg,
            }
            print(f"  MG {r}: β̄ = {avg[r]['mg_beta']:+.5f}  "
                  f"SE_MG = {avg[r]['mg_se']:.5f}  "
                  f"t = {avg[r]['mg_t']:.2f}")

    return cdf, avg


# ─── SECTION 4: PESARAN-YAMAGATA Δ̃ TEST (2008) ────────────────────────────────

def py_delta_tilde(df: pd.DataFrame, regressors: list[str]) -> dict:
    """
    Pesaran-Yamagata (2008) slope homogeneity test.
    S = sum_i (b_i - b_MG)' Σ_i^{-1} (b_i - b_MG)
    Δ = sqrt(N/(2k)) * (S/N - k)
    Δ̃ = sqrt(N/(2k*(T+1)/(T-k))) * (S/N - k)
    H0: slope homogeneity ~ N(0,1) as N, T → ∞.
    """
    countries = sorted(df["country"].unique())
    needed = [DEP] + regressors + ["country"]
    d = df.dropna(subset=needed).copy()

    k = len(regressors)
    betas = []
    Vs = []     # variance matrices
    T_list = []

    for c in countries:
        sub = d[d["country"] == c]
        if len(sub) < k + 3:
            continue
        X = sm.add_constant(sub[regressors].astype(float)).values
        y = sub[DEP].astype(float).values
        b, *_ = np.linalg.lstsq(X, y, rcond=None)
        b_k = b[1:]   # drop constant
        T_i = len(y)
        resid = y - X @ b
        s2 = np.dot(resid, resid) / (T_i - k - 1)
        Xk = X[:, 1:]  # no constant
        V = s2 * np.linalg.pinv(Xk.T @ Xk)
        betas.append(b_k)
        Vs.append(V)
        T_list.append(T_i)

    N = len(betas)
    if N < 2:
        return {"Delta": np.nan, "Delta_tilde": np.nan, "p": np.nan,
                "N": N, "k": k}

    b_mg = np.mean(betas, axis=0)  # MG estimate (simple average)
    T_avg = np.mean(T_list)

    S = 0.0
    for i in range(N):
        diff = betas[i] - b_mg
        try:
            V_inv = np.linalg.pinv(Vs[i])
            S += diff @ V_inv @ diff
        except Exception:
            S += np.dot(diff, diff)   # fallback: Euclidean

    Delta = np.sqrt(N / (2 * k)) * (S / N - k)
    denom_tilde = 2 * k * (T_avg + 1) / (T_avg - k)
    Delta_tilde = np.sqrt(N / denom_tilde) * (S / N - k)

    p = 2 * (1 - stats.norm.cdf(abs(Delta_tilde)))
    sig = "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""
    verdict = "Heterogeneous" if p < 0.10 else "Homogeneous (cannot reject)"

    print(f"  P-Y Δ = {Delta:.3f}, Δ̃ = {Delta_tilde:.3f}, p = {p:.4f}{sig}  [{verdict}]")
    return {"Delta": round(Delta, 3), "Delta_tilde": round(Delta_tilde, 3),
            "p": round(p, 4), "sig": sig, "N": N, "k": k,
            "T_avg": round(T_avg, 1), "S": round(S, 3), "verdict": verdict}


# ─── SECTION 5: CCEMG ESTIMATOR (Pesaran 2006) ────────────────────────────────

def ccemg(df: pd.DataFrame, regressors: list[str], label: str) -> dict:
    """
    Common Correlated Effects Mean Group (CCEMG, Pesaran 2006).
    Augments each country regression with cross-sectional means of y and X
    to capture unobserved common factors.
    """
    countries = sorted(df["country"].unique())
    needed = [DEP] + regressors + ["country", "DATE"]
    d = df.dropna(subset=needed).copy()

    # Compute cross-sectional means at each date
    dates = sorted(d["DATE"].unique())
    xsmean_dep = d.groupby("DATE")[DEP].mean().rename("csm_dep")
    xsmeans_x  = {}
    for r in regressors:
        if r in d.columns:
            xsmeans_x[f"csm_{r}"] = d.groupby("DATE")[r].mean()

    d = d.join(xsmean_dep, on="DATE")
    for col, ser in xsmeans_x.items():
        d = d.join(ser.rename(col), on="DATE")

    augmented_regs = regressors + ["csm_dep"] + list(xsmeans_x.keys())

    records = []
    for c in countries:
        sub = d[d["country"] == c].copy()
        if len(sub) < len(augmented_regs) + 3:
            print(f"  [{c}] skipped — N={len(sub)}")
            continue
        X_aug = sm.add_constant(sub[augmented_regs].astype(float).dropna())
        y = sub.loc[X_aug.index, DEP].astype(float)
        if len(y) < len(augmented_regs) + 3:
            continue
        try:
            res = sm.OLS(y, X_aug).fit()
            row = {"country": c}
            for r in regressors:
                if r in res.params.index:
                    row[f"b_{r}"] = res.params[r]
                    row[f"se_{r}"] = res.bse[r]
            row["N"] = len(y)
            row["R2"] = res.rsquared
            records.append(row)
            print(f"  [{c}] b_inflation = {res.params.get('inflation_monthly', np.nan):+.5f}  "
                  f"b_DXY = {res.params.get('global_dollar_change', np.nan):+.5f}  "
                  f"N={len(y)}")
        except Exception as e:
            print(f"  [{c}] error: {e}")

    if not records:
        return {}

    cdf = pd.DataFrame(records)
    avg_dict = {}
    for r in regressors:
        col = f"b_{r}"
        if col in cdf.columns:
            betas = cdf[col].dropna().values
            if len(betas) == 0:
                continue
            b_bar = float(np.mean(betas))
            se_mg = float(np.std(betas) / np.sqrt(len(betas)))
            t_mg = b_bar / (se_mg + 1e-10)
            p_mg = 2 * (1 - stats.t.cdf(abs(t_mg), df=len(betas) - 1))
            sig = "***" if p_mg < 0.01 else "**" if p_mg < 0.05 else "*" if p_mg < 0.10 else ""
            avg_dict[r] = {
                "ccemg_beta": round(b_bar, 6),
                "ccemg_se_mg": round(se_mg, 6),
                "ccemg_t": round(t_mg, 3),
                "ccemg_p": round(p_mg, 4),
                "ccemg_sig": sig,
                "N_countries": len(betas),
            }
            print(f"  CCEMG {r}: β̄ = {b_bar:+.5f}  SE_MG = {se_mg:.5f}  "
                  f"t = {t_mg:.2f}  p = {p_mg:.4f}{sig}")

    return avg_dict


# ─── SECTION 6: FINANCIAL INCLUSION MODERATOR ─────────────────────────────────

def run_fi_moderator(df: pd.DataFrame) -> list[dict]:
    """
    Test financial inclusion (FI) as moderator for crypto premium.
    FI = WB Findex 2021 account ownership (% adults).
    Regression: Δe = ... + β_CP * CP + β_FI * FI + β_CPFI * (CP × FI) + ε

    Prediction: β_CPFI > 0 (higher FI → less absorption, more amplification of CP effect)
    i.e., low-FI countries (Nigeria, Mexico) show stronger crypto substitution
    """
    crypto_df = df.dropna(subset=["crypto_premium"]).copy()
    crypto_df["fi_index"] = crypto_df["country"].map(FINDEX_2021)
    crypto_df["cp_x_fi"] = crypto_df["crypto_premium"] * crypto_df["fi_index"]

    countries = sorted(crypto_df["country"].unique())
    N_c = len(countries)
    needed = [DEP, "crypto_premium", "fi_index", "cp_x_fi", "country"]
    d = crypto_df.dropna(subset=needed).copy()

    print(f"\n  FI values in crypto sample: {dict(d.groupby('country')['fi_index'].first())}")
    print(f"  N_obs={len(d)}, N_clust={N_c}")

    results = []
    for spec_regs, label in [
        (MACRO + ["crypto_premium", "fi_index"], "M_crypto_FI_control"),
        (MACRO + ["crypto_premium", "fi_index", "cp_x_fi"], "M_crypto_FI_interact"),
    ]:
        # Country FE dummies
        fe = pd.get_dummies(d["country"], prefix="c", drop_first=True).astype(float)
        d2 = pd.concat([d.reset_index(drop=True), fe.reset_index(drop=True)], axis=1)
        all_x = spec_regs + list(fe.columns)

        d2 = d2.dropna(subset=[DEP] + spec_regs)
        X = sm.add_constant(d2[all_x].astype(float)).values
        y = d2[DEP].astype(float).values
        ctry = d2["country"].values
        ctries = sorted(d2["country"].unique())
        x_names = ["const"] + all_x
        tgt = {r: x_names.index(r) for r in spec_regs if r in x_names}

        beta, *_ = np.linalg.lstsq(X, y, rcond=None)
        resid = y - X @ beta

        boot = np.full((B, len(tgt)), np.nan)
        for b in range(B):
            wm = {c: RNG.choice(WEBB) for c in ctries}
            wv = np.array([wm[c] for c in ctry])
            ys = X @ beta + resid * wv
            bb, *_ = np.linalg.lstsq(X, ys, rcond=None)
            for j, r in enumerate(tgt):
                boot[b, j] = bb[tgt[r]]

        for j, r in enumerate(tgt):
            b0 = beta[tgt[r]]
            p  = float(np.mean(np.abs(boot[:, j] - b0) >= np.abs(b0)))
            dist = boot[:, j] - b0
            lo_ci = b0 + float(np.percentile(dist, 2.5))
            hi_ci = b0 + float(np.percentile(dist, 97.5))
            XtX_inv = np.linalg.pinv(X.T @ X)
            meat = sum(
                X[ctry == c].T @ np.outer(resid[ctry == c], resid[ctry == c]) @ X[ctry == c]
                for c in ctries
            )
            V = XtX_inv @ meat @ XtX_inv
            se = float(np.sqrt(max(V[tgt[r], tgt[r]], 0)))
            sig = "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""
            print(f"    {label} {r:40s}  β={b0:+.5f}  p={p:.3f}{sig}  [{lo_ci:+.5f},{hi_ci:+.5f}]")
            results.append(dict(model=label, variable=r, coef=round(b0, 6),
                                se_cr=round(se, 6), ci_lo=round(lo_ci, 6),
                                ci_hi=round(hi_ci, 6), p_webb=round(p, 4),
                                sig=sig, N_obs=len(d2), N_clust=len(ctries), B=B))
    return results


# ─── MAIN ──────────────────────────────────────────────────────────────────────

def main():
    df = load_panel()
    all_results = []
    report_lines = [
        "# P6 v17 — CD Test · CCEMG · Slope Heterogeneity · Financial Inclusion — 2026-04-09",
        "",
        "## Research Gap Context",
        "",
        "- **GAP 1**: No CD test reported → FE OLS potentially inconsistent under cross-sectional dependence",
        "- **GAP 2**: No slope homogeneity test → pooled OLS β assumes identical macro responses across 6 countries",
        "- **GAP 3**: Financial inclusion (WB Findex 2021) absent → mechanism for absorber/amplifier split not continuously tested",
        "",
    ]

    # ── 1. PESARAN CD TEST ─────────────────────────────────────────────────────
    print("\n[GAP 1] Pesaran CD test on FE baseline residuals")
    cd_result = pesaran_cd_test(df, MACRO)
    report_lines += [
        "## Pesaran (2004) CD Test — FE OLS Residuals (Macro Baseline, N=6)",
        "",
        f"CD = {cd_result['CD']:.3f}, p = {cd_result['p_CD']:.4f}{cd_result.get('sig','')}",
        "",
        f"**Verdict**: {cd_result['verdict']}",
        ("FE OLS inference is inconsistent under CD; CCEMG reported below."
         if "present" in cd_result["verdict"]
         else "FE OLS valid; CCEMG reported as confirmatory robustness."),
        "",
    ]

    # ── 2. PESARAN-YAMAGATA Δ̃ ─────────────────────────────────────────────────
    print("\n[GAP 2a] Pesaran-Yamagata slope homogeneity test")
    py_result = py_delta_tilde(df, MACRO)
    report_lines += [
        "## Pesaran-Yamagata (2008) Slope Homogeneity Test",
        "",
        f"S = {py_result['S']:.3f}, Δ = {py_result['Delta']:.3f}, Δ̃ = {py_result['Delta_tilde']:.3f}",
        f"p = {py_result['p']:.4f}{py_result.get('sig','')}",
        "",
        f"**Verdict**: {py_result['verdict']}",
        f"N = {py_result['N']}, k = {py_result['k']}, T_avg = {py_result['T_avg']:.0f}",
        "",
        "*Note*: P-Y asymptotic approximation requires N → ∞; with N = 6 the test is",
        "indicative. Direction of the test (reject/not reject) is the relevant signal;",
        "exact p-values should be interpreted cautiously.",
        "",
    ]

    # ── 3. MG ESTIMATOR ───────────────────────────────────────────────────────
    print("\n[GAP 2b] Mean Group (MG) estimator")
    mg_cdf, mg_avg = mean_group(df, MACRO, "MG_macro")

    report_lines += [
        "## Mean Group (MG) Country-Specific Slopes — Macro Baseline",
        "",
        "| Country | β_DXY | β_inflation | β_BMI | β_RAC | N | R² |",
        "|---|---|---|---|---|---|---|",
    ]
    for _, row in mg_cdf.iterrows():
        bdy = row.get("b_global_dollar_change", "—")
        bi  = row.get("b_inflation_monthly", "—")
        bb  = row.get("b_broad_money_instability", "—")
        br  = row.get("b_reserve_adequacy_change", "—")
        nd  = int(row.get("N", 0))
        r2  = row.get("R2", 0)
        fmt = lambda x: f"{x:+.4f}" if isinstance(x, float) else "—"
        report_lines.append(
            f"| {row['country']} | {fmt(bdy)} | {fmt(bi)} | {fmt(bb)} | {fmt(br)} | {nd} | {r2:.3f} |"
        )

    report_lines += ["", "**MG Average:**", ""]
    for r, d in mg_avg.items():
        report_lines.append(
            f"- {r}: β̄ = {d['mg_beta']:+.5f}, SE_MG = {d['mg_se']:.5f}, t = {d['mg_t']:.2f}"
        )
    report_lines.append("")

    # Collect for CSV
    for r, d in mg_avg.items():
        all_results.append({"model": "MG_macro", "variable": r, **d})

    # ── 4. CCEMG ──────────────────────────────────────────────────────────────
    print("\n[GAP 1+2] CCEMG estimator — macro baseline")
    ccemg_avg = ccemg(df, MACRO, "CCEMG_macro")

    report_lines += [
        "## CCEMG Estimator (Pesaran 2006) — Cross-Section Augmented MG",
        "",
        "| Variable | CCEMG β̄ | SE_MG | t | p | Sig |",
        "|---|---|---|---|---|---|",
    ]
    for r, d in ccemg_avg.items():
        report_lines.append(
            f"| {r} | {d['ccemg_beta']:+.6f} | {d['ccemg_se_mg']:.6f} "
            f"| {d['ccemg_t']:.3f} | {d['ccemg_p']:.4f} | {d['ccemg_sig']} |"
        )
        all_results.append({"model": "CCEMG_macro", "variable": r,
                             "coef": d["ccemg_beta"], "se_cr": d["ccemg_se_mg"],
                             "t_cr": d["ccemg_t"], "p_webb": d["ccemg_p"],
                             "sig": d["ccemg_sig"]})
    report_lines.append("")

    # ── 5. FI MODERATOR ───────────────────────────────────────────────────────
    print("\n[GAP 3] Financial inclusion moderator (crypto premium spec)")
    fi_results = run_fi_moderator(df)
    all_results += fi_results

    report_lines += [
        "## Financial Inclusion as Continuous Moderator (Crypto Premium, Webb Bootstrap B=999)",
        "",
        "**WB Findex 2021 account ownership (% adults 15+):**",
        "",
        "| Country | FI index | Regime |",
        "|---|---|---|",
        "| Nigeria | 0.453 | Amplifier |",
        "| Mexico | 0.491 | Amplifier |",
        "| India | 0.775 | Amplifier |",
        "| Argentina | 0.724 | Absorber |",
        "| Brazil | 0.840 | Amplifier |",
        "| South Africa | 0.850 | — |",
        "",
        "**Prediction**: β(cp × fi) > 0 → high-FI countries show weaker crypto absorption",
        "(existing bank access reduces the unbanked demand for stablecoins as dollar proxy).",
        "",
    ]
    for model in {r["model"] for r in fi_results}:
        sub = [r for r in fi_results if r["model"] == model]
        n_obs = sub[0]["N_obs"]
        n_cl  = sub[0]["N_clust"]
        report_lines += [f"### {model} (N={n_obs}, N_cl={n_cl})", "",
                          "| Variable | β | p_Webb | CI 95% | Sig |",
                          "|---|---|---|---|---|"]
        for row in sub:
            report_lines.append(
                f"| {row['variable']} | {row['coef']:+.5f} | {row['p_webb']:.3f} "
                f"| [{row['ci_lo']:+.5f}, {row['ci_hi']:+.5f}] | {row['sig']} |"
            )
        report_lines.append("")

    report_lines += [
        "## Interpretation Guide",
        "",
        "### CD Test",
        "- Significant → FE OLS residuals share common unobserved factors (dollar shocks not fully absorbed by DXY); CCEMG preferred",
        "- CD present validates using CCEMG as the primary estimator in robustness",
        "",
        "### P-Y Δ̃ Test",
        "- Significant → macro response slopes differ across countries; pooled OLS is misspecified",
        "- Heterogeneous slopes validate the triple-interaction design that allows Argentina's β to differ",
        "- Directly responds to LOO finding: Mexico's β₅ ≠ Brazil's/India's/Nigeria's β₅",
        "",
        "### CCEMG vs FE OLS",
        "- If CCEMG and FE OLS directionally agree: baseline results robust to CD correction",
        "- Larger CCEMG SEs expected (efficiency cost of augmentation)",
        "",
        "### Financial Inclusion Interaction",
        "- β(cp × fi) > 0: crypto absorption strongest in LOW-FI countries (unbanked channel)",
        "- Note: Argentina FI=0.724 is NOT lowest; Nigeria=0.453 is lowest but amplifier",
        "- If β(cp × fi) is NS: FI not the mechanism; institutional P2P infrastructure required",
    ]

    # ── SAVE ──────────────────────────────────────────────────────────────────
    out = pd.DataFrame(all_results)
    out.to_csv(OUT_CSV, index=False)
    print(f"\n[done] {OUT_CSV.name}")

    OUT_MD.write_text("\n".join(report_lines))
    print(f"[done] {OUT_MD.name}")


if __name__ == "__main__":
    main()
