from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import yfinance as yf


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
BASE = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_gold_crypto_dataset_v2.csv"
OUT = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_gold_crypto_dataset_v3_altcoins.csv"
OUT_NOTE = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_gold_crypto_dataset_v3_altcoins.source_note.md"

ALTCOIN_TICKERS = [
    "ETH-USD",
    "XRP-USD",
    "LTC-USD",
    "BCH-USD",
    "ADA-USD",
    "DOGE-USD",
    "BNB-USD",
    "SOL-USD",
    "TRX-USD",
    "LINK-USD",
    "DOT-USD",
    "AVAX-USD",
    "XLM-USD",
    "MATIC-USD",
]


def fetch_adj_close(ticker: str) -> pd.Series:
    df = yf.download(ticker, start="2016-05-01", end="2026-04-05", auto_adjust=False, progress=False)
    if df.empty:
        return pd.Series(dtype=float, name=ticker)
    if isinstance(df.columns, pd.MultiIndex):
        close = df["Adj Close"].iloc[:, 0]
    else:
        close = df["Adj Close"]
    close.name = ticker
    close.index = pd.to_datetime(close.index).normalize()
    return close


def main() -> None:
    base = pd.read_csv(BASE, parse_dates=["DATE"]).sort_values("DATE")
    base["DATE"] = pd.to_datetime(base["DATE"]).dt.normalize()

    prices = []
    coverage = []
    for ticker in ALTCOIN_TICKERS:
        series = fetch_adj_close(ticker)
        if series.empty:
            continue
        prices.append(series)
        coverage.append({
            "ticker": ticker,
            "start": str(series.dropna().index.min().date()) if series.dropna().size else None,
            "end": str(series.dropna().index.max().date()) if series.dropna().size else None,
            "obs": int(series.notna().sum()),
        })

    price_df = pd.concat(prices, axis=1).sort_index()
    ret_df = np.log(price_df).diff()

    out = ret_df.reset_index().rename(columns={"index": "DATE", ret_df.index.name or "Date": "DATE"})
    out["DATE"] = pd.to_datetime(out["DATE"]).dt.normalize()
    out["altcoin_equal_weight_return"] = ret_df.mean(axis=1, skipna=True).to_numpy()
    out["altcoin_breadth"] = (ret_df > 0).mean(axis=1, skipna=True).to_numpy()
    out["altcoin_dispersion"] = ret_df.std(axis=1, skipna=True).to_numpy()
    out["altcoin_active_count"] = ret_df.notna().sum(axis=1).to_numpy()

    for ticker in price_df.columns:
        short = ticker.replace("-USD", "").lower()
        out[f"{short}_return"] = ret_df[ticker].values

    merged = base.merge(out, on="DATE", how="left")
    merged.to_csv(OUT, index=False)

    cov_df = pd.DataFrame(coverage)
    lines = [
        "# Source Note",
        "- Added a broad altcoin market layer via `yfinance` daily USD crypto prices.",
        "- This is a reproducible broad altcoin basket, not a literal census of all altcoins.",
        "- Basket variables:",
        "  - `altcoin_equal_weight_return`",
        "  - `altcoin_breadth`",
        "  - `altcoin_dispersion`",
        "  - `altcoin_active_count`",
        "- Constituent coverage:",
        "",
        cov_df.to_markdown(index=False) if not cov_df.empty else "No altcoin series were retrieved.",
        "",
    ]
    OUT_NOTE.write_text("\n".join(lines), encoding="utf-8")

    print(f"Saved dataset: {OUT}")
    print(f"Saved note: {OUT_NOTE}")


if __name__ == "__main__":
    main()
