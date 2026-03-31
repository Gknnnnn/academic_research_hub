#!/usr/bin/env python3
import pandas as pd
import statsmodels.formula.api as smf
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / "data" / "turkiye_makro_data.csv"
OUTPUT = Path(__file__).resolve().parents[1] / "output" / "regression_summary.md"

def main():
    df = pd.read_csv(DATA)
    df = df.dropna(subset=["gdp_usd", "co2_kt", "elec_kwh_pc"])
    model = smf.ols("co2_kt ~ gdp_usd + elec_kwh_pc", data=df).fit()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", encoding="utf-8") as handle:
        handle.write("# Regression Summary\n\n")
        handle.write(model.summary().as_text())
    print("Wrote summary to", OUTPUT)

if __name__ == "__main__":
    main()
