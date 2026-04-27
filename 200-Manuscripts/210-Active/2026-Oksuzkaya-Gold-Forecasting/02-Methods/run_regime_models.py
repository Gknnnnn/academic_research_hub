import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error
from sklearn.neural_network import MLPRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

warnings.filterwarnings("ignore")

ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
ADV = ROOT / "400-Data/440-Custom-Datasets/gold_research_advanced_features.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/regime_outputs.md"


def metrics(y_true, y_pred):
    return (
        float(np.sqrt(mean_squared_error(y_true, y_pred))),
        float(mean_absolute_error(y_true, y_pred)),
        float((np.sign(y_true) == np.sign(y_pred)).mean()),
    )


def main():
    df = pd.read_csv(ADV, parse_dates=["DATE"]).sort_values("DATE").set_index("DATE")
    keep_cols = [c for c in df.columns if c.endswith("_ret") or c.startswith("DXY_x_") or c.startswith("USDJPY_x_") or c.startswith("USDCHF_x_") or c.startswith("SP500_x_") or c in ["regime_vix", "gold_vol_regime", "GOLD", "DXY", "USDJPY", "USDCHF", "SP500", "OIL", "VIX"]]
    data = df[keep_cols].copy()
    data = data.dropna()

    base_cols = ["DXY_ret", "USDJPY_ret", "USDCHF_ret", "SP500_ret", "OIL_ret", "VIX_ret", "DXY_x_VIX", "DXY_x_OIL", "SP500_x_VIX"]
    data = data.dropna(subset=base_cols + ["GOLD_ret", "regime_vix"])
    train = data.loc[: "2020-12-31"]
    test = data.loc["2021-01-01":]

    rows = []
    preds = pd.DataFrame(index=test.index)

    # regime-aware OLS
    for reg in ["calm", "stress", "crisis"]:
        tr = train[train["regime_vix"] == reg]
        te = test[test["regime_vix"] == reg]
        if len(tr) < 50 or len(te) < 10:
            continue
        fit = sm.OLS(tr["GOLD_ret"], sm.add_constant(tr[base_cols])).fit()
        pred = fit.predict(sm.add_constant(te[base_cols], has_constant="add"))
        rmse, mae, da = metrics(te["GOLD_ret"], pred)
        rows.append({"model": f"Regime OLS ({reg})", "rmse": rmse, "mae": mae, "directional_accuracy": da})
        preds.loc[te.index, f"Regime OLS ({reg})"] = pred

    # regime-aware RF
    rf = RandomForestRegressor(n_estimators=600, random_state=42, min_samples_leaf=4)
    rf.fit(train[base_cols], train["GOLD_ret"])
    rf_pred = rf.predict(test[base_cols])
    rmse, mae, da = metrics(test["GOLD_ret"], rf_pred)
    rows.append({"model": "Regime RF", "rmse": rmse, "mae": mae, "directional_accuracy": da})
    preds["Regime RF"] = rf_pred

    # regime-aware MLP
    mlp = Pipeline([
        ("scaler", StandardScaler()),
        ("mlp", MLPRegressor(hidden_layer_sizes=(128, 64), alpha=0.001, max_iter=4000, random_state=42)),
    ])
    mlp.fit(train[base_cols], train["GOLD_ret"])
    mlp_pred = mlp.predict(test[base_cols])
    rmse, mae, da = metrics(test["GOLD_ret"], mlp_pred)
    rows.append({"model": "Regime MLP", "rmse": rmse, "mae": mae, "directional_accuracy": da})
    preds["Regime MLP"] = mlp_pred

    res = pd.DataFrame(rows).sort_values("rmse")
    OUT_MD.write_text("\n".join([
        "# Regime Benchmark Summary",
        "",
        res.to_markdown(index=False),
        "",
        "## Notes",
        "- Regimes are defined from VIX thresholds and interaction terms.",
        "- This benchmark is intended to test whether stress regimes improve forecast stability.",
    ]), encoding="utf-8")
    print(res.to_string(index=False))
    print(f"Saved regime summary: {OUT_MD}")


if __name__ == "__main__":
    main()
