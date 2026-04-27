"""
Proposal D — System GMM + Webb Wild Cluster Bootstrap
M. Gökhan Özdemir | Kırıkkale University | 2026-04-09
Panel: N=9 BRICS-T+MINT, T=2000-2024
"""
import warnings
warnings.filterwarnings('ignore')

import numpy as np
import pandas as pd
from linearmodels.panel import PanelOLS, BetweenOLS, RandomEffects
from linearmodels import IV2SLS
import statsmodels.api as sm
from scipy import stats

np.random.seed(42)

BASE = "/sessions/compassionate-wonderful-gauss/mnt/Akademik_Arastirma/200-Manuscripts/210-Active/2026-MGO-Merkez-Bankasi-Bagimsizligi"

# ─────────────────────────────────────────────────────────────────────────────
# 1. VERİ YÜKLEME
# ─────────────────────────────────────────────────────────────────────────────
print("="*65)
print("PROPOSAL D — System GMM + Webb Bootstrap")
print("="*65)

df = pd.read_csv(f"{BASE}/data/processed/panel_D_merged_v2.csv")
df = df[df['sovereign_spread_bps'].notna()].copy()

# Dönüşümler
df['ln_spread']    = np.log(df['sovereign_spread_bps'] + 400)
df['ln_debt']      = np.log(df['govt_debt_gdp'].clip(lower=0.01))
df['ln_gdp_pc']    = np.log(df['gdp_pc_ppp'].clip(lower=1))
df['d_cbi_erosion']= ((df['d_political_dismissal']==1) |
                      ((df['iso3']=='TUR') & df['year'].between(2019,2022))).astype(int)

# Panel index
df = df.set_index(['iso3','year'])

CONTROLS = ['inflation_cpi','gdp_growth','govt_debt_gdp',
            'trade_openness','ln_gdp_pc','d_gfc','d_covid']

print(f"\nPanel: N={df.index.get_level_values(0).nunique()} ülke, "
      f"T={df.index.get_level_values(1).nunique()} yıl, "
      f"obs={len(df)}")
print(f"Ülkeler: {sorted(df.index.get_level_values(0).unique())}\n")

# ─────────────────────────────────────────────────────────────────────────────
# 2. M1 — 2-YÖN SABİT ETKİ (2-Way FE)
# ─────────────────────────────────────────────────────────────────────────────
print("="*65)
print("[M1] 2-Way FE + Driscoll-Kraay SE")
print("="*65)

dep   = df['ln_spread']
exog  = sm.add_constant(df[['cbi_lvaw'] + CONTROLS])

m1_fit = PanelOLS(
    dep, df[['cbi_lvaw'] + CONTROLS],
    entity_effects=True, time_effects=True, drop_absorbed=True
).fit(cov_type='kernel', kernel='bartlett', bandwidth=4)

print(m1_fit.summary.tables[1])
cbi_coef_m1 = m1_fit.params['cbi_lvaw']
cbi_se_m1   = m1_fit.std_errors['cbi_lvaw']
cbi_p_m1    = m1_fit.pvalues['cbi_lvaw']
print(f"\n→ CBI coef: {cbi_coef_m1:.4f} | SE: {cbi_se_m1:.4f} | p: {cbi_p_m1:.4f}")

# ─────────────────────────────────────────────────────────────────────────────
# 3. WEBB WILD CLUSTER BOOTSTRAP (zorunlu, N=9)
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*65)
print("[WEBB] Wild Cluster Bootstrap — CBI katsayısı (B=4999)")
print("(N=9 küme → asimptotik SE geçersiz; Webb 2023 ağırlıkları)")
print("="*65)

df_reset = df.reset_index()
countries = sorted(df_reset['iso3'].unique())
N_clusters = len(countries)

# Within dönüşümü (entity + time demeaning)
def within_transform(data, dep_var, indep_vars):
    d = data.copy()
    for col in [dep_var] + indep_vars:
        d[col + '_wt'] = (d[col]
                          - d.groupby('iso3')[col].transform('mean')
                          - d.groupby('year')[col].transform('mean')
                          + d[col].mean())
    return d

df_w = within_transform(df_reset, 'ln_spread',
                         ['cbi_lvaw'] + CONTROLS)
dep_wt  = df_w['ln_spread_wt'].values
X_wt    = df_w[['cbi_lvaw_wt'] + [c+'_wt' for c in CONTROLS]].values
iso_arr = df_w['iso3'].values

# OLS (within modeli)
XtX_inv = np.linalg.pinv(X_wt.T @ X_wt)
beta_ols = XtX_inv @ X_wt.T @ dep_wt
resid    = dep_wt - X_wt @ beta_ols

# Webb (2023) ağırlık seti: 6 deterministik nokta
WEBB_WEIGHTS = np.array([-np.sqrt(3/2), -np.sqrt(2/2), -np.sqrt(1/2),
                          np.sqrt(1/2),   np.sqrt(2/2),  np.sqrt(3/2)])

B = 4999
boot_coefs = np.empty(B)
rng = np.random.default_rng(42)

for b in range(B):
    # Her kümeye rastgele Webb ağırlığı ata
    w_draw = rng.choice(WEBB_WEIGHTS, size=N_clusters, replace=True)
    w_map  = {c: w_draw[i] for i, c in enumerate(countries)}
    w_obs  = np.array([w_map[c] for c in iso_arr])

    # Ağırlıklı artıklar ile yeni Y*
    y_star  = X_wt @ beta_ols + resid * w_obs
    beta_b  = XtX_inv @ X_wt.T @ y_star
    boot_coefs[b] = beta_b[0]   # CBI katsayısı

# Bootstrap istatistikleri
t_obs    = beta_ols[0] / np.std(boot_coefs)
p_webb   = np.mean(np.abs(boot_coefs - beta_ols[0]) >= abs(beta_ols[0]))
ci_low   = np.percentile(boot_coefs, 2.5)
ci_high  = np.percentile(boot_coefs, 97.5)

print(f"\nCBI katsayısı (OLS within): {beta_ols[0]:.4f}")
print(f"Bootstrap p-değeri (H0: β=0): {p_webb:.4f}")
print(f"95% Webb Bootstrap CI: [{ci_low:.4f}, {ci_high:.4f}]")
sig = "***" if p_webb < 0.01 else ("**" if p_webb < 0.05 else ("*" if p_webb < 0.10 else "NS"))
print(f"Anlamlılık: {sig}")

# ─────────────────────────────────────────────────────────────────────────────
# 4. M4 — SYSTEM GMM (pydynpd — Blundell-Bond)
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*65)
print("[M4] System GMM — Blundell-Bond (pydynpd)")
print("="*65)

try:
    from pydynpd import regression

    gmm_formula = ("ln_spread ~ lag(ln_spread,1) | cbi_lvaw inflation_cpi "
                   "gdp_growth govt_debt_gdp ln_gdp_pc d_gfc d_covid "
                   "| gmm(ln_spread,2,4) gmm(cbi_lvaw,2,4) | timedumm")

    df_gmm = df_reset[['iso3','year','ln_spread','cbi_lvaw',
                        'inflation_cpi','gdp_growth','govt_debt_gdp',
                        'trade_openness','ln_gdp_pc','d_gfc','d_covid']].dropna()

    m4 = regression.abond(gmm_formula, df_gmm, ['iso3','year'])
    print(m4.summary)

    # Sargan testi
    print(f"\nSargan p-değeri: {m4.sargan:.4f}")
    print(f"AR(1) p: {m4.AR1_p:.4f} | AR(2) p: {m4.AR2_p:.4f}")
    print("→ Geçerlilik: AR(1)<0.05 ✓ ve AR(2)>0.10 ✓ gerekli")

    gmm_ok = True
    gmm_cbi = None
    for key in dir(m4):
        if 'param' in key.lower() or 'coef' in key.lower():
            try:
                arr = getattr(m4, key)
                if hasattr(arr, '__len__') and len(arr) > 0:
                    print(f"  {key}: {arr}")
            except:
                pass

except Exception as e:
    print(f"⚠  System GMM hatası: {e}")
    print("   → Difference GMM (Arellano-Bond) ile devam edilecek")
    gmm_ok = False

# ─────────────────────────────────────────────────────────────────────────────
# 5. ROBUSTNESS: NGA EXCLUSİON (trade_openness boşluğu)
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*65)
print("[ROB] Robustness: ex-NGA (trade_openness boşluğu)")
print("="*65)

df_exnga = df[df.index.get_level_values(0) != 'NGA'].copy()
m_rob_nga = PanelOLS(
    df_exnga['ln_spread'], df_exnga[['cbi_lvaw'] + CONTROLS],
    entity_effects=True, time_effects=True, drop_absorbed=True
).fit(cov_type='kernel', kernel='bartlett', bandwidth=4)

cbi_nga = m_rob_nga.params['cbi_lvaw']
cbi_nga_p = m_rob_nga.pvalues['cbi_lvaw']
print(f"ex-NGA → CBI coef: {cbi_nga:.4f}  p={cbi_nga_p:.4f}")

# ─────────────────────────────────────────────────────────────────────────────
# 6. SONUÇ TABLOSU
# ─────────────────────────────────────────────────────────────────────────────
print("\n" + "="*65)
print("ÖZET SONUÇLAR — CBI katsayısı")
print("="*65)
print(f"{'Model':<30} {'β(CBI)':<10} {'SE':<8} {'p':<8} {'Not'}")
print("-"*65)
print(f"{'M1 2FE+DK':<30} {cbi_coef_m1:<10.4f} {cbi_se_m1:<8.4f} {cbi_p_m1:<8.4f} asimptotik")
print(f"{'Webb Bootstrap (B=4999)':<30} {beta_ols[0]:<10.4f} {'-':<8} {p_webb:<8.4f} Webb 2023 {sig}")
print(f"{'Rob. ex-NGA':<30} {cbi_nga:<10.4f} {'-':<8} {cbi_nga_p:<8.4f} DK SE")
print(f"\nWebb 95% CI: [{ci_low:.4f}, {ci_high:.4f}]")

# Sonuçları kaydet
results_dict = {
    'model':['M1_2FE_DK','Webb_Bootstrap','Rob_exNGA'],
    'cbi_coef':[cbi_coef_m1, beta_ols[0], cbi_nga],
    'se':[cbi_se_m1, np.nan, np.nan],
    'pvalue':[cbi_p_m1, p_webb, cbi_nga_p],
    'ci_low':[np.nan, ci_low, np.nan],
    'ci_high':[np.nan, ci_high, np.nan],
    'note':['Driscoll-Kraay SE','Webb 2023 B=4999','DK SE, N=8']
}
df_res = pd.DataFrame(results_dict)
out_path = f"{BASE}/data/processed/GMM_Webb_Results_2026-04-09.csv"
df_res.to_csv(out_path, index=False)
print(f"\n✅ Sonuçlar kaydedildi: GMM_Webb_Results_2026-04-09.csv")

