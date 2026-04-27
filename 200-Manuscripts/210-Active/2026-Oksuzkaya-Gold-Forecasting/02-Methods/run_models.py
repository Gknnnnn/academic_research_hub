import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm
from arch import arch_model
from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, mean_squared_error
from sklearn.neural_network import MLPRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import Ridge
from xgboost import XGBRegressor

warnings.filterwarnings("ignore")

ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
MASTER = ROOT / "400-Data/440-Custom-Datasets/gold_research_master.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/model_outputs.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/model_predictions.csv"
OUT_DIAG = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/model_diagnostics.md"


def metric_frame(y_true, y_pred):
    rmse = float(np.sqrt(mean_squared_error(y_true, y_pred)))
    mae = float(mean_absolute_error(y_true, y_pred))
    da = float((np.sign(y_true) == np.sign(y_pred)).mean())
    return rmse, mae, da


def make_returns(df):
    ret = np.log(df).diff()
    ret.columns = [f"{c}_ret" for c in df.columns]
    return ret.replace([np.inf, -np.inf], np.nan).dropna()


def add_leads_lags(x: pd.DataFrame, lags=(1, 2), leads=(1, 2)):
    pieces = [x]
    for col in x.columns:
        for l in lags:
            pieces.append(x[col].shift(l).rename(f"{col}_lag{l}"))
        for le in leads:
            pieces.append(x[col].shift(-le).rename(f"{col}_lead{le}"))
    return pd.concat(pieces, axis=1)


def ols_forecast(train_y, train_x, test_x):
    fit = sm.OLS(train_y, sm.add_constant(train_x)).fit()
    pred = fit.predict(sm.add_constant(test_x, has_constant="add"))
    return fit, pred


def quantile_forecast(train_y, train_x, test_x, q=0.5):
    fit = sm.QuantReg(train_y, sm.add_constant(train_x)).fit(q=q)
    pred = fit.predict(sm.add_constant(test_x, has_constant="add"))
    return fit, pred


def dols_forecast(train_y, train_x, test_x):
    train_diff = train_x.diff()
    test_diff = test_x.diff()
    train_dols = pd.concat(
        [train_x, train_diff.add_suffix("_d1"), train_diff.shift(1).add_suffix("_d1_lag1")],
        axis=1,
    ).dropna()
    # align target to the same index
    fit = sm.OLS(train_y.loc[train_dols.index], sm.add_constant(train_dols)).fit()
    test_dols = pd.concat(
        [test_x, test_diff.add_suffix("_d1"), test_diff.shift(1).add_suffix("_d1_lag1")],
        axis=1,
    ).dropna()
    pred = fit.predict(sm.add_constant(test_dols, has_constant="add"))
    return fit, pred


def garch_forecast(train_ret, horizon):
    am = arch_model(train_ret * 100, mean="Zero", vol="Garch", p=1, q=1, dist="normal")
    res = am.fit(disp="off")
    f = res.forecast(horizon=horizon, reindex=False)
    var = f.variance.values[-1, :]
    mean = np.zeros(horizon)
    return res, mean, np.sqrt(var) / 100


def rolling_window_forecast(df, features, target, train_size=2500, window=250, step=50):
    preds, obs = [], []
    for start in range(train_size, len(df) - window, step):
        train = df.iloc[:start]
        test = df.iloc[start:start + window]
        fit = sm.OLS(train[target], sm.add_constant(train[features])).fit()
        pred = fit.predict(sm.add_constant(test[features], has_constant="add"))
        preds.extend(pred.values.tolist())
        obs.extend(test[target].values.tolist())
    return np.array(obs), np.array(preds)


def stacking_holdout(train_df, test_df, target, blocks, split_frac=0.8):
    split_idx = int(len(train_df) * split_frac)
    tr_df = train_df.iloc[:split_idx].copy()
    val_df = train_df.iloc[split_idx:].copy()

    val_preds = pd.DataFrame(index=val_df.index)
    test_preds = pd.DataFrame(index=test_df.index)
    fitted_models = {}

    for name, (model, cols) in blocks.items():
        fitted = model.fit(tr_df[cols], tr_df[target])
        val_preds[name] = fitted.predict(val_df[cols])
        refit = model.fit(train_df[cols], train_df[target])
        test_preds[name] = refit.predict(test_df[cols])
        fitted_models[name] = refit

    meta = Ridge(alpha=1.0, random_state=42)
    meta.fit(val_preds, val_df[target])
    stacked_pred = meta.predict(test_preds)
    return val_preds, test_preds, stacked_pred, meta


def main():
    df = pd.read_csv(MASTER, parse_dates=["DATE"]).sort_values("DATE").set_index("DATE")
    ret = make_returns(df)

    # levels for cointegration-style methods
    lvl = np.log(df).dropna()
    lvl.columns = [f"{c}_lvl" for c in df.columns]

    # core return sample
    data = ret.copy()
    split_date = "2020-12-31"
    train = data.loc[:split_date].copy()
    test = data.loc["2021-01-01":].copy()

    y_train = train["GOLD_ret"]
    y_test = test["GOLD_ret"]

    base_cols = ["DXY_ret", "USDJPY_ret", "USDCHF_ret", "SP500_ret", "OIL_ret", "VIX_ret"]
    cur_cols = ["DXY_ret", "USDJPY_ret", "USDCHF_ret"]
    risk_cols = ["DXY_ret", "SP500_ret", "VIX_ret"]
    comm_cols = ["DXY_ret", "OIL_ret", "VIX_ret"]

    rows = []
    preds = pd.DataFrame(index=test.index)

    # OLS family
    for name, cols in {
        "Baseline OLS": base_cols,
        "Currency OLS": cur_cols,
        "Risk OLS": risk_cols,
        "Commodity OLS": comm_cols,
        "Full OLS": base_cols,
    }.items():
        fit, pred = ols_forecast(train[y_train.name], train[cols], test[cols])
        rmse, mae, da = metric_frame(y_test, pred)
        rows.append({"model": name, "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": fit.rsquared_adj})
        preds[name] = pred

    # Quantile regression
    qfit, qpred = quantile_forecast(y_train, train[base_cols], test[base_cols], q=0.5)
    rmse, mae, da = metric_frame(y_test, qpred)
    rows.append({"model": "Median Quantile", "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": np.nan})
    preds["Median Quantile"] = qpred

    # DOLS on levels, using log levels and leads/lags
    level_train = lvl.loc[train.index]
    level_test = lvl.loc[test.index]
    target_lvl = level_train["GOLD_lvl"]
    dols_x_train = level_train[["DXY_lvl", "USDJPY_lvl", "USDCHF_lvl", "SP500_lvl", "OIL_lvl", "VIX_lvl"]]
    dols_x_test = level_test[["DXY_lvl", "USDJPY_lvl", "USDCHF_lvl", "SP500_lvl", "OIL_lvl", "VIX_lvl"]]
    try:
        dfit, dpred = dols_forecast(target_lvl, dols_x_train, dols_x_test)
        # convert level forecast to return forecast for comparability
        dpred_ret = dpred.diff().dropna()
        aligned = y_test.loc[dpred_ret.index.intersection(y_test.index)]
        rmse, mae, da = metric_frame(aligned, dpred_ret.loc[aligned.index])
        rows.append({"model": "DOLS", "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": dfit.rsquared_adj})
        preds["DOLS"] = dpred_ret.reindex(test.index)
    except Exception:
        rows.append({"model": "DOLS", "rmse": np.nan, "mae": np.nan, "directional_accuracy": np.nan, "adj_r2": np.nan})

    # NARDL-style asymmetry proxy via split shocks
    split = data[["DXY_ret", "USDJPY_ret", "USDCHF_ret"]].copy()
    for c in split.columns:
        split[f"{c}_pos"] = split[c].clip(lower=0)
        split[f"{c}_neg"] = split[c].clip(upper=0)
    nardl_cols = [f"{c}_{s}" for c in ["DXY_ret", "USDJPY_ret", "USDCHF_ret"] for s in ("pos", "neg")]
    nardl_train = pd.concat([train["GOLD_ret"], split.loc[train.index, nardl_cols]], axis=1).dropna()
    nardl_test = pd.concat([test["GOLD_ret"], split.loc[test.index, nardl_cols]], axis=1).dropna()
    nfit = sm.OLS(nardl_train["GOLD_ret"], sm.add_constant(nardl_train[nardl_cols])).fit()
    npred = nfit.predict(sm.add_constant(nardl_test[nardl_cols], has_constant="add"))
    rmse, mae, da = metric_frame(nardl_test["GOLD_ret"], npred)
    rows.append({"model": "NARDL Shock Split OLS", "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": nfit.rsquared_adj})
    preds["NARDL Shock Split OLS"] = npred.reindex(test.index)

    # GARCH on gold returns
    try:
        gfit, gmean, gsigma = garch_forecast(y_train, len(y_test))
        # mean zero return forecast; directional accuracy will be weak
        gpred = pd.Series(gmean, index=y_test.index[:len(gmean)])
        rmse, mae, da = metric_frame(y_test.loc[gpred.index], gpred)
        rows.append({"model": "GARCH(1,1)", "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": np.nan})
        preds["GARCH(1,1)"] = gpred.reindex(test.index)
    except Exception:
        rows.append({"model": "GARCH(1,1)", "rmse": np.nan, "mae": np.nan, "directional_accuracy": np.nan, "adj_r2": np.nan})

    # Residual learners
    base_fit = sm.OLS(y_train, sm.add_constant(train[base_cols])).fit()
    base_resid = base_fit.resid
    rf = RandomForestRegressor(n_estimators=500, random_state=42, min_samples_leaf=5)
    gb = GradientBoostingRegressor(random_state=42)
    mlp = Pipeline(
        steps=[
            ("scaler", StandardScaler()),
            ("mlp", MLPRegressor(hidden_layer_sizes=(64, 32), activation="relu", alpha=0.001, max_iter=5000, random_state=42)),
        ]
    )
    xgb = XGBRegressor(
        n_estimators=500,
        learning_rate=0.05,
        max_depth=4,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=42,
        objective="reg:squarederror",
    )
    rf.fit(train[base_cols], base_resid)
    gb.fit(train[base_cols], base_resid)
    mlp.fit(train[base_cols], base_resid)
    xgb.fit(train[base_cols], base_resid)
    rf_pred = preds["Baseline OLS"] + rf.predict(test[base_cols])
    gb_pred = preds["Baseline OLS"] + gb.predict(test[base_cols])
    mlp_pred = preds["Baseline OLS"] + mlp.predict(test[base_cols])
    xgb_pred = preds["Baseline OLS"] + xgb.predict(test[base_cols])
    for name, pred in [("Hybrid OLS+RF", rf_pred), ("Hybrid OLS+GB", gb_pred), ("Hybrid OLS+MLP", mlp_pred), ("Hybrid OLS+XGB", xgb_pred)]:
        rmse, mae, da = metric_frame(y_test, pred)
        rows.append({"model": name, "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": np.nan})
        preds[name] = pred

    # rolling window benchmark
    obs, rw_pred = rolling_window_forecast(data, base_cols, "GOLD_ret", train_size=2500, window=250, step=125)
    rmse, mae, da = metric_frame(obs, rw_pred)
    rows.append({"model": "Rolling OLS", "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": np.nan})

    # stacked ensemble on strong base learners using a holdout meta-fit
    stack_blocks = {
        "Baseline OLS": (LinearRegression(), base_cols),
        "Currency OLS": (LinearRegression(), cur_cols),
        "Risk OLS": (LinearRegression(), risk_cols),
        "Commodity OLS": (LinearRegression(), comm_cols),
        "NARDL Shock Split OLS": (LinearRegression(), nardl_cols),
        "Hybrid OLS+RF": (RandomForestRegressor(n_estimators=250, random_state=42, min_samples_leaf=5), base_cols),
        "Hybrid OLS+GB": (GradientBoostingRegressor(random_state=42), base_cols),
        "Hybrid OLS+XGB": (
            XGBRegressor(
                n_estimators=300,
                learning_rate=0.05,
                max_depth=4,
                subsample=0.8,
                colsample_bytree=0.8,
                random_state=42,
                objective="reg:squarederror",
            ),
            base_cols,
        ),
    }
    stack_val, stack_test, stack_pred, stack_meta = stacking_holdout(train, test, "GOLD_ret", stack_blocks, split_frac=0.8)
    rmse, mae, da = metric_frame(y_test, stack_pred)
    rows.append({"model": "Stacked Ensemble", "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": np.nan})
    preds["Stacked Ensemble"] = stack_pred

    res = pd.DataFrame(rows).sort_values("rmse")
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    res.to_csv(OUT_CSV, index=False)

    summary = [
        "# Model Comparison Summary",
        "",
        f"- Train window: {train.index.min().date()} -> {train.index.max().date()}",
        f"- Test window: {test.index.min().date()} -> {test.index.max().date()}",
        "",
        "## Metrics",
        res.to_markdown(index=False),
        "",
        "## Interpretation",
        "- OLS family benchmarks the block-based linear specifications.",
        "- Quantile regression checks tail sensitivity.",
        "- DOLS checks cointegration-style robustness on levels.",
        "- NARDL shock split approximates asymmetry directly in returns.",
        "- GARCH benchmarks conditional volatility structure on gold returns.",
        "- Hybrid OLS+RF and OLS+GB test residual-learning gains.",
        "- Hybrid OLS+MLP tests a neural-network residual learner.",
        "- Hybrid OLS+XGB tests boosted trees after package installation.",
        "- Rolling OLS checks time-varying predictive stability.",
        "",
        "## Notes",
        "- XGBoost is installed and used in the benchmark.",
        "- FMOLS was estimated separately in R via cointReg and should be interpreted as a long-run cointegration benchmark.",
        "- DOLS remains the Python-side cointegration-robust benchmark here.",
    ]
    OUT_MD.write_text("\n".join(summary), encoding="utf-8")

    diag = [
        "# Model Diagnostics",
        "",
        f"- Baseline OLS RMSE: {res.loc[res['model']=='Baseline OLS', 'rmse'].iloc[0]:.6f}",
        f"- Hybrid OLS+RF RMSE: {res.loc[res['model']=='Hybrid OLS+RF', 'rmse'].iloc[0]:.6f}",
        f"- Hybrid OLS+GB RMSE: {res.loc[res['model']=='Hybrid OLS+GB', 'rmse'].iloc[0]:.6f}",
        f"- Hybrid OLS+MLP RMSE: {res.loc[res['model']=='Hybrid OLS+MLP', 'rmse'].iloc[0]:.6f}",
        f"- Hybrid OLS+XGB RMSE: {res.loc[res['model']=='Hybrid OLS+XGB', 'rmse'].iloc[0]:.6f}",
        f"- Best RMSE model: {res.iloc[0]['model']}",
    ]
    OUT_DIAG.write_text("\n".join(diag), encoding="utf-8")

    print(res.to_string(index=False))
    print(f"Saved summary: {OUT_MD}")
    print(f"Saved diagnostics: {OUT_DIAG}")
    print(f"Saved predictions: {OUT_CSV}")


if __name__ == "__main__":
    main()
