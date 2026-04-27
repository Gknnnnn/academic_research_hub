from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
DATASET = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_gold_crypto_dataset_v2.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_btc_only_robustness_summary.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_btc_only_robustness_metrics.csv"
OUT_COEFS = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_btc_only_robustness_coefficients.csv"


def metric_frame(y_true: pd.Series, y_pred: pd.Series) -> tuple[float, float, float]:
    err = y_true - y_pred
    rmse = float(np.sqrt(np.mean(np.square(err))))
    mae = float(np.mean(np.abs(err)))
    directional_accuracy = float((np.sign(y_true) == np.sign(y_pred)).mean())
    return rmse, mae, directional_accuracy


def fit_ols(train: pd.DataFrame, test: pd.DataFrame, target: str, features: list[str]):
    x_train = sm.add_constant(train[features].astype(float), has_constant="add")
    x_test = sm.add_constant(test[features].astype(float), has_constant="add")
    model = sm.OLS(train[target].astype(float), x_train).fit()
    pred = model.predict(x_test)
    rmse, mae, da = metric_frame(test[target], pred)
    return model, {"rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": float(model.rsquared_adj)}


def write_outputs(rows: list[dict], coef_rows: list[dict]) -> None:
    metrics = pd.DataFrame(rows).sort_values("rmse")
    metrics.to_csv(OUT_CSV, index=False)
    coefs = pd.DataFrame(coef_rows)
    coefs.to_csv(OUT_COEFS, index=False)

    lines = [
        "# Paper 5 BTC-Only Robustness",
        "",
        "## Model Metrics",
        "",
        metrics.to_markdown(index=False),
        "",
        "## Notes",
        "",
        "- These models remove `eth_return` entirely to test whether the Bitcoin-side signal survives without crypto co-movement control.",
        "- The purpose is not to replace the main spread equations, but to show that the Bitcoin stress narrative is not entirely an ETH shadow.",
        "",
        "## Key Coefficients",
        "",
        coefs.to_markdown(index=False),
        "",
    ]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    df = pd.read_csv(DATASET, parse_dates=["DATE"]).sort_values("DATE").reset_index(drop=True)
    df = df.replace([np.inf, -np.inf], np.nan)
    df["stablecoin_supply_change"] = df["stablecoin_supply_proxy"].pct_change()
    df["dxy_x_crisis"] = df["dxy_return"] * df["crisis_flag"]
    df["vix_x_crisis"] = df["vix_change"] * df["crisis_flag"]

    split_date = pd.Timestamp("2022-12-31")
    specs = {
        "BTC-Only Macro OLS": (
            "btc_return",
            ["dxy_return", "usdjpy_return", "usdchf_return", "vix_change", "epu_us", "currency_war_flag"],
        ),
        "BTC-Only Stablecoin OLS": (
            "btc_return",
            ["dxy_return", "vix_change", "crisis_flag", "stablecoin_supply_change"],
        ),
        "BTC-Only Crisis OLS": (
            "btc_return",
            ["dxy_return", "vix_change", "dxy_x_crisis", "vix_x_crisis", "crisis_flag", "stablecoin_supply_change"],
        ),
    }

    rows: list[dict] = []
    coef_rows: list[dict] = []
    for model_name, (target, features) in specs.items():
        sub = df[["DATE", target] + features].dropna().reset_index(drop=True)
        train = sub[sub["DATE"] <= split_date].copy()
        test = sub[sub["DATE"] > split_date].copy()
        model, metrics = fit_ols(train, test, target, features)
        rows.append({"model": model_name, **metrics})
        for term in features:
            coef_rows.append({
                "model": model_name,
                "term": term,
                "coef": float(model.params.get(term, np.nan)),
                "pvalue": float(model.pvalues.get(term, np.nan)),
            })

    write_outputs(rows, coef_rows)
    print(f"Saved metrics: {OUT_CSV}")
    print(f"Saved coefficients: {OUT_COEFS}")
    print(f"Saved summary: {OUT_MD}")


if __name__ == "__main__":
    main()
