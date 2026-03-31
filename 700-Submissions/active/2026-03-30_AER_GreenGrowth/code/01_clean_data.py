#!/usr/bin/env python3
import pandas as pd
from datetime import datetime
from pathlib import Path

VAULT_ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")

INPUT = Path(__file__).resolve().parents[1] / "data" / "turkiye_makro_data.csv"
OUTPUT = Path(__file__).resolve().parents[0] / "cleaned_data.csv"


def log_data_quality(dataset: Path, before: int, after: int, na_counts: pd.Series) -> None:
    log_path = VAULT_ROOT / "900-Dashboard" / "data_quality_log.md"
    ratio_logged = after / before * 100 if before else 0
    missing_summary = ", ".join(
        f"{col}={count}" for col, count in na_counts.items() if count > 0
    ) or "none"
    entry = [
        f"### {dataset.name}",
        f"- Date: {datetime.now().isoformat()}",
        f"- Rows before clean: {before}",
        f"- Rows after clean: {after} ({ratio_logged:.1f}% preserved)",
        f"- Missing cells by column: {missing_summary}",
        ""
    ]
    log_path.parent.mkdir(parents=True, exist_ok=True)
    existing = log_path.read_text(encoding="utf-8") if log_path.exists() else ""
    log_path.write_text(f"{existing}\n".rstrip() + "\n" + "\n".join(entry), encoding="utf-8")


def main():
    df = pd.read_csv(INPUT)
    before = len(df)
    na_counts = df.isna().sum()
    df = df.dropna(subset=["gdp_usd", "co2_kt"])
    after = len(df)
    df["year"] = df["year"].astype(int)
    df.to_csv(OUTPUT, index=False)
    log_data_quality(INPUT, before, after, na_counts)
    print("Saved cleaned data to", OUTPUT)
    print(f"{before - after} rows removed due to NA in gdp_usd/co2_kt")


if __name__ == "__main__":
    main()
