from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
DATASET = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_gold_currency_wars_dataset_v2.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_model_summary_v2.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_model_metrics_v2.csv"
OUT_COEFS = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_key_coefficients_v2.csv"


def metric_frame(y_true: pd.Series, y_pred: pd.Series) -> tuple[float, float, float]:
    err = y_true - y_pred
    rmse = float(np.sqrt(np.mean(np.square(err))))
    mae = float(np.mean(np.abs(err)))
    directional_accuracy = float((np.sign(y_true) == np.sign(y_pred)).mean())
    return rmse, mae, directional_accuracy


def fit_ols(train: pd.DataFrame, test: pd.DataFrame, target: str, features: list[str]):
    x_train = sm.add_constant(train[features], has_constant="add").astype(float)
    x_test = sm.add_constant(test[features], has_constant="add").astype(float)
    x_test = x_test.reindex(columns=x_train.columns, fill_value=1.0 if "const" in x_train.columns else 0.0)
    model = sm.OLS(train[target].astype(float), x_train).fit()
    pred = model.predict(x_test)
    rmse, mae, da = metric_frame(test[target], pred)
    return model, {"rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": float(model.rsquared_adj)}


def write_summary(rows: list[dict], key_coefs: list[dict]) -> None:
    metrics = pd.DataFrame(rows).sort_values("rmse")
    metrics.to_csv(OUT_CSV, index=False)
    coef_df = pd.DataFrame(key_coefs)
    coef_df.to_csv(OUT_COEFS, index=False)

    lines = [
        "# Paper 1 Model Summary v2",
        "",
        "## Model Metrics",
        "",
        metrics.to_markdown(index=False),
        "",
        "## Notes",
        "",
        "- `Extended Baseline OLS` adds the broad real dollar and round-1 MOVE proxy.",
        "- `Extended Safe Haven OLS` tests whether the new stress variables sharpen the safe-haven channel.",
        "- `MOVE proxy` here is `STLFSI4`, not the literal MOVE index.",
        "",
        "## Key Coefficients",
        "",
        coef_df.to_markdown(index=False),
        "",
    ]
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    df = pd.read_csv(DATASET, parse_dates=["DATE"]).sort_values("DATE")
    df = df.replace([np.inf, -np.inf], np.nan)

    split_date = pd.Timestamp("2020-12-31")
    train = df[df["DATE"] <= split_date].copy()
    test = df[df["DATE"] > split_date].copy()

    specs = {
        "Extended Baseline OLS": [
            "dxy_return", "usdjpy_return", "usdchf_return", "oil_return", "vix_change",
            "fed_funds_effective", "epu_us", "broad_real_dollar_change", "move_proxy_change",
        ],
        "Extended Safe Haven OLS": [
            "usdjpy_return", "usdchf_return", "vix_change", "epu_us",
            "broad_real_dollar_change", "move_proxy_change",
        ],
    }

    rows: list[dict] = []
    key_coefs: list[dict] = []
    target = "gold_return"

    for name, features in specs.items():
        sub = df[["DATE", target] + features].dropna().reset_index(drop=True)
        train_sub = sub[sub["DATE"] <= split_date].copy()
        test_sub = sub[sub["DATE"] > split_date].copy()
        model, metrics = fit_ols(train_sub, test_sub, target, features)
        rows.append({"model": name, **metrics})
        for feature in features:
            key_coefs.append(
                {
                    "model": name,
                    "term": feature,
                    "coef": float(model.params.get(feature, np.nan)),
                    "pvalue": float(model.pvalues.get(feature, np.nan)),
                }
            )

    write_summary(rows, key_coefs)
    print(f"Saved metrics: {OUT_CSV}")
    print(f"Saved coefficients: {OUT_COEFS}")
    print(f"Saved summary: {OUT_MD}")


if __name__ == "__main__":
    main()
