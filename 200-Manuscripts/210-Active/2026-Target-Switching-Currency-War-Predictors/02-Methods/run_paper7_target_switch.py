"""
Target-Switching Predictor Stability Test
Project: 2026-Target-Switching-Currency-War-Predictors
Inputs:  03-Results/paper7_shared_target_dataset.csv (N≈2,608)
Target:  Finance Research Letters (Q1)
Author:  M. G. Özdemir | Revival round 2 — 2026-04-07

Method: same predictor block tested against three TARGETS
        (gold_return, gold_rv_proxy, btc_return) with HAC SEs.
        Coefficient stability is the primary diagnostic; we report
        the cross-target standardized-coefficient gap.
"""
import pandas as pd, numpy as np
from pathlib import Path
import statsmodels.api as sm

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "03-Results/paper7_shared_target_dataset.csv"
OUT  = ROOT / "03-Results"

df = pd.read_csv(DATA, parse_dates=["DATE"]).dropna()
print(f"[INFO] N = {len(df)}")

predictors = ["dxy_return","usdjpy_return","usdchf_return","oil_return",
              "vix_change","epu_us","currency_war_flag"]
targets    = ["gold_return","gold_rv_proxy","btc_return"]

Z = (df[predictors] - df[predictors].mean()) / df[predictors].std()
Z = sm.add_constant(Z)

frames = []
for tgt in targets:
    y = (df[tgt] - df[tgt].mean()) / df[tgt].std()
    m = sm.OLS(y, Z).fit(cov_type="HAC", cov_kwds={"maxlags":5})
    frames.append(pd.DataFrame({
        "target": tgt,
        "predictor": predictors,
        "beta_std": m.params[predictors].round(4).values,
        "se":       m.bse[predictors].round(4).values,
        "p":        m.pvalues[predictors].round(4).values,
    }))
tab = pd.concat(frames, ignore_index=True)
tab.to_csv(OUT/"paper7_target_switch_betas.csv", index=False)

# Stability gap = max - min standardized beta across targets
pivot = tab.pivot(index="predictor", columns="target", values="beta_std")
pivot["range_max_min"] = (pivot.max(axis=1) - pivot.min(axis=1)).round(4)
pivot["sign_consistent"] = (np.sign(pivot[targets[0]]) == np.sign(pivot[targets[1]])) & \
                           (np.sign(pivot[targets[1]]) == np.sign(pivot[targets[2]]))
pivot.to_csv(OUT/"paper7_stability_matrix.csv")

with open(OUT/"paper7_target_switch_summary.md","w") as f:
    f.write("# Target-Switching Stability — Standardized Betas\n\n")
    f.write(f"N = {len(df)}, period {df.DATE.min().date()} → {df.DATE.max().date()}\n\n")
    f.write("Each predictor block is regressed against three different targets\n")
    f.write("(z-scored) with HAC SEs (Newey-West, lag=5).\n\n")
    f.write("## Stability matrix (standardized β)\n\n")
    f.write(pivot.to_markdown()); f.write("\n\n")
    unstable = pivot[~pivot["sign_consistent"]].index.tolist()
    f.write(f"**Sign-flipping (unstable) predictors:** {unstable}\n")

print("\n=== Stability matrix ===")
print(pivot)
