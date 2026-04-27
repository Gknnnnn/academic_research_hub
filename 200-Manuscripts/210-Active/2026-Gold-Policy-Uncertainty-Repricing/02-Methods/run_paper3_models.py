from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
DATASET = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Policy-Uncertainty-Repricing/03-Results/paper3_gold_policy_uncertainty_dataset.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Policy-Uncertainty-Repricing/03-Results/paper3_model_summary.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Policy-Uncertainty-Repricing/03-Results/paper3_model_metrics.csv"
OUT_COEFS = ROOT / "300-Projects/310-Active-Papers/2026-Gold-Policy-Uncertainty-Repricing/03-Results/paper3_key_coefficients.csv"


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
        "# Paper 3 Model Summary",
        "",
        "## Model Metrics",
        "",
        metrics.to_markdown(index=False),
        "",
        "## Interpretation",
        "",
        "- `Policy Core OLS` uses policy uncertainty and policy stance variables directly.",
        "- `Safe-Haven Repricing OLS` adds CHF and JPY comparisons to the policy block.",
        "- `Tightening Interaction OLS` tests whether policy uncertainty matters differently during tightening phases.",
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

    df["dxy_return"] = df["DXY"].pct_change()
    df["usdjpy_return"] = df["USDJPY"].pct_change()
    df["usdchf_return"] = df["USDCHF"].pct_change()
    df["oil_return"] = df["OIL"].pct_change()
    df["vix_change"] = df["VIX"].diff()
    df["epu_change"] = df["epu_us"].pct_change()
    df["ust10y_change"] = df["ust10y"].diff()
    df["tightening_x_epu"] = df["tightening_regime"] * df["epu_change"]
    df["easing_x_epu"] = df["easing_regime"] * df["epu_change"]
    df = df.dropna().reset_index(drop=True)

    split_date = pd.Timestamp("2020-12-31")
    train = df[df["DATE"] <= split_date].copy()
    test = df[df["DATE"] > split_date].copy()

    target = "gold_return"
    policy_core = ["epu_change", "fed_funds_effective", "ust10y_change", "policy_shock_flag"]
    repricing_block = ["epu_change", "dxy_return", "usdjpy_return", "usdchf_return", "vix_change", "ust10y_change"]
    tightening_block = ["epu_change", "tightening_regime", "tightening_x_epu", "dxy_return", "vix_change"]

    rows: list[dict] = []
    key_coefs: list[dict] = []

    for name, features in {
        "Policy Core OLS": policy_core,
        "Safe-Haven Repricing OLS": repricing_block,
        "Tightening Interaction OLS": tightening_block,
    }.items():
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

    # event-window style restricted sample around policy shock flags
    train_event = train[train["policy_shock_flag"] == 1]
    test_event = test[test["policy_shock_flag"] == 1]
    if len(train_event) > 100 and len(test_event) > 20:
        event_features = ["epu_change", "dxy_return", "ust10y_change", "vix_change"]
        model, _, metrics = fit_ols(train_event, test_event, target, event_features)
        rows.append({"model": "Policy Shock Window OLS", **metrics})
        for feature in event_features:
            key_coefs.append(
                {
                    "model": "Policy Shock Window OLS",
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
