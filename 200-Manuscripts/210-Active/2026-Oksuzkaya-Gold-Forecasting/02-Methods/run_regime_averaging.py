import numpy as np
import pandas as pd
import statsmodels.api as sm
from pathlib import Path
from sklearn.metrics import mean_absolute_error, mean_squared_error

ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
ADV = ROOT / "400-Data/440-Custom-Datasets/gold_research_advanced_features.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/regime_averaging_summary.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/regime_averaging_predictions.csv"


def metric_frame(y_true, y_pred):
    rmse = float(np.sqrt(mean_squared_error(y_true, y_pred)))
    mae = float(mean_absolute_error(y_true, y_pred))
    da = float((np.sign(y_true) == np.sign(y_pred)).mean())
    return rmse, mae, da


def fit_predict(train, test, cols):
    fit = sm.OLS(train["GOLD_ret"], sm.add_constant(train[cols])).fit()
    pred = fit.predict(sm.add_constant(test[cols], has_constant="add"))
    return fit, pred


def main():
    df = pd.read_csv(ADV, parse_dates=["DATE"]).sort_values("DATE").set_index("DATE")
    train = df.loc[: "2022-12-31"].copy()
    test = df.loc["2023-01-01":].copy()
    cols = ["DXY_ret", "USDJPY_ret", "USDCHF_ret", "SP500_ret", "OIL_ret", "VIX_ret"]

    regime_models = {}
    regime_preds = pd.DataFrame(index=test.index)
    for regime in ["calm", "stress", "crisis"]:
        tr = train[train["regime_vix"] == regime]
        te = test[test["regime_vix"] == regime]
        if len(tr) < 50 or len(te) == 0:
            continue
        fit, pred = fit_predict(tr, te, cols)
        regime_models[regime] = fit
        regime_preds.loc[te.index, regime] = pred

    # Fill missing regime predictions by using all regime models on all rows
    full_regime_preds = pd.DataFrame(index=test.index)
    for regime, fit in regime_models.items():
        full_regime_preds[regime] = fit.predict(sm.add_constant(test[cols], has_constant="add"))

    weights = {}
    for regime in regime_models:
        tr = train[train["regime_vix"] == regime]
        if len(tr) < 50:
            continue
        fit, pred = fit_predict(tr, tr, cols)
        rmse, _, _ = metric_frame(tr["GOLD_ret"], pred)
        weights[regime] = 1 / max(rmse, 1e-8)
    wsum = sum(weights.values()) or 1.0
    weights = {k: v / wsum for k, v in weights.items()}
    avg_pred = sum(full_regime_preds[r] * weights.get(r, 0) for r in full_regime_preds.columns)

    # hard assignment benchmark
    hard_pred = pd.Series(index=test.index, dtype=float)
    for regime in full_regime_preds.columns:
        idx = test["regime_vix"] == regime
        hard_pred.loc[idx] = full_regime_preds.loc[idx, regime]

    y = test["GOLD_ret"]
    rows = []
    for name, pred in [("Regime Hard Switch", hard_pred), ("Regime Averaging", avg_pred)]:
        pred = pred.dropna()
        yy = y.loc[pred.index]
        rmse, mae, da = metric_frame(yy, pred)
        rows.append({"model": name, "rmse": rmse, "mae": mae, "directional_accuracy": da})

    out = pd.DataFrame(rows).sort_values("rmse")
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(OUT_CSV, index=False)
    OUT_MD.write_text(
        "\n".join(
            [
                "# Regime Averaging Summary",
                "",
                f"- Training window: {train.index.min().date()} -> {train.index.max().date()}",
                f"- Test window: {test.index.min().date()} -> {test.index.max().date()}",
                f"- Weights: {weights}",
                "",
                out.to_markdown(index=False),
                "",
                "- Interpretation: regime-specific averaging is designed to capture time-varying predictive relevance across calm, stress, and crisis states.",
            ]
        ),
        encoding="utf-8",
    )
    print(out.to_string(index=False))
    print(f"Saved summary: {OUT_MD}")
    print(f"Saved predictions: {OUT_CSV}")


if __name__ == "__main__":
    main()
