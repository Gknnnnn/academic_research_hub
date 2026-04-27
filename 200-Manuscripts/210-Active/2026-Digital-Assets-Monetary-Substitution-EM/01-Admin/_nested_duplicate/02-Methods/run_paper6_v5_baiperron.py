#!/usr/bin/env python3
"""
run_paper6_v5_baiperron.py — Bai & Perron (1998, 2003) multiple
structural break test, country-by-country.

Motivation:
  CCEMG/AMG/GFE all suggest the inflation pass-through is masked by
  unobserved common factors AND by structural shifts (AR 2018 IMF
  programme; NG 2023 Naira unification; COVID 2020-03; Fed 2022 cycle).
  A formal Bai-Perron test locates these breaks endogenously.

Specification (per country i):
    Δfx_it = α_i^{(s)} + β_i^{(s)} · inflation_it + ε_it,   t ∈ regime s

  Multiple breaks {τ_1,...,τ_m} are estimated by global SSR minimisation
  over admissible partitions. supF(ℓ+1|ℓ) sequential test selects m.

References:
  Bai, J. & Perron, P. (1998). "Estimating and Testing Linear Models
    with Multiple Structural Changes." Econometrica 66(1): 47-78.
  Bai, J. & Perron, P. (2003). "Computation and Analysis of Multiple
    Structural Change Models." J. Applied Econometrics 18(1): 1-22.

Output: 03-Results/paper6_v5_baiperron.md
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy import stats

ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT = ROOT / "03-Results" / "paper6_v5_baiperron.md"

DEP = "fx_depreciation"
REGRESSOR = "inflation_monthly"
TRIM = 0.15      # ε trimming (Bai-Perron 2003 default)
MAX_BREAKS = 3   # m_max
SIG = 0.05


def _ssr_segment(y: np.ndarray, X: np.ndarray) -> float:
    if len(y) < X.shape[1] + 2:
        return np.inf
    try:
        beta, *_ = np.linalg.lstsq(X, y, rcond=None)
        r = y - X @ beta
        return float(r @ r)
    except np.linalg.LinAlgError:
        return np.inf


def _segment_ssr_table(y: np.ndarray, X: np.ndarray, h: int) -> np.ndarray:
    """SSR(i,j) for segment [i, j], i ≤ j, with min length h."""
    T = len(y)
    S = np.full((T, T), np.inf)
    for i in range(T):
        for j in range(i + h - 1, T):
            S[i, j] = _ssr_segment(y[i:j + 1], X[i:j + 1])
    return S


def _optimal_partition(S: np.ndarray, m: int, h: int) -> tuple[float, list[int]]:
    """
    Bai-Perron (2003) dynamic-programming partition: minimum SSR with
    exactly m breaks (m+1 regimes) given precomputed segment SSR table S.
    Returns (total_SSR, [τ_1,...,τ_m]) — break dates are inclusive end of
    regime ℓ (so regime ℓ = [τ_{ℓ-1}+1, τ_ℓ]).
    """
    T = S.shape[0]
    # F[k, t] = min SSR splitting [0..t] into k+1 regimes
    F = np.full((m + 1, T), np.inf)
    P = np.full((m + 1, T), -1, dtype=int)
    F[0] = S[0]
    for k in range(1, m + 1):
        for t in range((k + 1) * h - 1, T):
            best, arg = np.inf, -1
            for j in range(k * h - 1, t - h + 1):
                v = F[k - 1, j] + S[j + 1, t]
                if v < best:
                    best, arg = v, j
            F[k, t] = best
            P[k, t] = arg
    # backtrack
    breaks = []
    t = T - 1
    for k in range(m, 0, -1):
        j = P[k, t]
        breaks.append(j)
        t = j
    return float(F[m, T - 1]), sorted(breaks)


def _supF(SSR0: float, SSR1: float, T: int, q: int) -> tuple[float, float]:
    """
    sup-F(1|0) statistic: tests m=0 vs m=1 break.
    F = ((SSR0 - SSR1)/q) / (SSR1/(T - 2q))
    Asymptotic distribution non-standard (Andrews 1993; Bai-Perron 2003);
    here we report the F value and an approximate χ²(q)-based p-value as
    an upper bound (the true critical values are slightly more conservative).
    """
    if SSR1 <= 0 or T <= 2 * q:
        return np.nan, np.nan
    F = ((SSR0 - SSR1) / q) / (SSR1 / (T - 2 * q))
    p = 1 - stats.chi2.cdf(q * F, q)
    return float(F), float(p)


def country_baiperron(d: pd.DataFrame) -> dict:
    d = d.dropna(subset=[DEP, REGRESSOR]).sort_values("DATE").reset_index(drop=True)
    T = len(d)
    if T < 60:
        return {"available": False, "reason": f"T={T} < 60"}
    h = max(int(np.ceil(TRIM * T)), 10)

    y = d[DEP].astype(float).values
    X = sm.add_constant(d[REGRESSOR].astype(float).values.reshape(-1, 1))
    q = X.shape[1]

    S = _segment_ssr_table(y, X, h)
    SSR0 = S[0, T - 1]

    results = {}
    for m in range(1, MAX_BREAKS + 1):
        if (m + 1) * h > T:
            break
        ssr_m, brks = _optimal_partition(S, m, h)
        results[m] = {"SSR": ssr_m, "breaks_idx": brks,
                      "break_dates": [d["DATE"].iloc[b].strftime("%Y-%m") for b in brks]}

    # Sequential supF(ℓ+1|ℓ): use the simpler 0 vs 1 first; for ℓ ≥ 1 we
    # compare SSR_ℓ vs SSR_{ℓ+1} via the same F formula.
    seq = []
    prev_ssr, prev_m = SSR0, 0
    for m in sorted(results.keys()):
        F, p = _supF(prev_ssr, results[m]["SSR"], T, q)
        seq.append({"test": f"supF({m}|{m-1})", "F": F, "p": p})
        if not np.isnan(p) and p > SIG:
            break
        prev_ssr, prev_m = results[m]["SSR"], m

    return {"available": True, "T": T, "h": h, "results": results,
            "seq": seq, "selected_m": prev_m}


def main() -> int:
    df = pd.read_csv(PANEL)
    df["DATE"] = pd.to_datetime(df["DATE"])
    out = ["# Paper 6 v5 — Bai-Perron (2003) Structural Break Test\n",
           f"**Equation:** Δfx_it = α^(s) + β^(s) · {REGRESSOR}_it + ε_it (per country)\n",
           f"**Trimming ε = {TRIM}, max breaks m = {MAX_BREAKS}, sequential supF(ℓ+1|ℓ) at 5%**\n"]
    for c, g in df.groupby("country"):
        print(f"[bp] {c}...")
        r = country_baiperron(g)
        out.append(f"\n## {c}\n")
        if not r["available"]:
            out.append(f"- Skipped ({r['reason']}).")
            continue
        out.append(f"- T = {r['T']}, h (min regime length) = {r['h']}")
        out.append("\n### Sequential supF tests\n")
        out.append("| Test | F | p (χ² approx) |")
        out.append("|---|---|---|")
        for s in r["seq"]:
            out.append(f"| {s['test']} | {s['F']:.3f} | {s['p']:.4f} |")
        out.append(f"\n- **Selected number of breaks: m̂ = {r['selected_m']}**")
        if r["selected_m"] >= 1 and r["selected_m"] in r["results"]:
            dates = r["results"][r["selected_m"]]["break_dates"]
            out.append(f"- **Estimated break date(s):** {', '.join(dates)}")

    OUT.write_text("\n".join(out) + "\n")
    print(f"[bp] yazıldı: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
