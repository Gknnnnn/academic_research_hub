from __future__ import annotations

from io import StringIO
from pathlib import Path
import subprocess

import pandas as pd


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
PORTFOLIO_CACHE = ROOT / "300-Projects" / "310-Active-Papers" / "2026-Research-Portfolio-Currency-Wars" / "data-cache"
MASTER_CSV = ROOT / "400-Data" / "440-Custom-Datasets" / "gold_research_master.csv"
OUT_CSV = ROOT / "300-Projects" / "310-Active-Papers" / "2026-Gold-Crypto-Safe-Haven-Competition" / "03-Results" / "paper5_gold_crypto_dataset_v1.csv"
OUT_NOTE = ROOT / "300-Projects" / "310-Active-Papers" / "2026-Gold-Crypto-Safe-Haven-Competition" / "03-Results" / "paper5_gold_crypto_dataset_v1.source_note.md"

FRED_SERIES = {
    "CBBTCUSD": "btc_usd",
    "CBETHUSD": "eth_usd",
    "USEPUINDXD": "epu_us",
    "DFF": "fed_funds_effective",
}


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def fetch_fred_csv(series_id: str, col_name: str) -> pd.DataFrame:
    cache_file = PORTFOLIO_CACHE / f"{series_id}.csv"
    if cache_file.exists():
        raw = cache_file.read_text(encoding="utf-8")
    else:
        url = f"https://fred.stlouisfed.org/graph/fredgraph.csv?id={series_id}"
        result = subprocess.run(["curl", "-sS", url], check=True, capture_output=True, text=True)
        raw = result.stdout
        ensure_dir(PORTFOLIO_CACHE)
        cache_file.write_text(raw, encoding="utf-8")
    df = pd.read_csv(StringIO(raw))
    df.columns = ["DATE", col_name]
    df["DATE"] = pd.to_datetime(df["DATE"])
    df[col_name] = pd.to_numeric(df[col_name], errors="coerce")
    return df


def main() -> None:
    gold = pd.read_csv(MASTER_CSV, parse_dates=["DATE"]).sort_values("DATE")

    extra = None
    for series_id, col_name in FRED_SERIES.items():
        frame = fetch_fred_csv(series_id, col_name)
        extra = frame if extra is None else extra.merge(frame, on="DATE", how="outer")

    merged = gold.merge(extra, on="DATE", how="left").sort_values("DATE")
    # Forward-fill macro and policy series for calendar alignment, but never backfill crypto
    for col in ["epu_us", "fed_funds_effective"]:
        merged[col] = merged[col].ffill()
    for col in ["btc_usd", "eth_usd"]:
        merged[col] = merged[col].ffill()

    merged["gold_return"] = merged["GOLD"].pct_change()
    merged["btc_return"] = merged["btc_usd"].pct_change()
    merged["eth_return"] = merged["eth_usd"].pct_change()
    merged["gold_btc_spread_return"] = merged["gold_return"] - merged["btc_return"]
    merged["btc_vol_proxy"] = merged["btc_return"].abs()
    merged["eth_vol_proxy"] = merged["eth_return"].abs()
    merged["dxy_return"] = merged["DXY"].pct_change()
    merged["usdjpy_return"] = merged["USDJPY"].pct_change()
    merged["usdchf_return"] = merged["USDCHF"].pct_change()
    merged["oil_return"] = merged["OIL"].pct_change()
    merged["vix_change"] = merged["VIX"].diff()
    merged["currency_war_flag"] = (
        (merged["DXY"].pct_change(20) > 0.02)
        | (merged["fed_funds_effective"].diff(5) > 0)
    ).astype(int)
    merged["crisis_flag"] = (merged["VIX"] >= 30).astype(int)

    cols = [
        "DATE", "GOLD", "btc_usd", "eth_usd", "DXY", "USDJPY", "USDCHF", "OIL", "VIX",
        "epu_us", "fed_funds_effective",
        "gold_return", "btc_return", "eth_return", "gold_btc_spread_return",
        "btc_vol_proxy", "eth_vol_proxy", "dxy_return", "usdjpy_return", "usdchf_return",
        "oil_return", "vix_change", "currency_war_flag", "crisis_flag",
    ]

    final = merged[cols].dropna().reset_index(drop=True)
    ensure_dir(OUT_CSV.parent)
    final.to_csv(OUT_CSV, index=False)

    OUT_NOTE.write_text(
        "\n".join(
            [
                "# Source Note",
                "- Base gold data: gold_research_master.csv",
                "- Added FRED crypto series: CBBTCUSD and CBETHUSD",
                "- Added policy and monetary series: USEPUINDXD and DFF",
                "- Stablecoin market capitalization is intentionally excluded from v1 because no equally clean and reproducible free series was confirmed in this workflow.",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Saved dataset: {OUT_CSV}")
    print(f"Saved note: {OUT_NOTE}")


if __name__ == "__main__":
    main()
