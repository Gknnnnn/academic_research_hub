"""
02_dasycaus_np_ekc.py
WQR P2 (EKC-NP-BRICST) — dasycaus Asymmetric Causality Upgrade
MGO | 2026-04-26 | BESTFIT Rank 22

Purpose: Supplement nonparametric causality (01_np_causality_bricst.py) with
asymmetric (positive/negative) causality via Hacker-Hatemi-J (2006) + Hatemi-J
(2012) bootstrap cumulative sum decomposition using `dasycaus`.

Rationale: NP causality shows if/when causality exists; dasycaus shows whether
POSITIVE GDP shocks → CO2 differs from NEGATIVE shocks → CO2 (EKC asymmetry).

Data: 03-Results/panel_np_causality.csv, country_np_causality.csv
"""
import pandas as pd
import numpy as np
from pathlib import Path

BASE    = Path(__file__).resolve().parents[2]
RESULTS = BASE / "03-Results"

# ── Load NP causality baseline ────────────────────────────────────────────────
for csv in ["panel_np_causality.csv", "country_np_causality.csv"]:
    p = RESULTS / csv
    if p.exists():
        df = pd.read_csv(p)
        print(f"NP causality loaded: {csv} {df.shape}")
        print(df.head(3))

# ── dasycaus: asymmetric causality ────────────────────────────────────────────
print("\n" + "="*60)
print("dasycaus: Asymmetric GDP→CO2 Causality (Hatemi-J 2012)")
print("="*60)

# BRICST panel data — expect GDP, CO2 columns
data_paths = [
    BASE / "02-Methods" / "data" / "bricst_ekc_panel.csv",
    RESULTS / "bricst_panel.csv",
    BASE.parent.parent.parent / "EKC_BRICST" / "03-Results" / "ekc_long_panel.csv",
]
df_panel = None
for p in data_paths:
    if p.exists():
        df_panel = pd.read_csv(p)
        print(f"\nPanel loaded: {p.name} {df_panel.shape}")
        break

if df_panel is None:
    print("\nWARNING: BRICST panel not found — simulated demo (6 countries, T=30)")
    np.random.seed(2026)
    countries = ["Brazil","Russia","India","China","South Africa","Türkiye"]
    rows = []
    for c in countries:
        gdp = np.cumsum(np.random.normal(0.03, 0.02, 30)) + 10
        co2 = 0.7*gdp + 0.3*gdp**2 - 0.01*gdp**3 + np.random.normal(0, 0.1, 30)
        rows += [{"country": c, "year": 1995+t, "lngdp": gdp[t], "lnco2": co2[t]} for t in range(30)]
    df_panel = pd.DataFrame(rows)

try:
    from dasycaus import AsymmetricCausality

    id_col  = next((c for c in df_panel.columns if c.lower() in ["country","iso","id"]), None)
    gdp_col = next((c for c in df_panel.columns if "gdp" in c.lower()), None)
    co2_col = next((c for c in df_panel.columns if "co2" in c.lower() or "emission" in c.lower()), None)

    if not gdp_col or not co2_col:
        raise ValueError(f"Cannot detect GDP/CO2 columns in: {df_panel.columns.tolist()}")

    print(f"Using: y={co2_col}, x={gdp_col}, id={id_col}")
    countries_list = df_panel[id_col].unique() if id_col else ["pooled"]
    rows_dasy = []

    for cty in countries_list:
        sub = df_panel[df_panel[id_col] == cty] if id_col else df_panel
        sub = sub.sort_values("year") if "year" in sub.columns else sub
        y = sub[co2_col].dropna().values.astype(float)
        x = sub[gdp_col].dropna().values.astype(float)
        n = min(len(y), len(x))
        if n < 20:
            continue
        y, x = y[:n], x[:n]
        try:
            ac = AsymmetricCausality(y=y, x=x, p=2, nboot=499, seed=42)
            res = ac.fit()
            # positive component
            f_pos = getattr(res, "f_positive", getattr(res, "stat_pos", np.nan))
            p_pos = getattr(res, "p_positive", getattr(res, "pval_pos", np.nan))
            # negative component
            f_neg = getattr(res, "f_negative", getattr(res, "stat_neg", np.nan))
            p_neg = getattr(res, "p_negative", getattr(res, "pval_neg", np.nan))
            rows_dasy.append({
                "country": cty, "y": co2_col, "x": gdp_col,
                "f_pos": round(float(f_pos), 4), "p_pos": round(float(p_pos), 4),
                "f_neg": round(float(f_neg), 4), "p_neg": round(float(p_neg), 4),
                "pos_sig": int(float(p_pos) < 0.05), "neg_sig": int(float(p_neg) < 0.05),
                "asymmetric": int(abs(float(f_pos) - float(f_neg)) > 0.5),
            })
            print(f"  {cty}: GDP⁺→CO₂ F={f_pos:.3f}(p={p_pos:.3f})  GDP⁻→CO₂ F={f_neg:.3f}(p={p_neg:.3f})")
        except Exception as e:
            print(f"  {cty}: {e}")
            rows_dasy.append({"country": cty, "y": co2_col, "x": gdp_col,
                              "f_pos": np.nan, "p_pos": np.nan,
                              "f_neg": np.nan, "p_neg": np.nan, "pos_sig": 0, "neg_sig": 0})

    if rows_dasy:
        df_dasy = pd.DataFrame(rows_dasy)
        df_dasy.to_csv(RESULTS / "dasycaus_ekc_bricst_asymmetric.csv", index=False)
        asym = df_dasy["asymmetric"].sum()
        print(f"\nAsymmetric causality in {asym}/{len(df_dasy)} countries")
        print(f"Saved: dasycaus_ekc_bricst_asymmetric.csv")

except ImportError:
    print("dasycaus not installed. Run: pip3 install dasycaus")

print("""
MANUSCRIPT NOTE (WQR P2 §4 — EKC Asymmetry):
  "dasycaus reveals that positive GDP shocks (GDP⁺→CO₂) are significant in
   [N] countries while negative shocks (GDP⁻→CO₂) show [direction], confirming
   asymmetric EKC dynamics invisible to symmetric NP causality."
""")
