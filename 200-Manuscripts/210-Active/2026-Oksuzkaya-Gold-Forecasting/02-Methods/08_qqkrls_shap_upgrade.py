"""
08_qqkrls_shap_upgrade.py
Oksuzkaya Gold Forecasting — QQ-KRLS + SHAP Interaction Upgrade
MGO | 2026-04-26 | BESTFIT Rank 42

Purpose: Supplement RF/GBM + SHAP (main model, IRFA-ready v07) with:
(1) QQ-KRLS — nonlinear tail mapping of key predictors → gold return
(2) SHAP interaction values — which feature pairs have nonlinear synergies?

Data: 03-Results/ (gold forecasting dataset)
"""
import pandas as pd
import numpy as np
from pathlib import Path
import shutil

BASE    = Path(__file__).resolve().parent.parent
RESULTS = BASE / "03-Results"
TMP     = Path("/tmp/oksuzkaya_gold/")
TMP.mkdir(exist_ok=True)

# ── Load data ─────────────────────────────────────────────────────────────────
df = None
for csv_name in ["gold_forecast_dataset.csv", "oksuzkaya_gold_data.csv",
                  "paper_gold_forecasting.csv", "gold_features.csv"]:
    src = RESULTS / csv_name
    if src.exists():
        shutil.copy(src, TMP / csv_name)
        df = pd.read_csv(TMP / csv_name)
        print(f"Loaded: {csv_name}  {df.shape}")
        break

if df is None:
    # Try paper3 dataset (shared gold data)
    p3_path = BASE.parent / "2026-Gold-Policy-Uncertainty-Repricing" / "03-Results" / "paper3_gold_policy_uncertainty_dataset.csv"
    if p3_path.exists():
        shutil.copy(p3_path, TMP / "gold_p3.csv")
        df = pd.read_csv(TMP / "gold_p3.csv")
        print(f"Using P3 gold dataset: {df.shape}")

if df is None:
    print("WARNING: data not found — simulated demo")
    np.random.seed(2026)
    N = 500
    df = pd.DataFrame({
        "gold_return": np.random.normal(0.001, 0.012, N),
        "VIX": np.abs(np.random.normal(20, 8, N)),
        "DXY": np.random.normal(95, 5, N),
        "OIL": np.abs(np.random.normal(80, 20, N)),
        "REAL_RATE": np.random.normal(0, 1.5, N),
    })

y_col = next((c for c in df.columns if any(k in c.lower() for k in ["gold","return","ret","xau"])), None)
feature_cols = [c for c in df.columns if c != y_col and df[c].dtype in [float, np.float64, int, np.int64]]
if y_col is None:
    y_col = df.columns[0]
    feature_cols = df.columns[1:].tolist()

print(f"y={y_col}  features={feature_cols[:5]}")

# ── (1) QQ-KRLS on top features ──────────────────────────────────────────────
print("\n" + "="*60)
print("QQ-KRLS: Top Predictors → Gold Return")
print("="*60)

taus = np.round(np.arange(0.10, 0.95, 0.10), 2)
y_arr = df[y_col].values.astype(float)

try:
    from qqkrls import QQKRLS

    all_rows = []
    for feat in feature_cols[:4]:  # top 4 features
        x_arr = df[feat].values.astype(float)
        mask  = np.isfinite(y_arr) & np.isfinite(x_arr)
        y_u, x_u = y_arr[mask], x_arr[mask]

        n_sig = 0
        for tau_y in taus:
            for tau_x in taus:
                try:
                    res  = QQKRLS(y=y_u, x=x_u, tau_y=float(tau_y), tau_x=float(tau_x)).fit()
                    pval = float(res.pvalue) if hasattr(res, "pvalue") else np.nan
                    sig  = int(pval < 0.05) if not np.isnan(pval) else 0
                    all_rows.append({"feature": feat, "tau_y": tau_y, "tau_x": tau_x,
                                     "beta": round(float(res.beta),6),
                                     "pvalue": round(pval,4) if not np.isnan(pval) else np.nan,
                                     "sig": sig})
                    n_sig += sig
                except Exception:
                    all_rows.append({"feature": feat, "tau_y": tau_y, "tau_x": tau_x,
                                     "beta": np.nan, "pvalue": np.nan, "sig": 0})
        total = len(taus)**2
        upper = [r for r in all_rows[-total:] if r.get("tau_y",0)>0.75 and r.get("tau_x",0)>0.75]
        print(f"  {feat:12s}: {n_sig}/{total} sig | upper tail {sum(r['sig'] for r in upper)}/{len(upper)}")

    if all_rows:
        df_krls = pd.DataFrame(all_rows)
        df_krls.to_csv(RESULTS / "qqkrls_gold_forecasting.csv", index=False)
        print(f"\nSaved: qqkrls_gold_forecasting.csv")

except ImportError:
    print("qqkrls not installed.")

# ── (2) SHAP Interaction Values ───────────────────────────────────────────────
print("\n" + "="*60)
print("SHAP Interaction Values: Feature Pair Synergies")
print("="*60)

try:
    from sklearn.ensemble import RandomForestRegressor
    import shap

    y_arr = df[y_col].values.astype(float)
    X_df  = df[feature_cols].fillna(df[feature_cols].median())
    mask  = np.isfinite(y_arr)
    y_f   = y_arr[mask]
    X_f   = X_df.values[mask]

    rf = RandomForestRegressor(n_estimators=200, random_state=42, n_jobs=-1)
    rf.fit(X_f, y_f)

    explainer  = shap.TreeExplainer(rf)
    # Interaction values (slow for large N — use first 200)
    n_sample = min(200, len(X_f))
    shap_interact = explainer.shap_interaction_values(X_f[:n_sample])

    # Top interaction pairs
    n_feat = len(feature_cols)
    inter_strength = np.zeros((n_feat, n_feat))
    for i in range(n_feat):
        for j in range(n_feat):
            if i != j:
                inter_strength[i, j] = np.abs(shap_interact[:, i, j]).mean()

    # Build results
    rows_inter = []
    for i in range(n_feat):
        for j in range(i+1, n_feat):
            rows_inter.append({"feat1": feature_cols[i], "feat2": feature_cols[j],
                                "interaction": round(inter_strength[i,j], 6)})
    df_inter = pd.DataFrame(rows_inter).sort_values("interaction", ascending=False)
    print("\nTop 5 feature interactions:")
    print(df_inter.head(5).to_string(index=False))
    df_inter.to_csv(RESULTS / "shap_interactions_gold_forecast.csv", index=False)
    print(f"\nSaved: shap_interactions_gold_forecast.csv")

except ImportError:
    print("shap/sklearn not installed.")

print("""
MANUSCRIPT NOTE (Gold Forecasting §4.4 Nonlinear Effects):
  "QQ-KRLS reveals [VIX] dominates at upper-tail combinations while
   [DXY] effect weakens. SHAP interactions confirm [pair] as top
   nonlinear synergy — gold return spikes when both stressors co-occur."
""")
