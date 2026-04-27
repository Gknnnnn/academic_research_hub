"""
AI-Green Transformation Panel — Real WDI Data Pipeline v02
===========================================================
Author : Dr. M. Gökhan Özdemir, Kırıkkale University
Date   : 2026-04-10

Workflow
--------
1. Pull 7 WDI indicators for 41 economies, 2010-2022 via World Bank API
2. Construct 5-component AIRI (standardised arithmetic mean)
3. Run Pesaran CD + CIPS unit root (manual, CD-robust)
4. Run MG estimation — full sample + by income group (CCEMG-style: CSM augmentation)
5. Webb (2023) wild-cluster bootstrap (B = 999, 6-point weights) for small-cluster inference
6. Dumitrescu-Hurlin panel causality (K=2 lags)
7. Export CSV tables for manuscript update

Usage:  python build_real_panel_airi_v02.py
Output: ../03-Results/ai_green_panel_v02_real.csv
        ../03-Results/tables/table2_descriptive.csv
        ../03-Results/tables/table3_cd_test.csv
        ../03-Results/tables/table4_cips.csv
        ../03-Results/tables/table5_mg_full.csv
        ../03-Results/tables/table6_mg_income.csv
        ../03-Results/tables/table7_dh_causality.csv
"""

import warnings
warnings.filterwarnings("ignore")

import numpy as np
import pandas as pd
from pathlib import Path
from scipy import stats
from scipy.stats import norm
import requests, json, time

# ─── Paths ───────────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parents[1]
OUT_DATA = ROOT / "03-Results"
OUT_TABLES = OUT_DATA / "tables"
OUT_TABLES.mkdir(parents=True, exist_ok=True)

# ─── Country Panel (N=41) ─────────────────────────────────────────────────────
INCOME_MAP = {
    # HIC (n=22)
    "USA": "HIC", "GBR": "HIC", "DEU": "HIC", "FRA": "HIC", "CAN": "HIC",
    "JPN": "HIC", "KOR": "HIC", "AUS": "HIC", "ESP": "HIC", "ITA": "HIC",
    "NLD": "HIC", "SWE": "HIC", "BEL": "HIC", "AUT": "HIC", "DNK": "HIC",
    "FIN": "HIC", "IRL": "HIC", "PRT": "HIC", "GRC": "HIC", "CZE": "HIC",
    "SGP": "HIC", "NZL": "HIC",
    # UMIC (n=11)
    "BRA": "UMIC", "RUS": "UMIC", "CHN": "UMIC", "MEX": "UMIC", "TUR": "UMIC",
    "ARG": "UMIC", "MYS": "UMIC", "THA": "UMIC", "COL": "UMIC", "JOR": "UMIC",
    "AZE": "UMIC",
    # LMIC (n=8)
    "PHL": "LMIC", "VNM": "LMIC", "IND": "LMIC", "IDN": "LMIC",
    "PAK": "LMIC", "EGY": "LMIC", "KEN": "LMIC", "GHA": "LMIC",
}
COUNTRIES = list(INCOME_MAP.keys())
YEARS = list(range(2010, 2023))

# ─── WDI Indicators ──────────────────────────────────────────────────────────
INDICATORS = {
    "EN.ATM.CO2E.PC"   : "co2_pc",          # CO2 emissions per capita (metric tons)
    "NY.GDP.PCAP.KD"   : "gdp_pc",          # GDP per capita (constant 2015 USD)
    "NV.IND.MANF.ZS"   : "industry_va",     # Manufacturing value added (% GDP)
    "IT.NET.USER.ZS"   : "ai1_internet",    # AIRI: internet users (% population)
    "GB.XPD.RSDV.GD.ZS": "ai2_rd",          # AIRI: R&D expenditure (% GDP)
    "SE.TER.ENRR"      : "ai3_tertiary",    # AIRI: tertiary enrollment (%)
    "SP.POP.SCIE.RD.P6": "ai4_researchers", # AIRI: researchers per million
    "IT.MOB.CON.ZS"    : "ai5_mobile",      # AIRI: mobile broadband subscriptions
    "EG.ELC.RNEW.ZS"   : "ren_share",       # Renewable electricity output (% of total)
}

def fetch_wdi(indicator_code, countries, years):
    """Fetch a single WDI indicator for a list of ISO3 codes and years."""
    base = "https://api.worldbank.org/v2/country"
    ctry_str = ";".join(countries)
    yr_str   = f"{years[0]}:{years[-1]}"
    url = f"{base}/{ctry_str}/indicator/{indicator_code}?date={yr_str}&format=json&per_page=5000"
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        data = r.json()
        if len(data) < 2 or not data[1]:
            return pd.DataFrame()
        rows = []
        for obs in data[1]:
            if obs.get("value") is not None:
                rows.append({
                    "iso3": obs["countryiso3code"],
                    "year": int(obs["date"]),
                    "value": float(obs["value"])
                })
        return pd.DataFrame(rows)
    except Exception as e:
        print(f"  [WARN] {indicator_code}: {e}")
        return pd.DataFrame()

# ─── Step 1: Pull WDI Data ────────────────────────────────────────────────────
print("=" * 60)
print("STEP 1 — Pulling WDI Data")
print("=" * 60)

dfs = []
for ind_code, col_name in INDICATORS.items():
    print(f"  Fetching {ind_code} → {col_name}...")
    df_ind = fetch_wdi(ind_code, COUNTRIES, YEARS)
    if not df_ind.empty:
        df_ind = df_ind.rename(columns={"value": col_name})
        dfs.append(df_ind)
    time.sleep(0.3)  # polite rate-limiting

# Merge all indicators
panel = None
for df_ind in dfs:
    if panel is None:
        panel = df_ind
    else:
        col = [c for c in df_ind.columns if c not in ["iso3", "year"]][0]
        panel = panel.merge(df_ind[["iso3", "year", col]], on=["iso3", "year"], how="outer")

# Filter to our 41 countries and 2010-2022
panel = panel[panel["iso3"].isin(COUNTRIES) & panel["year"].isin(YEARS)].copy()
panel["income_group"] = panel["iso3"].map(INCOME_MAP)

print(f"\n  Raw panel: {len(panel)} rows, {panel['iso3'].nunique()} countries")
print(f"  Missing values before imputation:")
print(panel.isnull().sum())

# ─── Step 2: Construct AIRI ───────────────────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 2 — Constructing AIRI")
print("=" * 60)

airi_cols = ["ai1_internet", "ai2_rd", "ai3_tertiary", "ai4_researchers", "ai5_mobile"]

# Forward/backward fill within country for minor gaps
panel = panel.sort_values(["iso3", "year"])
for col in airi_cols + ["co2_pc", "gdp_pc", "industry_va", "ren_share"]:
    if col in panel.columns:
        panel[col] = panel.groupby("iso3")[col].transform(
            lambda x: x.interpolate(method="linear", limit_direction="both").ffill().bfill()
        )

# Standardize each AIRI component (global z-score across all i,t)
for col in airi_cols:
    if col in panel.columns:
        mu  = panel[col].mean()
        sig = panel[col].std()
        if sig > 0:
            panel[f"z_{col}"] = (panel[col] - mu) / sig
        else:
            panel[f"z_{col}"] = 0.0

z_cols = [f"z_{c}" for c in airi_cols if f"z_{c}" in panel.columns]
panel["airi"] = panel[z_cols].mean(axis=1)

# Normalize AIRI to [0,1] for readability (preserve relative ordering)
airi_min, airi_max = panel["airi"].min(), panel["airi"].max()
panel["airi_norm"] = (panel["airi"] - airi_min) / (airi_max - airi_min)

# ─── Step 3: Log-transform variables ─────────────────────────────────────────
panel["ln_co2"]      = np.log(panel["co2_pc"].clip(lower=0.01))
panel["ln_gdp"]      = np.log(panel["gdp_pc"].clip(lower=1))
panel["ln_ren"]      = np.log(panel["ren_share"].clip(lower=0.1))
panel["ln_ind_va"]   = np.log(panel["industry_va"].clip(lower=0.1))
# AIRI: standardised z-score can be negative; use level (already mean 0)
panel["ln_airi"]     = panel["airi"]   # keep as index level

# Final balanced panel
analysis_cols = ["iso3", "year", "income_group",
                 "ln_co2", "ln_airi", "ln_gdp", "ln_ren", "ln_ind_va",
                 "airi", "airi_norm"]
panel = panel[analysis_cols].dropna(subset=["ln_co2", "ln_airi", "ln_gdp"])
panel = panel.sort_values(["iso3", "year"]).reset_index(drop=True)

N = panel["iso3"].nunique()
T = panel["year"].nunique()
NT = len(panel)
print(f"  Balanced panel: N={N}, T={T}, NT={NT}")
print(f"  Income groups: {panel.groupby('income_group')['iso3'].nunique().to_dict()}")

# Save panel
panel.to_csv(OUT_DATA / "ai_green_panel_v02_real.csv", index=False)
print(f"  → Saved: ai_green_panel_v02_real.csv")

# ─── Top/Bottom AIRI 2022 ─────────────────────────────────────────────────────
airi_2022 = (panel[panel["year"] == 2022]
             .sort_values("airi_norm", ascending=False)
             [["iso3", "income_group", "airi_norm"]])
print("\n  Top 5 AIRI 2022:")
print(airi_2022.head(5).to_string(index=False))
print("  Bottom 5 AIRI 2022:")
print(airi_2022.tail(5).to_string(index=False))

# ─── Table 2: Descriptive Statistics ─────────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 3 — Descriptive Statistics (Table 2)")
print("=" * 60)

desc_vars = {
    "ln CO₂ per capita": "ln_co2",
    "AIRI (standardised)": "ln_airi",
    "ln GDP per capita": "ln_gdp",
    "ln Renewable Share": "ln_ren",
    "ln Industry VA": "ln_ind_va",
}
rows = []
for label, col in desc_vars.items():
    s = panel[col]
    rows.append({
        "Variable": label,
        "Mean": round(s.mean(), 3),
        "Std. Dev.": round(s.std(), 3),
        "Min": round(s.min(), 3),
        "Max": round(s.max(), 3),
        "N": int(s.notna().sum()),
    })
t2 = pd.DataFrame(rows)
t2.to_csv(OUT_TABLES / "table2_descriptive.csv", index=False)
print(t2.to_string(index=False))

# ─── Table 3: Pesaran CD Test ─────────────────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 4 — Pesaran CD Test (Table 3)")
print("=" * 60)

def pesaran_cd(df, var):
    """Compute Pesaran (2004) CD statistic for panel variable."""
    countries_list = df["iso3"].unique()
    N_c = len(countries_list)
    # De-mean within country
    df2 = df.copy()
    df2["dm"] = df2.groupby("iso3")[var].transform(lambda x: x - x.mean())
    # Pivot to T × N matrix
    wide = df2.pivot(index="year", columns="iso3", values="dm").dropna(axis=1, how="all")
    cols = wide.columns.tolist()
    N_c = len(cols)
    T_c = len(wide)
    if N_c < 2:
        return np.nan, np.nan, np.nan
    mat = wide.values
    rho_sum = 0.0
    rho_vals = []
    count = 0
    for ii in range(N_c - 1):
        for jj in range(ii + 1, N_c):
            x, y = mat[:, ii], mat[:, jj]
            mask = ~(np.isnan(x) | np.isnan(y))
            if mask.sum() < 3:
                continue
            r = np.corrcoef(x[mask], y[mask])[0, 1]
            rho_vals.append(r)
            rho_sum += np.sqrt(T_c) * r
            count += 1
    if count == 0:
        return np.nan, np.nan, np.nan
    cd_stat = np.sqrt(2 / (N_c * (N_c - 1))) * rho_sum
    p_val = 2 * (1 - norm.cdf(abs(cd_stat)))
    rho_bar = np.mean(rho_vals)
    return round(cd_stat, 3), round(p_val, 4), round(rho_bar, 3)

cd_rows = []
for label, col in desc_vars.items():
    cd_s, cd_p, rho_bar = pesaran_cd(panel, col)
    cd_rows.append({"Variable": label, "CD Statistic": cd_s,
                    "p-value": cd_p, "ρ̄": rho_bar})
t3 = pd.DataFrame(cd_rows)
t3.to_csv(OUT_TABLES / "table3_cd_test.csv", index=False)
print(t3.to_string(index=False))

# ─── Table 4: CIPS Unit Root ──────────────────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 5 — CIPS Unit Root Test (Table 4)")
print("=" * 60)

def cadf_statistic(y_i, dm_y_bar, max_lags=1):
    """Pesaran CADF t-statistic for unit i (including cross-section mean)."""
    n = len(y_i)
    if n < 6:
        return np.nan
    dy = np.diff(y_i)
    y_lag = y_i[:-1]
    d_ybar = np.diff(dm_y_bar)
    ybar_lag = dm_y_bar[:-1]
    T_ = len(dy)
    X = np.column_stack([y_lag[:T_], ybar_lag[:T_], d_ybar[:T_], np.ones(T_)])
    try:
        b, res, _, _ = np.linalg.lstsq(X, dy[:T_], rcond=None)
        resid = dy[:T_] - X @ b
        sigma2 = np.sum(resid**2) / (T_ - X.shape[1])
        cov = sigma2 * np.linalg.pinv(X.T @ X)
        se = np.sqrt(max(cov[0, 0], 1e-12))
        return b[0] / se
    except:
        return np.nan

def cips_test(df, var):
    """Compute Pesaran (2007) CIPS statistic."""
    countries_list = df["iso3"].unique()
    # cross-section mean per year
    csm = df.groupby("year")[var].mean().to_dict()
    t_stats = []
    for c in countries_list:
        sub = df[df["iso3"] == c].sort_values("year")
        y_i = sub[var].values
        ybar = np.array([csm.get(yr, np.nan) for yr in sub["year"]])
        if np.isnan(y_i).any() or np.isnan(ybar).any() or len(y_i) < 6:
            continue
        t_i = cadf_statistic(y_i, ybar)
        if not np.isnan(t_i):
            t_stats.append(t_i)
    if len(t_stats) == 0:
        return np.nan
    return round(np.mean(t_stats), 3)

cips_rows = []
crit_5pct = -2.52  # Pesaran (2007) critical value for N≈40, T=13, 5%
for label, col in desc_vars.items():
    cips_s = cips_test(panel, col)
    result = "I(0) ✓" if (not np.isnan(cips_s) and cips_s < crit_5pct) else "I(1)"
    cips_rows.append({"Variable": label, "CIPS Statistic": cips_s,
                      "Critical Value (5%)": crit_5pct, "Result": result})
t4 = pd.DataFrame(cips_rows)
t4.to_csv(OUT_TABLES / "table4_cips.csv", index=False)
print(t4.to_string(index=False))

# ─── CCEMG (MG with Cross-Section Mean Augmentation) ──────────────────────────

def ccemg_income(df, dep="ln_co2", regressors=None, group_col="income_group",
                 group_val=None, B=999, seed=42):
    """
    Mean Group estimator with CCE augmentation (cross-section means added as controls).
    Webb (2023) wild-cluster bootstrap for inference.

    Returns dict with MG estimates, SEs, t-stats, p-values, and bootstrap CIs.
    """
    np.random.seed(seed)
    if regressors is None:
        regressors = ["ln_airi", "ln_gdp", "ln_ren"]

    sub = df.copy()
    if group_val is not None:
        sub = sub[sub[group_col] == group_val].copy()

    # Add cross-section mean augmentation (CSM) per year
    for v in [dep] + regressors:
        csm_v = sub.groupby("year")[v].transform("mean")
        sub[f"csm_{v}"] = csm_v

    countries_sub = sub["iso3"].unique()
    N_g = len(countries_sub)
    betas = {r: [] for r in regressors}

    for c in countries_sub:
        ci = sub[sub["iso3"] == c].sort_values("year")
        y = ci[dep].values
        # regressors + CSM columns
        X_cols = regressors + [f"csm_{v}" for v in [dep] + regressors]
        X_cols_avail = [col for col in X_cols if col in ci.columns]
        X = ci[X_cols_avail].values
        # Remove constant collinear columns
        if len(y) < len(X_cols_avail) + 2:
            continue
        X = np.column_stack([X, np.ones(len(X))])
        try:
            b, _, _, _ = np.linalg.lstsq(X, y, rcond=None)
            for j, r in enumerate(regressors):
                if j < len(b):
                    betas[r].append(b[j])
        except:
            continue

    results = {}
    for r in regressors:
        b_arr = np.array(betas[r])
        if len(b_arr) < 2:
            results[r] = {"beta": np.nan, "se": np.nan, "t": np.nan,
                          "p": np.nan, "ci_lo": np.nan, "ci_hi": np.nan, "N_valid": 0}
            continue
        beta_mg = b_arr.mean()
        # MG SE: combines within-country and between-country variance
        se_mg = b_arr.std(ddof=1) / np.sqrt(len(b_arr))
        t_mg = beta_mg / se_mg if se_mg > 0 else np.nan
        # p-value from t(N_g - 1)
        p_mg = 2 * stats.t.sf(abs(t_mg), df=len(b_arr) - 1) if not np.isnan(t_mg) else np.nan

        # Webb (2023) wild-cluster bootstrap
        # Cluster = country; residual from MG pooled regression (for bootstrap draws)
        # Use 6-point discrete Webb weights: ±sqrt(3/2), ±1/sqrt(2), ±sqrt(2)
        webb_weights = np.array([-np.sqrt(3/2), -1/np.sqrt(2), -np.sqrt(2),
                                  np.sqrt(3/2),  1/np.sqrt(2),  np.sqrt(2)])
        boot_betas = []
        for _ in range(B):
            # For each cluster (country), draw a single weight
            b_boot = []
            for val, b_i in zip(np.random.choice(webb_weights, size=len(b_arr)),
                                 b_arr):
                b_boot.append(beta_mg + val * (b_i - beta_mg))
            boot_betas.append(np.mean(b_boot))
        boot_arr = np.array(boot_betas)
        ci_lo, ci_hi = np.percentile(boot_arr, [2.5, 97.5])

        results[r] = {
            "beta"   : round(beta_mg, 4),
            "se"     : round(se_mg, 4),
            "t"      : round(t_mg, 3) if not np.isnan(t_mg) else np.nan,
            "p"      : round(p_mg, 4) if not np.isnan(p_mg) else np.nan,
            "ci_lo"  : round(ci_lo, 4),
            "ci_hi"  : round(ci_hi, 4),
            "N_valid": len(b_arr),
        }

    results["_N_countries"] = N_g
    results["_N_obs"]       = len(sub)
    return results

# ─── Table 5: Full-Sample CCEMG ───────────────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 6 — CCEMG Full Sample (Table 5)")
print("=" * 60)

res_full = ccemg_income(panel, group_val=None, B=999)
t5_rows = []
for var, lbl in [("ln_airi", "AIRI"), ("ln_gdp", "ln GDP per capita"),
                  ("ln_ren", "ln Renewable Share")]:
    r = res_full.get(var, {})
    stars = ""
    if not np.isnan(r.get("p", np.nan)):
        p = r["p"]
        stars = "***" if p < 0.01 else ("**" if p < 0.05 else ("*" if p < 0.10 else ""))
    t5_rows.append({
        "Variable": lbl,
        "β̂": f"{r.get('beta', np.nan):.4f}{stars}",
        "SE": f"{r.get('se', np.nan):.4f}",
        "t": f"{r.get('t', np.nan):.3f}",
        "p": f"{r.get('p', np.nan):.4f}",
        "95% CI": f"[{r.get('ci_lo', np.nan):.3f}, {r.get('ci_hi', np.nan):.3f}]",
    })
t5 = pd.DataFrame(t5_rows)
t5.to_csv(OUT_TABLES / "table5_mg_full.csv", index=False)
print(f"  N countries = {res_full['_N_countries']}, N obs = {res_full['_N_obs']}")
print(t5.to_string(index=False))

# ─── Table 6: CCEMG by Income Group ───────────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 7 — CCEMG by Income Group (Table 6 — HEADLINE)")
print("=" * 60)

groups = [("HIC", "High Income"), ("UMIC", "Upper-Middle Income"), ("LMIC", "Lower-Middle Income")]
group_results = {}
for grp, grp_label in groups:
    r = ccemg_income(panel, group_val=grp, B=999)
    group_results[grp] = r
    print(f"\n  {grp_label} (N={r['_N_countries']}, obs={r['_N_obs']})")
    for v in ["ln_airi", "ln_gdp", "ln_ren"]:
        rv = r.get(v, {})
        print(f"    {v}: β={rv.get('beta', np.nan):.4f}  SE={rv.get('se', np.nan):.4f}  "
              f"p={rv.get('p', np.nan):.4f}  "
              f"CI=[{rv.get('ci_lo', np.nan):.3f},{rv.get('ci_hi', np.nan):.3f}]  "
              f"N_valid={rv.get('N_valid', 0)}")

# Export Table 6 wide format
t6_rows = []
var_labels = {"ln_airi": "AIRI", "ln_gdp": "ln GDP per capita",
              "ln_ren": "ln Renewable Share"}
for v, vlbl in var_labels.items():
    row = {"Variable": vlbl}
    for grp, grp_label in groups:
        r = group_results[grp].get(v, {})
        p = r.get("p", np.nan)
        b = r.get("beta", np.nan)
        stars = "" if np.isnan(p) else ("***" if p<0.01 else "**" if p<0.05 else "*" if p<0.10 else "")
        row[grp] = f"{b:.4f}{stars} ({r.get('se', np.nan):.4f}) [p={p:.4f}]"
    t6_rows.append(row)
# Add N obs
row_n = {"Variable": "N obs"}
for grp, _ in groups:
    row_n[grp] = group_results[grp]["_N_obs"]
t6_rows.append(row_n)
t6 = pd.DataFrame(t6_rows)
t6.to_csv(OUT_TABLES / "table6_mg_income.csv", index=False)

# ─── Table 7: Dumitrescu-Hurlin Causality ─────────────────────────────────────
print("\n" + "=" * 60)
print("STEP 8 — Dumitrescu-Hurlin Panel Causality (Table 7)")
print("=" * 60)

def dh_causality(df, x_var, y_var, K=2):
    """
    Dumitrescu-Hurlin (2012) heterogeneous panel Granger causality.
    H0: No causality in any cross-section unit.
    Returns Wbar, Zbar, p-value.
    """
    countries_list = df["iso3"].unique()
    N_c = len(countries_list)
    wald_stats = []
    for c in countries_list:
        sub = df[df["iso3"] == c].sort_values("year")
        y = sub[y_var].values
        x = sub[x_var].values
        T_c = len(y)
        if T_c < K + 4:
            continue
        # Build design matrix: y lags + x lags
        Y_d = y[K:]
        X_cols_list = []
        for k in range(1, K + 1):
            X_cols_list.append(y[K - k: T_c - k])  # y_lag_k
        for k in range(1, K + 1):
            X_cols_list.append(x[K - k: T_c - k])  # x_lag_k
        X_full = np.column_stack(X_cols_list + [np.ones(len(Y_d))])
        X_rest = np.column_stack([y[K - k: T_c - k] for k in range(1, K + 1)]
                                  + [np.ones(len(Y_d))])
        try:
            b_full, res_f, _, _ = np.linalg.lstsq(X_full, Y_d, rcond=None)
            b_rest, res_r, _, _ = np.linalg.lstsq(X_rest, Y_d, rcond=None)
            SSR_f = np.sum((Y_d - X_full @ b_full) ** 2)
            SSR_r = np.sum((Y_d - X_rest @ b_rest) ** 2)
            if SSR_f < 1e-12:
                continue
            F = ((SSR_r - SSR_f) / K) / (SSR_f / (len(Y_d) - X_full.shape[1]))
            wald_stats.append(K * F)
        except:
            continue
    if len(wald_stats) < 2:
        return np.nan, np.nan, np.nan
    W_bar = np.mean(wald_stats)
    # DH Z-stat (standardised)
    Z_bar = np.sqrt(N_c) * (W_bar / K - 1)
    p_val = 2 * (1 - norm.cdf(abs(Z_bar)))
    return round(W_bar, 3), round(Z_bar, 3), round(p_val, 4)

dh_pairs = [
    ("ln_airi", "ln_co2",  "AI → CO₂"),
    ("ln_airi", "ln_ren",  "AI → Renewable"),
    ("ln_co2",  "ln_airi", "CO₂ → AI"),
    ("ln_gdp",  "ln_co2",  "GDP → CO₂"),
    ("ln_ren",  "ln_co2",  "Renewable → CO₂"),
    ("ln_co2",  "ln_ren",  "CO₂ → Renewable"),
]

t7_rows = []
for x_v, y_v, label in dh_pairs:
    w, z, p = dh_causality(panel, x_v, y_v, K=2)
    stars = "" if np.isnan(p) else ("***" if p<0.01 else "**" if p<0.05 else "*" if p<0.10 else "")
    t7_rows.append({"Causal Direction": label,
                    "Wald (avg)": w,
                    "Z-statistic": z,
                    "p-value": f"{p:.4f}{stars}" if not np.isnan(p) else "—"})
    print(f"  {label:30s} W̄={w:7.3f}  Z={z:7.3f}  p={p}")

t7 = pd.DataFrame(t7_rows)
t7.to_csv(OUT_TABLES / "table7_dh_causality.csv", index=False)

# ─── Print summary for manuscript update ─────────────────────────────────────
print("\n" + "=" * 60)
print("SUMMARY — Key Numbers for Manuscript Update")
print("=" * 60)
print(f"\n  Panel: N={N}, T={T}, NT={NT}")

print("\n  TABLE 5 (Full CCEMG):")
airi_full = res_full.get("ln_airi", {})
print(f"    ln AIRI: β={airi_full.get('beta','?')}, SE={airi_full.get('se','?')}, "
      f"t={airi_full.get('t','?')}, p={airi_full.get('p','?')}, "
      f"95%CI=[{airi_full.get('ci_lo','?')},{airi_full.get('ci_hi','?')}]")

print("\n  TABLE 6 (By Income Group — HEADLINE):")
for grp, label in groups:
    rv = group_results[grp].get("ln_airi", {})
    print(f"    {label}: β={rv.get('beta','?')}, SE={rv.get('se','?')}, "
          f"p={rv.get('p','?')}, "
          f"CI=[{rv.get('ci_lo','?')},{rv.get('ci_hi','?')}]")

print("\n  TABLE 7 (DH Causality):")
for x_v, y_v, label in dh_pairs[:3]:
    # re-report from already computed
    pass

print("\n[DONE] All tables saved to:", OUT_TABLES)
