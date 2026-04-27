from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
DATASET = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_gold_currency_wars_dataset_v2.csv"
OUT_SUMMARY = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_nardl_summary_v1.md"
OUT_COEFS = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_nardl_coefficients_v1.csv"
OUT_LONGRUN = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_nardl_long_run_v1.csv"


def partial_sum(series: pd.Series, positive: bool) -> pd.Series:
    piece = series.clip(lower=0) if positive else series.clip(upper=0)
    return piece.fillna(0.0).cumsum()


def build_dataset() -> pd.DataFrame:
    df = pd.read_csv(DATASET, parse_dates=["DATE"]).sort_values("DATE").reset_index(drop=True)
    df = df.replace([np.inf, -np.inf], np.nan)

    df["gold_log"] = np.log(df["GOLD"].replace(0, np.nan))
    df["dxy_pos_cum"] = partial_sum(df["dxy_return"], positive=True)
    df["dxy_neg_cum"] = partial_sum(df["dxy_return"], positive=False)
    df["jpy_pos_cum"] = partial_sum(df["usdjpy_return"], positive=True)
    df["jpy_neg_cum"] = partial_sum(df["usdjpy_return"], positive=False)

    df["d_gold_log"] = df["gold_log"].diff()
    df["dxy_pos"] = df["dxy_return"].clip(lower=0)
    df["dxy_neg"] = df["dxy_return"].clip(upper=0)
    df["jpy_pos"] = df["usdjpy_return"].clip(lower=0)
    df["jpy_neg"] = df["usdjpy_return"].clip(upper=0)

    df["gold_log_lag1"] = df["gold_log"].shift(1)
    df["dxy_pos_cum_lag1"] = df["dxy_pos_cum"].shift(1)
    df["dxy_neg_cum_lag1"] = df["dxy_neg_cum"].shift(1)
    df["jpy_pos_cum_lag1"] = df["jpy_pos_cum"].shift(1)
    df["jpy_neg_cum_lag1"] = df["jpy_neg_cum"].shift(1)
    df["d_gold_log_lag1"] = df["d_gold_log"].shift(1)

    keep = [
        "DATE", "d_gold_log", "gold_log_lag1", "dxy_pos_cum_lag1", "dxy_neg_cum_lag1",
        "jpy_pos_cum_lag1", "jpy_neg_cum_lag1", "d_gold_log_lag1",
        "dxy_pos", "dxy_neg", "jpy_pos", "jpy_neg", "epu_us", "fed_funds_effective",
    ]
    return df[keep].dropna().reset_index(drop=True)


def main() -> None:
    df = build_dataset()
    features = [
        "gold_log_lag1",
        "dxy_pos_cum_lag1",
        "dxy_neg_cum_lag1",
        "jpy_pos_cum_lag1",
        "jpy_neg_cum_lag1",
        "d_gold_log_lag1",
        "dxy_pos",
        "dxy_neg",
        "jpy_pos",
        "jpy_neg",
        "epu_us",
        "fed_funds_effective",
    ]
    X = sm.add_constant(df[features].astype(float), has_constant="add")
    y = df["d_gold_log"].astype(float)
    model = sm.OLS(y, X).fit()

    coef_df = pd.DataFrame({
        "term": model.params.index,
        "coef": model.params.values,
        "pvalue": model.pvalues.values,
    })
    coef_df.to_csv(OUT_COEFS, index=False)

    ect = float(model.params["gold_log_lag1"])
    long_run_rows = []
    for level_term in ["dxy_pos_cum_lag1", "dxy_neg_cum_lag1", "jpy_pos_cum_lag1", "jpy_neg_cum_lag1"]:
        long_run_rows.append({
            "term": level_term.replace("_cum_lag1", "_long_run"),
            "coef": float(-model.params[level_term] / ect) if ect != 0 else np.nan,
        })
    long_run_df = pd.DataFrame(long_run_rows)
    long_run_df.to_csv(OUT_LONGRUN, index=False)

    lines = [
        "# Paper 1 NARDL-Style ECM Summary v1",
        "",
        "## Model Shape",
        "",
        "- Dependent variable: `delta log(gold)`",
        "- Error-correction style specification with lagged level terms and short-run asymmetric differences.",
        "- Asymmetry channels: positive/negative DXY changes and positive/negative USDJPY changes.",
        "",
        "## Core Diagnostics",
        "",
        f"- Observations: {len(df)}",
        f"- Adjusted R-squared: {float(model.rsquared_adj):.6f}",
        f"- Error-correction coefficient on `gold_log_lag1`: {float(model.params['gold_log_lag1']):.6f} (p={float(model.pvalues['gold_log_lag1']):.6g})",
        "",
        "## Short-Run Asymmetry",
        "",
        coef_df[coef_df["term"].isin(["dxy_pos", "dxy_neg", "jpy_pos", "jpy_neg"])].to_markdown(index=False),
        "",
        "## Long-Run Asymmetry",
        "",
        long_run_df.to_markdown(index=False),
        "",
        "## Interpretation Notes",
        "",
        "- A negative and significant error-correction term supports an ECM-style adjustment story.",
        "- Differences between positive and negative partial-sum coefficients indicate asymmetric long-run transmission.",
        "- This is a practical NARDL-style implementation for the current draft stage, not yet a full lag-order search exercise.",
        "",
    ]
    OUT_SUMMARY.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Saved summary: {OUT_SUMMARY}")
    print(f"Saved coefficients: {OUT_COEFS}")
    print(f"Saved long-run table: {OUT_LONGRUN}")


if __name__ == "__main__":
    main()
