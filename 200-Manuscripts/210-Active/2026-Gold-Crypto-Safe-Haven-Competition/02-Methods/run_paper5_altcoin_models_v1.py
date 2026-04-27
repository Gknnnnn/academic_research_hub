from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
DATASET = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_gold_crypto_dataset_v3_altcoins.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_altcoin_model_summary_v1.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_altcoin_model_metrics_v1.csv"
OUT_COEFS = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Crypto-Safe-Haven-Competition/03-Results/paper5_altcoin_model_coefficients_v1.csv"


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


def main() -> None:
    df = pd.read_csv(DATASET, parse_dates=["DATE"]).sort_values("DATE").reset_index(drop=True)
    df = df.replace([np.inf, -np.inf], np.nan)
    df["stablecoin_supply_change"] = df["stablecoin_supply_proxy"].pct_change()
    split_date = pd.Timestamp("2022-12-31")

    specs = {
        "Altcoin-Augmented Spread OLS": (
            "gold_btc_spread_return",
            ["dxy_return", "vix_change", "currency_war_flag", "crisis_flag", "stablecoin_supply_change", "altcoin_equal_weight_return", "altcoin_breadth"],
        ),
        "BTC with Altcoin Market OLS": (
            "btc_return",
            ["dxy_return", "vix_change", "currency_war_flag", "stablecoin_supply_change", "altcoin_equal_weight_return", "altcoin_breadth", "altcoin_dispersion"],
        ),
    }

    rows = []
    coef_rows = []
    for model_name, (target, features) in specs.items():
        sub = df[["DATE", target] + features].dropna().reset_index(drop=True)
        train = sub[sub["DATE"] <= split_date].copy()
        test = sub[sub["DATE"] > split_date].copy()
        if train.empty or test.empty:
            continue
        model, metrics = fit_ols(train, test, target, features)
        rows.append({"model": model_name, **metrics})
        for term in features:
            coef_rows.append({
                "model": model_name,
                "term": term,
                "coef": float(dict(zip(model.feature_names, model.params)).get(term, np.nan)),
                "pvalue": float(dict(zip(model.feature_names, model.pvalues)).get(term, np.nan)),
            })

    metrics_df = pd.DataFrame(rows).sort_values("rmse")
    coef_df = pd.DataFrame(coef_rows)
    metrics_df.to_csv(OUT_CSV, index=False)
    coef_df.to_csv(OUT_COEFS, index=False)

    lines = [
        "# Paper 5 Altcoin Layer Summary v1",
        "",
        "## Model Metrics",
        "",
        metrics_df.to_markdown(index=False),
        "",
        "## Notes",
        "",
        "- `Altcoin-Augmented Spread OLS` adds a broad altcoin market basket to the gold-BTC competition equation.",
        "- `BTC with Altcoin Market OLS` tests whether Bitcoin stress remains linked to the broader altcoin complex even after stablecoin liquidity is controlled for.",
        "- The altcoin layer is a broad basket proxy, not a literal census of every altcoin.",
        "",
        "## Key Coefficients",
        "",
        coef_df.to_markdown(index=False),
        "",
    ]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")

    print(f"Saved metrics: {OUT_CSV}")
    print(f"Saved coefficients: {OUT_COEFS}")
    print(f"Saved summary: {OUT_MD}")


if __name__ == "__main__":
    main()
