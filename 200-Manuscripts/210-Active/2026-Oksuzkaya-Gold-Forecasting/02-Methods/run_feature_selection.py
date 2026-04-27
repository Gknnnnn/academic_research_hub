import numpy as np
import pandas as pd
from pathlib import Path
from sklearn.linear_model import LassoCV, ElasticNetCV
from sklearn.metrics import mean_absolute_error, mean_squared_error
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline

ROOT = Path("/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma")
ADV = ROOT / "400-Data/440-Custom-Datasets/gold_research_advanced_features.csv"
OUT_MD = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/feature_selection_summary.md"
OUT_CSV = ROOT / "300-Projects/310-Active-Papers/2026-Oksuzkaya-Gold-Forecasting/03-Results/feature_selection_ranking.csv"


def metric_frame(y_true, y_pred):
    rmse = float(np.sqrt(mean_squared_error(y_true, y_pred)))
    mae = float(mean_absolute_error(y_true, y_pred))
    da = float((np.sign(y_true) == np.sign(y_pred)).mean())
    return rmse, mae, da


def main():
    df = pd.read_csv(ADV, parse_dates=["DATE"]).sort_values("DATE").set_index("DATE")
    y = df["GOLD_ret"]
    X = df.drop(columns=["GOLD", "GOLD_ret", "DATE"], errors="ignore")
    X = X.drop(columns=["regime_vix", "gold_vol_regime"], errors="ignore")
    X = X.replace([np.inf, -np.inf], np.nan).dropna()
    y = y.loc[X.index]

    split = int(len(X) * 0.8)
    X_train, X_test = X.iloc[:split], X.iloc[split:]
    y_train, y_test = y.iloc[:split], y.iloc[split:]

    lasso = Pipeline([
        ("scaler", StandardScaler()),
        ("model", LassoCV(cv=5, random_state=42, max_iter=20000)),
    ])
    enet = Pipeline([
        ("scaler", StandardScaler()),
        ("model", ElasticNetCV(cv=5, random_state=42, max_iter=20000, l1_ratio=[0.1, 0.3, 0.5, 0.7, 0.9])),
    ])

    lasso.fit(X_train, y_train)
    enet.fit(X_train, y_train)

    lasso_pred = lasso.predict(X_test)
    enet_pred = enet.predict(X_test)

    rows = []
    for name, model, pred in [
        ("LassoCV", lasso, lasso_pred),
        ("ElasticNetCV", enet, enet_pred),
    ]:
        rmse, mae, da = metric_frame(y_test, pred)
        rows.append({
            "model": name,
            "rmse": rmse,
            "mae": mae,
            "directional_accuracy": da,
            "selected_features": int(np.sum(np.abs(model[-1].coef_) > 1e-10)),
            "alpha": float(model[-1].alpha_),
        })

    ranking = pd.DataFrame(rows).sort_values("rmse")
    coef_rows = []
    for name, model in [("LassoCV", lasso), ("ElasticNetCV", enet)]:
        coef = pd.Series(model[-1].coef_, index=X.columns)
        for feat, val in coef.sort_values(key=lambda s: s.abs(), ascending=False).items():
            if abs(val) > 1e-10:
                coef_rows.append({"model": name, "feature": feat, "coef": float(val), "abs_coef": float(abs(val))})
    coef_df = pd.DataFrame(coef_rows).sort_values(["model", "abs_coef"], ascending=[True, False])

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    ranking.to_csv(OUT_CSV, index=False)
    OUT_MD.write_text(
        "\n".join([
            "# Feature Selection Summary",
            "",
            f"- Training window: {X_train.index.min().date()} -> {X_train.index.max().date()}",
            f"- Test window: {X_test.index.min().date()} -> {X_test.index.max().date()}",
            "",
            ranking.to_markdown(index=False),
            "",
            "## Non-zero coefficients",
            "",
            coef_df.head(40).to_markdown(index=False),
            "",
            "- Interpretation: sparse regularization is used here as a disciplined lag-search and feature-selection proxy.",
        ]),
        encoding="utf-8",
    )
    print(ranking.to_string(index=False))
    print(f"Saved summary: {OUT_MD}")
    print(f"Saved ranking: {OUT_CSV}")


if __name__ == "__main__":
    main()
