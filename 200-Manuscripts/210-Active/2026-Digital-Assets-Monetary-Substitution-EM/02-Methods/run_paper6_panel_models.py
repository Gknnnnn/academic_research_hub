from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
DATASET = ROOT / "300-Projects/310-Active-Papers/2026-Digital-Assets-Monetary-Substitution-EM/03-Results/paper6_em_panel_v2_crypto_attention.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Digital-Assets-Monetary-Substitution-EM/03-Results/paper6_panel_summary.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Digital-Assets-Monetary-Substitution-EM/03-Results/paper6_panel_metrics.csv"
OUT_COEFS = ROOT / "300-Projects/310-Active-Papers/2026-Digital-Assets-Monetary-Substitution-EM/03-Results/paper6_panel_coefficients.csv"


def metric_frame(y_true: pd.Series, y_pred: pd.Series) -> tuple[float, float]:
    err = y_true - y_pred
    rmse = float(np.sqrt(np.mean(np.square(err))))
    mae = float(np.mean(np.abs(err)))
    return rmse, mae


def fit_ols(train: pd.DataFrame, test: pd.DataFrame, target: str, features: list[str]):
    model = sm.OLS(train[target], sm.add_constant(train[features])).fit()
    pred = model.predict(sm.add_constant(test[features], has_constant="add"))
    rmse, mae = metric_frame(test[target], pred)
    return model, pred, {
        "rmse": rmse,
        "mae": mae,
        "adj_r2": float(model.rsquared_adj),
    }


def add_country_dummies(df: pd.DataFrame) -> pd.DataFrame:
    dummies = pd.get_dummies(df["country"], prefix="country", drop_first=True, dtype=float)
    return pd.concat([df, dummies], axis=1)


def write_summary(rows: list[dict], coefs: list[dict]) -> None:
    metrics = pd.DataFrame(rows).sort_values("rmse")
    coef_df = pd.DataFrame(coefs)
    metrics.to_csv(OUT_CSV, index=False)
    coef_df.to_csv(OUT_COEFS, index=False)
    lines = [
        "# Paper 6 Panel Summary",
        "",
        "## Model Metrics",
        "",
        metrics.to_markdown(index=False),
        "",
        "## Interpretation",
        "",
        "- `FX Fragility OLS` is the baseline country-panel macro model.",
        "- `Pressure Index OLS` treats the constructed substitution-pressure measure as the dependent variable.",
        "- `Country-FE Style OLS` adds country dummies to absorb level differences across countries.",
        "",
        "## Key Coefficients",
        "",
        coef_df.to_markdown(index=False),
        "",
        "## Limitation",
        "",
        "- The current digital-asset layer uses global attention proxies, so this is still an intermediate version rather than the final country-specific cryptoization model.",
    ]
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    df = pd.read_csv(DATASET, parse_dates=["DATE"]).sort_values(["country", "DATE"]).reset_index(drop=True)

    df["fx_depreciation_lag1"] = df.groupby("country")["fx_depreciation"].shift(1)
    df["pressure_lag1"] = df.groupby("country")["monetary_substitution_pressure_v1"].shift(1)
    df["dxy_change_lag1"] = df.groupby("country")["global_dollar_change"].shift(1)
    df["fed_change_lag1"] = df.groupby("country")["fed_change"].shift(1)
    df["btc_attention_change"] = df["global_btc_attention"].pct_change()
    df["crypto_attention_change"] = df["global_crypto_attention"].pct_change()
    df["tether_attention_change"] = df["global_tether_attention"].pct_change()
    df = add_country_dummies(df)
    df = df.dropna().reset_index(drop=True)

    split_date = pd.Timestamp("2020-01-01")
    train = df[df["DATE"] < split_date].copy()
    test = df[df["DATE"] >= split_date].copy()

    dummy_cols = [c for c in df.columns if c.startswith("country_")]
    rows: list[dict] = []
    coefs: list[dict] = []

    specs = {
        "FX Fragility OLS": (
            "fx_depreciation",
            ["global_dollar_change", "fed_change", "fx_depreciation_lag1"],
        ),
        "Pressure Index OLS": (
            "monetary_substitution_pressure_v1",
            ["global_dollar_change", "fed_change", "pressure_lag1"],
        ),
        "Crypto Attention OLS": (
            "monetary_substitution_pressure_v1",
            ["global_dollar_change", "pressure_lag1", "btc_attention_change", "crypto_attention_change", "tether_attention_change"],
        ),
        "Country-FE Style OLS": (
            "fx_depreciation",
            ["global_dollar_change", "fed_change", "fx_depreciation_lag1"] + dummy_cols,
        ),
    }

    for name, (target, features) in specs.items():
        model, _, metrics = fit_ols(train, test, target, features)
        rows.append({"model": name, **metrics})
        for feature in features:
            coefs.append(
                {
                    "model": name,
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
