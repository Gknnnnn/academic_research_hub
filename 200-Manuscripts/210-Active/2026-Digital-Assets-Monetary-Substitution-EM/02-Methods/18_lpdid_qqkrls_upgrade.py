"""
18_lpdid_qqkrls_upgrade.py
Digital Assets EM (P6 JIMF) — LP-DiD + QQ-KRLS Upgrade
MGO | 2026-04-26 | BESTFIT Rank 29

Purpose: Supplement existing Panel SVAR + Bai-Perron + Westerlund + CCEMG
(extensive scripts v3–v17) with:
(1) LP-DiD: dynamic crypto adoption treatment effect h=0..8 quarters
(2) QQ-KRLS: nonlinear VIX/EPU → crypto adoption at tail combinations

Key novelty: while existing scripts show level effects, LP-DiD reveals
the DYNAMIC path of adoption — does crypto substitution build up over time
or decay? QKRLS shows whether uncertainty → crypto is amplified at extremes.

Data: run_paper6_models_v17.py output (CCE-FI estimates)
"""
import pandas as pd
import numpy as np
from pathlib import Path
import shutil

BASE    = Path(__file__).resolve().parent.parent
RESULTS = BASE / "03-Results"
TMP     = Path("/tmp/p6_digital/")
TMP.mkdir(exist_ok=True)

# ── Load paper6 data ──────────────────────────────────────────────────────────
df = None
for csv_name in ["paper6_panel.csv", "paper6_panel_v3.csv", "digital_assets_panel.csv",
                  "paper6_em_crypto_panel.csv"]:
    src = RESULTS / csv_name
    if src.exists():
        tmp_p = TMP / csv_name
        shutil.copy(src, tmp_p)
        df = pd.read_csv(tmp_p)
        print(f"Loaded: {csv_name}  {df.shape}")
        break

if df is None:
    print("WARNING: P6 panel not found — simulated demo (25 EM countries, T=24 quarters)")
    np.random.seed(2026)
    N, T = 25, 24
    rows = []
    for n in range(N):
        crypto_adoption = np.cumsum(np.random.binomial(1, 0.1, T))
        first_adopt     = np.where(crypto_adoption > 0)[0][0] if crypto_adoption.max() > 0 else T
        vix = np.random.normal(25, 8, T)
        epu = np.random.normal(150, 40, T)
        ms  = np.random.normal(12, 3, T) - 0.1 * vix
        rows += [{"country": f"EM{n+1:02d}", "quarter": 2016 + t*0.25,
                  "monetary_substitution": ms[t], "crypto_adopt": int(crypto_adoption[t] > 0),
                  "VIX": vix[t], "EPU": epu[t], "first_adopt_q": 2016 + first_adopt*0.25}
                 for t in range(T)]
    df = pd.DataFrame(rows)

cols = df.columns.tolist()
id_col   = next((c for c in cols if c.lower() in ["country","iso","id","economy"]), cols[0])
time_col = next((c for c in cols if any(k in c.lower() for k in ["quarter","year","time","period"])), cols[1])
y_col    = next((c for c in cols if any(k in c.lower() for k in ["substitut","ms","monetary","subst"])), cols[2])
treat_col = next((c for c in cols if any(k in c.lower() for k in ["adopt","crypto","treat","bitcoin"])), None)
vix_col  = next((c for c in cols if "vix" in c.lower()), None)
epu_col  = next((c for c in cols if "epu" in c.lower()), None)
print(f"id={id_col}  time={time_col}  y={y_col}  treat={treat_col}  vix={vix_col}")

# ── (1) LP-DiD: Crypto Adoption → Monetary Substitution ──────────────────────
print("\n" + "="*60)
print("LP-DiD: Crypto Adoption → Monetary Substitution (h=0..8)")
print("="*60)

if treat_col is not None:
    try:
        # compute event_time
        df = df.sort_values([id_col, time_col])
        first_treat = (df[df[treat_col] == 1]
                       .groupby(id_col)[time_col].min()
                       .rename("first_treat"))
        df = df.merge(first_treat, on=id_col, how="left")
        df["event_time"] = df[time_col] - df["first_treat"]
        df["treated"]    = df["first_treat"].notna()

        rows_lp = []
        for h in range(9):
            df_h = df.copy()
            df_h["y_lead"]  = df_h.groupby(id_col)[y_col].shift(-h)
            df_h["D_treat"] = ((df_h["event_time"] == 0) & df_h["treated"]).astype(int)
            df_h = df_h.dropna(subset=["y_lead"])

            # OLS with unit + time FE (python statsmodels equivalent)
            from statsmodels.formula.api import ols
            df_h["unit_fe"]    = df_h[id_col].astype("category")
            df_h["time_fe"]    = df_h[time_col].astype("category")
            formula = "y_lead ~ D_treat + C(unit_fe) + C(time_fe) - 1"
            try:
                import statsmodels.api as sm
                y_arr = df_h["y_lead"].values
                D_arr = df_h["D_treat"].values
                X_arr = np.column_stack([D_arr, pd.get_dummies(df_h[id_col]).values,
                                         pd.get_dummies(df_h[time_col]).values])
                mod = sm.OLS(y_arr, X_arr)
                res = mod.fit(cov_type="cluster", cov_kwds={"groups": df_h[id_col].values})
                coef_val = res.params[0]
                se_val   = res.bse[0]
                rows_lp.append({"h": h, "coef": round(coef_val, 4),
                                 "se": round(se_val, 4),
                                 "ci_lo": round(coef_val - 1.96*se_val, 4),
                                 "ci_hi": round(coef_val + 1.96*se_val, 4),
                                 "pval": round(2*(1 - float(__import__("scipy.stats", fromlist=["norm"]).stats.norm.cdf(abs(coef_val/se_val)))), 4)})
                sig = "***" if rows_lp[-1]["pval"] < 0.01 else ("**" if rows_lp[-1]["pval"] < 0.05 else "")
                print(f"  h={h}: β={coef_val:.4f} (se={se_val:.4f}) {sig}")
            except Exception as e:
                print(f"  h={h}: {e}")
                rows_lp.append({"h": h, "coef": np.nan, "se": np.nan,
                                 "ci_lo": np.nan, "ci_hi": np.nan, "pval": np.nan})

        if rows_lp:
            df_lp = pd.DataFrame(rows_lp)
            df_lp.to_csv(RESULTS / "lpdid_crypto_adoption_ms.csv", index=False)
            print(f"\nSaved: lpdid_crypto_adoption_ms.csv")
            peak_h = df_lp["h"].iloc[df_lp["coef"].abs().idxmax()]
            peak_b = df_lp["coef"].abs().max()
            print(f"Peak effect: h={peak_h} quarters  |β|={peak_b:.4f}")

    except Exception as e:
        print(f"LP-DiD error: {e}")
else:
    print("No treatment column detected — LP-DiD skipped")

# ── (2) QQ-KRLS: VIX/EPU → Monetary Substitution ─────────────────────────────
print("\n" + "="*60)
print("QQ-KRLS: Uncertainty → Monetary Substitution (Nonlinear Tail)")
print("="*60)

taus = np.round(np.arange(0.10, 0.95, 0.10), 2)

try:
    from qqkrls import QQKRLS

    y_arr = df[y_col].values.astype(float)
    pairs = []
    if vix_col:
        pairs.append(("VIX→MS", df[vix_col].values.astype(float)))
    if epu_col:
        pairs.append(("EPU→MS", df[epu_col].values.astype(float)))

    for pair_name, x_raw in pairs:
        mask = np.isfinite(y_arr) & np.isfinite(x_raw)
        y_use, x_use = y_arr[mask], x_raw[mask]

        rows_krls = []
        for tau_y in taus:
            for tau_x in taus:
                try:
                    res  = QQKRLS(y=y_use, x=x_use, tau_y=float(tau_y), tau_x=float(tau_x)).fit()
                    pval = float(res.pvalue) if hasattr(res, "pvalue") else np.nan
                    rows_krls.append({"pair": pair_name, "tau_y": tau_y, "tau_x": tau_x,
                                      "beta": round(float(res.beta), 6),
                                      "pvalue": round(pval, 4) if not np.isnan(pval) else np.nan,
                                      "sig": int(pval < 0.05) if not np.isnan(pval) else 0})
                except Exception:
                    rows_krls.append({"pair": pair_name, "tau_y": tau_y, "tau_x": tau_x,
                                      "beta": np.nan, "pvalue": np.nan, "sig": 0})

        df_k = pd.DataFrame(rows_krls)
        sig_n = df_k["sig"].sum()
        upper = df_k[(df_k.tau_y > 0.75) & (df_k.tau_x > 0.75)]
        print(f"\n  {pair_name}: {sig_n}/{len(df_k)} sig | upper tail {upper['sig'].sum()}/{len(upper)}")

    # Save all results
    if rows_krls:
        all_krls = pd.DataFrame([r for r in rows_krls])
        all_krls.to_csv(RESULTS / "qqkrls_digital_assets_ms.csv", index=False)
        print(f"Saved: qqkrls_digital_assets_ms.csv")

except ImportError:
    print("qqkrls not installed.")

print("""
MANUSCRIPT NOTE (P6 JIMF §5 Robustness):
  "LP-DiD reveals crypto adoption effects on monetary substitution peak at
   h=[X] quarters (β=[Y]), while QQ-KRLS shows upper-tail amplification —
   uncertainty → MS relationship is [stronger/nonlinear] at extreme
   distributional combinations, consistent with flight-to-crypto dynamics."
""")
