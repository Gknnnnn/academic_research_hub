# ============================================================
# KG-MGO-02 (Solo MGO): Gold Deposits, Bank Performance, Currency Risk
# Script 04: Multiple-Threshold NARDL (mtnardl) Upgrade
# Roudane package: mtnardl (PyPI)
# Research question: Does TRY depreciation cross a threshold that
#   switches the gold deposit → ROA/NIM transmission regime?
# Date: 2026-04-25 | Author: M. Gökhan Özdemir
# ============================================================

import pandas as pd
import numpy as np
from mtnardl import MTNARDL
import warnings
warnings.filterwarnings("ignore")

# ---- 0. Load Data ----
df = pd.read_csv(
    "../01-Data/processed/bddk_panel_final_v2.csv"
)

# Focus on deposit banks aggregate (most complete series, T=43)
agg = (
    df[df["group_name"] == "deposit_banks"]
    .sort_values("period_q")
    .reset_index(drop=True)
    .dropna(subset=["roa", "gold_dep_share", "d_try", "GD_pos", "GD_neg",
                    "TRY_pos", "TRY_neg", "npl", "log_total_dep"])
)

print(f"Deposit banks series: T={len(agg)} quarters ({agg['period_q'].iloc[0]}–{agg['period_q'].iloc[-1]})")
print(f"Variables: {list(agg.columns)}\n")

# ---- 1. MTNARDL: 2-regime threshold (TRY depreciation as threshold var) ----
# Hypothesis: when ΔTRY > τ*, the gold deposit → ROA channel strengthens
# Model: ROA_t = c + β⁺₁·GD⁺_t + β⁻₁·GD⁻_t  [regime 1: low TRY stress]
#              + β⁺₂·GD⁺_t + β⁻₂·GD⁻_t  [regime 2: high TRY stress]
#              + controls + ε_t

y   = agg["roa"].values
x   = agg["gold_dep_share"].values  # threshold NARDL uses original variable; model decomposes
# Threshold variable: TRY depreciation rate
thr = agg["d_try"].values

print("=" * 60)
print("MTNARDL — Dependent: ROA | Threshold: ΔTRY")
print("=" * 60)

try:
    mt_roa = MTNARDL(agg, "roa", "gold_dep_share", n_regimes=2).fit()
    print(mt_roa.summary())
    print("\nRegime thresholds (τ*):", mt_roa.thresholds)
    print("Regime-specific asymmetric coefficients:")
    for reg_name, coef_dict in mt_roa.regime_results.items():
        print(f"  {reg_name}: GD⁺={coef_dict.get('pos', 'n/a'):.4f} | GD⁻={coef_dict.get('neg', 'n/a'):.4f}")
except Exception as e:
    print(f"[MTNARDL ERROR]: {e}")
    print("Falling back to manual threshold split...\n")

    # ---- 1b. Manual Threshold Split (fallback) ----
    # Identify TRY depreciation threshold via grid search
    try_vals = np.percentile(agg["d_try"].dropna(), [25, 33, 50, 67, 75])
    print("TRY depreciation percentiles:", dict(zip([25,33,50,67,75], try_vals.round(4))))

    results_thresh = {}
    for pct, tau in zip([25, 33, 50, 67, 75], try_vals):
        agg_lo = agg[agg["d_try"] <= tau]
        agg_hi = agg[agg["d_try"] > tau]
        if len(agg_lo) < 10 or len(agg_hi) < 10:
            continue
        from numpy.linalg import lstsq
        # Low-stress regime: GD_pos, GD_neg → ROA
        X_lo = np.column_stack([
            np.ones(len(agg_lo)),
            agg_lo["GD_pos"].fillna(0),
            agg_lo["GD_neg"].fillna(0),
            agg_lo["npl"].fillna(agg_lo["npl"].mean()),
            agg_lo["log_total_dep"].fillna(agg_lo["log_total_dep"].mean())
        ])
        b_lo, _, _, _ = lstsq(X_lo, agg_lo["roa"].fillna(0), rcond=None)

        # High-stress regime
        X_hi = np.column_stack([
            np.ones(len(agg_hi)),
            agg_hi["GD_pos"].fillna(0),
            agg_hi["GD_neg"].fillna(0),
            agg_hi["npl"].fillna(agg_hi["npl"].mean()),
            agg_hi["log_total_dep"].fillna(agg_hi["log_total_dep"].mean())
        ])
        b_hi, _, _, _ = lstsq(X_hi, agg_hi["roa"].fillna(0), rcond=None)

        results_thresh[pct] = {
            "tau": tau,
            "n_lo": len(agg_lo), "n_hi": len(agg_hi),
            "GD_pos_lo": b_lo[1], "GD_neg_lo": b_lo[2],
            "GD_pos_hi": b_hi[1], "GD_neg_hi": b_hi[2]
        }

    print("\n--- Manual Threshold Results (ROA) ---")
    print(f"{'τ-pct':>6} {'τ*':>8} {'N_lo':>5} {'N_hi':>5} "
          f"{'GD⁺_lo':>9} {'GD⁻_lo':>9} {'GD⁺_hi':>9} {'GD⁻_hi':>9}")
    for pct, r in results_thresh.items():
        print(f"{pct:>6} {r['tau']:>8.4f} {r['n_lo']:>5} {r['n_hi']:>5} "
              f"{r['GD_pos_lo']:>9.4f} {r['GD_neg_lo']:>9.4f} "
              f"{r['GD_pos_hi']:>9.4f} {r['GD_neg_hi']:>9.4f}")

    print("\nInterpretation key:")
    print("  GD⁺_lo vs GD⁺_hi: does gold inflow effect strengthen under TRY stress?")
    print("  GD⁻_lo vs GD⁻_hi: does gold outflow effect weaken/reverse under TRY stress?")
    print("  Expected: |GD⁺_hi| > |GD⁺_lo| → TRY threshold amplification ✓")

# ---- 2. MTNARDL for NIM ----
print("\n" + "=" * 60)
print("MTNARDL — Dependent: NIM | Threshold: ΔTRY")
print("=" * 60)

agg_nim = (
    df[df["group_name"] == "deposit_banks"]
    .sort_values("period_q")
    .reset_index(drop=True)
    .dropna(subset=["nim", "gold_dep_share", "d_try"])
)

try:
    mt_nim = MTNARDL(agg_nim, "nim", "gold_dep_share", n_regimes=2).fit()
    print(mt_nim.summary())
except Exception as e:
    print(f"[MTNARDL NIM ERROR]: {e}")
    print("Manual threshold split needed (same structure as ROA above).")

# ---- 3. Export threshold results ----
print("\n" + "=" * 60)
print("SUMMARY FOR MANUSCRIPT TABLE R7")
print("=" * 60)
print("""
Table R7: Multiple-Threshold NARDL Results
------------------------------------------
This table reports regime-dependent asymmetric coefficients from the
multiple-threshold NARDL model (MTNARDL). The threshold variable is
the quarterly TRY depreciation rate (ΔTRY_t). Regime 1 (low-stress)
corresponds to ΔTRY ≤ τ*; Regime 2 (high-stress) to ΔTRY > τ*.

Columns: τ* | β⁺[R1] | β⁻[R1] | β⁺[R2] | β⁻[R2] | Wald(sym)[R1] | Wald(sym)[R2]

Expected finding: β⁺[R2] > β⁺[R1] → gold deposit inflows generate
larger ROA windfall under TRY depreciation pressure (consistent with
H2: TRY amplification channel).
""")
