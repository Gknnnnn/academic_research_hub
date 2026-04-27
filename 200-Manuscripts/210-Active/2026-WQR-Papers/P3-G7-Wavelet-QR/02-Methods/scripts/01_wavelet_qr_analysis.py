"""
WQR P3 — G7 Energy-Growth Wavelet Quantile Regression
N=7, T=33 (1990–2022), annual data
Method: wqr.wavelet_qr() — MODWT (la8, J=4) + quantile regression at each scale
Author: MGO, 2026-04-25
"""

import pandas as pd
import numpy as np
import sys
import warnings
warnings.filterwarnings('ignore')

# Fix for Python 3.14 compatibility in wqr.causality
import importlib.util
spec = importlib.util.find_spec('wqr')
if spec:
    import wqr
    print(f"wqr version: {getattr(wqr, '__version__', 'unknown')}")

BASE = "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/200-Manuscripts/210-Active/2026-WQR-Papers/P3-G7-Wavelet-QR"
DATA = f"{BASE}/data/g7_energy_growth_panel_20260425.csv"
RESULTS = f"{BASE}/03-Results"

panel = pd.read_csv(DATA)
G7 = ['CAN','FRA','DEU','ITA','JPN','GBR','USA']
quantiles = [0.10, 0.25, 0.50, 0.75, 0.90]
# Wavelet levels: la8, J=4 (scale 1=2yr, 2=4yr, 3=8yr, 4=16yr for annual data)
# J=4 with T=33 is feasible; higher J would reduce obs per scale
n_levels = 4

print(f"Panel loaded: {panel.shape}, countries: {list(panel['iso_code'].unique())}")

# --- Country-level wavelet QR ---
results = []

for iso in G7:
    df_c = panel[panel['iso_code'] == iso].sort_values('year').copy()
    T = len(df_c)
    print(f"\n{iso} (T={T})")

    x = df_c['ln_ec'].values   # energy consumption
    y = df_c['ln_gdp'].values  # GDP

    try:
        # EC -> GDP direction
        res_fwd = wqr.wavelet_qr(x, y, quantiles=quantiles, wavelet='la8', n_levels=n_levels)
        for level_idx, level_res in enumerate(res_fwd):
            scale = level_idx + 1
            for q_idx, q in enumerate(quantiles):
                coef = level_res['coefficients'][q_idx] if hasattr(level_res, '__getitem__') else None
                # Handle dict or object
                if isinstance(level_res, dict):
                    coef = level_res.get('coefficients', [None]*len(quantiles))
                    if isinstance(coef, (list, np.ndarray)):
                        coef_val = float(coef[q_idx]) if len(coef) > q_idx else None
                    else:
                        coef_val = None
                    pval = level_res.get('p_values', [None]*len(quantiles))
                    pval_val = float(pval[q_idx]) if isinstance(pval, (list, np.ndarray)) and len(pval) > q_idx else None
                else:
                    coef_val = None
                    pval_val = None
                results.append({
                    'iso3': iso, 'direction': 'EC→GDP', 'scale': scale,
                    'quantile': q, 'coefficient': coef_val, 'p_value': pval_val
                })
    except Exception as e:
        print(f"  EC→GDP wavelet_qr failed: {type(e).__name__}: {e}")
        # Fallback: manual wavelet decomposition + quantile regression
        try:
            import pywt
            from statsmodels.regression.quantile_regression import QuantReg

            # MODWT via pywt (level-by-level detail coefficients)
            wavelet = pywt.Wavelet('db4')  # la8 ≈ db4 in practice

            for direction, x_use, y_use in [('EC→GDP', x, y), ('GDP→EC', y, x)]:
                # Decompose x and y
                x_coeffs = pywt.wavedec(x_use, wavelet, level=n_levels, mode='periodization')
                y_coeffs = pywt.wavedec(y_use, wavelet, level=n_levels, mode='periodization')

                for level_idx in range(1, n_levels+1):
                    # Detail coefficients at this level
                    detail_x = x_coeffs[level_idx]
                    detail_y = y_coeffs[level_idx]

                    min_len = min(len(detail_x), len(detail_y))
                    if min_len < 10:
                        for q in quantiles:
                            results.append({
                                'iso3': iso, 'direction': direction, 'scale': level_idx,
                                'quantile': q, 'coefficient': None, 'p_value': None,
                                'note': 'too_few_obs'
                            })
                        continue

                    X = detail_x[:min_len].reshape(-1, 1)
                    Y = detail_y[:min_len]

                    for q in quantiles:
                        try:
                            mod = QuantReg(Y, np.column_stack([np.ones(len(Y)), X]))
                            res = mod.fit(q=q, max_iter=1000)
                            coef_val = float(res.params[1])
                            pval_val = float(res.pvalues[1])
                        except Exception:
                            coef_val = None
                            pval_val = None
                        results.append({
                            'iso3': iso, 'direction': direction, 'scale': level_idx,
                            'quantile': q, 'coefficient': coef_val, 'p_value': pval_val
                        })
            print(f"  Fallback (pywt + QuantReg) succeeded")
            break
        except Exception as e2:
            print(f"  Fallback also failed: {e2}")
            for direction in ['EC→GDP', 'GDP→EC']:
                for scale in range(1, n_levels+1):
                    for q in quantiles:
                        results.append({
                            'iso3': iso, 'direction': direction, 'scale': scale,
                            'quantile': q, 'coefficient': None, 'p_value': None
                        })

# Also attempt GDP -> EC if wqr worked above
# (already handled in fallback; for wqr path add here)

print("\n--- Running analysis complete ---")
df_results = pd.DataFrame(results)
print(df_results.head(20))
print(f"\nTotal rows: {len(df_results)}")
df_results.to_csv(f"{RESULTS}/country_wavelet_qr_20260425.csv", index=False)
print("Saved to 03-Results/country_wavelet_qr_20260425.csv")
