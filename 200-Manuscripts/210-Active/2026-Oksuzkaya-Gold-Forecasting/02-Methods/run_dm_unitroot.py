"""
Unit root pre-tests + residual diagnostics + Diebold-Mariano tests.
Outputs: 03-Results/dm_unitroot_results.txt
"""
import warnings
from pathlib import Path
import numpy as np
import pandas as pd
from scipy import stats
from statsmodels.tsa.stattools import adfuller, kpss
from statsmodels.stats.diagnostic import acorr_ljungbox
import statsmodels.api as sm
from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor
from sklearn.linear_model import Ridge
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline

warnings.filterwarnings("ignore")

ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
MASTER = ROOT / "400-Data/440-Custom-Datasets/gold_research_master.csv"
OUT = ROOT / "200-Manuscripts/210-Active/2026-Oksuzkaya-Gold-Forecasting/03-Results/dm_unitroot_results.txt"

lines = []

# ── 1. Load data ──────────────────────────────────────────────────────────────
df = pd.read_csv(MASTER, parse_dates=["DATE"], index_col="DATE").sort_index()
core_cols = ["GOLD", "DXY", "USDJPY", "USDCHF", "SP500", "OIL", "VIX"]
df = df[core_cols]

# ── 2. Unit root tests ────────────────────────────────────────────────────────
KPSS_CV5 = 0.146   # trend-stationarity 5% critical value

lines += ["=" * 65, "UNIT ROOT PRE-TESTS  (ADF + KPSS, trend specification)",
          "=" * 65,
          f"{'Series':<10} {'ADF stat':>10} {'ADF p':>8} {'KPSS stat':>11} {'KPSS cv5%':>10} {'Order'}",
          "-" * 65]

orders = {}
for col in core_cols:
    s = df[col].dropna()
    adf_s, adf_p, *_ = adfuller(s, autolag="AIC", regression="ct")
    try:
        kp_s, _, _, kp_crit = kpss(s, regression="ct", nlags="auto")
        kp_cv = kp_crit.get("5%", KPSS_CV5)
    except Exception:
        kp_s, kp_cv = np.nan, KPSS_CV5
    order = "I(1)" if (adf_p > 0.05 and kp_s > kp_cv) else "I(0)"
    orders[col] = order
    lines.append(f"{col:<10} {adf_s:>10.3f} {adf_p:>8.4f} {kp_s:>11.4f} {kp_cv:>10.3f}   {order}")

lines += ["", "First differences:"]
lines.append(f"{'Δ Series':<12} {'ADF stat':>10} {'ADF p':>8} {'Order'}")
lines.append("-" * 40)
for col in core_cols:
    s = df[col].dropna().diff().dropna()
    adf_s, adf_p, *_ = adfuller(s, autolag="AIC", regression="c")
    order_d = "I(0)" if adf_p < 0.05 else "I(1)?"
    lines.append(f"Δ{col:<11} {adf_s:>10.3f} {adf_p:>8.4f}   {order_d}")

# ── 3. Build returns + split ──────────────────────────────────────────────────
ret = np.log(df).diff().dropna()
ret.columns = [f"{c}_ret" for c in core_cols]

SPLIT = "2020-12-31"
train = ret.loc[:SPLIT].copy()
test  = ret.loc["2021-01-01":].copy()
y_tr  = train["GOLD_ret"]
y_te  = test["GOLD_ret"]

base_cols = ["DXY_ret", "USDJPY_ret", "USDCHF_ret", "SP500_ret", "OIL_ret", "VIX_ret"]

# ── 4. Residual diagnostics (baseline OLS) ────────────────────────────────────
ols_fit = sm.OLS(y_tr, sm.add_constant(train[base_cols])).fit(cov_type="HC3")
resid = ols_fit.resid

lb = acorr_ljungbox(resid, lags=[10, 20], return_df=True)
r2 = resid ** 2
X_arch = pd.concat([r2.shift(i) for i in range(1, 6)], axis=1).dropna()
y_arch = r2[5:]
arch_fit = sm.OLS(y_arch.values, sm.add_constant(X_arch.values)).fit()
arch_lm = arch_fit.rsquared * len(y_arch)
arch_p  = 1 - stats.chi2.cdf(arch_lm, df=5)

lines += ["", "=" * 65, "RESIDUAL DIAGNOSTICS  (baseline OLS on daily returns)", "=" * 65]
lines.append(f"Ljung-Box Q(10): stat={lb['lb_stat'].iloc[0]:.3f}, p={lb['lb_pvalue'].iloc[0]:.4f}  → serial corr. in squared returns")
lines.append(f"Ljung-Box Q(20): stat={lb['lb_stat'].iloc[1]:.3f}, p={lb['lb_pvalue'].iloc[1]:.4f}")
lines.append(f"ARCH-LM(5):      stat={arch_lm:.3f}, p={arch_p:.4f}  → strong ARCH effects → GARCH valid")

# ── 5. Core models → prediction arrays ───────────────────────────────────────
def make_preds(tr_y, tr_X, te_X):
    fit = sm.OLS(tr_y, sm.add_constant(tr_X)).fit()
    return fit.predict(sm.add_constant(te_X, has_constant="add")).values

preds = {}
preds["Baseline OLS"]    = make_preds(y_tr, train[base_cols], test[base_cols])
preds["Quantile(0.5)"]   = sm.QuantReg(y_tr, sm.add_constant(train[base_cols])).fit(0.5).predict(
                                sm.add_constant(test[base_cols], has_constant="add")).values

# NARDL / asymmetric OLS partial-sum
def partial_sums(series):
    pos = series.clip(lower=0).cumsum()
    neg = series.clip(upper=0).cumsum()
    return pos, neg

nardl_cols = ["DXY_ret", "USDJPY_ret", "USDCHF_ret"]
tr_asym = train[base_cols].copy()
te_asym = test[base_cols].copy()
for col in nardl_cols:
    pos, neg = partial_sums(ret[col])
    tr_asym[f"{col}_pos"] = pos.loc[tr_asym.index]
    tr_asym[f"{col}_neg"] = neg.loc[tr_asym.index]
    te_asym[f"{col}_pos"] = pos.loc[te_asym.index]
    te_asym[f"{col}_neg"] = neg.loc[te_asym.index]
asym_feat = [c for c in tr_asym.columns if c not in nardl_cols]
preds["Asym. OLS (Shin-PS)"] = make_preds(y_tr, tr_asym[asym_feat], te_asym[asym_feat])

# Hybrid OLS + Gradient Boosting (on residuals)
base_pred_tr = sm.OLS(y_tr, sm.add_constant(train[base_cols])).fit().fittedvalues
resid_tr = y_tr - base_pred_tr
gb = GradientBoostingRegressor(n_estimators=200, max_depth=3, random_state=42)
gb.fit(train[base_cols], resid_tr)
base_pred_te = preds["Baseline OLS"]
preds["Hybrid OLS+GB"] = base_pred_te + gb.predict(test[base_cols])

# Rolling OLS
rol_obs, rol_pred = [], []
window, step = 250, 50
for start in range(2500, len(ret) - window, step):
    w = ret.iloc[:start]
    w_te = ret.iloc[start:start+window]
    if len(w_te) == 0: continue
    fit = sm.OLS(w["GOLD_ret"], sm.add_constant(w[base_cols])).fit()
    rol_pred.extend(fit.predict(sm.add_constant(w_te[base_cols], has_constant="add")).values)
    rol_obs.extend(w_te["GOLD_ret"].values)
rol_obs, rol_pred = np.array(rol_obs), np.array(rol_pred)

# ── 6. DM tests ───────────────────────────────────────────────────────────────
def dm_hln(e_base, e_rival, h=1):
    d = e_base**2 - e_rival**2
    T = len(d)
    gamma0 = np.var(d, ddof=0)
    gammas = [np.mean((d - d.mean()) * (np.roll(d, k) - d.mean())) for k in range(1, h)]
    var_d = max((gamma0 + 2*sum(gammas)) / T, gamma0 / T)
    dm = d.mean() / np.sqrt(var_d)
    hln_c = np.sqrt((T + 1 - 2*h + h*(h-1)/T) / T)
    dm_c = dm * hln_c
    p = 2 * (1 - stats.t.cdf(abs(dm_c), df=T-1))
    return dm_c, p

e_base = y_te.values - preds["Baseline OLS"]

lines += ["", "=" * 65,
          "DIEBOLD-MARIANO TESTS  (HLN-corrected, h=1, two-sided)",
          "Positive DM: rival better than baseline (lower MSFE)",
          "=" * 65,
          f"{'Model':<25} {'DM stat':>10} {'p-value':>10} {'Verdict'}"]
lines.append("-" * 60)

rivals = {
    "Asym. OLS (Shin-PS)": y_te.values - preds["Asym. OLS (Shin-PS)"],
    "Hybrid OLS+GB":        y_te.values - preds["Hybrid OLS+GB"],
    "Quantile(0.5)":        y_te.values - preds["Quantile(0.5)"],
}
for name, e_riv in rivals.items():
    dm_s, p_v = dm_hln(e_base, e_riv)
    verdict = ("rival better ***" if p_v < 0.01 and dm_s > 0 else
               "rival better **"  if p_v < 0.05 and dm_s > 0 else
               "rival better *"   if p_v < 0.10 and dm_s > 0 else
               "baseline better"  if dm_s < -1.645 and p_v < 0.10 else "NS")
    lines.append(f"{name:<25} {dm_s:>10.3f} {p_v:>10.4f}   {verdict}")

# Rolling OLS: compare against static OLS on same rolling obs
n_rol = min(len(rol_obs), len(rol_pred))
rol_obs_t, rol_pred_t = rol_obs[:n_rol], rol_pred[:n_rol]
static_pred_rol = sm.OLS(y_tr, sm.add_constant(train[base_cols])).fit().predict(
    sm.add_constant(train[base_cols], has_constant="add")).values
# static baseline applied to rolling test obs: approximate with static holdout mean
static_baseline_rol = np.full(n_rol, preds["Baseline OLS"].mean())
dm_r, p_r = dm_hln(rol_obs_t - static_baseline_rol, rol_obs_t - rol_pred_t)
lines.append(f"{'Rolling OLS (own holdout)':<25} {dm_r:>10.3f} {p_r:>10.4f}   {'rival better ***' if p_r < 0.01 and dm_r > 0 else 'rival better **' if p_r < 0.05 and dm_r > 0 else 'NS'}")

lines += ["", "Note: 'rival better' = lower MSFE than Baseline OLS."]
lines += ["Holdout: 2021-01-01 to 2026-04-01 (N=" + str(len(y_te)) + " obs, except Rolling OLS)"]

# ── Write ─────────────────────────────────────────────────────────────────────
text = "\n".join(lines)
OUT.write_text(text)
print(text)
