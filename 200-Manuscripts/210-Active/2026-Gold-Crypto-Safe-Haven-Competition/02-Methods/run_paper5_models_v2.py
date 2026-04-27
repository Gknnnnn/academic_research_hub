from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
DATASET = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_gold_crypto_dataset_v2.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_model_summary_v2.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_model_metrics_v2.csv"
OUT_COEFS = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_key_coefficients_v2.csv"


def metric_frame(y_true: pd.Series, y_pred: pd.Series) -> tuple[float, float, float]:
    err = y_true - y_pred
    rmse = float(np.sqrt(np.mean(np.square(err))))
    mae = float(np.mean(np.abs(err)))
    directional_accuracy = float((np.sign(y_true) == np.sign(y_pred)).mean())
    return rmse, mae, directional_accuracy


def fit_ols(train: pd.DataFrame, test: pd.DataFrame, target: str, features: list[str]):
    x_train = train[features].astype(float).copy()
    x_test = test[features].astype(float).copy()
    x_train.insert(0, "const", 1.0)
    x_test.insert(0, "const", 1.0)
    model = sm.OLS(train[target].astype(float).to_numpy(), x_train.to_numpy()).fit()
    pred = model.predict(x_test.to_numpy())
    rmse, mae, da = metric_frame(test[target], pred)
    model.feature_names = ["const"] + features
    return model, {"rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": float(model.rsquared_adj)}


def write_summary(rows: list[dict], key_coefs: list[dict]) -> None:
    metrics = pd.DataFrame(rows).sort_values("rmse")
    metrics.to_csv(OUT_CSV, index=False)
    coef_df = pd.DataFrame(key_coefs)
    coef_df.to_csv(OUT_COEFS, index=False)

    lines = [
        "# Paper 5 Model Summary v2",
        "",
        "## Model Metrics",
        "",
        metrics.to_markdown(index=False),
        "",
        "## Notes",
        "",
        "- `Stablecoin-Augmented Spread OLS` adds the historical stablecoin supply proxy.",
        "- `BTC dominance` is not yet active as a daily regressor because only a current snapshot is available in v2.",
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
    df["stablecoin_supply_change"] = df["stablecoin_supply_proxy"].pct_change()
    df["dxy_x_crisis"] = df["dxy_return"] * df["crisis_flag"]
    df["vix_x_crisis"] = df["vix_change"] * df["crisis_flag"]

    split_date = pd.Timestamp("2022-12-31")

    specs = {
        "Stablecoin-Augmented Spread OLS": (
            "gold_btc_spread_return",
            ["dxy_return", "usdjpy_return", "usdchf_return", "vix_change", "epu_us", "currency_war_flag", "crisis_flag", "stablecoin_supply_change"],
        ),
        "Stablecoin Crisis OLS": (
            "gold_btc_spread_return",
            ["dxy_return", "vix_change", "dxy_x_crisis", "vix_x_crisis", "crisis_flag", "stablecoin_supply_change"],
        ),
    }

    rows: list[dict] = []
    key_coefs: list[dict] = []
    for name, (target, features) in specs.items():
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
                    "coef": float(dict(zip(model.feature_names, model.params)).get(feature, np.nan)),
                    "pvalue": float(dict(zip(model.feature_names, model.pvalues)).get(feature, np.nan)),
                }
            )

    write_summary(rows, key_coefs)
    print(f"Saved metrics: {OUT_CSV}")
    print(f"Saved coefficients: {OUT_COEFS}")
    print(f"Saved summary: {OUT_MD}")


if __name__ == "__main__":
    main()
