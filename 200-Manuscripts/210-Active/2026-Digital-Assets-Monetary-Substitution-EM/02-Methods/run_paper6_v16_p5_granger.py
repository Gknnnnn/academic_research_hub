#!/usr/bin/env python3
"""
run_paper6_v16_p5_granger.py — P5: Dumitrescu-Hurlin Panel Granger Causality
2026-04-09

Tests direction of causality between crypto_premium and fx_depreciation.
Addresses the simultaneity concern: does depreciation CAUSE crypto-premium
widening, or does crypto absorption CAUSE depreciation dampening?

DH test (Dumitrescu & Hurlin 2012):
  H0: x does not Granger-cause y for all i
  Under H0: no country i has Granger-causality from x → y
  Test statistic: W_bar (average of country-specific Wald stats)
  Asymptotic distribution under H0: N(0,1) as T,N → ∞
  Z-bar tilde statistic corrects for finite T (Dumitrescu-Hurlin 2012, eq.11)

Panel VAR (bivariate, 1 lag):
  Estimated country-by-country; IRFs averaged across countries.

Data: crypto_premium subsample (N=348, 6 countries, ~2017-2022).

Outputs:
  03-Results/paper6_v16_p5_granger.csv
  03-Results/paper6_v16_p5_granger.md
"""
from __future__ import annotations
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path
from scipy import stats

ROOT    = Path(__file__).resolve().parents[1]
PANEL   = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT_CSV = ROOT / "03-Results" / "paper6_v16_p5_granger.csv"
OUT_MD  = ROOT / "03-Results" / "paper6_v16_p5_granger.md"

LAGS = 2   # lag order for DH test


def prep_crypto_panel() -> pd.DataFrame:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    df = df.sort_values(["country", "DATE"])
    # Keep only rows with crypto_premium
    df = df.dropna(subset=["crypto_premium", "fx_depreciation"]).copy()
    # Winsorise by country
    for col in ["fx_depreciation", "crypto_premium"]:
        df[col] = df.groupby("country")[col].transform(
            lambda s: s.clip(s.quantile(0.05), s.quantile(0.95)))
    print(f"Crypto panel: N={len(df)}, "
          f"countries={sorted(df['country'].unique())}, "
          f"N_cl={df['country'].nunique()}")
    return df


def country_wald(y: np.ndarray, x: np.ndarray, lags: int) -> float:
    """
    Country-specific Wald statistic for H0: x does not Granger-cause y.
    Regress y on lags(y) + lags(x); test joint significance of lags(x).
    Returns Wald statistic (chi²/lags for W_bar average).
    """
    T = len(y)
    if T <= 2 * lags + 2:
        return np.nan

    # Build regressor matrix: const, y_{t-1},...,y_{t-p}, x_{t-1},...,x_{t-p}
    rows = []
    for t in range(lags, T):
        row = [1.0]
        row += [y[t - l] for l in range(1, lags + 1)]
        row += [x[t - l] for l in range(1, lags + 1)]
        rows.append(row)

    X = np.array(rows)
    Y = y[lags:]
    n = len(Y)
    k = X.shape[1]  # const + p*y_lags + p*x_lags

    beta, *_ = np.linalg.lstsq(X, Y, rcond=None)
    resid = Y - X @ beta
    s2 = np.dot(resid, resid) / (n - k)

    # Restricted model: only const + lags(y), no lags(x)
    X_r = X[:, :1 + lags]
    beta_r, *_ = np.linalg.lstsq(X_r, Y, rcond=None)
    resid_r = Y - X_r @ beta_r
    RSS_r = np.dot(resid_r, resid_r)
    RSS_u = np.dot(resid, resid)

    if s2 <= 0 or RSS_u <= 0:
        return np.nan

    # F-stat, converted to Wald = F * lags
    F = ((RSS_r - RSS_u) / lags) / (RSS_u / (n - k))
    W = F * lags  # Wald ~ chi²(lags) asymptotically
    return float(W)


def dh_test(df: pd.DataFrame, cause: str, effect: str,
            lags: int = 2) -> dict:
    """
    Dumitrescu-Hurlin (2012) panel Granger causality test.
    Returns W_bar, Z_bar, Z_bar_tilde, p-value (two-sided normal approx).
    """
    countries = sorted(df["country"].unique())
    N = len(countries)
    walds = []
    for c in countries:
        sub = df[df["country"] == c].sort_values("DATE")
        y = sub[effect].values
        x = sub[cause].values
        w = country_wald(y, x, lags)
        if not np.isnan(w):
            walds.append(w)
            print(f"    {c}: W={w:.3f}")
        else:
            print(f"    {c}: skipped (insufficient obs)")

    if len(walds) < 2:
        return {"cause": cause, "effect": effect, "W_bar": np.nan,
                "Z_bar": np.nan, "Z_bar_tilde": np.nan,
                "p_approx": np.nan, "N": N, "lags": lags}

    N_valid = len(walds)
    W_bar = np.mean(walds)

    # Z_bar: standard normal approx (Dumitrescu-Hurlin 2012, eq.9)
    # Under H0, each W_i ~ chi²(lags)/lags → E[W_i]=1, Var[W_i]=2/T_i
    # Use pooled T
    T_avg = df.groupby("country").size().mean()
    Z_bar = np.sqrt(N_valid / (2 * lags)) * (W_bar - lags)

    # Z_bar_tilde: finite-T correction (eq.11)
    # E[W_i] = lags; Var[W_i] = 2*lags*(T_i - 2*lags - 1)/(T_i - 2*lags - 3)
    # Use pooled T approximation
    T = T_avg
    if T > 2 * lags + 3:
        k1 = lags
        k2 = 2 * lags * (T - 2 * lags - 1) / (T - 2 * lags - 3)
        Z_bar_tilde = np.sqrt(N_valid / k2) * (W_bar * (T - 2 * lags - 3) /
                                                 (T - 2 * lags - 1) - k1)
    else:
        Z_bar_tilde = Z_bar  # fallback

    p_approx = 2 * (1 - stats.norm.cdf(abs(Z_bar_tilde)))

    sig = "***" if p_approx < 0.01 else "**" if p_approx < 0.05 else "*" if p_approx < 0.10 else ""
    print(f"  W_bar={W_bar:.3f}, Z_bar={Z_bar:.3f}, "
          f"Z_tilde={Z_bar_tilde:.3f}, p={p_approx:.4f}{sig}")

    return {"cause": cause, "effect": effect,
            "W_bar": round(W_bar, 4),
            "Z_bar": round(Z_bar, 4),
            "Z_bar_tilde": round(Z_bar_tilde, 4),
            "p_approx": round(p_approx, 4),
            "sig": sig,
            "N": N_valid, "lags": lags, "T_avg": round(T_avg, 1)}


def panel_var_irf(df: pd.DataFrame, lags: int = 1,
                  periods: int = 12) -> pd.DataFrame:
    """
    Bivariate panel VAR: [fx_depreciation, crypto_premium].
    Estimate country-by-country OLS; average A matrices.
    Compute orthogonalised IRF via Cholesky (dep first → crypto second:
    identifies 'contemporaneous shock to depreciation causes crypto response').
    """
    countries = sorted(df["country"].unique())
    A_list = []  # list of (2×2) lag-1 coefficient matrices

    for c in countries:
        sub = df[df["country"] == c].sort_values("DATE")
        y = sub[["fx_depreciation", "crypto_premium"]].values
        T = len(y)
        if T <= lags + 2:
            continue
        Y = y[lags:]
        X = np.column_stack([y[lags - l - 1: T - l - 1] for l in range(lags)] +
                            [np.ones(T - lags)])
        A, *_ = np.linalg.lstsq(X, Y, rcond=None)
        A_list.append(A[:2 * lags, :].T)   # (2×2) for lag-1

    if not A_list:
        return pd.DataFrame()

    A_avg = np.mean(A_list, axis=0)  # average VAR coefficient matrix

    # Residual covariance for average country
    resid_list = []
    for c in countries:
        sub = df[df["country"] == c].sort_values("DATE")
        y = sub[["fx_depreciation", "crypto_premium"]].values
        T = len(y)
        if T <= lags + 2:
            continue
        Y = y[lags:]
        X = np.column_stack([y[lags - l - 1: T - l - 1] for l in range(lags)] +
                            [np.ones(T - lags)])
        A, *_ = np.linalg.lstsq(X, Y, rcond=None)
        resid = Y - X @ A
        resid_list.append(resid)

    resid_all = np.vstack(resid_list)
    Sigma = np.cov(resid_all.T)

    # Cholesky: P s.t. P @ P.T = Sigma (lower triangular)
    P = np.linalg.cholesky(Sigma)

    # IRF computation
    irf = np.zeros((periods, 2, 2))  # [horizon, response_var, shock_var]
    irf[0] = P  # impact response

    Phi = np.eye(2)
    A_pad = A_avg  # 2×2 coefficient matrix
    for h in range(1, periods):
        Phi = A_pad @ Phi
        irf[h] = Phi @ P

    # Normalise by impact shock size
    records = []
    var_names = ["fx_depreciation", "crypto_premium"]
    shock_names = ["shock_fx", "shock_crypto"]
    for h in range(periods):
        for r_idx, r_name in enumerate(var_names):
            for s_idx, s_name in enumerate(shock_names):
                records.append({
                    "horizon": h,
                    "response": r_name,
                    "shock": s_name,
                    "irf": round(float(irf[h, r_idx, s_idx]), 6),
                })
    return pd.DataFrame(records)


def main():
    df = prep_crypto_panel()
    all_results = []
    irf_records = []

    print(f"\n[DH Test] Lags = {LAGS}")

    # ── H1: crypto_premium → fx_depreciation ─────────────────────────────────
    print("\n  H1: crypto_premium → fx_depreciation (safety-valve direction)")
    r1 = dh_test(df, cause="crypto_premium", effect="fx_depreciation", lags=LAGS)
    all_results.append(r1)

    # ── H2: fx_depreciation → crypto_premium (reverse) ───────────────────────
    print("\n  H2: fx_depreciation → crypto_premium (reverse causality)")
    r2 = dh_test(df, cause="fx_depreciation", effect="crypto_premium", lags=LAGS)
    all_results.append(r2)

    # ── Panel VAR IRF ─────────────────────────────────────────────────────────
    print("\n[Panel VAR] Bivariate IRF (country-average A matrices, Cholesky)")
    irf_df = panel_var_irf(df, lags=1, periods=12)
    if not irf_df.empty:
        print(irf_df[irf_df["shock"] == "shock_fx"].to_string(index=False))

    # ── SAVE ─────────────────────────────────────────────────────────────────
    out = pd.DataFrame(all_results)
    out.to_csv(OUT_CSV, index=False)
    print(f"\n[done] {OUT_CSV.name}")

    # ── MARKDOWN ─────────────────────────────────────────────────────────────
    lines = [
        "# P6 v16 — P5: Dumitrescu-Hurlin Panel Granger Causality — 2026-04-09",
        "",
        f"**Lag order**: {LAGS}  |  **Data**: crypto_premium subsample (N=348, 6 countries)",
        "",
        "## DH Granger Causality Results",
        "",
        "| Direction | W_bar | Z_bar_tilde | p (approx.) | Verdict |",
        "|---|---|---|---|---|",
    ]
    for r in all_results:
        direction = f"{r['cause']} → {r['effect']}"
        verdict = "Granger-causes" if r.get("p_approx", 1) < 0.10 else "No causality"
        lines.append(
            f"| {direction} | {r['W_bar']:.3f} | {r['Z_bar_tilde']:.3f} "
            f"| {r['p_approx']:.4f}{r.get('sig','')} | {verdict} |"
        )
    lines += [
        "",
        "## Panel VAR IRF (shock to fx_depreciation → crypto_premium response)",
        "",
        "| Horizon | Response: fx_dep | Response: crypto_prem |",
        "|---|---|---|",
    ]
    if not irf_df.empty:
        fx_shock = irf_df[irf_df["shock"] == "shock_fx"]
        fx_resp = fx_shock[fx_shock["response"] == "fx_depreciation"]["irf"].values
        cp_resp = fx_shock[fx_shock["response"] == "crypto_premium"]["irf"].values
        for h in range(min(12, len(fx_resp))):
            lines.append(f"| {h} | {fx_resp[h]:+.5f} | {cp_resp[h]:+.5f} |")
    lines += [
        "",
        "## Interpretation",
        "",
        "- **H1 (crypto → dep)**: if significant, crypto premium Granger-causes depreciation",
        "  (reverse safety-valve: premium widening precedes FX stress)",
        "- **H2 (dep → crypto)**: if significant, depreciation drives premium (demand-pull:",
        "  FX stress causes agents to buy crypto at a premium)",
        "- If **both significant**: bidirectional feedback loop",
        "- If **H2 only**: premium is a consequence of FX stress, not a causal absorber",
        "- Panel VAR IRF: does a shock to depreciation raise or lower the crypto premium",
        "  over subsequent months?",
    ]
    OUT_MD.write_text("\n".join(lines))
    print(f"[done] {OUT_MD.name}")

    if not irf_df.empty:
        irf_df.to_csv(OUT_CSV.with_suffix("").as_posix() + "_irf.csv", index=False)


if __name__ == "__main__":
    main()
