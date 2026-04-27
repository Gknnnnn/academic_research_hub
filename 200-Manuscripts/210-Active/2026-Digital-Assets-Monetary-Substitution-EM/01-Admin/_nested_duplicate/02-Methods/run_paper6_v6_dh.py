#!/usr/bin/env python3
"""
run_paper6_v6_dh.py — Dumitrescu-Hurlin (2012) panel Granger
non-causality test under cross-section heterogeneity.

Motivation:
  v4-v6 evidence quantifies the long-run elasticity (CCEMG/AMG/MG-ARDL
  ≈ +0.32) but does not establish causal direction. Pesaran (2004) CD
  has confirmed cross-section dependence; Dumitrescu-Hurlin (2012)
  is the standard panel non-causality test that accommodates both
  heterogeneous slopes and CSD-robust block-bootstrap inference.

Specification (Dumitrescu-Hurlin 2012, Eq. 1):
    y_it = α_i + Σ_{k=1}^{K} γ_{i,k} y_{i,t-k}
                  + Σ_{k=1}^{K} β_{i,k} x_{i,t-k} + ε_it

  Per-country Wald W_i for H0: β_{i,1} = ... = β_{i,K} = 0.
  Group-mean: W̄ = N⁻¹ Σ W_i.
  Asymptotic standardised statistics:
      Z̄        = √(N/(2K)) · (W̄ − K)               ~ N(0,1)
      Z̄^HNC    = √(N(T−2K−5)/(2K(T−K−3))) ·
                 ((T−2K−3)/(T−2K−1) · W̄ − K)         ~ N(0,1) (small-T)

Two directions tested:
  (a) inflation_monthly → fx_depreciation
  (b) fx_depreciation → inflation_monthly

References:
  Dumitrescu, E.-I., & Hurlin, C. (2012). Testing for Granger
    non-causality in heterogeneous panels. Economic Modelling 29(4): 1450-1460.

Output: 03-Results/paper6_v6_dh.md
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy import stats

ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT = ROOT / "03-Results" / "paper6_v6_dh.md"

LAGS = (1, 2, 3)


def _country_wald(g: pd.DataFrame, y_col: str, x_col: str, K: int) -> dict | None:
    g = g.sort_values("DATE").dropna(subset=[y_col, x_col]).reset_index(drop=True)
    if len(g) < 4 * K + 10:
        return None
    y = g[y_col].astype(float).values
    x = g[x_col].astype(float).values
    T = len(y)
    Y = y[K:]
    cols = []
    for k in range(1, K + 1):
        cols.append(y[K - k:T - k])
    for k in range(1, K + 1):
        cols.append(x[K - k:T - k])
    X = np.column_stack([np.ones(T - K)] + cols)
    try:
        res = sm.OLS(Y, X).fit()
    except Exception:
        return None
    # joint Wald that the K x-lag coefficients are zero
    n_params = X.shape[1]
    R = np.zeros((K, n_params))
    for j in range(K):
        R[j, 1 + K + j] = 1
    try:
        wald = float(res.f_test(R).fvalue) * K  # F * q gives χ²(q) Wald
    except Exception:
        return None
    return {"W": wald, "T_eff": T - K}


def _dh_statistic(country_W: dict, K: int) -> dict:
    Ws = [v["W"] for v in country_W.values() if v is not None]
    Ts = [v["T_eff"] for v in country_W.values() if v is not None]
    N = len(Ws)
    if N == 0:
        return {"available": False}
    W_bar = float(np.mean(Ws))
    T_bar = float(np.mean(Ts))
    Z_bar = np.sqrt(N / (2 * K)) * (W_bar - K)
    p_Z = 2 * (1 - stats.norm.cdf(abs(Z_bar)))
    # Hurlin small-T standardised statistic
    if T_bar > 2 * K + 5:
        scale = np.sqrt(N * (T_bar - 2 * K - 5) / (2 * K * (T_bar - K - 3)))
        adj_W = ((T_bar - 2 * K - 3) / (T_bar - 2 * K - 1)) * W_bar - K
        Z_HNC = scale * adj_W
        p_HNC = 2 * (1 - stats.norm.cdf(abs(Z_HNC)))
    else:
        Z_HNC, p_HNC = np.nan, np.nan
    return {"available": True, "N": N, "T_bar": T_bar, "W_bar": W_bar,
            "Z_bar": float(Z_bar), "p_Z": float(p_Z),
            "Z_HNC": float(Z_HNC) if not np.isnan(Z_HNC) else np.nan,
            "p_HNC": float(p_HNC) if not np.isnan(p_HNC) else np.nan,
            }


def _direction(df: pd.DataFrame, y: str, x: str, K: int, label: str) -> dict:
    cw = {}
    for c, g in df.groupby("country"):
        cw[c] = _country_wald(g, y, x, K)
    return {"label": label, "K": K, "country_W": cw, **_dh_statistic(cw, K)}


def main() -> int:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    print(f"[v6_dh] panel: {df.shape}")

    out = ["# Paper 6 v6 — Dumitrescu-Hurlin (2012) Panel Granger Causality\n",
           "**Variables:** y₁ = inflation_monthly, y₂ = fx_depreciation\n",
           "**H₀ (per direction):** x does NOT Granger-cause y in any cross-section\n",
           f"**Lag orders tested:** K ∈ {LAGS}\n"]

    for K in LAGS:
        out.append(f"\n## Lag order K = {K}\n")
        for (y, x, lab) in [
            ("fx_depreciation", "inflation_monthly", "inflation_monthly → fx_depreciation"),
            ("inflation_monthly", "fx_depreciation", "fx_depreciation → inflation_monthly"),
        ]:
            r = _direction(df, y, x, K, lab)
            print(f"[v6_dh] K={K} {lab}: Z̄={r['Z_bar']:+.2f} (p={r['p_Z']:.3f}), "
                  f"Z̄^HNC={r['Z_HNC']:+.2f} (p={r['p_HNC']:.3f})")
            out.append(f"\n### {lab}\n")
            out.append(f"- N usable countries = {r['N']}, T̄ = {r['T_bar']:.0f}, W̄ = {r['W_bar']:.3f}")
            out.append(f"- **Z̄ = {r['Z_bar']:+.3f}, p = {r['p_Z']:.4f}**")
            out.append(f"- **Z̄^HNC (small-T) = {r['Z_HNC']:+.3f}, p = {r['p_HNC']:.4f}**")
            out.append("\n#### Country-level Wald statistics\n")
            out.append("| Country | W_i | T_eff |")
            out.append("|---|---|---|")
            for c, v in r["country_W"].items():
                if v is None:
                    out.append(f"| {c} | — | insufficient |")
                else:
                    out.append(f"| {c} | {v['W']:.3f} | {v['T_eff']} |")

    out.append("\n## Interpretation\n")
    out.append("- A rejection of H₀ in **both** directions implies bidirectional Granger causality (feedback loop), consistent with the inflation-FX spiral hypothesis in EM economies.")
    out.append("- A rejection only in (inflation → FX) implies unidirectional pass-through, consistent with the orthodox monetary-substitution framework.")
    out.append("- Cross-validate with Stata `xtgcause` (Lopez & Weber 2017) before submission.")

    OUT.write_text("\n".join(out) + "\n")
    print(f"[v6_dh] yazıldı: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
