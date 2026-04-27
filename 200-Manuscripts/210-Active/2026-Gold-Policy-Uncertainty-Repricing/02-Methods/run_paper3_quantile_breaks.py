"""
Quantile Regression + Structural Break Augmentation
Project: 2026-Gold-Policy-Uncertainty-Repricing
Adds:    (i) quantile regression at tau ∈ {0.10, 0.50, 0.90} to capture
              asymmetric safe-haven effects across the gold-return distribution,
         (ii) Bai-Perron-style structural break detection on the gold-EPU
              relationship using a rolling Chow-style F sequence.
Author:  M. G. Özdemir | Revived 2026-04-07
Caveats: @baiperron_caveat — supF p-values are chi-sq(q) approximations.
"""
import pandas as pd, numpy as np, os
from pathlib import Path
import statsmodels.api as sm
import statsmodels.formula.api as smf

ROOT = Path("/sessions/eager-busy-cori/mnt/Akademik_Arastirma/300-Projects/310-Active-Papers/2026-Gold-Policy-Uncertainty-Repricing")
DATA = ROOT / "03-Results/paper3_gold_policy_uncertainty_dataset.csv"
OUT  = ROOT / "03-Results"

df = pd.read_csv(DATA, parse_dates=["DATE"])
df = df.dropna(subset=["gold_return","epu_us","fed_funds_effective","ust10y","VIX"])
# Build clean change variables
df["epu_change"]   = df["epu_us"].pct_change()
df["ust10y_change"] = df["ust10y"].diff()
df["vix_change"]   = df["VIX"].pct_change()
df = df.dropna()
print(f"[INFO] N = {len(df)}, period {df.DATE.min().date()} → {df.DATE.max().date()}")

# ---- 1. Quantile regression --------------------------------------------------
features = ["epu_change","fed_funds_effective","ust10y_change","vix_change"]
X = sm.add_constant(df[features])
y = df["gold_return"]

qr_rows = []
for tau in [0.10, 0.50, 0.90]:
    m = sm.QuantReg(y, X).fit(q=tau, max_iter=2000)
    for v in features + ["const"]:
        qr_rows.append({"tau":tau,"term":v,
                        "coef":round(m.params[v],6),
                        "se":round(m.bse[v],6),
                        "p":round(m.pvalues[v],4)})
qr_df = pd.DataFrame(qr_rows)
qr_df.to_csv(OUT / "quantile_regression.csv", index=False)

# ---- 2. Structural break: rolling Chow-F on gold ~ epu_change ---------------
# Walk a candidate break point through 15%-85% of the sample, compute Chow F.
n = len(df)
lo = int(0.15*n); hi = int(0.85*n)
F_seq = []
def rss(yy, XX):
    b, *_ = np.linalg.lstsq(XX, yy, rcond=None)
    e = yy - XX @ b
    return float(e @ e)
Xb = np.column_stack([np.ones(n), df["epu_change"].values])
yb = y.values
RSS_full = rss(yb, Xb)
k = Xb.shape[1]
for tau in range(lo, hi):
    R1 = rss(yb[:tau], Xb[:tau])
    R2 = rss(yb[tau:], Xb[tau:])
    F  = ((RSS_full - (R1+R2)) / k) / ((R1+R2) / (n - 2*k))
    F_seq.append((tau, F))
F_arr = np.array(F_seq)
sup_idx = np.argmax(F_arr[:,1])
sup_tau = int(F_arr[sup_idx,0])
sup_F   = float(F_arr[sup_idx,1])
sup_date = df["DATE"].iloc[sup_tau]

with open(OUT / "structural_break_summary.md","w") as f:
    f.write("# Bai-Perron-style supF (Single-Break Test)\n\n")
    f.write(f"- Period: {df.DATE.min().date()} → {df.DATE.max().date()}\n")
    f.write(f"- N = {n}\n")
    f.write(f"- supF statistic: **{sup_F:.2f}**\n")
    f.write(f"- Estimated break date: **{sup_date.date()}**\n\n")
    f.write("**Caveat (@baiperron_caveat):** supF p-values are chi-square(q) "
            "asymptotic approximations; cross-check with R `strucchange::sctest` "
            "or Stata `xtbreak` before final submission.\n")

print("\n=== Quantile regression (key coefs) ===")
print(qr_df[qr_df.term.isin(["epu_change","vix_change","fed_funds_effective"])].to_string(index=False))
print(f"\n=== supF break test ===")
print(f"supF = {sup_F:.2f}  break ≈ {sup_date.date()}")
