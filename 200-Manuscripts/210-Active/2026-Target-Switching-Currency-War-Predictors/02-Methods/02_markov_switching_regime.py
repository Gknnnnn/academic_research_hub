"""
02_markov_switching_regime.py
Target-Switching Currency War Predictors — Markov-Switching Regime
MGO | 2026-04-26 | BESTFIT Rank 35

Purpose: Supplement multinomial logit (currency war predictor model) with
Markov-Switching AR to identify latent currency-war regimes from exchange
rate dynamics without requiring pre-specified break dates.

Key: Hamilton (1989) MS-AR detects when a country is in "competitive
depreciation" vs "managed float" vs "crisis" regime. Regime probabilities
serve as instruments for the multinomial logit model.
"""
import pandas as pd
import numpy as np
from pathlib import Path
import shutil

BASE    = Path(__file__).resolve().parent.parent
RESULTS = BASE / "03-Results"
RESULTS.mkdir(exist_ok=True)

# ── Load data ─────────────────────────────────────────────────────────────────
data_candidates = [
    BASE / "02-Methods" / "data" / "currency_war_panel.csv",
    RESULTS / "currency_war_predictors.csv",
    BASE / "data" / "fx_panel_monthly.csv",
]
df = None
for p in data_candidates:
    if p.exists():
        df = pd.read_csv(p)
        print(f"Loaded: {p.name}  {df.shape}")
        break

if df is None:
    print("WARNING: data not found — simulated demo")
    np.random.seed(2026)
    N = 600
    # Simulate 3-regime exchange rate
    regime = np.zeros(N, dtype=int)
    regime[150:250] = 1   # competitive depreciation
    regime[400:480] = 2   # crisis
    sigma = [0.005, 0.015, 0.030]
    mu    = [-0.001, -0.008, 0.002]
    fx_chg = np.array([mu[r] + sigma[r]*np.random.randn() for r in regime])
    df = pd.DataFrame({
        "month": pd.date_range("2000-01", periods=N, freq="ME"),
        "fx_change": fx_chg,
        "reer": np.cumsum(fx_chg),
        "target_switch": (regime > 0).astype(int),
    })

# detect series
fx_col = next((c for c in df.columns if any(k in c.lower()
               for k in ["fx","reer","exchange","rate","return"])), df.columns[1])
print(f"Using series: {fx_col}")
series = df[fx_col].dropna().values.astype(float)

# ── Markov-Switching AR(1) ────────────────────────────────────────────────────
print("\n" + "="*60)
print("MS-AR(1): Currency War Regime Detection")
print("="*60)

rows_ms = []
try:
    from statsmodels.tsa.regime_switching.markov_autoregression import MarkovAutoregression

    for k in [2, 3]:
        try:
            mod = MarkovAutoregression(series, k_regimes=k, order=1,
                                       switching_ar=True, switching_variance=True)
            res = mod.fit(disp=False, maxiter=200)

            print(f"\n{k}-Regime MS-AR(1):")
            regime_means = []
            for r in range(k):
                mu_r  = res.params.get(f"[{r}]intercept", np.nan)
                sig_r = np.sqrt(res.params.get(f"[{r}]sigma2", np.nan))
                p_rr  = res.regime_transition[r,r] if hasattr(res, "regime_transition") else np.nan
                dur   = 1/(1-p_rr) if not np.isnan(p_rr) and p_rr < 1 else np.nan
                print(f"  Regime {r}: μ={float(mu_r):.4f}  σ={float(sig_r):.4f}"
                      f"  P(stay)={float(p_rr):.3f}  E[dur]={float(dur):.1f}")
                regime_means.append(float(mu_r))
                rows_ms.append({"k": k, "regime": r,
                                 "mu": round(float(mu_r),5), "sigma": round(float(sig_r),5),
                                 "p_stay": round(float(p_rr),4), "expected_duration": round(float(dur),1)})

            # Label regimes by mu
            sorted_r = np.argsort(regime_means)
            labels = {sorted_r[0]: "appreciation",
                      sorted_r[-1]: "competitive_deprec"}
            if k == 3:
                labels[sorted_r[1]] = "managed_float"
            print(f"  Regime labels: {labels}")

            # Save smoothed probabilities
            smooth = res.smoothed_marginal_probabilities
            n_obs  = len(smooth)
            out_df = df.iloc[-n_obs:].copy()
            for r in range(k):
                out_df[f"prob_regime{r}"] = smooth.values[:, r]
            out_df["dominant_regime"] = np.argmax(smooth.values, axis=1)
            out_df["regime_label"] = out_df["dominant_regime"].map(labels)
            out_df.to_csv(RESULTS / f"ms_regime_{k}state_currency_war.csv", index=False)
            print(f"  Saved: ms_regime_{k}state_currency_war.csv")

        except Exception as e:
            print(f"  {k}-regime error: {e}")

    if rows_ms:
        pd.DataFrame(rows_ms).to_csv(RESULTS / "ms_params_currency_war.csv", index=False)

except ImportError:
    print("statsmodels not installed.")

print("""
MANUSCRIPT NOTE (Target-Switching §4.2 Regime Detection):
  "MS-AR(1) identifies [K] latent regimes in exchange rate dynamics:
   competitive depreciation (μ=[X], σ=[Y], E[dur]=[Z] months),
   managed float, and appreciation. Smoothed regime probabilities are
   used as time-varying instruments in the multinomial logit model."
""")
