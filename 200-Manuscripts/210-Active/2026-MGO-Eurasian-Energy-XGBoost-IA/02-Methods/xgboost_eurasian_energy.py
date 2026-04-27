"""
Eurasian Energy Import Dependency — XGBoost + SHAP
Target: Inteligencia Artificial (SCIE Q2)
Author: Res. Asst. Dr. M. Gökhan Özdemir
Date: 2026-04-24
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score, mean_squared_error
import xgboost as xgb
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')
import warnings
warnings.filterwarnings('ignore')

# ── 0. Paths ──────────────────────────────────────────────────────────────────
BASE = "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/"
DATA_PATH = BASE + "2026-IGI-Eurasian-Energy-Geopolitics/02-Data/panel_eurasian_energy_v2_20260422.csv"
OUT_DIR   = BASE + "2026-MGO-Eurasian-Energy-XGBoost-IA/03-Results/"
import os; os.makedirs(OUT_DIR, exist_ok=True)

# ── 1. Load & Clean ───────────────────────────────────────────────────────────
df = pd.read_csv(DATA_PATH)
print(f"Raw: {df.shape}, Countries: {df['country'].nunique()}, Years: {df['year'].min()}–{df['year'].max()}")

# Features for XGBoost
FEATURES = ['ln_gdppc', 'trade', 'inflation', 'exrate_dep', 'res_rents',
            'ca_bal', 'exporter', 'fiscal_comp']
TARGET   = 'energy_dep'

# Drop rows missing DV or all features
df_model = df[['country', 'year', TARGET] + FEATURES].dropna(subset=[TARGET])
df_model = df_model.dropna(thresh=len(FEATURES) - 2)  # allow max 2 missing features

# Feature matrix: fill remaining NAs with column median
X_full = df_model[FEATURES].copy()
for col in FEATURES:
    X_full[col].fillna(X_full[col].median(), inplace=True)
y_full = df_model[TARGET].values

print(f"Model sample: {len(df_model)} obs, {df_model['country'].nunique()} countries")
print(f"Countries: {sorted(df_model['country'].unique())}")

# ── 2. Temporal Split: train 2000-2017, test 2018-2022 ────────────────────────
train_mask = df_model['year'] <= 2017
test_mask  = df_model['year'] >= 2018

X_train, y_train = X_full[train_mask], y_full[train_mask]
X_test,  y_test  = X_full[test_mask],  y_full[test_mask]
print(f"\nTrain: {len(X_train)} obs | Test: {len(X_test)} obs")

# ── 3. XGBoost (tuned) ────────────────────────────────────────────────────────
xgb_params = dict(
    n_estimators=300, max_depth=4, learning_rate=0.05,
    subsample=0.8, colsample_bytree=0.8,
    min_child_weight=3, gamma=0.1,
    base_score=0.5,          # fix SHAP/XGBoost version compatibility
    random_state=42, n_jobs=-1
)
xgb_model = xgb.XGBRegressor(**xgb_params)
xgb_model.fit(X_train, y_train,
              eval_set=[(X_test, y_test)],
              verbose=False)

y_pred_train = xgb_model.predict(X_train)
y_pred_test  = xgb_model.predict(X_test)

r2_train = r2_score(y_train, y_pred_train)
r2_test  = r2_score(y_test,  y_pred_test)
rmse_test = np.sqrt(mean_squared_error(y_test, y_pred_test))

print(f"\nXGBoost  Train R²={r2_train:.3f} | Test R²={r2_test:.3f} | RMSE={rmse_test:.2f} pp")

# ── 4. Random Forest Benchmark ────────────────────────────────────────────────
rf_model = RandomForestRegressor(n_estimators=300, max_depth=6, random_state=42, n_jobs=-1)
rf_model.fit(X_train, y_train)
r2_rf = r2_score(y_test, rf_model.predict(X_test))
rmse_rf = np.sqrt(mean_squared_error(y_test, rf_model.predict(X_test)))
print(f"Random Forest         Test R²={r2_rf:.3f} | RMSE={rmse_rf:.2f} pp")

# ── 5. OLS Benchmark ─────────────────────────────────────────────────────────
ols = LinearRegression().fit(X_train, y_train)
r2_ols = r2_score(y_test, ols.predict(X_test))
rmse_ols = np.sqrt(mean_squared_error(y_test, ols.predict(X_test)))
print(f"Pooled OLS            Test R²={r2_ols:.3f} | RMSE={rmse_ols:.2f} pp")

# ── 6. Save model comparison ──────────────────────────────────────────────────
model_comp = pd.DataFrame({
    'Model':    ['XGBoost', 'Random Forest', 'Pooled OLS'],
    'Train_R2': [r2_train, None, None],
    'Test_R2':  [r2_test, r2_rf, r2_ols],
    'RMSE':     [rmse_test, rmse_rf, rmse_ols]
})
model_comp.to_csv(OUT_DIR + "model_comparison_xgb.csv", index=False)
print(f"\nSaved: model_comparison_xgb.csv")

# ── 7. SHAP Analysis (XGBoost native pred_contribs — version-safe) ───────────
dmatrix_full = xgb.DMatrix(X_full.values, feature_names=FEATURES)
contribs     = xgb_model.get_booster().predict(dmatrix_full, pred_contribs=True)
shap_arr     = contribs[:, :-1].astype(float)   # (N, n_features); drop bias column
bias_val     = float(contribs[0, -1])

FEAT_LABELS = [
    'ln(GDP per capita)', 'Trade Openness (%)', 'Inflation (CPI %)',
    'Exch. Rate Depreciation', 'Resource Rents (% GDP)',
    'Current Account Balance', 'Net Energy Exporter', 'Fiscal Composite'
]
mean_abs_shap = np.abs(shap_arr).mean(axis=0)

# ── 7a. Bar chart — Mean |SHAP| ───────────────────────────────────────────────
order_asc = np.argsort(mean_abs_shap)   # ascending → bottom-to-top on horizontal bar

fig, ax = plt.subplots(figsize=(8, 5))
ax.barh([FEAT_LABELS[i] for i in order_asc], mean_abs_shap[order_asc], color='#1f77b4')
ax.set_xlabel("Mean |SHAP value| (percentage points)")
ax.set_title("Mean |SHAP| — Energy Import Dependency (Eurasian Panel)", fontsize=11, pad=10)
ax.spines[['top', 'right']].set_visible(False)
plt.tight_layout()
plt.savefig(OUT_DIR + "fig_shap_bar.tiff", dpi=300, bbox_inches='tight')
plt.savefig(OUT_DIR + "fig_shap_bar.png",  dpi=150, bbox_inches='tight')
plt.close()
print("Saved: fig_shap_bar.tiff")

# ── 7b. Beeswarm-style scatter ────────────────────────────────────────────────
rank_order = np.argsort(mean_abs_shap)[::-1]   # most important first (top row)
rng = np.random.default_rng(42)

fig, ax = plt.subplots(figsize=(9, 6))
sc_handle = None
for plot_pos, feat_idx in enumerate(rank_order):
    feat_vals = X_full.iloc[:, feat_idx].values.astype(float)
    sv        = shap_arr[:, feat_idx]
    v_min, v_max = feat_vals.min(), feat_vals.max()
    norm_vals = (feat_vals - v_min) / (v_max - v_min + 1e-9)
    y_jitter  = rng.uniform(-0.25, 0.25, size=len(sv))
    sc_handle = ax.scatter(sv, np.full(len(sv), plot_pos) + y_jitter,
                           c=norm_vals, cmap='RdBu_r', alpha=0.65, s=18,
                           vmin=0, vmax=1)

ax.set_yticks(range(len(FEATURES)))
ax.set_yticklabels([FEAT_LABELS[i] for i in rank_order], fontsize=9)
ax.axvline(0, color='black', lw=0.8, ls='--')
ax.set_xlabel("SHAP value (impact on energy import dependency, pp)")
ax.set_title("SHAP Beeswarm — Energy Import Dependency", fontsize=11, pad=10)
cbar = fig.colorbar(sc_handle, ax=ax, pad=0.01)
cbar.set_label("Feature value\n(low → high)", fontsize=8)
ax.spines[['top', 'right']].set_visible(False)
plt.tight_layout()
plt.savefig(OUT_DIR + "fig_shap_beeswarm.tiff", dpi=300, bbox_inches='tight')
plt.savefig(OUT_DIR + "fig_shap_beeswarm.png",  dpi=150, bbox_inches='tight')
plt.close()
print("Saved: fig_shap_beeswarm.tiff")

# ── 8. Country-level SHAP waterfall (3 representative countries) ──────────────
ctry_col = df_model['country'].values   # same row order as X_full / shap_arr

focus_countries = ['Turkiye', 'Russian Federation', 'Armenia']
for ctry in focus_countries:
    mask = ctry_col == ctry
    if mask.sum() == 0:
        matches = [c for c in np.unique(ctry_col) if ctry.lower() in c.lower()]
        if matches:
            ctry  = matches[0]
            mask  = ctry_col == ctry
        else:
            print(f"Country {ctry} not found — skipping waterfall")
            continue
    pos        = int(np.where(mask)[0][-1])        # index of most recent obs
    year_label = df_model.iloc[pos]['year']
    sv         = shap_arr[pos]
    pred       = float(xgb_model.predict(X_full.iloc[[pos]])[0])

    order_w = np.argsort(np.abs(sv))               # ascending → smallest at bottom
    colors  = ['#d73027' if v >= 0 else '#4575b4' for v in sv[order_w]]

    cumulative = bias_val
    lefts = []
    for v in sv[order_w]:
        lefts.append(cumulative)
        cumulative += v

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.barh([FEAT_LABELS[i] for i in order_w], sv[order_w],
            left=lefts, color=colors, height=0.6)
    ax.axvline(bias_val, color='grey',  lw=1.0, ls='--',
               label=f'E[f(X)] = {bias_val:.1f}')
    ax.axvline(pred,     color='black', lw=1.5, ls='-',
               label=f'f(x) = {pred:.1f}')
    ax.set_xlabel("SHAP contribution (percentage points)")
    ax.set_title(f"SHAP Waterfall — {ctry} ({int(year_label)})", fontsize=11, pad=10)
    ax.legend(fontsize=8)
    ax.spines[['top', 'right']].set_visible(False)
    plt.tight_layout()
    safe = ctry.replace('ü', 'u').replace('ö', 'o').replace(' ', '_')
    plt.savefig(OUT_DIR + f"fig_waterfall_{safe}.tiff", dpi=300, bbox_inches='tight')
    plt.savefig(OUT_DIR + f"fig_waterfall_{safe}.png",  dpi=150, bbox_inches='tight')
    plt.close()
    print(f"Saved: fig_waterfall_{safe}.tiff")

# ── 9. SHAP importance table ─────────────────────────────────────────────────
shap_importance = pd.DataFrame({
    'Feature':   FEAT_LABELS,
    'Mean_SHAP': mean_abs_shap
}).sort_values('Mean_SHAP', ascending=False)
shap_importance.to_csv(OUT_DIR + "shap_importance_energy.csv", index=False)
print(f"\nSaved: shap_importance_energy.csv")
print("\nTop SHAP features:")
print(shap_importance.to_string(index=False))

print("\n✅ Analysis complete. All outputs in 03-Results/")
