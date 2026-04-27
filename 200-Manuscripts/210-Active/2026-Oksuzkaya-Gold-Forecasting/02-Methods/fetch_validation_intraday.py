import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import requests

ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
OUT_DIR = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results"
OUT_CSV = OUT_DIR / "gold_validation_intraday.csv"
OUT_MD = OUT_DIR / "gold_validation_intraday_report.md"
LOCAL_CACHE = OUT_DIR / "gold_validation_intraday_cache.json"


def request_json(url: str, *, params=None, headers=None, timeout=30, retries=2, sleep_s=2):
    last_exc = None
    for attempt in range(retries + 1):
        try:
            r = requests.get(url, params=params, headers=headers, timeout=timeout)
            r.raise_for_status()
            return r.json()
        except Exception as exc:
            last_exc = exc
            if attempt < retries:
                time.sleep(sleep_s)
    raise last_exc


def fetch_twelvedata(symbol: str, interval: str = "1min", outputsize: int = 5000):
    api_key = os.getenv("TWELVEDATA_API_KEY")
    if not api_key:
        return None, "TWELVEDATA_API_KEY not set"
    url = "https://api.twelvedata.com/time_series"
    params = {
        "symbol": symbol,
        "interval": interval,
        "outputsize": outputsize,
        "apikey": api_key,
        "format": "JSON",
    }
    data = request_json(url, params=params, timeout=30)
    if "values" not in data:
        return None, data
    df = pd.DataFrame(data["values"])
    if "datetime" in df.columns:
        df["datetime"] = pd.to_datetime(df["datetime"])
        df = df.sort_values("datetime").set_index("datetime")
    for c in df.columns:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    return df, data


def fetch_goldapi():
    api_key = os.getenv("GOLDAPI_KEY")
    if not api_key:
        return None, "GOLDAPI_KEY not set"
    url = "https://www.goldapi.io/api/XAU/USD"
    headers = {"x-access-token": api_key, "Content-Type": "application/json"}
    data = request_json(url, headers=headers, timeout=30)
    return pd.DataFrame([data]), data


def fetch_metalpriceapi():
    api_key = os.getenv("METALPRICE_API_KEY")
    if not api_key:
        return None, "METALPRICE_API_KEY not set"
    url = "https://api.metalpriceapi.com/v1/latest"
    params = {
        "api_key": api_key,
        "base": "XAU",
        "currencies": "USD",
    }
    data = request_json(url, params=params, timeout=30)
    return pd.DataFrame([data]), data


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    reports = []

    td_symbols = {
        "XAUUSD": "XAU/USD",
        "USDJPY": "USD/JPY",
        "USDCHF": "USD/CHF",
        "VIX": "VIX",
        "SP500": "SPX",
    }
    for name, sym in td_symbols.items():
        try:
            df, raw = fetch_twelvedata(sym)
            if df is None:
                reports.append(f"- {name}: skipped ({raw})")
                continue
            latest = df.iloc[-1]
            rows.append({
                "timestamp_utc": df.index[-1].tz_localize(None) if getattr(df.index, "tz", None) is not None else df.index[-1],
                "source": "twelvedata",
                "symbol": sym,
                "name": name,
                "close": float(latest.get("close", latest.get("price", float("nan")))),
                "open": float(latest.get("open", float("nan"))) if "open" in latest else float("nan"),
                "high": float(latest.get("high", float("nan"))) if "high" in latest else float("nan"),
                "low": float(latest.get("low", float("nan"))) if "low" in latest else float("nan"),
                "volume": float(latest.get("volume", float("nan"))) if "volume" in latest else float("nan"),
            })
            reports.append(f"- {name}: fetched {len(df)} rows from Twelve Data")
        except Exception as e:
            reports.append(f"- {name}: error ({e})")

    try:
        gdf, raw = fetch_goldapi()
        if gdf is not None:
            rows.append({
                "timestamp_utc": datetime.now(timezone.utc).replace(tzinfo=None),
                "source": "goldapi",
                "symbol": "XAU/USD",
                "name": "XAUUSD",
                "close": float(gdf.iloc[0].get("price", float("nan"))),
                "open": float(gdf.iloc[0].get("open_price", float("nan"))),
                "high": float(gdf.iloc[0].get("high_price", float("nan"))),
                "low": float(gdf.iloc[0].get("low_price", float("nan"))),
                "volume": float(gdf.iloc[0].get("volume", float("nan"))) if "volume" in gdf.columns else float("nan"),
            })
            reports.append("- XAUUSD: fetched from GoldAPI")
        else:
            reports.append(f"- XAUUSD: skipped ({raw})")
    except Exception as e:
        reports.append(f"- XAUUSD: error ({e})")

    try:
        mdf, raw = fetch_metalpriceapi()
        if mdf is not None:
            rows.append({
                "timestamp_utc": datetime.now(timezone.utc).replace(tzinfo=None),
                "source": "metalpriceapi",
                "symbol": "XAU/USD",
                "name": "XAUUSD",
                "close": float(mdf.iloc[0].get("rates", {}).get("USD", float("nan"))) if isinstance(mdf.iloc[0].get("rates", {}), dict) else float("nan"),
                "open": float("nan"),
                "high": float("nan"),
                "low": float("nan"),
                "volume": float("nan"),
            })
            reports.append("- XAUUSD: fetched from MetalpriceAPI")
        else:
            reports.append(f"- XAUUSD: skipped ({raw})")
    except Exception as e:
        reports.append(f"- XAUUSD: error ({e})")

    out_df = pd.DataFrame(rows)
    if not out_df.empty:
        out_df.to_csv(OUT_CSV, index=False)
        out_df.to_json(LOCAL_CACHE, orient="records", indent=2, force_ascii=False)

    OUT_MD.write_text(
        "\n".join(
            [
                "# Validation / Intraday Fetch Report",
                "",
                f"- Generated: {datetime.now().isoformat(timespec='seconds')}",
                f"- Rows: {len(out_df)}",
                f"- Cache: {'written' if not out_df.empty else 'not written'}",
                "",
                "## Status",
                *reports,
                "",
                "## Notes",
                "- Twelve Data and GoldAPI are treated as validation / extension providers.",
                "- Main paper continues to rely on the official daily backbone.",
                "- If no API keys are set, the script remains a no-op but still documents the access state.",
                "- A local cache is written only when at least one provider returns data.",
            ]
        ),
        encoding="utf-8",
    )
    print(f"Saved: {OUT_CSV if not out_df.empty else 'no data written'}")
    print(f"Saved report: {OUT_MD}")


if __name__ == "__main__":
    main()
