import os
import numpy as np
import pandas as pd


INPUT_CSV = os.path.normpath(
    "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/400-Data/440-Custom-Datasets/gold_research_master.csv"
)
OUTPUT_DIR = os.path.normpath(
    "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results"
)
FEATURE_CSV = os.path.join(OUTPUT_DIR, "gold_research_features.csv")
MISSING_MD = os.path.join(OUTPUT_DIR, "gold_research_missingness.md")


def make_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    for col in df.columns:
        out[f"{col}_ret"] = df[col].pct_change()
        out[f"{col}_logret"] = np.log(df[col].where(df[col] > 0)).diff()
        out[f"{col}_lag1"] = df[col].shift(1)
        out[f"{col}_lag5"] = df[col].shift(5)
        out[f"{col}_lag20"] = df[col].shift(20)
    return out


def write_missingness(df: pd.DataFrame):
    lines = ["# Gold Forecasting Missingness Report", "", f"- Rows: {len(df)}", f"- Columns: {len(df.columns)}", ""]
    lines.append("## Column Coverage")
    for col in df.columns:
        miss = int(df[col].isna().sum())
        pct = miss / len(df) * 100 if len(df) else 0
        lines.append(f"- {col}: {miss} missing ({pct:.2f}%)")
    if "GOLD" not in df.columns:
        lines.append("")
        lines.append("## Notes")
        lines.append("- `GOLD` is not present in the current master file.")
    if "DXY" not in df.columns:
        lines.append("- `DXY` is not present in the current master file.")
    return "\n".join(lines)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    df = pd.read_csv(INPUT_CSV, parse_dates=["DATE"]).set_index("DATE").sort_index()
    features = make_features(df).dropna()
    features.to_csv(FEATURE_CSV)
    with open(MISSING_MD, "w", encoding="utf-8") as f:
        f.write(write_missingness(df))
    print(f"Saved features: {FEATURE_CSV}")
    print(f"Saved missingness report: {MISSING_MD}")
    print(f"Feature shape: {features.shape}")


if __name__ == "__main__":
    main()
