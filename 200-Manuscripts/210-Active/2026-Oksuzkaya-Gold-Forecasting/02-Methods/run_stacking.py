import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm
from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error, mean_squared_error

warnings.filterwarnings("ignore")

ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
MASTER = ROOT / "400-Data/440-Custom-Datasets/gold_research_master.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/stacking_summary.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/stacking_predictions.csv"


def metric_frame(y_true, y_pred):
    rmse = float(np.sqrt(mean_squared_error(y_true, y_pred)))
    mae = float(mean_absolute_error(y_true, y_pred))
    da = float((np.sign(y_true) == np.sign(y_pred)).mean())
    return rmse, mae, da


def make_returns(df):
    ret = np.log(df).diff()
    ret.columns = [f"{c}_ret" for c in df.columns]
    return ret.replace([np.inf, -np.inf], np.nan).dropna()


def ols_fit_predict(train_y, train_x, test_x):
    fit = sm.OLS(train_y, sm.add_constant(train_x)).fit()
    return fit.predict(sm.add_constant(test_x, has_constant="add"))


def main():
    df = pd.read_csv(MASTER, parse_dates=["DATE"]).sort_values("DATE").set_index("DATE")
    ret = make_returns(df)
    train = ret.loc[: "2020-12-31"].copy()
    test = ret.loc["2021-01-01":].copy()

    y_train = train["GOLD_ret"]
    y_test = test["GOLD_ret"]
    base_cols = ["DXY_ret", "USDJPY_ret", "USDCHF_ret", "SP500_ret", "OIL_ret", "VIX_ret"]
    cur_cols = ["DXY_ret", "USDJPY_ret", "USDCHF_ret"]
    risk_cols = ["DXY_ret", "SP500_ret", "VIX_ret"]
    comm_cols = ["DXY_ret", "OIL_ret", "VIX_ret"]

    # constituent model predictions
    pred_frame = pd.DataFrame(index=test.index)
    pred_frame["Baseline OLS"] = ols_fit_predict(y_train, train[base_cols], test[base_cols])
    pred_frame["Currency OLS"] = ols_fit_predict(y_train, train[cur_cols], test[cur_cols])
    pred_frame["Risk OLS"] = ols_fit_predict(y_train, train[risk_cols], test[risk_cols])
    pred_frame["Commodity OLS"] = ols_fit_predict(y_train, train[comm_cols], test[comm_cols])
    # Refit residual learners properly
    base_fit = sm.OLS(y_train, sm.add_constant(train[base_cols])).fit()
    base_resid = base_fit.resid
    rf = RandomForestRegressor(n_estimators=300, random_state=42, min_samples_leaf=5).fit(train[base_cols], base_resid)
    gb = GradientBoostingRegressor(random_state=42).fit(train[base_cols], base_resid)
    pred_frame["Hybrid OLS+RF"] = pred_frame["Baseline OLS"] + rf.predict(test[base_cols])
    pred_frame["Hybrid OLS+GB"] = pred_frame["Baseline OLS"] + gb.predict(test[base_cols])

    # simple stacking split
    split_idx = int(len(pred_frame) * 0.7)
    stack_train = pred_frame.iloc[:split_idx]
    stack_test = pred_frame.iloc[split_idx:]
    stack_y_train = y_test.iloc[:split_idx]
    stack_y_test = y_test.iloc[split_idx:]

    meta = Ridge(alpha=1.0)
    meta.fit(stack_train, stack_y_train)
    stacked_pred = pd.Series(meta.predict(stack_test), index=stack_y_test.index, name="Stacked Ensemble")

    rmse, mae, da = metric_frame(stack_y_test, stacked_pred)
    out = pd.DataFrame([{"model": "Stacked Ensemble", "rmse": rmse, "mae": mae, "directional_accuracy": da}])
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(OUT_CSV, index=False)
    OUT_MD.write_text(
        "\n".join(
            [
                "# Stacking Summary",
                "",
                f"- Ensemble input models: {', '.join(pred_frame.columns)}",
                f"- Meta-learner split: first {split_idx} observations of the out-of-sample window for training, remaining {len(stack_test)} for evaluation",
                "",
                out.to_markdown(index=False),
                "",
                "- Meta-learner: Ridge regression",
                "- Interpretation: a compact forecast-combination layer on top of the strongest block and residual models.",
            ]
        ),
        encoding="utf-8",
    )
    print(out.to_string(index=False))
    print(f"Saved summary: {OUT_MD}")
    print(f"Saved predictions: {OUT_CSV}")


if __name__ == "__main__":
    main()
