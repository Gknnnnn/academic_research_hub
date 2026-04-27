import os
from datetime import datetime

import pandas as pd
from pandas_datareader import data as web


SERIES_PLAN = {
    "GOLD": [("IQ12260", "1984-12-01"), ("IR14270", "1992-12-01")],
    "DXY": [("DTWEXM", "1980-01-01"), ("DTWEXAFEGS", "2006-01-02")],
    "USDJPY": [("DEXJPUS", "1980-01-01")],
    "USDCHF": [("DEXSZUS", "1980-01-01")],
    "SP500": [("SP500", "2016-04-04")],
    "OIL": [("DCOILWTICO", "1986-01-02")],
    "VIX": [("VIXCLS", "1990-01-02")],
}

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_CSV = os.path.normpath(
    os.path.join(PROJECT_DIR, "..", "..", "..", "400-Data", "440-Custom-Datasets", "gold_research_master.csv")
)
REPORT_MD = os.path.normpath(
    os.path.join(PROJECT_DIR, "03-Results", "gold_research_source_report.md")
)


def fetch_series(series_id: str, start_date: str, end_date: str) -> pd.DataFrame:
    df = web.DataReader(series_id, "fred", start_date, end_date)
    df.index = pd.to_datetime(df.index)
    return df


def splice_series(name: str, plans, end_date: str) -> pd.DataFrame:
    series_list = []
    for sid, start in plans:
        try:
            print(f"🔍 Fetching {name}:{sid} from {start}...")
            series_list.append(fetch_series(sid, start, end_date).iloc[:, 0])
        except Exception as exc:
            print(f"⚠️ {name}:{sid} failed: {exc}")
    if not series_list:
        return pd.DataFrame()
    combined = series_list[0].copy()
    for series in series_list[1:]:
        combined = combined.combine_first(series)
    return combined.to_frame(name)


def build_report(df: pd.DataFrame) -> str:
    lines = [
        "# Gold Forecasting Source Report",
        "",
        f"- Generated: {datetime.now().isoformat(timespec='seconds')}",
        f"- Rows: {len(df)}",
        f"- Columns: {len(df.columns)}",
        f"- Window: {df.index.min().date()} -> {df.index.max().date()}",
        "",
        "## Coverage",
    ]
    for col in df.columns:
        lines.append(f"- {col}: first={df[col].first_valid_index()} last={df[col].last_valid_index()}")
    return "\n".join(lines)


def main():
    print(f"🚀 Initializing Historical Research Ingestion at {datetime.now()}...")
    os.makedirs(os.path.dirname(OUTPUT_CSV), exist_ok=True)
    os.makedirs(os.path.dirname(REPORT_MD), exist_ok=True)

    end_date = datetime.now().strftime("%Y-%m-%d")
    frames = []
    for name, plans in SERIES_PLAN.items():
        frame = splice_series(name, plans, end_date)
        if not frame.empty:
            frames.append(frame)

    if not frames:
        print("❌ No series could be fetched.")
        return None

    full_df = pd.concat(frames, axis=1).sort_index()
    full_df.index.name = "DATE"
    full_df = full_df.interpolate(method="time").ffill().bfill()
    full_df.to_csv(OUTPUT_CSV)

    with open(REPORT_MD, "w", encoding="utf-8") as f:
        f.write(build_report(full_df))

    print(f"✅ Master Dataset Generated: {OUTPUT_CSV}")
    print(f"📊 Rows: {len(full_df)} | Columns: {list(full_df.columns)}")
    print(f"📅 Window: {full_df.index.min().date()} -> {full_df.index.max().date()}")
    print(f"📝 Report: {REPORT_MD}")
    return full_df


if __name__ == "__main__":
    main()
