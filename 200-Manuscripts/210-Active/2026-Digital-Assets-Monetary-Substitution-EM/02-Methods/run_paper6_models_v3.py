"""
P6 Model Suite v3 — Optimal Estimation Strategy
=================================================
Step 1: Country-FE OLS baseline (diagnostic — are new vars significant?)
Step 2: Pooled Quantile Regression q=[0.25,0.50,0.75,0.90] (main results)
Step 3: Panel ARDL with 1 lag (if quantile shows dynamics matter)

Research question: Do digital-asset proxies explain EM currency fragility,
and does this effect concentrate in high-depreciation regimes?

Output:
  03-Results/paper6_v3_ols_baseline.csv
  03-Results/paper6_v3_quantile_results.csv
  03-Results/paper6_v3_ardl_results.csv
  03-Results/paper6_v3_model_summary.md
"""

import warnings
import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path
from statsmodels.regression.quantile_regression import QuantReg

warnings.filterwarnings("ignore")

# ── paths ──────────────────────────────────────────────────────────────────
BASE    = Path(__file__).resolve().parent.parent
RESULTS = BASE / "03-Results"
V3_PATH = RESULTS / "paper6_em_panel_v3.csv"
OUT_OLS  = RESULTS / "paper6_v3_ols_baseline.csv"
OUT_QR   = RESULTS / "paper6_v3_quantile_results.csv"
OUT_ARDL = RESULTS / "paper6_v3_ardl_results.csv"
OUT_SUM  = RESULTS / "paper6_v3_model_summary.md"

QUANTILES = [0.25, 0.50, 0.75, 0.90]


# ── data prep ──────────────────────────────────────────────────────────────

def load_and_prep(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, parse_dates=["DATE"])
    df = df.sort_values(["country", "DATE"]).reset_index(drop=True)

    # Keep 2012+ (Google Trends only available from 2004; crypto era from 2012)
    df = df[df["DATE"] >= "2012-01-01"].copy()

    # Country dummies
    df["country_code"] = pd.Categorical(df["country"]).codes
    countries = df["country"].unique().tolist()
    ref = countries[0]  # Brazil as reference
    for c in countries[1:]:
        df[f"d_{c.lower().replace(' ', '_')}"] = (df["country"] == c).astype(int)

    # Lag fx_depreciation (AR term)
    df["fx_dep_lag1"] = df.groupby("country")["fx_depreciation"].shift(1)

    # Changes in Google Trends (flow, not level)
    for col in ["country_btc_interest", "country_stablecoin_interest"]:
        if col in df.columns:
            df[f"{col}_chg"] = df.groupby("country")[col].diff()
            # Normalize 0-100 to 0-1
            df[col] = df[col] / 100.0
            df[f"{col}_chg"] = df[f"{col}_chg"] / 100.0

    # M2 instability: abs YoY change in broad_money_pct_gdp (already computed in v3)
    # If not present, compute here
    if "broad_money_instability" not in df.columns and "broad_money_pct_gdp" in df.columns:
        df["broad_money_instability"] = df.groupby("country")["broad_money_pct_gdp"].transform(
            lambda x: x.pct_change(12).abs()
        )

    # Reserve adequacy change
    if "reserve_adequacy_change" not in df.columns and "reserves_months_imports" in df.columns:
        df["reserve_adequacy_change"] = df.groupby("country")["reserves_months_imports"].transform(
            lambda x: x.pct_change(12)
        )

    # Inflation monthly proxy (annual / 12)
    if "inflation_cpi_ann" in df.columns:
        df["inflation_monthly"] = df["inflation_cpi_ann"] / 12.0

    df = df.dropna(subset=["fx_depreciation", "global_dollar_change"])
    return df, countries, ref


# ── Step 1: Country-FE OLS baseline ────────────────────────────────────────

def run_ols_baseline(df: pd.DataFrame, countries: list, ref: str) -> tuple:
    print("\n[Step 1] Country-FE OLS Baseline...")

    country_dummies = [f"d_{c.lower().replace(' ', '_')}"
                       for c in countries if c != ref
                       and f"d_{c.lower().replace(' ', '_')}" in df.columns]

    # Build feature sets: macro-only, then add crypto layer
    macro_features = ["global_dollar_change", "fed_change", "fx_dep_lag1",
                      "inflation_monthly", "broad_money_instability",
                      "reserve_adequacy_change"] + country_dummies

    crypto_features = ["country_btc_interest_chg", "country_stablecoin_interest_chg"]

    results_rows = []

    for label, features in [
        ("FE-Macro-Only", macro_features),
        ("FE-Macro+Crypto", macro_features + crypto_features),
    ]:
        cols = [f for f in features if f in df.columns]
        sub = df[["fx_depreciation"] + cols].dropna()
        if len(sub) < 50:
            print(f"  {label}: insufficient data ({len(sub)} rows)")
            continue

        y = sub["fx_depreciation"]
        X = sm.add_constant(sub[cols])
        model = sm.OLS(y, X).fit(cov_type="HC3")

        print(f"  {label}: N={len(sub)}, adj_R²={model.rsquared_adj:.4f}")
        for var in cols:
            results_rows.append({
                "model": label,
                "variable": var,
                "coef": round(model.params.get(var, np.nan), 6),
                "std_err": round(model.bse.get(var, np.nan), 6),
                "t_stat": round(model.tvalues.get(var, np.nan), 4),
                "p_value": round(model.pvalues.get(var, np.nan), 4),
                "n_obs": len(sub),
                "adj_r2": round(model.rsquared_adj, 4),
            })

    ols_df = pd.DataFrame(results_rows)
    ols_df.to_csv(OUT_OLS, index=False)
    print(f"  Saved: {OUT_OLS.name}")
    return ols_df


# ── Step 2: Quantile Regression ────────────────────────────────────────────

def run_quantile_regression(df: pd.DataFrame, countries: list, ref: str) -> pd.DataFrame:
    print("\n[Step 2] Quantile Regression q=[0.25, 0.50, 0.75, 0.90]...")

    country_dummies = [f"d_{c.lower().replace(' ', '_')}"
                       for c in countries if c != ref
                       and f"d_{c.lower().replace(' ', '_')}" in df.columns]

    features = (["global_dollar_change", "fed_change", "fx_dep_lag1",
                 "inflation_monthly", "broad_money_instability",
                 "reserve_adequacy_change",
                 "country_btc_interest_chg", "country_stablecoin_interest_chg"]
                + country_dummies)

    cols = [f for f in features if f in df.columns]
    sub = df[["fx_depreciation"] + cols].dropna()
    print(f"  Sample: N={len(sub)}")

    if len(sub) < 50:
        print("  Insufficient data for quantile regression.")
        return pd.DataFrame()

    y = sub["fx_depreciation"].values
    X = sm.add_constant(sub[cols]).values
    col_names = ["const"] + cols

    results_rows = []
    for q in QUANTILES:
        qmod = QuantReg(y, X).fit(q=q, max_iter=2000)
        print(f"  q={q}: pseudo_R²={qmod.prsquared:.4f}")
        for i, var in enumerate(col_names):
            results_rows.append({
                "quantile": q,
                "variable": var,
                "coef": round(qmod.params[i], 6),
                "std_err": round(qmod.bse[i], 6),
                "t_stat": round(qmod.tvalues[i], 4),
                "p_value": round(qmod.pvalues[i], 4),
                "pseudo_r2": round(qmod.prsquared, 4),
                "n_obs": len(sub),
            })

    qr_df = pd.DataFrame(results_rows)
    qr_df.to_csv(OUT_QR, index=False)
    print(f"  Saved: {OUT_QR.name}")
    return qr_df


# ── Step 3: Panel ARDL (1 lag) ─────────────────────────────────────────────

def run_panel_ardl(df: pd.DataFrame, countries: list, ref: str) -> pd.DataFrame:
    print("\n[Step 3] Panel ARDL (1 lag)...")

    country_dummies = [f"d_{c.lower().replace(' ', '_')}"
                       for c in countries if c != ref
                       and f"d_{c.lower().replace(' ', '_')}" in df.columns]

    # ARDL: include lagged DV + lagged X
    df["btc_interest_lag1"] = df.groupby("country")["country_btc_interest"].shift(1)
    df["stable_interest_lag1"] = df.groupby("country")["country_stablecoin_interest"].shift(1)
    df["dollar_lag1"] = df.groupby("country")["global_dollar_change"].shift(1)

    features = (["global_dollar_change", "dollar_lag1",
                 "fed_change", "fx_dep_lag1",
                 "inflation_monthly", "broad_money_instability",
                 "country_btc_interest_chg", "btc_interest_lag1",
                 "country_stablecoin_interest_chg", "stable_interest_lag1"]
                + country_dummies)

    cols = [f for f in features if f in df.columns]
    sub = df[["fx_depreciation"] + cols].dropna()
    print(f"  ARDL sample: N={len(sub)}")

    if len(sub) < 50:
        print("  Insufficient data.")
        return pd.DataFrame()

    y = sub["fx_depreciation"]
    X = sm.add_constant(sub[cols])
    model = sm.OLS(y, X).fit(cov_type="HC3")
    print(f"  ARDL: N={len(sub)}, adj_R²={model.rsquared_adj:.4f}")

    rows = []
    for var in cols:
        rows.append({
            "model": "Panel-ARDL-1lag",
            "variable": var,
            "coef": round(model.params.get(var, np.nan), 6),
            "std_err": round(model.bse.get(var, np.nan), 6),
            "t_stat": round(model.tvalues.get(var, np.nan), 4),
            "p_value": round(model.pvalues.get(var, np.nan), 4),
            "n_obs": len(sub),
            "adj_r2": round(model.rsquared_adj, 4),
        })

    ardl_df = pd.DataFrame(rows)
    ardl_df.to_csv(OUT_ARDL, index=False)
    print(f"  Saved: {OUT_ARDL.name}")
    return ardl_df


# ── Summary writer ─────────────────────────────────────────────────────────

def write_summary(ols_df, qr_df, ardl_df):
    lines = ["# P6 v3 Model Summary", "", f"**Date:** 2026-04-04", ""]

    # OLS
    lines += ["## Step 1: Country-FE OLS", ""]
    if not ols_df.empty:
        crypto_vars = ["country_btc_interest_chg", "country_stablecoin_interest_chg"]
        for model in ols_df["model"].unique():
            sub = ols_df[ols_df["model"] == model]
            adj_r2 = sub["adj_r2"].iloc[0]
            n = sub["n_obs"].iloc[0]
            lines.append(f"### {model}  (N={n}, adj_R²={adj_r2})")
            lines.append("")
            lines.append("| Variable | Coef | p-value | Sig |")
            lines.append("|---|---|---|---|")
            for _, row in sub.iterrows():
                sig = "***" if row["p_value"] < 0.01 else ("**" if row["p_value"] < 0.05
                       else ("*" if row["p_value"] < 0.10 else ""))
                flag = " ← **CRYPTO**" if row["variable"] in crypto_vars else ""
                lines.append(f"| {row['variable']}{flag} | {row['coef']:.4f} | {row['p_value']:.3f} | {sig} |")
            lines.append("")

    # Quantile
    lines += ["## Step 2: Quantile Regression", ""]
    if not qr_df.empty:
        crypto_vars = ["country_btc_interest_chg", "country_stablecoin_interest_chg"]
        # Focus table: crypto vars across quantiles
        lines.append("### Crypto Variables Across Quantiles")
        lines.append("")
        lines.append("| Variable | q=0.25 | q=0.50 | q=0.75 | q=0.90 |")
        lines.append("|---|---|---|---|---|")
        for var in crypto_vars:
            sub = qr_df[qr_df["variable"] == var]
            row_parts = [f"`{var}`"]
            for q in QUANTILES:
                qsub = sub[sub["quantile"] == q]
                if qsub.empty:
                    row_parts.append("—")
                else:
                    c = qsub.iloc[0]["coef"]
                    p = qsub.iloc[0]["p_value"]
                    sig = "***" if p < 0.01 else ("**" if p < 0.05 else ("*" if p < 0.10 else ""))
                    row_parts.append(f"{c:.4f}{sig}")
            lines.append("| " + " | ".join(row_parts) + " |")
        lines.append("")

        # Interpretation
        lines.append("### Interpretation")
        btc_90 = qr_df[(qr_df["variable"] == "country_btc_interest_chg") &
                       (qr_df["quantile"] == 0.90)]
        if not btc_90.empty and btc_90.iloc[0]["p_value"] < 0.10:
            lines.append("- ✅ BTC interest is significant at q=0.90 → "
                         "crypto demand concentrates in HIGH-depreciation regimes")
            lines.append("- This supports the threshold/substitution hypothesis")
        else:
            lines.append("- ⚠️ BTC interest not significant even at q=0.90 → "
                         "measurement still insufficient OR substitution channel weak")
        lines.append("")

    # ARDL
    lines += ["## Step 3: Panel ARDL", ""]
    if not ardl_df.empty:
        adj_r2 = ardl_df["adj_r2"].iloc[0]
        n = ardl_df["n_obs"].iloc[0]
        lines.append(f"N={n}, adj_R²={adj_r2}")
        lines.append("")
        lag_vars = ["btc_interest_lag1", "stable_interest_lag1"]
        lines.append("| Variable | Coef | p-value | Sig |")
        lines.append("|---|---|---|---|")
        for _, row in ardl_df[ardl_df["variable"].isin(
                ["country_btc_interest_chg", "btc_interest_lag1",
                 "country_stablecoin_interest_chg", "stable_interest_lag1",
                 "global_dollar_change", "inflation_monthly",
                 "broad_money_instability"])].iterrows():
            sig = "***" if row["p_value"] < 0.01 else ("**" if row["p_value"] < 0.05
                   else ("*" if row["p_value"] < 0.10 else ""))
            lines.append(f"| {row['variable']} | {row['coef']:.4f} | {row['p_value']:.3f} | {sig} |")
        lines.append("")

    # Verdict
    lines += ["## Draft Readiness Verdict", ""]
    if not qr_df.empty:
        sig_crypto = qr_df[
            (qr_df["variable"].isin(["country_btc_interest_chg",
                                     "country_stablecoin_interest_chg"])) &
            (qr_df["p_value"] < 0.10)
        ]
        if len(sig_crypto) > 0:
            lines.append("✅ **DRAFT READY:** At least one crypto proxy is significant.")
            lines.append("Proceed to manuscript build with quantile results as main table.")
        else:
            lines.append("⚠️ **NOT YET DRAFT READY:** Crypto proxies remain insignificant.")
            lines.append("Consider: (1) extend country list, (2) use exchange volume data,")
            lines.append("(3) reframe as measurement methodology paper.")
    lines.append("")

    OUT_SUM.write_text("\n".join(lines))
    print(f"\n  Summary: {OUT_SUM.name}")


# ── main ────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("P6 Model Suite v3")
    print("=" * 60)

    if not V3_PATH.exists():
        print(f"❌ v3 panel not found: {V3_PATH}")
        print("   Run build_paper6_panel_v3.py first.")
        return

    df, countries, ref = load_and_prep(V3_PATH)
    print(f"Loaded: {len(df)} rows, {df['country'].nunique()} countries")
    print(f"Date range: {df['DATE'].min().date()} — {df['DATE'].max().date()}")
    print(f"Columns: {[c for c in df.columns if 'btc' in c or 'stable' in c or 'inflation' in c]}")

    ols_df  = run_ols_baseline(df, countries, ref)
    qr_df   = run_quantile_regression(df, countries, ref)
    ardl_df = run_panel_ardl(df, countries, ref)
    write_summary(ols_df, qr_df, ardl_df)

    print("\n" + "=" * 60)
    print("Done. Check paper6_v3_model_summary.md for verdict.")
    print("=" * 60)


if __name__ == "__main__":
    main()
