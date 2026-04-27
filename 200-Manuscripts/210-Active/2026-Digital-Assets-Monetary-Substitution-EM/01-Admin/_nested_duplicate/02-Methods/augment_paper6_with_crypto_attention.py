from __future__ import annotations

from io import StringIO
from pathlib import Path
import json
import subprocess

import pandas as pd


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
CACHE_DIR = ROOT / "300-Projects" / "310-Active-Papers" / "2026-Research-Portfolio-Currency-Wars" / "data-cache"
INPUT_CSV = ROOT / "300-Projects" / "310-Active-Papers" / "2026-Digital-Assets-Monetary-Substitution-EM" / "03-Results" / "paper6_em_panel_v1.csv"
OUT_CSV = ROOT / "300-Projects" / "310-Active-Papers" / "2026-Digital-Assets-Monetary-Substitution-EM" / "03-Results" / "paper6_em_panel_v2_crypto_attention.csv"
OUT_NOTE = ROOT / "300-Projects" / "310-Active-Papers" / "2026-Digital-Assets-Monetary-Substitution-EM" / "03-Results" / "paper6_em_panel_v2_crypto_attention.source_note.md"

WIKI_SERIES = {
    "Bitcoin": "global_btc_attention",
    "Tether_(cryptocurrency)": "global_tether_attention",
    "Cryptocurrency": "global_crypto_attention",
}


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def fetch_wiki_pageviews(article: str) -> pd.DataFrame:
    safe_name = article.replace("/", "_")
    cache_file = CACHE_DIR / f"wiki_{safe_name}.json"
    if cache_file.exists():
        raw = cache_file.read_text(encoding="utf-8")
    else:
        url = (
            "https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/"
            f"en.wikipedia/all-access/user/{article}/daily/20140101/20260401"
        )
        result = subprocess.run(["curl", "-sS", url], check=True, capture_output=True, text=True)
        raw = result.stdout
        ensure_dir(CACHE_DIR)
        cache_file.write_text(raw, encoding="utf-8")
    payload = json.loads(raw)
    items = payload.get("items", [])
    rows = []
    for item in items:
        ts = item["timestamp"][:8]
        rows.append({"DATE": pd.to_datetime(ts, format="%Y%m%d"), "views": item["views"]})
    return pd.DataFrame(rows)


def monthly_mean(df: pd.DataFrame, col_name: str) -> pd.DataFrame:
    out = df.copy()
    out["DATE"] = out["DATE"].dt.to_period("M").dt.to_timestamp()
    out = out.groupby("DATE", as_index=False)["views"].mean()
    out = out.rename(columns={"views": col_name})
    return out


def main() -> None:
    panel = pd.read_csv(INPUT_CSV, parse_dates=["DATE"]).sort_values(["country", "DATE"])

    attention = None
    for article, col_name in WIKI_SERIES.items():
        df = fetch_wiki_pageviews(article)
        monthly = monthly_mean(df, col_name)
        attention = monthly if attention is None else attention.merge(monthly, on="DATE", how="outer")

    attention = attention.sort_values("DATE").ffill().bfill()
    merged = panel.merge(attention, on="DATE", how="left").sort_values(["country", "DATE"])
    merged["crypto_proxy_missing"] = 0

    ensure_dir(OUT_CSV.parent)
    merged.to_csv(OUT_CSV, index=False)
    OUT_NOTE.write_text(
        "\n".join(
            [
                "# Source Note",
                "- Base panel: paper6_em_panel_v1.csv",
                "- Added monthly global attention proxies from Wikimedia pageviews",
                "- Proxies included: Bitcoin, Tether (cryptocurrency), Cryptocurrency",
                "- These are global attention indicators, not country-specific adoption measures",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Saved panel: {OUT_CSV}")
    print(f"Saved note: {OUT_NOTE}")


if __name__ == "__main__":
    main()
