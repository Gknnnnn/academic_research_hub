from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
DATASET = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_gold_crypto_dataset_v1.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_model_summary.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_model_metrics.csv"
OUT_COEFS = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_key_coefficients.csv"


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


def write_summary(rows: list[dict], key_coefs: list[dict]) -> None:
    metrics = pd.DataFrame(rows).sort_values("rmse")
    metrics.to_csv(OUT_CSV, index=False)
    coef_df = pd.DataFrame(key_coefs)
    coef_df.to_csv(OUT_COEFS, index=False)
    lines = [
        "# Paper 5 Model Summary",
        "",
        "## Model Metrics",
        "",
        metrics.to_markdown(index=False),
        "",
        "## Interpretation",
        "",
        "- `Gold Safe-Haven OLS` explains gold with crypto and macro stress controls.",
        "- `BTC Safe-Haven OLS` explains Bitcoin with the same macro-financial environment.",
        "- `Gold-BTC Spread OLS` targets direct competition between the two assets.",
        "- `Crisis Competition OLS` uses macro crisis interactions only and avoids target-component leakage.",
        "",
        "## Key Coefficients",
        "",
        coef_df.to_markdown(index=False),
        "",
    ]
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    df = pd.read_csv(DATASET, parse_dates=["DATE"]).sort_values("DATE").reset_index(drop=True)
    df = df.replace([np.inf, -np.inf], np.nan)

    df["dxy_x_crisis"] = df["dxy_return"] * df["crisis_flag"]
    df["vix_x_crisis"] = df["vix_change"] * df["crisis_flag"]
    df["epu_change"] = df["epu_us"].pct_change()
    df["epu_x_crisis"] = df["epu_change"] * df["crisis_flag"]
    df = df.dropna().reset_index(drop=True)

    split_date = pd.Timestamp("2022-12-31")
    train = df[df["DATE"] <= split_date].copy()
    test = df[df["DATE"] > split_date].copy()

    specs = {
        "Gold Safe-Haven OLS": (
            "gold_return",
            ["btc_return", "eth_return", "dxy_return", "usdjpy_return", "usdchf_return", "vix_change", "epu_us"],
        ),
        "BTC Safe-Haven OLS": (
            "btc_return",
            ["gold_return", "eth_return", "dxy_return", "vix_change", "epu_us", "currency_war_flag"],
        ),
        "Gold-BTC Spread OLS": (
            "gold_btc_spread_return",
            ["dxy_return", "usdjpy_return", "usdchf_return", "vix_change", "epu_us", "currency_war_flag", "crisis_flag"],
        ),
        "Crisis Competition OLS": (
            "gold_btc_spread_return",
            ["dxy_return", "usdjpy_return", "usdchf_return", "vix_change", "epu_change", "dxy_x_crisis", "vix_x_crisis", "epu_x_crisis", "crisis_flag"],
        ),
    }

    rows: list[dict] = []
    key_coefs: list[dict] = []

    for name, (target, features) in specs.items():
        model, _, metrics = fit_ols(train, test, target, features)
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
