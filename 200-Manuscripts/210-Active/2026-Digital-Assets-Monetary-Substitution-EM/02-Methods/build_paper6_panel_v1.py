from __future__ import annotations

from io import StringIO
from pathlib import Path
import subprocess

import pandas as pd


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
PORTFOLIO_CACHE = ROOT / "300-Projects" / "310-Active-Papers" / "2026-Research-Portfolio-Currency-Wars" / "data-cache"
OUT_CSV = ROOT / "300-Projects" / "310-Active-Papers" / "2026-Digital-Assets-Monetary-Substitution-EM" / "03-Results" / "paper6_em_panel_v1.csv"
OUT_NOTE = ROOT / "300-Projects" / "310-Active-Papers" / "2026-Digital-Assets-Monetary-Substitution-EM" / "03-Results" / "paper6_em_panel_v1.source_note.md"

SERIES_MAP = {
    "DEXBZUS": ("Brazil", "usdbrl"),
    "DEXMXUS": ("Mexico", "usdmxn"),
    "DEXINUS": ("India", "usdinr"),
    "DEXSFUS": ("South Africa", "usdzar"),
    "DTWEXM": (None, "dxy"),
    "DFF": (None, "fed_funds_effective"),
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


def monthly_last(df: pd.DataFrame, value_col: str) -> pd.DataFrame:
    out = df.copy()
    out["month"] = out["DATE"].dt.to_period("M").dt.to_timestamp()
    out = out.sort_values("DATE").groupby("month", as_index=False)[value_col].last()
    out = out.rename(columns={"month": "DATE"})
    return out


def main() -> None:
    global_frames = []
    country_frames = []

    for series_id, (country, col_name) in SERIES_MAP.items():
        frame = fetch_fred_csv(series_id, col_name)
        monthly = monthly_last(frame, col_name)
        if country is None:
            global_frames.append(monthly)
        else:
            monthly["country"] = country
            country_frames.append(monthly)

    global_df = global_frames[0]
    for frame in global_frames[1:]:
        global_df = global_df.merge(frame, on="DATE", how="outer")
    global_df = global_df.sort_values("DATE").ffill().bfill()

    panel_parts = []
    for frame in country_frames:
        value_col = [c for c in frame.columns if c not in {"DATE", "country"}][0]
        tmp = frame.merge(global_df, on="DATE", how="left").sort_values("DATE")
        tmp["fx_level"] = tmp[value_col]
        tmp["fx_depreciation"] = tmp["fx_level"].pct_change()
        tmp["global_dollar_change"] = tmp["dxy"].pct_change()
        tmp["fed_change"] = tmp["fed_funds_effective"].diff()
        tmp["monetary_substitution_pressure_v1"] = (
            tmp["fx_depreciation"].abs().fillna(0)
            + tmp["global_dollar_change"].abs().fillna(0)
            + tmp["fed_change"].abs().fillna(0) / 100
        )
        tmp["crypto_proxy_missing"] = 1
        tmp["fx_series_code"] = value_col
        panel_parts.append(
            tmp[
                [
                    "DATE",
                    "country",
                    "fx_series_code",
                    "fx_level",
                    "dxy",
                    "fed_funds_effective",
                    "fx_depreciation",
                    "global_dollar_change",
                    "fed_change",
                    "monetary_substitution_pressure_v1",
                    "crypto_proxy_missing",
                ]
            ]
        )

    panel = pd.concat(panel_parts, ignore_index=True)
    panel = panel.dropna(subset=["fx_depreciation"]).reset_index(drop=True)

    ensure_dir(OUT_CSV.parent)
    panel.to_csv(OUT_CSV, index=False)
    OUT_NOTE.write_text(
        "\n".join(
            [
                "# Source Note",
                "- v1 panel countries: Brazil, Mexico, India, South Africa",
                "- Monthly panel built from public FRED FX series plus DXY and effective fed funds rate",
                "- `monetary_substitution_pressure_v1` is only a starter pressure index, not the final conceptual index",
                "- Crypto adoption proxies are not yet integrated; `crypto_proxy_missing=1` marks this explicitly",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Saved panel: {OUT_CSV}")
    print(f"Saved note: {OUT_NOTE}")


if __name__ == "__main__":
    main()
