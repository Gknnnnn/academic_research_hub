from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
DATASET = ROOT / "300-Projects/310-Active-Papers/2026-Target-Switching-Currency-War-Predictors/03-Results/paper7_shared_target_dataset.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Target-Switching-Currency-War-Predictors/03-Results/paper7_model_summary.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Target-Switching-Currency-War-Predictors/03-Results/paper7_model_metrics.csv"
OUT_COEFS = ROOT / "300-Projects/310-Active-Papers/2026-Target-Switching-Currency-War-Predictors/03-Results/paper7_key_coefficients.csv"


def metric_frame(y_true: pd.Series, y_pred: pd.Series) -> tuple[float, float, float]:
    err = y_true - y_pred
    rmse = float(np.sqrt(np.mean(np.square(err))))
    mae = float(np.mean(np.abs(err)))
    directional_accuracy = float((np.sign(y_true) == np.sign(y_pred)).mean())
    return rmse, mae, directional_accuracy


def fit_ols(train: pd.DataFrame, test: pd.DataFrame, target: str, features: list[str]):
    model = sm.OLS(train[target], sm.add_constant(train[features])).fit()
    pred = model.predict(sm.add_constant(test[features], has_constant="add"))
    rmse, mae, da = metric_frame(test[target], pred)
    return model, {
        "rmse": rmse,
        "mae": mae,
        "directional_accuracy": da,
        "adj_r2": float(model.rsquared_adj),
    }


def write_summary(rows: list[dict], coefs: list[dict]) -> None:
    metrics = pd.DataFrame(rows)
    coef_df = pd.DataFrame(coefs)
    metrics.to_csv(OUT_CSV, index=False)
    coef_df.to_csv(OUT_COEFS, index=False)
    lines = [
        "# Paper 7 Model Summary",
        "",
        "## Model Metrics",
        "",
        metrics.to_markdown(index=False),
        "",
        "## Interpretation",
        "",
        "- The same predictor universe is applied to multiple targets.",
        "- Differences in sign, fit, and directional accuracy indicate target sensitivity.",
        "",
        "## Key Coefficients",
        "",
        coef_df.to_markdown(index=False),
        "",
    ]
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    df = pd.read_csv(DATASET, parse_dates=["DATE"]).sort_values("DATE").reset_index(drop=True)
    df = df.dropna().reset_index(drop=True)

    split_date = pd.Timestamp("2022-12-31")
    train = df[df["DATE"] <= split_date].copy()
    test = df[df["DATE"] > split_date].copy()

    predictors = ["dxy_return", "usdjpy_return", "usdchf_return", "oil_return", "vix_change", "epu_us", "currency_war_flag"]
    targets = ["gold_return", "gold_rv_proxy", "btc_return", "gold_btc_spread_return"]

    rows = []
    coefs = []
    for target in targets:
        model, metrics = fit_ols(train, test, target, predictors)
        rows.append({"target": target, **metrics})
        for feature in predictors:
            coefs.append(
                {
                    "target": target,
                    "term": feature,
                    "coef": float(model.params.get(feature, np.nan)),
                    "pvalue": float(model.pvalues.get(feature, np.nan)),
                }
            )

    write_summary(rows, coefs)
    print(f"Saved metrics: {OUT_CSV}")
    print(f"Saved coefficients: {OUT_COEFS}")
    print(f"Saved summary: {OUT_MD}")


if __name__ == "__main__":
    main()
