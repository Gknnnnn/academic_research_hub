#!/usr/bin/env python3
"""
extend_panel_wdi_2022_2024.py — Extend master panel to 2022-2024 via WB API.

Fetches WDI variables for 2022-2024, stacks with master panel,
saves extended panel for GAIRI analysis (2019-2024).

Variables:
  EN.GHG.CO2.PC.CE.AR5  → carbon intensity proxy (CO2/capita)
  EG.FEC.RNEW.ZS        → renewable energy share (%)
  NY.GDP.PCAP.CD        → GDP per capita (USD)
  NE.TRD.GNFS.ZS        → trade openness (% GDP)
  SP.URB.TOTL.IN.ZS     → urbanization (%)
  BX.KLT.DINV.WD.GD.ZS  → FDI net inflows (% GDP)
"""
from __future__ import annotations
import json, time, urllib.request
import numpy as np
import pandas as pd
from pathlib import Path

ROOT   = Path(__file__).resolve().parents[1]
MASTER = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/"
              "Akademik_Arastirma/400-Data/Global-Panels/Clean/panel_master_v1.csv")
OUT    = ROOT / "03-Data" / "ai_indices"
OUT.mkdir(parents=True, exist_ok=True)

WDI_VARS = {
    "EN.GHG.CO2.PC.CE.AR5" : "carbon_intensity_gdp_proxy",   # CO2 pc (AR5)
    "EG.FEC.RNEW.ZS"       : "renewable_energy",
    "NY.GDP.PCAP.CD"        : "gdp_per_capita",
    "NE.TRD.GNFS.ZS"       : "trade_openness",
    "SP.URB.TOTL.IN.ZS"    : "urbanization",
    "BX.KLT.DINV.WD.GD.ZS" : "fdi",
}
YEARS = [2022, 2023, 2024]


import ssl as _ssl
_CTX = _ssl.create_default_context()
_CTX.check_hostname = False
_CTX.verify_mode = _ssl.CERT_NONE


def fetch_wdi(indicator: str, years: list[int]) -> pd.DataFrame:
    """Fetch WDI indicator for all countries, given years."""
    yr_str = f"{min(years)}:{max(years)}"
    url = (f"https://api.worldbank.org/v2/country/all/indicator/{indicator}"
           f"?date={yr_str}&format=json&per_page=20000")
    try:
        with urllib.request.urlopen(url, context=_CTX, timeout=30) as r:
            data = json.loads(r.read())
    except Exception as e:
        print(f"  [ERR] {indicator}: {e}")
        return pd.DataFrame()

    if len(data) < 2 or not data[1]:
        return pd.DataFrame()

    rows = []
    for rec in data[1]:
        iso3 = rec.get("countryiso3code") or rec.get("country", {}).get("id", "")
        yr   = rec.get("date")
        val  = rec.get("value")
        if iso3 and yr and val is not None:
            rows.append({"iso3": iso3, "year": int(yr), "value": float(val)})
    df = pd.DataFrame(rows)
    return df


def main():
    print("[WDI Extension] Fetching 2022-2024 data from World Bank API...")
    frames = {}
    for code, col_name in WDI_VARS.items():
        print(f"  Fetching {code} → {col_name}")
        df = fetch_wdi(code, YEARS)
        if len(df):
            df = df.rename(columns={"value": col_name})
            frames[col_name] = df
            print(f"    {len(df)} obs, {df['iso3'].nunique()} countries")
        time.sleep(0.5)  # polite rate-limit

    if not frames:
        print("[ERR] No WDI data fetched. Check internet connection.")
        return

    # Merge all fetched variables
    panel_new = None
    for col, df in frames.items():
        if panel_new is None:
            panel_new = df
        else:
            panel_new = panel_new.merge(df, on=["iso3","year"], how="outer")

    # Load master panel to get iso3 mapping and existing columns
    master = pd.read_csv(MASTER)
    iso_col = "iso3" if "iso3" in master.columns else "country_code"

    # Keep only countries in master panel
    valid_iso3 = master[iso_col].unique()
    panel_new = panel_new[panel_new["iso3"].isin(valid_iso3)].copy()

    # Rename carbon proxy to match master
    if "carbon_intensity_gdp_proxy" in panel_new.columns:
        # Compute carbon intensity as CO2pc / GDPpc (rough proxy, log-transformed later)
        if "gdp_per_capita" in panel_new.columns:
            panel_new["carbon_intensity_gdp"] = (
                panel_new["carbon_intensity_gdp_proxy"]
                / panel_new["gdp_per_capita"].replace({0: np.nan})
            )
        else:
            panel_new["carbon_intensity_gdp"] = panel_new["carbon_intensity_gdp_proxy"]
        panel_new = panel_new.drop(columns=["carbon_intensity_gdp_proxy"])

    # Copy country_name from master via iso3
    name_map = master[[iso_col,"country_name"]].drop_duplicates().set_index(iso_col)["country_name"]
    panel_new["country_name"] = panel_new["iso3"].map(name_map)
    panel_new = panel_new.rename(columns={"iso3": iso_col})

    # Stack with master panel (2019-2021 slice)
    master_sub = master[master["year"].between(2019, 2024)].copy()
    # Align columns
    shared_cols = [c for c in panel_new.columns if c in master_sub.columns]
    combined = pd.concat([
        master_sub[shared_cols],
        panel_new[shared_cols]
    ], ignore_index=True)
    combined = combined.drop_duplicates(subset=[iso_col,"year"], keep="first")
    combined = combined.sort_values([iso_col,"year"]).reset_index(drop=True)

    # Log-transform
    for v in ["gdp_per_capita","carbon_intensity_gdp","ecological_footprint"]:
        if v in combined.columns:
            combined[f"ln_{v}"] = np.log(combined[v].replace({0: np.nan}))

    out_path = OUT / "panel_extended_2019_2024.csv"
    combined.to_csv(out_path, index=False)
    print(f"\n[OK] Extended panel saved: {out_path}")
    print(f"     Shape: {combined.shape}, years: {sorted(combined['year'].unique())}")
    print(f"     Countries: {combined[iso_col].nunique()}")


if __name__ == "__main__":
    main()
