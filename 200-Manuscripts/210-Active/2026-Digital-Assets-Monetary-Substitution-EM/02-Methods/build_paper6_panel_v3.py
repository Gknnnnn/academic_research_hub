"""
P6 Panel v3 Builder
===================
Adds country-level Google Trends (BTC + stablecoin),
World Bank macro (inflation, M2, reserves),
and country policy rates to the existing v2 panel.

Output: paper6_em_panel_v3.csv

Run: python build_paper6_panel_v3.py
"""

import time
import pandas as pd
import numpy as np
from pathlib import Path

# ── paths ──────────────────────────────────────────────────────────────────
BASE = Path(__file__).resolve().parent.parent
RESULTS = BASE / "03-Results"
V2_PATH = RESULTS / "paper6_em_panel_v2_crypto_attention.csv"
V3_PATH = RESULTS / "paper6_em_panel_v3.csv"
LOG_PATH = RESULTS / "build_v3_log.md"

COUNTRIES = {
    "Brazil":       {"geo": "BR", "iso3": "BRA", "fred_policy": "BRMFTDM"},
    "Mexico":       {"geo": "MX", "iso3": "MEX", "fred_policy": None},
    "India":        {"geo": "IN", "iso3": "IND", "fred_policy": None},
    "South Africa": {"geo": "ZA", "iso3": "ZAF", "fred_policy": None},
}

COUNTRY_NAME_MAP = {
    "Brazil": "Brazil", "Mexico": "Mexico",
    "India": "India", "South Africa": "South Africa"
}

# ── 1. Google Trends — country-level BTC + stablecoin ──────────────────────

def fetch_google_trends_country(geo: str, keywords: list, label: str,
                                 start: str = "2012-01-01",
                                 end: str = "2024-12-31") -> pd.Series:
    """
    Returns monthly average interest (0-100) for given keywords and geo.
    Uses pytrends with rate-limit protection.
    """
    try:
        from pytrends.request import TrendReq
    except ImportError:
        print("  pytrends not installed. Run: pip install pytrends")
        return pd.Series(dtype=float, name=label)

    pytrends = TrendReq(hl="en-US", tz=360, timeout=(10, 25))
    all_series = []

    for kw in keywords:
        try:
            pytrends.build_payload(
                [kw], cat=0, timeframe=f"{start} {end}",
                geo=geo, gprop=""
            )
            df = pytrends.interest_over_time()
            if df.empty:
                print(f"  No data: {kw} / {geo}")
                continue
            df.index = pd.to_datetime(df.index)
            monthly = df[kw].resample("MS").mean()
            all_series.append(monthly)
            time.sleep(60)  # rate limit protection
        except Exception as e:
            print(f"  Error {kw}/{geo}: {e}")
            time.sleep(90)

    if not all_series:
        return pd.Series(dtype=float, name=label)

    combined = pd.concat(all_series, axis=1).mean(axis=1)
    combined.name = label
    return combined


def build_trends_block(start: str = "2012-01-01", end: str = "2024-12-31") -> pd.DataFrame:
    """Build country-level BTC and stablecoin interest panel."""
    print("\n[1/4] Fetching Google Trends by country...")
    records = []

    btc_keywords = {
        "Brazil":       ["bitcoin", "criptomoeda"],
        "Mexico":       ["bitcoin", "criptomoneda"],
        "India":        ["bitcoin", "cryptocurrency"],
        "South Africa": ["bitcoin", "cryptocurrency"],
    }
    stable_keywords = {
        "Brazil":       ["tether", "USDT", "stablecoin"],
        "Mexico":       ["tether", "USDT"],
        "India":        ["tether", "USDT"],
        "South Africa": ["tether", "USDT"],
    }

    trends_data = {}
    for country, meta in COUNTRIES.items():
        geo = meta["geo"]
        print(f"  {country} ({geo}) — BTC...")
        btc_series = fetch_google_trends_country(
            geo, btc_keywords[country], f"{country.lower().replace(' ', '_')}_btc_interest",
            start, end
        )
        print(f"  {country} ({geo}) — stablecoin...")
        stable_series = fetch_google_trends_country(
            geo, stable_keywords[country], f"{country.lower().replace(' ', '_')}_stablecoin_interest",
            start, end
        )
        trends_data[country] = {
            "btc": btc_series,
            "stablecoin": stable_series,
        }

    # Build long-format rows
    all_dates = pd.date_range(start, end, freq="MS")
    for country, series_dict in trends_data.items():
        for date in all_dates:
            row = {"DATE": date, "country": country}
            for key, series in series_dict.items():
                col = f"{country.lower().replace(' ', '_')}_{key}_interest"
                row[col] = series.get(date, np.nan)
            records.append(row)

    if not records:
        return pd.DataFrame()

    df = pd.DataFrame(records)
    return df


# ── 2. World Bank — inflation, M2, reserves ────────────────────────────────

def fetch_worldbank_macro() -> pd.DataFrame:
    """
    Fetches annual World Bank indicators and forward-fills to monthly.
    Returns long-format panel.
    """
    print("\n[2/4] Fetching World Bank macro indicators...")
    try:
        import wbdata
    except ImportError:
        print("  wbdata not installed. Run: pip install wbdata")
        return _worldbank_fallback()

    indicators = {
        "FP.CPI.TOTL.ZG":    "inflation_cpi_ann",
        "FM.LBL.BMNY.GD.ZS": "broad_money_pct_gdp",
        "FI.RES.TOTL.MO":    "reserves_months_imports",
        "NY.GDP.PCAP.CD":    "gdp_per_capita",
    }

    iso3_list = [meta["iso3"] for meta in COUNTRIES.values()]
    country_name_by_iso3 = {meta["iso3"]: name for name, meta in COUNTRIES.items()}

    try:
        raw = wbdata.get_dataframe(indicators, country=iso3_list)
        raw = raw.reset_index()
        raw.columns = raw.columns.str.lower()
        # wbdata returns 'date' as year string and 'country' as name
        raw["year"] = pd.to_numeric(raw["date"], errors="coerce")
        raw = raw.dropna(subset=["year"])
        raw["year"] = raw["year"].astype(int)
    except Exception as e:
        print(f"  wbdata error: {e}")
        return _worldbank_fallback()

    # Forward-fill annual to monthly
    monthly_rows = []
    for _, row in raw.iterrows():
        country_name = row.get("country", "")
        year = int(row["year"])
        for month in range(1, 13):
            date = pd.Timestamp(year=year, month=month, day=1)
            monthly_rows.append({
                "DATE": date,
                "country": country_name,
                "inflation_cpi_ann": row.get("inflation_cpi_ann"),
                "broad_money_pct_gdp": row.get("broad_money_pct_gdp"),
                "reserves_months_imports": row.get("reserves_months_imports"),
                "gdp_per_capita": row.get("gdp_per_capita"),
                "wb_source": "wbdata_api",
            })

    df = pd.DataFrame(monthly_rows)
    # Sort and forward-fill within each country
    df = df.sort_values(["country", "DATE"])
    for col in ["inflation_cpi_ann", "broad_money_pct_gdp",
                "reserves_months_imports", "gdp_per_capita"]:
        df[col] = df.groupby("country")[col].transform(
            lambda x: x.fillna(method="ffill")
        )
    return df


def _worldbank_fallback() -> pd.DataFrame:
    """Returns empty template if wbdata unavailable."""
    print("  World Bank fallback: returning empty template.")
    return pd.DataFrame(columns=[
        "DATE", "country", "inflation_cpi_ann",
        "broad_money_pct_gdp", "reserves_months_imports",
        "gdp_per_capita", "wb_source"
    ])


# ── 3. FRED country policy rates ───────────────────────────────────────────

def fetch_fred_policy_rates() -> pd.DataFrame:
    """
    Fetches Brazil policy rate from FRED.
    Mexico/India/South Africa: uses proxy or returns NaN.
    """
    print("\n[3/4] Fetching country policy rates from FRED...")
    try:
        import pandas_datareader.data as web
    except ImportError:
        print("  pandas-datareader not installed.")
        return pd.DataFrame()

    rows = []

    # Brazil SELIC rate (available on FRED)
    try:
        br = web.DataReader("BRMFTDM", "fred", "1995-01-01", "2024-12-31")
        br = br.resample("MS").last().reset_index()
        br.columns = ["DATE", "policy_rate"]
        br["country"] = "Brazil"
        rows.append(br)
        print("  Brazil SELIC: OK")
    except Exception as e:
        print(f"  Brazil SELIC error: {e}")

    # Mexico: FRED does not have clean Banxico rate series
    # India: Use FRED INDIRLTLT01STM as long-rate proxy
    try:
        ind = web.DataReader("INDIRLTLT01STM", "fred", "1995-01-01", "2024-12-31")
        ind = ind.resample("MS").last().reset_index()
        ind.columns = ["DATE", "policy_rate"]
        ind["country"] = "India"
        rows.append(ind)
        print("  India long-rate proxy: OK")
    except Exception as e:
        print(f"  India rate error: {e}")

    if not rows:
        return pd.DataFrame()

    df = pd.concat(rows, ignore_index=True)
    df["policy_rate_source"] = "FRED"
    return df[["DATE", "country", "policy_rate", "policy_rate_source"]]


# ── 4. Merge with v2 panel ─────────────────────────────────────────────────

def build_v3_panel(skip_trends: bool = False) -> pd.DataFrame:
    """
    Loads v2 panel and merges all new layers.
    skip_trends=True skips Google Trends (use when rate-limited).
    """
    print("\n[4/4] Building v3 panel...")

    if not V2_PATH.exists():
        raise FileNotFoundError(f"v2 panel not found: {V2_PATH}")

    v2 = pd.read_csv(V2_PATH, parse_dates=["DATE"])
    v2["DATE"] = pd.to_datetime(v2["DATE"]).dt.to_period("M").dt.to_timestamp()
    print(f"  v2 loaded: {len(v2)} rows, countries: {v2['country'].unique().tolist()}")

    # World Bank
    wb = fetch_worldbank_macro()
    if not wb.empty:
        wb["DATE"] = pd.to_datetime(wb["DATE"]).dt.to_period("M").dt.to_timestamp()
        v3 = v2.merge(wb, on=["DATE", "country"], how="left")
    else:
        v3 = v2.copy()
        for col in ["inflation_cpi_ann", "broad_money_pct_gdp",
                    "reserves_months_imports", "gdp_per_capita"]:
            v3[col] = np.nan
        v3["wb_source"] = "pending"

    # FRED policy rates
    pol = fetch_fred_policy_rates()
    if not pol.empty:
        pol["DATE"] = pd.to_datetime(pol["DATE"]).dt.to_period("M").dt.to_timestamp()
        v3 = v3.merge(pol, on=["DATE", "country"], how="left")
    else:
        v3["policy_rate"] = np.nan
        v3["policy_rate_source"] = "pending"

    # Google Trends (optional, slow)
    if not skip_trends:
        trends = build_trends_block()
        if not trends.empty:
            trends["DATE"] = pd.to_datetime(trends["DATE"]).dt.to_period("M").dt.to_timestamp()
            # Trends are wide by country — need to restructure
            # Each row has DATE + country + country_btc_interest + country_stablecoin_interest
            # We need the matching column for each country row
            def get_country_trend(row, suffix):
                col = f"{row['country'].lower().replace(' ', '_')}_{suffix}"
                return trends.loc[
                    (trends["DATE"] == row["DATE"]) & (trends["country"] == row["country"]),
                    col
                ].values[0] if col in trends.columns else np.nan

            v3["country_btc_interest"] = v3.apply(
                lambda r: get_country_trend(r, "btc_interest"), axis=1
            )
            v3["country_stablecoin_interest"] = v3.apply(
                lambda r: get_country_trend(r, "stablecoin_interest"), axis=1
            )
        else:
            v3["country_btc_interest"] = np.nan
            v3["country_stablecoin_interest"] = np.nan
            v3["trends_source"] = "pending"
    else:
        v3["country_btc_interest"] = np.nan
        v3["country_stablecoin_interest"] = np.nan
        v3["trends_source"] = "skipped_rate_limit"
        print("  Google Trends skipped (skip_trends=True)")

    # Derived: broad money growth rate (YoY change)
    if "broad_money_pct_gdp" in v3.columns:
        v3 = v3.sort_values(["country", "DATE"])
        v3["broad_money_instability"] = v3.groupby("country")["broad_money_pct_gdp"].transform(
            lambda x: x.pct_change(12).abs()
        )
    else:
        v3["broad_money_instability"] = np.nan

    # Derived: reserve adequacy change
    if "reserves_months_imports" in v3.columns:
        v3["reserve_adequacy_change"] = v3.groupby("country")["reserves_months_imports"].transform(
            lambda x: x.pct_change(12)
        )
    else:
        v3["reserve_adequacy_change"] = np.nan

    v3 = v3.sort_values(["country", "DATE"]).reset_index(drop=True)
    v3["panel_version"] = "v3"
    v3["build_date"] = "2026-04-04"

    return v3


# ── main ────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("P6 Panel v3 Builder")
    print("=" * 60)

    # Set skip_trends=True for fast run without rate limits
    # Set skip_trends=False for full fetch (takes ~30 min due to rate limits)
    SKIP_TRENDS = False

    try:
        v3 = build_v3_panel(skip_trends=SKIP_TRENDS)
        RESULTS.mkdir(parents=True, exist_ok=True)
        v3.to_csv(V3_PATH, index=False)
        print(f"\n✅ v3 panel saved: {V3_PATH}")
        print(f"   Rows: {len(v3)}, Columns: {len(v3.columns)}")
        print(f"   New columns: inflation_cpi_ann, broad_money_pct_gdp, "
              f"reserves_months_imports, country_btc_interest, "
              f"country_stablecoin_interest, broad_money_instability, "
              f"reserve_adequacy_change")

        # Write build log
        missing = {col: int(v3[col].isna().sum()) for col in [
            "inflation_cpi_ann", "broad_money_pct_gdp",
            "reserves_months_imports", "country_btc_interest",
            "country_stablecoin_interest"
        ] if col in v3.columns}

        log = f"""# P6 v3 Build Log

**Date:** 2026-04-04
**Output:** paper6_em_panel_v3.csv
**Rows:** {len(v3)}
**Columns:** {len(v3.columns)}
**Countries:** {v3['country'].unique().tolist()}
**Date range:** {v3['DATE'].min()} — {v3['DATE'].max()}

## Missing Value Counts (NaN)
{chr(10).join(f'- `{k}`: {v} NaN rows' for k, v in missing.items())}

## Variable Status
| Variable | Source | Status |
|---|---|---|
| fx_depreciation | FRED | ✅ v1 |
| global_dollar_change | FRED | ✅ v1 |
| inflation_cpi_ann | World Bank WDI | {'✅' if missing.get('inflation_cpi_ann', 1) < len(v3) * 0.5 else '⚠️ partial'} |
| broad_money_pct_gdp | World Bank WDI | {'✅' if missing.get('broad_money_pct_gdp', 1) < len(v3) * 0.5 else '⚠️ partial'} |
| reserves_months_imports | World Bank WDI | {'✅' if missing.get('reserves_months_imports', 1) < len(v3) * 0.5 else '⚠️ partial'} |
| country_btc_interest | Google Trends | {'✅' if missing.get('country_btc_interest', 1) < len(v3) * 0.5 else '⚠️ pending — run with skip_trends=False'} |
| country_stablecoin_interest | Google Trends | {'✅' if missing.get('country_stablecoin_interest', 1) < len(v3) * 0.5 else '⚠️ pending — run with skip_trends=False'} |

## Next Step
Run `run_paper6_panel_models_v3.py` to refit models with new variables.
"""
        LOG_PATH.write_text(log)
        print(f"   Log: {LOG_PATH}")

    except Exception as e:
        print(f"\n❌ Build failed: {e}")
        raise


if __name__ == "__main__":
    main()
