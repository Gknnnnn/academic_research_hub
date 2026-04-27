import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm
from statsmodels.tsa.regime_switching.markov_regression import MarkovRegression
from arch import arch_model
from sklearn.metrics import mean_absolute_error, mean_squared_error

warnings.filterwarnings("ignore")

ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
MASTER = ROOT / "400-Data/440-Custom-Datasets/gold_research_master.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/advanced_volatility_summary.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/advanced_volatility_predictions.csv"


def metrics(y_true, y_pred):
    rmse = float(np.sqrt(mean_squared_error(y_true, y_pred)))
    mae = float(mean_absolute_error(y_true, y_pred))
    da = float((np.sign(y_true) == np.sign(y_pred)).mean())
    return rmse, mae, da


def make_returns(df):
    ret = np.log(df).diff()
    ret.columns = [f"{c}_ret" for c in df.columns]
    return ret.replace([np.inf, -np.inf], np.nan).dropna()


def realized_proxy(ret: pd.Series, window: int = 20) -> pd.Series:
    # proxy realized volatility based on squared daily returns
    return ret.pow(2).rolling(window).mean().rename(f"{ret.name}_rv{window}")


def har_rv_forecast(rv: pd.Series, test_start: str):
    lag1 = rv.shift(1)
    lag5 = rv.shift(1).rolling(5).mean()
    lag22 = rv.shift(1).rolling(22).mean()
    X = pd.concat([lag1, lag5, lag22], axis=1)
    X.columns = ["rv_lag1", "rv_lag5", "rv_lag22"]
    data = pd.concat([rv, X], axis=1).dropna()
    train = data.loc[:test_start]
    test = data.loc[test_start:]
    fit = sm.OLS(train.iloc[:, 0], sm.add_constant(train.iloc[:, 1:])).fit()
    pred = fit.predict(sm.add_constant(test.iloc[:, 1:], has_constant="add"))
    return fit, test.iloc[:, 0], pred


def garch_family_forecasts(train_ret: pd.Series, horizon: int):
    spec = [
        ("GARCH(1,1)", dict(vol="Garch", p=1, o=0, q=1, power=2.0, dist="normal")),
        ("EGARCH(1,1)", dict(vol="EGARCH", p=1, o=1, q=1, dist="skewt")),
        ("GJR-GARCH(1,1)", dict(vol="GARCH", p=1, o=1, q=1, dist="skewt")),
        ("APARCH(1,1)", dict(vol="APARCH", p=1, o=1, q=1, dist="skewt")),
        ("FIGARCH(1,d,1)", dict(vol="FIGARCH", p=1, q=1, dist="t")),
    ]
    rows = []
    preds = {}
    for name, kwargs in spec:
        try:
            dist = kwargs.pop("dist", "t")
            am = arch_model(train_ret * 100, mean="Zero", dist=dist, rescale=False, **kwargs)
            res = am.fit(disp="off")
            f = res.forecast(horizon=horizon, reindex=False)
            var = f.variance.values[-1, :]
            pred = pd.Series(var / 10000.0, index=range(horizon), name=name)
            preds[name] = pred
        except Exception:
            preds[name] = pd.Series(dtype=float)
    return preds


def markov_switching_forecast(train_ret: pd.Series, test_ret: pd.Series):
    # Two-state switching mean and variance proxy on returns
    try:
        mod = MarkovRegression(train_ret * 100, k_regimes=2, trend="c", switching_variance=True)
        res = mod.fit(em_iter=10, search_reps=10, disp=False)
        pred_mean = res.predict(start=len(train_ret), end=len(train_ret) + len(test_ret) - 1)
        # approximate variance proxy from state probabilities
        probs = res.smoothed_marginal_probabilities
        state_var = train_ret.pow(2).rolling(20).mean().dropna()
        base_var = float(state_var.iloc[-1]) if len(state_var) else float(train_ret.pow(2).mean())
        # convert predicted mean from percent scale
        pred_mean = pd.Series(pred_mean / 100.0, index=test_ret.index[:len(pred_mean)])
        return res, pred_mean, base_var
    except Exception:
        return None, pd.Series(dtype=float), np.nan


def main():
    df = pd.read_csv(MASTER, parse_dates=["DATE"]).sort_values("DATE").set_index("DATE")
    ret = make_returns(df)
    y = ret["GOLD_ret"].dropna()

    split_date = "2020-12-31"
    train_ret = y.loc[:split_date]
    test_ret = y.loc["2021-01-01":]

    rows = []
    pred_frame = pd.DataFrame(index=test_ret.index)

    # baseline variance proxy
    rv20 = realized_proxy(y, window=20)
    har_fit, har_true, har_pred = har_rv_forecast(rv20, "2021-01-01")
    har_true = har_true.reindex(har_pred.index)
    rmse, mae, da = metrics(har_true, har_pred)
    rows.append({"model": "HAR-RV proxy", "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": har_fit.rsquared_adj})
    pred_frame["HAR-RV proxy"] = har_pred.reindex(test_ret.index)

    # GARCH family
    garch_preds = garch_family_forecasts(train_ret, len(test_ret))
    for name, pred in garch_preds.items():
        if pred.empty:
            rows.append({"model": name, "rmse": np.nan, "mae": np.nan, "directional_accuracy": np.nan, "adj_r2": np.nan})
            continue
        # convert variance forecast to volatility proxy and align against squared returns
        pred.index = test_ret.index[:len(pred)]
        true_var = test_ret.pow(2).loc[pred.index]
        rmse, mae, da = metrics(true_var, pred)
        rows.append({"model": name, "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": np.nan})
        pred_frame[name] = pred.reindex(test_ret.index)

    # a simple long-memory proxy on absolute returns
    absret = y.abs()
    X = pd.DataFrame({
        "abs_lag1": absret.shift(1),
        "abs_lag5": absret.shift(1).rolling(5).mean(),
        "abs_lag22": absret.shift(1).rolling(22).mean(),
    }).dropna()
    y_abs = absret.loc[X.index]
    train_mask = X.index <= pd.Timestamp(split_date)
    fit = sm.OLS(y_abs.loc[train_mask], sm.add_constant(X.loc[train_mask])).fit()
    pred = fit.predict(sm.add_constant(X.loc[~train_mask], has_constant="add"))
    rmse, mae, da = metrics(y_abs.loc[~train_mask], pred)
    rows.append({"model": "HAR-ABS proxy", "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": fit.rsquared_adj})
    pred_frame["HAR-ABS proxy"] = pred.reindex(test_ret.index)

    # Markov-switching mean benchmark
    ms_res, ms_pred, base_var = markov_switching_forecast(train_ret, test_ret)
    if len(ms_pred):
        aligned = test_ret.loc[ms_pred.index]
        rmse, mae, da = metrics(aligned, ms_pred)
        rows.append({"model": "Markov-switching mean", "rmse": rmse, "mae": mae, "directional_accuracy": da, "adj_r2": np.nan})
        pred_frame["Markov-switching mean"] = ms_pred.reindex(test_ret.index)
    else:
        rows.append({"model": "Markov-switching mean", "rmse": np.nan, "mae": np.nan, "directional_accuracy": np.nan, "adj_r2": np.nan})

    res = pd.DataFrame(rows).sort_values("rmse")
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    res.to_csv(OUT_CSV, index=False)
    OUT_MD.write_text(
        "\n".join([
            "# Advanced Volatility Summary",
            "",
            f"- Train window: {y.index.min().date()} -> {split_date}",
            f"- Test window: {test_ret.index.min().date()} -> {test_ret.index.max().date()}",
            "",
            res.to_markdown(index=False),
            "",
            "## Notes",
            "- HAR-RV and HAR-ABS are proxy models because intraday realized volatility is not yet available in this environment.",
            "- GARCH-family models are fit on gold returns and evaluated against squared-return volatility proxies.",
            "- Markov-switching is included as a state-dependent benchmark for mean dynamics, not as a full multivariate volatility model.",
            "- DCC-GARCH is left as a multivariate extension because the current benchmark is univariate.",
        ]),
        encoding="utf-8",
    )
    print(res.to_string(index=False))
    print(f"Saved summary: {OUT_MD}")
    print(f"Saved predictions: {OUT_CSV}")


if __name__ == "__main__":
    main()
