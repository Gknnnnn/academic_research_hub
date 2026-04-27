"""
CE-CogEcon — Macro pilot v2 (Oturum 3, 2026-04-07)
Extends Oturum-2 TWFE/MG pilot with second-generation panel pipeline:
  Pesaran (2004) CD, CIPS (Pesaran 2007), Westerlund (2007) ECM,
  CS-ARDL Mean Group (Chudik-Pesaran 2015), Dumitrescu-Hurlin (2012).

Purpose: clear the macro arm (M3+M4) before GESIS Eurobarometer becomes
available, so that v0.2 manuscript can carry full pre-GESIS results.

Input : 400-Data/processed/eurostat_macro.csv (27 EU MS × 2010-2024, NT=405)
Output: 600-Results/CE_pilot_v2/{cd, cips, westerlund, csardl_mg, dh}.csv
"""
import os, numpy as np, pandas as pd
from scipy import stats
from numpy.linalg import lstsq, pinv

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC  = os.path.join(ROOT, "400-Data", "processed", "eurostat_macro.csv")
OUT  = os.path.join(ROOT, "600-Results", "CE_pilot_v2")
os.makedirs(OUT, exist_ok=True)

df = pd.read_csv(SRC).sort_values(["country","year"]).reset_index(drop=True)
df["ln_cmu"]  = np.log(df["CMU"])
df["ln_gdp"]  = np.log(df["gdp_pc"])
df["ln_educ"] = np.log(df["tert_educ_25_34"])
df["ln_prod"] = np.log(df["res_productivity"])

VARS = ["ln_cmu","ln_gdp","ln_educ","ln_prod"]

# ---------- 1. Pesaran (2004) CD test on residuals from country-specific OLS ----------
def pesaran_cd(panel, y, X):
    resids = {}
    for c, g in panel.groupby("country"):
        Y = g[y].values; Z = np.column_stack([np.ones(len(g))] + [g[v].values for v in X])
        b,*_ = lstsq(Z, Y, rcond=None)
        resids[c] = Y - Z @ b
    countries = list(resids); N=len(countries); T=min(len(r) for r in resids.values())
    R = np.array([resids[c][:T] for c in countries])
    rho_sum=0; pairs=0
    for i in range(N):
        for j in range(i+1,N):
            rho = np.corrcoef(R[i], R[j])[0,1]
            if np.isfinite(rho): rho_sum += rho; pairs += 1
    CD = np.sqrt(2*T/(N*(N-1))) * rho_sum
    return CD, 2*(1 - stats.norm.cdf(abs(CD)))

cd_rows=[]
for v in VARS:
    others=[u for u in VARS if u!=v]
    cd, p = pesaran_cd(df, v, others)
    cd_rows.append({"var":v,"CD":round(cd,3),"p":round(p,4)})
pd.DataFrame(cd_rows).to_csv(os.path.join(OUT,"cd.csv"), index=False)

# ---------- 2. CIPS panel unit root (Pesaran 2007), p=1 ----------
def cips(panel, var, p=1):
    cadf=[]
    cs_mean = panel.groupby("year")[var].transform("mean")
    panel = panel.assign(_y=panel[var], _ybar=cs_mean)
    for c, g in panel.groupby("country"):
        g = g.sort_values("year").copy()
        g["d"]=g["_y"].diff(); g["L"]=g["_y"].shift(1)
        g["dybar"]=g["_ybar"].diff(); g["Lybar"]=g["_ybar"].shift(1)
        for k in range(1,p+1):
            g[f"dL{k}"]=g["d"].shift(k); g[f"dybarL{k}"]=g["dybar"].shift(k)
        g=g.dropna()
        if len(g)<6: continue
        Z=np.column_stack([np.ones(len(g)), g["L"], g["Lybar"], g["dybar"]] +
                          [g[f"dL{k}"] for k in range(1,p+1)] +
                          [g[f"dybarL{k}"] for k in range(1,p+1)])
        Y=g["d"].values
        b,*_ = lstsq(Z, Y, rcond=None)
        e = Y - Z @ b
        s2 = (e@e)/(len(g)-Z.shape[1])
        XtX_inv = pinv(Z.T @ Z)
        se_L = np.sqrt(s2 * XtX_inv[1,1])
        cadf.append(b[1]/se_L)
    return np.mean(cadf), len(cadf)

cips_rows=[]
for v in VARS:
    t, n = cips(df, v)
    # Pesaran (2007) CV at 5% for T=15,N=27 ≈ -2.18 (intercept only) — ours has trend (cs avg)
    cips_rows.append({"var":v,"CIPS":round(t,3),"N_used":n,"reject_unit_root_5pct": t<-2.18})
pd.DataFrame(cips_rows).to_csv(os.path.join(OUT,"cips.csv"), index=False)

# ---------- 3. Westerlund (2007) Gt panel cointegration (simplified) ----------
def westerlund_gt(panel, y, X):
    stats_=[]
    for c, g in panel.groupby("country"):
        g=g.sort_values("year").copy()
        Z=np.column_stack([np.ones(len(g))]+[g[v].values for v in X])
        Y=g[y].values
        b,*_=lstsq(Z,Y,rcond=None)
        u=Y-Z@b
        du=np.diff(u); ul=u[:-1]
        if len(du)<4: continue
        XX=np.column_stack([np.ones(len(du)), ul])
        bb,*_=lstsq(XX, du, rcond=None)
        e=du - XX@bb
        s2=(e@e)/(len(du)-2)
        var_alpha = s2 * pinv(XX.T@XX)[1,1]
        stats_.append(bb[1]/np.sqrt(var_alpha))
    return np.mean(stats_), len(stats_)

gt, n = westerlund_gt(df, "ln_cmu", ["ln_gdp","ln_educ","ln_prod"])
pd.DataFrame([{"test":"Westerlund Gt","stat":round(gt,3),"N":n,"H0":"no cointegration"}]).to_csv(os.path.join(OUT,"westerlund.csv"), index=False)

# ---------- 4. CS-ARDL Mean Group (Chudik-Pesaran 2015), lag (1,1) ----------
def csardl_mg(panel, y, X, p=1, q=1):
    coefs=[]
    cs = panel.groupby("year")[[y]+X].transform("mean").add_suffix("_csa")
    P = pd.concat([panel, cs], axis=1)
    for c, g in P.groupby("country"):
        g=g.sort_values("year").copy()
        for k in range(1,p+1):
            g[f"L{k}_{y}"]=g[y].shift(k)
        for v in X:
            for k in range(0,q+1):
                g[f"L{k}_{v}"]=g[v].shift(k)
        g=g.dropna()
        if len(g)<6: continue
        cols = [f"L{k}_{y}" for k in range(1,p+1)] + \
               [f"L{k}_{v}" for v in X for k in range(0,q+1)] + \
               [f"{u}_csa" for u in [y]+X]
        Z=np.column_stack([np.ones(len(g))]+[g[col].values for col in cols])
        Y=g[y].values
        b,*_=lstsq(Z,Y,rcond=None)
        # long-run β_v = (β_v0 + β_v1) / (1 - φ1)
        phi1 = b[1]
        idx = 1 + p
        lr={}
        for v in X:
            num = b[idx] + b[idx+1]
            lr[v] = num / (1 - phi1)
            idx += (q+1)
        lr["country"]=c
        coefs.append(lr)
    R=pd.DataFrame(coefs)
    mg = {v: R[v].mean() for v in X}
    se = {v: R[v].std()/np.sqrt(len(R)) for v in X}
    out = pd.DataFrame({"var":list(X), "MG_long_run":list(mg.values()),
                        "SE":list(se.values()),
                        "t":[mg[v]/se[v] for v in X]}).round(4)
    return out, R

mg_table, mg_country = csardl_mg(df, "ln_cmu", ["ln_gdp","ln_educ","ln_prod"])
mg_table.to_csv(os.path.join(OUT,"csardl_mg.csv"), index=False)
mg_country.to_csv(os.path.join(OUT,"csardl_mg_country.csv"), index=False)

# ---------- 5. Dumitrescu-Hurlin (2012) panel causality ----------
def dh(panel, y, x, lag=2):
    Wbars=[]
    for c, g in panel.groupby("country"):
        g=g.sort_values("year").copy()
        for k in range(1,lag+1):
            g[f"y{k}"]=g[y].shift(k); g[f"x{k}"]=g[x].shift(k)
        g=g.dropna()
        if len(g)<lag+3: continue
        Z=np.column_stack([np.ones(len(g))]+[g[f"y{k}"].values for k in range(1,lag+1)]+
                          [g[f"x{k}"].values for k in range(1,lag+1)])
        Y=g[y].values
        b,*_=lstsq(Z,Y,rcond=None)
        e=Y-Z@b; rss1=e@e
        Z0=np.column_stack([np.ones(len(g))]+[g[f"y{k}"].values for k in range(1,lag+1)])
        b0,*_=lstsq(Z0,Y,rcond=None); e0=Y-Z0@b0; rss0=e0@e0
        T=len(g)
        F = ((rss0-rss1)/lag) / (rss1/(T-2*lag-1))
        Wbars.append(F*lag)  # convert F to Wald-like
    Wbar=np.mean(Wbars); N=len(Wbars); T=15
    Z = np.sqrt(N/(2*lag)) * (Wbar - lag)
    p = 2*(1 - stats.norm.cdf(abs(Z)))
    return Wbar, Z, p, N

dh_rows=[]
pairs=[("ln_gdp","ln_cmu"),("ln_cmu","ln_gdp"),
       ("ln_educ","ln_cmu"),("ln_cmu","ln_educ"),
       ("ln_prod","ln_cmu"),("ln_cmu","ln_prod")]
for x,y in pairs:
    Wbar,Z,p,N = dh(df, y, x)
    dh_rows.append({"H0":f"{x} ↛ {y}","Wbar":round(Wbar,3),"Zbar":round(Z,3),"p":round(p,4),"N":N})
pd.DataFrame(dh_rows).to_csv(os.path.join(OUT,"dh.csv"), index=False)

print("OK — wrote", os.listdir(OUT))
