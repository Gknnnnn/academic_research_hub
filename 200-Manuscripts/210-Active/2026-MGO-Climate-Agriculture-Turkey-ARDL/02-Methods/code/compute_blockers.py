"""
compute_blockers.py — Python equivalent of compute_blockers.R
Özdemir & Işık (2026) — Climate-Agriculture-Turkey-ARDL

Fallback if R is unavailable. Requires:
  pip install statsmodels openpyxl pandas numpy scipy

Run from project root:
  python3 code/compute_blockers.py

Outputs: results/blockers_unit_root.csv
         results/blockers_bootstrap.csv
         results/blockers_appendix_A4.csv
"""

import sys, os, warnings
warnings.filterwarnings('ignore')
import numpy as np
import pandas as pd
from scipy import stats
from scipy.linalg import lstsq as scipy_lstsq
import statsmodels.tsa.stattools as sts
from statsmodels.regression.linear_model import OLS
from statsmodels.tools import add_constant
from statsmodels.stats.diagnostic import (het_breuschpagan,
                                           acorr_breusch_godfrey)
from statsmodels.stats.stattools import jarque_bera
from statsmodels.stats.anova import anova_lm

os.makedirs("results", exist_ok=True)

DATA = "data/turkey_climate_agri_1970_2021.xlsx"
raw  = pd.read_excel(DATA, sheet_name="Sayfa1")
raw.columns = ["year","alan_raw","ava","co2_raw","tsso_raw","tsa","pr"]

df = pd.DataFrame()
df['year']    = raw['year'].values
df['lnAVA']   = np.log(raw['ava'])
df['lnPR']    = np.log(raw['pr'])
df['lnTSA']   = np.log(raw['tsa'])
df['lnTSSO']  = np.log(raw['tsso_raw'])
df['lnALAN']  = np.log(raw['alan_raw'] / 10)
df['lnCO2']   = np.log(raw['co2_raw'])
df['TSA_anom'] = raw['tsa'] - raw['tsa'].mean()

print("Data loaded. T =", len(df))
print(df[['lnAVA','lnPR','lnTSA','lnTSSO','lnALAN','lnCO2']].describe().round(3).to_string())

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 1 — UNIT ROOT BATTERY
# ─────────────────────────────────────────────────────────────────────────────
print("\n=== BLOCK 1: UNIT ROOT BATTERY ===\n")

def dfgls(x, maxlag=4, trend='c'):
    """Elliott-Rothenberg-Stock (1996) DF-GLS test, constant-only."""
    x = np.asarray(x, dtype=float)
    T = len(x)
    c_bar = -7.0 if trend == 'c' else -13.5
    alpha = 1.0 + c_bar / T
    d = np.ones((T,1)) if trend=='c' else np.column_stack([np.ones(T), np.arange(1,T+1)])
    x_t = np.concatenate([[x[0]], x[1:] - alpha*x[:-1]])
    d_t = np.zeros_like(d)
    d_t[0] = d[0]
    for t in range(1,T):
        d_t[t] = d[t] - alpha*d[t-1]
    beta_gls, _, _, _ = scipy_lstsq(d_t, x_t)
    x_gls = x - d @ beta_gls
    res = sts.adfuller(x_gls, maxlag=maxlag, regression='nc', autolag=None)
    return res[0]  # test statistic

rows = []
for v in ['lnAVA','lnPR','lnTSA','lnTSSO','lnALAN','lnCO2']:
    x   = df[v].dropna().values
    dx  = np.diff(x)

    adf_l,  adf_lp  = sts.adfuller(x,  maxlag=4, regression='c',  autolag=None)[:2]
    adf_d,  adf_dp  = sts.adfuller(dx, maxlag=4, regression='c',  autolag=None)[:2]
    kpss_l, kpss_lp = sts.kpss(x,  regression='c', nlags='auto')[:2]
    kpss_d, kpss_dp = sts.kpss(dx, regression='c', nlags='auto')[:2]
    dfgls_l = dfgls(x,  maxlag=4)
    dfgls_d = dfgls(dx, maxlag=4)

    # Signs: ADF — more negative → reject unit root (I(0))
    #        KPSS — larger → reject stationarity (I(1))
    #        DF-GLS — < -1.94 (5%) → reject unit root (I(0))
    adf_sig   = '***' if adf_lp<0.01 else '**' if adf_lp<0.05 else '*' if adf_lp<0.10 else ''
    kpss_sig  = '***' if kpss_lp<0.01 else '**' if kpss_lp<0.05 else '*' if kpss_lp<0.10 else ''
    dfgls_sig = '***' if dfgls_l<-2.57 else '*' if dfgls_l<-1.94 else ''

    I_d = 'I(0)' if (adf_lp < 0.10 and kpss_lp > 0.05 and dfgls_l < -1.61) else 'I(1)'

    print(f"{v:<10}  ADF={adf_l:+7.3f}{adf_sig:<3}  "
          f"KPSS={kpss_l:6.3f}{kpss_sig:<3}  "
          f"DFGLS={dfgls_l:+7.3f}{dfgls_sig:<3}  -> {I_d}")

    rows.append({'Variable':v,'ADF_level':round(adf_l,3),'ADF_sig':adf_sig,
                 'ADF_diff':round(adf_d,3),'KPSS_level':round(kpss_l,3),
                 'KPSS_sig':kpss_sig,'KPSS_diff':round(kpss_d,3),
                 'DFGLS_level':round(dfgls_l,3),'DFGLS_sig':dfgls_sig,
                 'DFGLS_diff':round(dfgls_d,3),'I_d':I_d})

# Zivot-Andrews on lnPR
za_stat, za_p, za_cv, za_lag, za_bp = sts.zivot_andrews(
    df['lnPR'].dropna().values, maxlag=4, regression='c', autolag=None)
za_year = int(df['year'].iloc[za_bp]) if za_bp < len(df) else '?'
print(f"\nZivot-Andrews on lnPR: stat={za_stat:.3f}  p={za_p:.4f}  "
      f"break_obs={za_bp} (year≈{za_year})")
print("ZA crit: 1%=-5.34  5%=-4.80  10%=-4.58")
print("Verdict:", "REJECT unit root (I(0) with break OK)" if za_stat < -4.80
      else "FAIL to reject — break may drive apparent stationarity")

pd.DataFrame(rows).to_csv("results/blockers_unit_root.csv", index=False)
print("\nSaved: results/blockers_unit_root.csv")

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 2 — WILD BOOTSTRAP
# ─────────────────────────────────────────────────────────────────────────────
print("\n=== BLOCK 2: WILD BOOTSTRAP (B=2000) ===\n")

def build_cecm(data, tsa_col='lnTSA'):
    d = data.copy()
    for v in ['lnAVA','lnPR',tsa_col,'lnTSSO','lnALAN','lnCO2']:
        if v in d.columns:
            d[f'D_{v}'] = d[v].diff()
    d['LD1_DlnAVA']  = d['D_lnAVA'].shift(1)
    d['LD2_DlnAVA']  = d['D_lnAVA'].shift(2)
    d['LD3_DlnAVA']  = d['D_lnAVA'].shift(3)
    tsa_d = f'D_{tsa_col}'
    d['LD1_DlnTSA']  = d[tsa_d].shift(1)
    d['LD1_DlnALAN'] = d['D_lnALAN'].shift(1)
    for v in ['lnAVA','lnPR','lnTSSO','lnALAN','lnCO2']:
        d[f'L1_{v}'] = d[v].shift(1)
    tsa_level = tsa_col
    d[f'L1_{tsa_level}'] = d[tsa_level].shift(1)
    d_cc = d.dropna()
    Y = d_cc['D_lnAVA']
    X_cols = ['LD1_DlnAVA','LD2_DlnAVA','LD3_DlnAVA',
              f'D_lnPR', tsa_d,'LD1_DlnTSA',
              'D_lnTSSO','D_lnALAN','LD1_DlnALAN','D_lnCO2',
              'L1_lnAVA','L1_lnPR',f'L1_{tsa_level}','L1_lnTSSO','L1_lnALAN','L1_lnCO2']
    X_cols = [c for c in X_cols if c in d_cc.columns]
    X = add_constant(d_cc[X_cols])
    return OLS(Y, X).fit(), d_cc, X_cols

model, d_cc, X_cols = build_cecm(df)
delta1   = model.params['L1_lnAVA']
lr_vars  = ['L1_lnPR','L1_lnTSA','L1_lnTSSO','L1_lnALAN','L1_lnCO2']
lr_names = ['lnPR','lnTSA','lnTSSO','lnALAN','lnCO2']
theta_ols = {v: -model.params[v]/delta1 for v in lr_vars if v in model.params}

np.random.seed(42)
B      = 2000
fitted = model.fittedvalues.values
resid  = model.resid.values
n_obs  = len(fitted)
X_arr  = add_constant(d_cc[X_cols]).values
Y_arr  = d_cc['D_lnAVA'].values

boot_draws = {v: [] for v in lr_vars if v in model.params}

for b in range(B):
    w      = np.random.choice([-1.0, 1.0], size=n_obs)
    Y_boot = fitted + resid * w
    try:
        m_b = OLS(Y_boot, X_arr).fit()
        d1b = m_b.params[X_cols.index('L1_lnAVA')+1]
        if abs(d1b) < 1e-10: continue
        for v in boot_draws:
            idx = X_cols.index(v)+1
            boot_draws[v].append(-m_b.params[idx]/d1b)
    except Exception:
        pass

print(f"Bootstrap draws OK: {len(boot_draws['L1_lnPR'])}")
print()

boot_rows = []
for v, nm in zip(lr_vars, lr_names):
    if v not in boot_draws: continue
    draws     = np.array(boot_draws[v])
    theta_j   = theta_ols[v]
    boot_se   = np.std(draws)
    boot_lo   = np.percentile(draws, 2.5)
    boot_hi   = np.percentile(draws, 97.5)
    delta_se  = model.bse[v] / abs(delta1)
    boot_p    = 2*min(np.mean(draws>0), np.mean(draws<0))
    sig       = '***' if boot_p<0.01 else '**' if boot_p<0.05 else '*' if boot_p<0.10 else ''

    print(f"{nm:<12}  OLS={theta_j:+8.4f}  BootSE={boot_se:7.4f}  "
          f"CI=[{boot_lo:+8.4f},{boot_hi:+8.4f}]  DeltaSE={delta_se:7.4f}  "
          f"p={boot_p:.4f} {sig}")

    boot_rows.append({'Variable':nm,'OLS_theta':round(theta_j,4),
                      'Boot_SE':round(boot_se,4),
                      'Boot_CI_lo':round(boot_lo,4),'Boot_CI_hi':round(boot_hi,4),
                      'Delta_SE':round(delta_se,4),'Boot_p':round(boot_p,4),'Sig':sig})

pd.DataFrame(boot_rows).to_csv("results/blockers_bootstrap.csv", index=False)
print("\nSaved: results/blockers_bootstrap.csv")

pr = next(r for r in boot_rows if r['Variable']=='lnPR')
print(f"\nPRECIPITATION: survives bootstrap at 10% = "
      f"{'YES' if pr['Boot_p']<0.10 else 'NO'} (p={pr['Boot_p']:.4f})")

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 3 — APPENDIX A4
# ─────────────────────────────────────────────────────────────────────────────
print("\n=== BLOCK 3: APPENDIX A4 — TSA ANOMALY SPEC ===\n")

model_A4, d_A4, X_A4_cols = build_cecm(df, tsa_col='TSA_anom')
delta1_A4 = model_A4.params['L1_lnAVA']

# Bounds F-test
lv_A4 = ['L1_lnAVA','L1_lnPR','L1_TSA_anom','L1_lnTSSO','L1_lnALAN','L1_lnCO2']
lv_A4 = [v for v in lv_A4 if v in model_A4.params.index]
R = np.zeros((len(lv_A4), len(model_A4.params)))
for i, v in enumerate(lv_A4):
    j = list(model_A4.params.index).index(v)
    R[i,j] = 1
Ftest = model_A4.f_test(R)
F_val = float(Ftest.fvalue)
F_p   = float(Ftest.pvalue)
hl_A4 = np.log(0.5)/np.log(1+delta1_A4)

print(f"A4 Bounds F = {F_val:.3f}  p = {F_p:.4f}  "
      f"({'Cointegrated' if F_val>4.68 else 'Borderline'} at 1%)")
print(f"A4 ECT = {delta1_A4:.4f}  SE={model_A4.bse['L1_lnAVA']:.4f}  "
      f"half-life = {hl_A4:.2f} yr\n")

A4_rows = []
lr_A4v = ['L1_lnPR','L1_TSA_anom','L1_lnTSSO','L1_lnALAN','L1_lnCO2']
lr_A4n = ['lnPR','TSA_anom','lnTSSO','lnALAN','lnCO2']
for v, nm in zip(lr_A4v, lr_A4n):
    if v not in model_A4.params.index: continue
    theta_j = -model_A4.params[v] / delta1_A4
    se_j    = model_A4.bse[v] / abs(delta1_A4)
    t_j     = theta_j / se_j
    p_j     = 2*(1 - stats.t.cdf(abs(t_j), df=model_A4.df_resid))
    sig     = '***' if p_j<0.01 else '**' if p_j<0.05 else '*' if p_j<0.10 else ''
    print(f"  {nm:<14}  {theta_j:+8.4f}{sig:<3}  SE={se_j:.4f}  t={t_j:.3f}  p={p_j:.4f}")
    A4_rows.append({'Variable':nm,'A4_theta':round(theta_j,4),'SE':round(se_j,4),
                    't_stat':round(t_j,3),'p_value':round(p_j,4),'Sig':sig,
                    'F_bounds':round(F_val,3),'ECT':round(delta1_A4,4),
                    'Halflife':round(hl_A4,2)})

# Diagnostics
res_A4 = model_A4.resid
bg    = acorr_breusch_godfrey(model_A4, nlags=2)
jb    = jarque_bera(res_A4)
bpg   = het_breuschpagan(res_A4, model_A4.model.exog)
print(f"\n  BG LM(2):  chi2={bg[0]:.3f}  p={bg[1]:.3f}  "
      f"{'(pass)' if bg[1]>0.05 else '(FAIL)'}")
print(f"  J-Bera:    JB={jb[0]:.3f}    p={jb[1]:.3f}  "
      f"{'(pass)' if jb[1]>0.05 else '(FAIL)'}")
print(f"  BPG:       chi2={bpg[0]:.3f}  p={bpg[1]:.3f}  "
      f"{'(pass)' if bpg[1]>0.05 else '(FAIL)'}")

# Key check: temperature significance in A4
tsa_row = next((r for r in A4_rows if r['Variable']=='TSA_anom'), None)
if tsa_row:
    print(f"\n  TSA_anom theta = {tsa_row['A4_theta']:+.4f}  p = {tsa_row['p_value']:.4f}")
    if tsa_row['p_value'] > 0.10:
        print("  CONFIRMED: temperature INSIGNIFICANT under anomaly spec")
        print("  §5.4 'we expect... to be preserved' → CAN NOW READ 'is confirmed'")
    else:
        print("  WARNING: temperature SIGNIFICANT — §5.4 assertion FAILS; revise paper")

pd.DataFrame(A4_rows).to_csv("results/blockers_appendix_A4.csv", index=False)
print("\nSaved: results/blockers_appendix_A4.csv")

print("\n=== ALL COMPLETE — see results/blockers_*.csv ===")
print("\nEMBEDDING GUIDE:")
print("  Table 2 Panel A  →  blockers_unit_root.csv columns KPSS + DFGLS")
print("  Table 2 Panel B  →  blockers_bootstrap.csv columns Boot_SE + Boot_CI")
print("  Appendix Table A4 → blockers_appendix_A4.csv (paste as table)")
print("  §5.4 wording     →  update 'we expect' if TSA_anom p > 0.10")
