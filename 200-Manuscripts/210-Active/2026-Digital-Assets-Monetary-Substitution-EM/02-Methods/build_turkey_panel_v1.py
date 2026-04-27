#!/usr/bin/env python3
"""
build_turkey_panel_v1.py — MC-2 response: extend EM panel with Turkey rows.

Motivation (MC-2 from referee report)
---------------------------------------
The triple-interaction model rests on a single treated unit (Argentina).
Turkey satisfies two of the three institutional conditions for the absorber
mechanism: (1) formal capital controls (BDDK restrictions, 2018-onward),
(2) extreme inflation (65%+ CPI 2023), and partial crypto adoption
(GCAI rank #11-12, 2021-2024). Including Turkey as a second quasi-treated
unit tests generalisability.

Data sources
------------
  FX:         FRED CCUSMA02TRM618N  (monthly average TRY/USD, nominal)
  CPI:        FRED TURCPIALLMINMEI  (CPI all items, Turkey, monthly index)
  Broad money: World Bank WDI FM.LBL.BMNY.GD.ZS (annual, interpolated)
  Reserves:   World Bank WDI FI.RES.TOTL.MO (months of imports, annual)
  GCAI ranks: chainalysis_gcai_2020_2024.csv (Turkey 2021-2024 added)

Output
------
  03-Results/turkey_panel_v1.csv      — Turkey-only monthly rows
  03-Results/paper6_em_panel_v5.csv  — full panel with Turkey appended
"""
from __future__ import annotations
import datetime
import numpy as np
import pandas as pd
import pandas_datareader.data as web
import wbdata
from pathlib import Path

ROOT    = Path(__file__).resolve().parents[1]
PANEL_V4 = ROOT / "03-Results" / "paper6_em_panel_v4.csv"
OUT_TR   = ROOT / "03-Results" / "turkey_panel_v1.csv"
OUT_V5   = ROOT / "03-Results" / "paper6_em_panel_v5.csv"

START = datetime.datetime(2017, 1, 1)
END   = datetime.datetime(2026, 3, 1)

COUNTRY = "Turkey"


# ─── 1. Monthly FX (CCUSMA02TRM618N) ─────────────────────────────────────────

def fetch_turkey_fx() -> pd.DataFrame:
    """Returns monthly TRY/USD rate, resampled to month-start."""
    print("  [FX] Fetching FRED CCUSMA02TRM618N (TRY/USD monthly)…")
    df = web.DataReader("CCUSMA02TRM618N", "fred", START, END)
    df_m = df.resample("MS").mean()
    df_m.columns = ["fx_level"]
    df_m.index.name = "DATE"
    # fx_depreciation = monthly % change in TRY/USD (+ = lira depreciates)
    df_m["fx_depreciation"] = df_m["fx_level"].pct_change()
    return df_m.reset_index()


# ─── 2. Monthly CPI → monthly inflation ───────────────────────────────────────

def fetch_turkey_cpi() -> pd.DataFrame:
    """
    TURCPIALLMINMEI = Turkey CPI all items, monthly index (OECD/FRED).
    Returns month-on-month log-difference as decimal (consistent with
    the panel variable 'inflation_monthly').
    """
    print("  [CPI] Fetching FRED TURCPIALLMINMEI (Turkey CPI monthly)…")
    df = web.DataReader("TURCPIALLMINMEI", "fred", START, END)
    df_m = df.resample("MS").last()
    df_m.columns = ["cpi_index"]
    df_m.index.name = "DATE"
    # Month-on-month inflation (decimal, consistent with rest of panel)
    df_m["inflation_monthly"] = df_m["cpi_index"].pct_change()
    return df_m.reset_index()[["DATE", "inflation_monthly"]]


# ─── 3. Annual WB macro → linear interpolation to monthly ────────────────────

def fetch_wb_annual(indicator: str, label: str, country_iso3: str = "TUR") -> pd.Series:
    """Fetch annual WB series and return monthly-interpolated version."""
    print(f"  [WB] Fetching {indicator} ({label}) for {country_iso3}…")
    try:
        df = wbdata.get_dataframe({indicator: label}, country=country_iso3)
        df = df.reset_index()
        df["date"] = pd.to_datetime(df["date"].astype(str) + "-01-01")
        df = df.sort_values("date").set_index("date")[label]
        # Extend one year forward and backward for interpolation
        idx_monthly = pd.date_range(
            start=df.index.min(), end="2026-01-01", freq="MS"
        )
        df_m = df.reindex(
            df.index.union(idx_monthly)
        ).interpolate(method="time")
        df_m = df_m.reindex(idx_monthly)
        df_m.index.name = "DATE"
        return df_m
    except Exception as e:
        print(f"    WB fetch error for {indicator}: {e}")
        return pd.Series(dtype=float, name=label)


# ─── 4. Compute BMI and reserve adequacy change ───────────────────────────────

def compute_bmi(broad_money_pct_gdp: pd.Series) -> pd.Series:
    """
    Broad Money Instability = |YoY change in (M2/GDP ratio)|
    Taken as absolute 12-month difference in monthly series.
    Decimal units (consistent with panel).
    """
    bmi = broad_money_pct_gdp.diff(12).abs() / 100   # pct → decimal
    bmi.name = "broad_money_instability"
    return bmi


def compute_reserve_change(reserves_months: pd.Series) -> pd.Series:
    """
    reserve_adequacy_change = 12-month change in months-of-import coverage.
    Decimal units.
    """
    chg = reserves_months.diff(12) / 100
    chg.name = "reserve_adequacy_change"
    return chg


# ─── 5. Assemble Turkey monthly panel ────────────────────────────────────────

def build_turkey_panel() -> pd.DataFrame:
    # ── FX ──
    fx_df = fetch_turkey_fx()
    # ── CPI ──
    cpi_df = fetch_turkey_cpi()
    # ── WB: broad money (M2/GDP %) ──
    bm_s = fetch_wb_annual("FM.LBL.BMNY.GD.ZS", "broad_money_pct_gdp")
    # ── WB: reserves (months of imports) ──
    res_s = fetch_wb_annual("FI.RES.TOTL.MO", "reserves_months")

    # Derived series
    bmi_s  = compute_bmi(bm_s)
    radc_s = compute_reserve_change(res_s)

    # Combine
    df = fx_df.merge(cpi_df, on="DATE", how="left")

    # Align WB monthly series
    for s in [bmi_s, radc_s, bm_s]:
        s_df = s.reset_index()
        s_df.columns = ["DATE", s.name]
        df = df.merge(s_df, on="DATE", how="left")

    df["country"] = COUNTRY
    df["year"]    = pd.to_datetime(df["DATE"]).dt.year
    df["month"]   = pd.to_datetime(df["DATE"]).dt.month
    df["fx_series_code"] = "FRED.CCUSMA02TRM618N"
    df["panel_version"]  = "v5-turkey"
    df["build_date"]     = "2026-04-09"

    # Stub columns to match v4 schema (NaN where not applicable)
    stub_cols = [
        "dxy", "fed_funds_effective", "global_dollar_change", "fed_change",
        "monetary_substitution_pressure_v1", "crypto_proxy_missing",
        "global_btc_attention", "global_tether_attention",
        "global_crypto_attention", "inflation_cpi_ann", "reserves_months_imports",
        "policy_rate", "trends_source", "btc_interest", "stablecoin_interest",
        "country_btc_interest", "country_stablecoin_interest",
        "country_btc_interest_chg", "country_stablecoin_interest_chg",
        "cc_btc_local_close", "cc_btc_local_volume_to",
        "crypto_implied_usd_rate", "log_crypto_volume", "crypto_premium",
    ]
    for c in stub_cols:
        if c not in df.columns:
            df[c] = np.nan

    return df


# ─── 6. Main ─────────────────────────────────────────────────────────────────

def main():
    print("Building Turkey monthly panel for MC-2 extension…\n")
    turkey = build_turkey_panel()

    # Diagnostics
    print(f"\nTurkey panel: {len(turkey)} rows, {turkey['year'].min()}-{turkey['year'].max()}")
    print("Inflation coverage:", turkey["inflation_monthly"].notna().sum(), "months")
    print("BMI coverage:      ", turkey["broad_money_instability"].notna().sum(), "months")
    print("Reserves coverage: ", turkey["reserve_adequacy_change"].notna().sum(), "months")
    print("\nSample stats (GCAI sub-sample 2021-2024):")
    sub = turkey[turkey["year"].isin([2021, 2022, 2023, 2024])]
    print(sub[["fx_depreciation", "inflation_monthly",
               "broad_money_instability", "reserve_adequacy_change"]].describe())

    # Save Turkey-only
    turkey.to_csv(OUT_TR, index=False)
    print(f"\n✓ Turkey panel → {OUT_TR}")

    # Append to full panel
    v4 = pd.read_csv(PANEL_V4)
    v4["DATE"] = pd.to_datetime(v4["DATE"])
    turkey["DATE"] = pd.to_datetime(turkey["DATE"])

    # Align column order
    common_cols = [c for c in v4.columns if c in turkey.columns]
    v5 = pd.concat([v4, turkey[common_cols]], ignore_index=True)
    v5 = v5.sort_values(["country", "DATE"]).reset_index(drop=True)
    v5.to_csv(OUT_V5, index=False)
    print(f"✓ Full panel v5 → {OUT_V5}")
    print(f"  Countries: {sorted(v5['country'].unique())}")
    print(f"  Rows: {len(v4)} → {len(v5)} (+{len(v5)-len(v4)} Turkey rows)")


if __name__ == "__main__":
    main()
