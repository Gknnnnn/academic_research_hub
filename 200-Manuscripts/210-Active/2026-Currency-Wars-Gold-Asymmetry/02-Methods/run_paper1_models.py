from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
DATASET = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_gold_currency_wars_dataset.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_model_summary.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_model_metrics.csv"
OUT_COEFS = ROOT / "300-Projects/310-Active-Papers/2026-Currency-Wars-Gold-Asymmetry/03-Results/paper1_key_coefficients.csv"


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
    return model, pred, {
        "rmse": rmse,
        "mae": mae,
        "directional_accuracy": da,
        "adj_r2": float(model.rsquared_adj),
    }


def make_shock_split(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    out = df.copy()
    for col in columns:
        out[f"{col}_pos"] = out[col].clip(lower=0)
        out[f"{col}_neg"] = out[col].clip(upper=0)
    return out


def write_summary(rows: list[dict], key_coefs: list[dict]) -> None:
    metrics = pd.DataFrame(rows)
    metrics.to_csv(OUT_CSV, index=False)
    pd.DataFrame(key_coefs).to_csv(OUT_COEFS, index=False)

    lines = [
        "# Paper 1 Model Summary",
        "",
        "## Model Metrics",
        "",
        metrics.to_markdown(index=False),
        "",
        "## Interpretation",
        "",
        "- `Baseline OLS` uses the full currency-war and stress control set.",
        "- `Currency War OLS` keeps the reserve-currency and hard-currency core.",
        "- `Safe Haven OLS` focuses on safe-haven stress channels.",
        "- `Shock Split OLS` tests sign asymmetry using positive and negative return decompositions.",
        "",
        "## Key Coefficients",
        "",
        pd.DataFrame(key_coefs).to_markdown(index=False),
        "",
    ]
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    df = pd.read_csv(DATASET, parse_dates=["DATE"]).sort_values("DATE")
    df = df.replace([np.inf, -np.inf], np.nan).dropna().reset_index(drop=True)

    split_date = pd.Timestamp("2020-12-31")
    train = df[df["DATE"] <= split_date].copy()
    test = df[df["DATE"] > split_date].copy()

    target = "gold_return"
    baseline_cols = ["dxy_return", "usdjpy_return", "usdchf_return", "oil_return", "vix_change", "fed_funds_effective", "epu_us"]
    currency_cols = ["dxy_return", "usdjpy_return", "usdchf_return", "fed_funds_effective"]
    safehaven_cols = ["usdjpy_return", "usdchf_return", "vix_change", "epu_us"]

    rows: list[dict] = []
    key_coefs: list[dict] = []

    for name, features in {
        "Baseline OLS": baseline_cols,
        "Currency War OLS": currency_cols,
        "Safe Haven OLS": safehaven_cols,
    }.items():
        model, _, metrics = fit_ols(train, test, target, features)
        rows.append({"model": name, **metrics})
        for feature in features[:4]:
            key_coefs.append(
                {
                    "model": name,
                    "term": feature,
                    "coef": float(model.params.get(feature, np.nan)),
                    "pvalue": float(model.pvalues.get(feature, np.nan)),
                }
            )

    split_cols = ["dxy_return", "usdjpy_return", "usdchf_return", "oil_return"]
    shock_df = make_shock_split(df, split_cols)
    shock_features = [f"{col}_{sign}" for col in split_cols for sign in ("pos", "neg")] + ["vix_change", "epu_us"]
    shock_train = shock_df[shock_df["DATE"] <= split_date].dropna().copy()
    shock_test = shock_df[shock_df["DATE"] > split_date].dropna().copy()
    shock_model, _, shock_metrics = fit_ols(shock_train, shock_test, target, shock_features)
    rows.append({"model": "Shock Split OLS", **shock_metrics})

    for feature in ["dxy_return_pos", "dxy_return_neg", "usdjpy_return_pos", "usdjpy_return_neg", "usdchf_return_pos", "usdchf_return_neg"]:
        key_coefs.append(
            {
                "model": "Shock Split OLS",
                "term": feature,
                "coef": float(shock_model.params.get(feature, np.nan)),
                "pvalue": float(shock_model.pvalues.get(feature, np.nan)),
            }
        )

    write_summary(rows, key_coefs)
    print(f"Saved metrics: {OUT_CSV}")
    print(f"Saved coefficients: {OUT_COEFS}")
    print(f"Saved summary: {OUT_MD}")


if __name__ == "__main__":
    main()
