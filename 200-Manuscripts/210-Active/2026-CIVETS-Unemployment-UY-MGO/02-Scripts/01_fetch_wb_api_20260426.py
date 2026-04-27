"""
CIVETS Unemployment Project — WB API Data Fetch
Script: 01_fetch_wb_api_20260426.py
Author: MGO
Date: 2026-04-26
Sources: World Bank WDI + WGI (free API, no key required)
"""

import requests, json, time, os
import pandas as pd
from pathlib import Path

BASE = "https://api.worldbank.org/v2"
CIVETS = ["COL", "IDN", "VNM", "EGY", "TUR", "ZAF"]
COUNTRY_STR = ";".join(CIVETS)
YEARS = "2000:2023"

WDI_INDICATORS = {
    "unemp":      "SL.UEM.TOTL.ZS",
    "gdp_growth": "NY.GDP.MKTP.KD.ZG",
    "gdp_pc":     "NY.GDP.PCAP.KD",
    "inflation":  "FP.CPI.TOTL.ZG",
    "trade":      "NE.TRD.GNFS.ZS",
    "fdi":        "BX.KLT.DINV.WD.GD.ZS",
    "gov_exp":    "GC.XPN.TOTL.GD.ZS",
    "internet":   "IT.NET.USER.ZS",
    "lfp":        "SL.TLF.ACTI.ZS",
}

WGI_INDICATORS = {
    "goveff":  "GE.EST",
    "rulelaw": "RL.EST",
    "corrupt": "CC.EST",
    "polstab": "PV.EST",
    "voice":   "VA.EST",
}

COUNTRY_NAMES = {
    "COL": "Colombia", "IDN": "Indonesia", "VNM": "Vietnam",
    "EGY": "Egypt", "TUR": "Türkiye", "ZAF": "South Africa"
}

def fetch_indicator(indicator_code, label, year_range=YEARS):
    url = (f"{BASE}/country/{COUNTRY_STR}/indicator/{indicator_code}"
           f"?format=json&per_page=500&date={year_range}")
    try:
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        data = r.json()
        if len(data) < 2 or not data[1]:
            print(f"  ⚠ {label}: no data returned")
            return []
        records = []
        for rec in data[1]:
            records.append({
                "iso3c": rec["countryiso3code"],
                "year":  int(rec["date"]),
                label:   rec["value"]
            })
        print(f"  ✅ {label}: {len(records)} records")
        return records
    except Exception as e:
        print(f"  ❌ {label}: {e}")
        return []

# ── Build base panel (iso3c × year) ─────────────────────────
base_rows = [{"iso3c": c, "year": y} for c in CIVETS for y in range(2000, 2024)]
panel = pd.DataFrame(base_rows)
panel["country"] = panel["iso3c"].map(COUNTRY_NAMES)

# ── Fetch WDI ───────────────────────────────────────────────
print("\n── Fetching WDI indicators ──")
for label, code in WDI_INDICATORS.items():
    records = fetch_indicator(code, label)
    if records:
        df = pd.DataFrame(records)[["iso3c", "year", label]]
        panel = panel.merge(df, on=["iso3c", "year"], how="left")
    time.sleep(0.5)

# ── Fetch WGI ───────────────────────────────────────────────
print("\n── Fetching WGI indicators (1996–2023) ──")
for label, code in WGI_INDICATORS.items():
    records = fetch_indicator(code, label, year_range="1996:2023")
    if records:
        df = pd.DataFrame(records)[["iso3c", "year", label]]
        panel = panel.merge(df, on=["iso3c", "year"], how="left")
    time.sleep(0.5)

# ── Save ────────────────────────────────────────────────────
out = Path("01-Data/raw")
out.mkdir(parents=True, exist_ok=True)

panel = panel.sort_values(["iso3c", "year"]).reset_index(drop=True)
panel.to_csv(out / "civets_panel_merged_20260426.csv", index=False)
print(f"\n✅ Saved: civets_panel_merged_20260426.csv  ({panel.shape[0]} rows × {panel.shape[1]} cols)")

# ── Missing value audit ─────────────────────────────────────
print("\n── Missing value audit ──")
vars_of_interest = list(WDI_INDICATORS.keys()) + list(WGI_INDICATORS.keys())
total = len(panel)
audit = []
for v in vars_of_interest:
    if v in panel.columns:
        n_miss = panel[v].isna().sum()
        audit.append({"variable": v, "n_missing": n_miss, "pct_missing": round(n_miss/total*100,1)})
audit_df = pd.DataFrame(audit).sort_values("n_missing", ascending=False)
print(audit_df.to_string(index=False))

# ── Spot-check: latest unemployment ─────────────────────────
print("\n── Unemployment spot check (latest year with data) ──")
latest = (panel.dropna(subset=["unemp"])
               .sort_values("year", ascending=False)
               .groupby("iso3c").first()
               .reset_index()[["iso3c", "country", "year", "unemp"]])
print(latest.to_string(index=False))

# ── Spot-check: latest WGI governance effectiveness ─────────
print("\n── Governance Effectiveness spot check ──")
latest_wgi = (panel.dropna(subset=["goveff"])
                   .sort_values("year", ascending=False)
                   .groupby("iso3c").first()
                   .reset_index()[["iso3c", "country", "year", "goveff"]])
print(latest_wgi.to_string(index=False))

# ── Panel completeness summary ───────────────────────────────
print("\n── Panel completeness by country (unemp, gdp_growth, goveff) ──")
for c in CIVETS:
    sub = panel[panel.iso3c == c]
    n_u = sub["unemp"].notna().sum()
    n_g = sub["gdp_growth"].notna().sum()
    n_w = sub["goveff"].notna().sum()
    print(f"  {c}: unemp={n_u}/24  gdp_growth={n_g}/24  goveff={n_w}/24")
