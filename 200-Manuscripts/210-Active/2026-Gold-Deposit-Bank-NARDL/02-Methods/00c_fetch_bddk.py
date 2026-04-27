#!/usr/bin/env python3
"""
KG-MGO-02: BDDK Data Fetcher
Fetches all required data for Gold Deposit NARDL paper.
Run: python3 00c_fetch_bddk.py

Requirements:
    pip install bddkdata pandas
"""

import bddkdata
import pandas as pd
import os
import time

RAW_DIR = "../01-Data/raw"
os.makedirs(RAW_DIR, exist_ok=True)

# ── Groups to fetch ───────────────────────────────────────────────────────────
GROUPS = {
    10001: "all_banking",
    10002: "deposit_banks",
    10003: "participation_banks",
    10004: "dev_investment",
    10005: "domestic_private",
    10006: "state",
    10007: "foreign",
    10008: "deposit_domestic_private",
    10009: "deposit_state",
    10010: "deposit_foreign",
    10011: "participation_domestic_private",
    10012: "participation_state",
    10013: "participation_foreign",
}

# ── Tables to fetch ───────────────────────────────────────────────────────────
TABLES = {
    1:  "balance_sheet",      # Total assets, deposits, equity
    2:  "income_statement",   # Interest income/expense, net profit
    9:  "deposit_types",      # GOLD DEPOSITS HERE
    12: "capital_adequacy",   # CAR
    15: "ratios",             # ROA, NIM, NPL, ROE
}

START_YEAR, START_MONTH = 2015, 1
END_YEAR,   END_MONTH   = 2025, 12


def fetch_table(table_no: int, table_name: str) -> pd.DataFrame:
    """Fetch one table across all bank groups, 2015-2025."""
    print(f"\n{'='*60}")
    print(f"Fetching Table {table_no}: {table_name}")
    print(f"{'='*60}")

    dfs = []
    for gid, gname in GROUPS.items():
        try:
            df = bddkdata.fetch_data(
                start_year=START_YEAR, start_month=START_MONTH,
                end_year=END_YEAR,     end_month=END_MONTH,
                table_no=table_no,
                currency="TL",
                group=gid,
                lang="en",
                save_excel=False,
            )
            if df is not None:
                df["group_id"]   = gid
                df["group_name"] = gname
                dfs.append(df)
                n_periods = df["Period"].nunique()
                print(f"  group={gid} ({gname}): {len(df)} rows, {n_periods} months ✓")
            else:
                print(f"  group={gid} ({gname}): No data returned")
            time.sleep(0.3)  # Be polite to server
        except Exception as e:
            print(f"  group={gid} ({gname}): ERROR — {str(e)[:80]}")

    if not dfs:
        print(f"  No data for table {table_no}")
        return None

    combined = pd.concat(dfs, ignore_index=True)
    out_path = os.path.join(RAW_DIR, f"bddk_table{table_no:02d}_{table_name}.csv")
    combined.to_csv(out_path, index=False)
    print(f"  → Saved: {out_path} ({len(combined):,} rows)")
    return combined


def summarize_gold(df_deposits: pd.DataFrame):
    """Print summary of gold deposit data."""
    if df_deposits is None:
        return
    pm = df_deposits[df_deposits["Item"].str.contains(
        "Precious Metal|Gold", na=False, case=False
    )]
    print(f"\n{'='*60}")
    print("GOLD DEPOSIT SUMMARY")
    print(f"{'='*60}")
    print(f"Total precious metal rows: {len(pm)}")
    print(f"Groups: {sorted(pm['group_name'].unique())}")
    print(f"Periods: {pm['Period'].min()} → {pm['Period'].max()}")
    if "Total" in pm.columns:
        print(f"Max total gold (million TL): {pm['Total'].max():,.0f}")
    print("\nSample rows:")
    print(pm[["group_name", "Item", "Total", "Period"]].head(10).to_string())


def summarize_ratios(df_ratios: pd.DataFrame):
    """Print ROA/NIM/NPL availability."""
    if df_ratios is None:
        return
    roa = df_ratios[df_ratios["Item"].str.contains("Net Income.*Total Assets", na=False)]
    nim = df_ratios[df_ratios["Item"].str.contains("Net Interest.*Total Assets", na=False)]
    npl = df_ratios[df_ratios["Item"].str.contains("Non-Performing.*Cash Loans", na=False)]
    print(f"\n{'='*60}")
    print("FINANCIAL RATIOS SUMMARY")
    print(f"{'='*60}")
    print(f"ROA rows: {len(roa)} | groups: {sorted(roa['group_name'].unique())}")
    print(f"NIM rows: {len(nim)} | groups: {sorted(nim['group_name'].unique())}")
    print(f"NPL rows: {len(npl)} | groups: {sorted(npl['group_name'].unique())}")
    if len(roa) > 0 and "Ratio" in roa.columns:
        print(f"\nROA sample:")
        print(roa[["group_name", "Ratio", "Period"]].head(6).to_string())


def main():
    print("BDDK Data Fetch — KG-MGO-02 Gold Deposit NARDL")
    print(f"Period: {START_YEAR}-{START_MONTH:02d} → {END_YEAR}-{END_MONTH:02d}")
    print(f"Output: {RAW_DIR}/\n")

    results = {}
    for table_no, table_name in TABLES.items():
        results[table_no] = fetch_table(table_no, table_name)

    # Summary reports
    summarize_gold(results.get(9))
    summarize_ratios(results.get(15))

    print("\n" + "="*60)
    print("FETCH COMPLETE")
    print("="*60)
    for tno, tname in TABLES.items():
        df = results.get(tno)
        status = f"{len(df):,} rows" if df is not None else "FAILED"
        print(f"  Table {tno:2d} ({tname}): {status}")

    print("\nNext: Run R script 00b_bddk_data_pipeline.R")
    print("  panel <- build_full_panel('../01-Data/raw')")


if __name__ == "__main__":
    main()
