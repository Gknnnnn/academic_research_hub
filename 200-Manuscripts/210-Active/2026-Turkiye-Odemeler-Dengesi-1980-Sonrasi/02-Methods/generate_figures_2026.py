"""
Türkiye Ödemeler Dengesi — Şekil Üretim Scripti (2026 Revizyonu)
Şekil 3.1 : Kırılma yılları makro göstergeler (1980-2026)
Şekil 3.3 : USD/TL kur ve brüt rezervler (2005-2026)
Şekil 3.4 : Finansman, rezerv değişimi ve net hata/noksan (2005-2026)

Veri kaynakları:
  - WDI (World Bank): 1980-2024 — wdi_macro_indicators_1980_2024.csv
  - TCMB seçilmiş: 2005-2024 — tcmb_turkiye_2005_2024_selected.csv
  - IMF WEO Nisan 2026 tahmini: 2025-2026 (†)
"""

from pathlib import Path
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
import numpy as np

# ---------- Paths ----------
BASE = Path(__file__).resolve().parents[1]
DATA = BASE / "03-Results"
FIG  = DATA / "figures"
FIG.mkdir(exist_ok=True)

PALETTE = {
    "blue":   "#1f4e79",
    "red":    "#c00000",
    "green":  "#375623",
    "orange": "#c55a11",
    "grey":   "#595959",
    "ltblue": "#2e75b6",
    "ltred":  "#ff6961",
}

# IMF WEO Nisan 2026 tahmini verileri — Türkiye
IMF_2025 = {
    "year": 2025,
    "gdp_growth": 3.6,
    "inflation": 34.9,
    "current_account": -1.9,
    "trade_open": 62.0,   # yazar tahmini (IMF WEO tutarlı)
    "fdi": 0.8,           # yazar tahmini
    "gdp_pc": 15949.07,   # IMF NGDPD/nüfus türetilmiş
    "usd_try": 38.5,      # IMF NGDPD serisi türetilmiş
    "gross_reserves": 55000.0,  # TCMB rezerv yeniden yapılanması (ortalama tahmin, milyar $ × 1000)
    "bop_reserve_assets": 3500.0,   # BOP rezerv varlıkları değişimi (yazar tahmini)
    "net_errors_omissions": -800.0, # yazar tahmini
    "portfolio_inv_liabilities": 1200.0,  # yazar tahmini
    "policy_rate": 40.0,
}

IMF_2026 = {
    "year": 2026,
    "gdp_growth": 3.4,
    "inflation": 28.6,
    "current_account": -2.8,
    "trade_open": 63.0,
    "fdi": 0.9,
    "gdp_pc": 16500.0,
    "usd_try": 44.0,      # yazar tahmini (kur baskısı beklentisi)
    "gross_reserves": 60000.0,
    "bop_reserve_assets": 2500.0,
    "net_errors_omissions": -600.0,
    "portfolio_inv_liabilities": 1000.0,
    "policy_rate": 32.0,
}

# ---------- Load WDI data ----------
wdi = pd.read_csv(DATA / "wdi_macro_indicators_1980_2024.csv")
wdi_extra = pd.DataFrame([IMF_2025, IMF_2026])[[
    "year", "gdp_pc", "gdp_growth", "inflation", "current_account", "trade_open", "fdi"
]]
wdi_full = pd.concat([wdi, wdi_extra], ignore_index=True).sort_values("year")

# ---------- Load TCMB data ----------
tcmb_raw = pd.read_csv(DATA / "tcmb_turkiye_2005_2024_selected.csv", parse_dates=["date"])
tcmb_raw["year"] = tcmb_raw["date"].dt.year
tcmb_ann = tcmb_raw.groupby("year")[[
    "usd_try", "gross_reserves", "bop_reserve_assets",
    "net_errors_omissions", "portfolio_inv_liabilities", "policy_rate"
]].mean().reset_index()

tcmb_extra = pd.DataFrame([IMF_2025, IMF_2026])[[
    "year", "usd_try", "gross_reserves", "bop_reserve_assets",
    "net_errors_omissions", "portfolio_inv_liabilities", "policy_rate"
]]
tcmb_full = pd.concat([tcmb_ann, tcmb_extra], ignore_index=True).sort_values("year")

# ========== ŞEKİL 3.1 — Kırılma yılları makro göstergeler (1980-2026) ==========

BREAK_YEARS = [1980, 1989, 1994, 2001, 2008, 2013, 2018, 2020, 2024, 2025]
LABELS = ["1980\nDışa açılma", "1989\nFinansal\nliberalizasyon", "1994\nKriz",
          "2001\nKriz", "2008\nKüresel kriz", "2013\nFed taper", "2018\nDöviz krizi",
          "2020\nCOVID-19", "2024\nNormalleşme", "2025†\nDevam"]

sel = wdi_full[wdi_full["year"].isin(BREAK_YEARS)].set_index("year")

fig, axes = plt.subplots(3, 1, figsize=(12, 10), sharex=False)
fig.suptitle("Türkiye'de Yapısal Kırılma Yıllarında Makroekonomik Göstergeler (1980–2026)",
             fontsize=13, fontweight="bold", y=0.98)

x = np.arange(len(BREAK_YEARS))
width = 0.65

# Panel A — Reel büyüme
vals_g = [sel.loc[y, "gdp_growth"] if y in sel.index else np.nan for y in BREAK_YEARS]
colors_g = [PALETTE["red"] if v < 0 else PALETTE["blue"] for v in vals_g]
axes[0].bar(x, vals_g, width=width, color=colors_g, alpha=0.85, edgecolor="white", linewidth=0.5)
axes[0].axhline(0, color="black", linewidth=0.8)
axes[0].set_ylabel("Reel büyüme (%)", fontsize=9)
axes[0].set_title("A — Reel GSYİH Büyümesi (%)", fontsize=10, loc="left", pad=3)
axes[0].set_xticks(x); axes[0].set_xticklabels(LABELS, fontsize=7.5)
axes[0].tick_params(axis="y", labelsize=8)
for i, (xi, v) in enumerate(zip(x, vals_g)):
    if not np.isnan(v):
        va = "bottom" if v >= 0 else "top"
        offset = 0.15 if v >= 0 else -0.15
        axes[0].text(xi, v + offset, f"{v:.1f}", ha="center", fontsize=7, color="black")
# IMF estimate shading
axes[0].axvspan(8.5, 9.5, alpha=0.08, color=PALETTE["orange"])

# Panel B — Enflasyon
vals_inf = [sel.loc[y, "inflation"] if y in sel.index else np.nan for y in BREAK_YEARS]
axes[1].bar(x, vals_inf, width=width, color=PALETTE["red"], alpha=0.80, edgecolor="white", linewidth=0.5)
axes[1].set_ylabel("Enflasyon (%)", fontsize=9)
axes[1].set_title("B — Tüketici Fiyat Enflasyonu (%)", fontsize=10, loc="left", pad=3)
axes[1].set_xticks(x); axes[1].set_xticklabels(LABELS, fontsize=7.5)
axes[1].tick_params(axis="y", labelsize=8)
for i, (xi, v) in enumerate(zip(x, vals_inf)):
    if not np.isnan(v):
        axes[1].text(xi, v + 1.5, f"{v:.0f}", ha="center", fontsize=7, color="black")
axes[1].axvspan(8.5, 9.5, alpha=0.08, color=PALETTE["orange"])

# Panel C — Cari denge/GSYİH
vals_ca = [wdi_full[wdi_full["year"] == y]["current_account"].values[0]
           if len(wdi_full[wdi_full["year"] == y]) > 0 else np.nan for y in BREAK_YEARS]
colors_ca = [PALETTE["red"] if v < 0 else PALETTE["green"] for v in vals_ca]
axes[2].bar(x, vals_ca, width=width, color=colors_ca, alpha=0.85, edgecolor="white", linewidth=0.5)
axes[2].axhline(0, color="black", linewidth=0.8)
axes[2].set_ylabel("Cari denge/GSYİH (%)", fontsize=9)
axes[2].set_title("C — Cari İşlemler Dengesi (GSYİH yüzdesi)", fontsize=10, loc="left", pad=3)
axes[2].set_xticks(x); axes[2].set_xticklabels(LABELS, fontsize=7.5)
axes[2].tick_params(axis="y", labelsize=8)
for i, (xi, v) in enumerate(zip(x, vals_ca)):
    if not np.isnan(v):
        va = "bottom" if v >= 0 else "top"
        offset = 0.1 if v >= 0 else -0.1
        axes[2].text(xi, v + offset, f"{v:.1f}", ha="center", fontsize=7, color="black")
axes[2].axvspan(8.5, 9.5, alpha=0.08, color=PALETTE["orange"])

# Footnote
fig.text(0.01, 0.005,
         "Kaynak: World Bank WDI (1980–2024); IMF WEO Nisan 2026 (2025†, turuncu şerit).",
         fontsize=7, color=PALETTE["grey"])
plt.tight_layout(rect=[0, 0.02, 1, 0.97])
out_31 = FIG / "sekil_3_1_kirilma_yillari_makro_1980_2026.png"
fig.savefig(out_31, dpi=300, bbox_inches="tight")
plt.close(fig)
print(f"✅ Şekil 3.1 kaydedildi → {out_31}")

# ========== ŞEKİL 3.3 — USD/TL kur ve brüt rezervler (2005-2026) ==========

fig, ax1 = plt.subplots(figsize=(12, 5))
ax2 = ax1.twinx()

years = tcmb_full["year"].values
usdtry = tcmb_full["usd_try"].values
reserves = tcmb_full["gross_reserves"].values / 1000  # milyon → milyar

# USD/TL çizgi (sol eksen)
l1, = ax1.plot(years, usdtry, color=PALETTE["blue"], linewidth=2.2, marker="o",
               markersize=4, label="USD/TL (yıllık ort.)")
ax1.fill_between(years, 0, usdtry, alpha=0.08, color=PALETTE["blue"])
ax1.set_xlabel("Yıl", fontsize=9)
ax1.set_ylabel("USD/TL (yıllık ortalama)", fontsize=9, color=PALETTE["blue"])
ax1.tick_params(axis="y", labelcolor=PALETTE["blue"], labelsize=8)
ax1.tick_params(axis="x", labelsize=8)
ax1.set_xlim(2004.5, 2026.5)
ax1.set_xticks(range(2005, 2027, 1))
ax1.set_xticklabels([str(y) for y in range(2005, 2027, 1)], rotation=45, ha="right", fontsize=7.5)

# Brüt rezervler çubuk (sağ eksen)
bar_width = 0.6
bars = ax2.bar(years, reserves, width=bar_width, alpha=0.50, color=PALETTE["green"],
               label="Brüt rezervler (milyar $)")
ax2.set_ylabel("TCMB Brüt Rezervleri (milyar ABD Doları)", fontsize=9, color=PALETTE["green"])
ax2.tick_params(axis="y", labelcolor=PALETTE["green"], labelsize=8)

# IMF tahmini bölgesi
ax1.axvspan(2024.5, 2026.5, alpha=0.08, color=PALETTE["orange"], zorder=0)
ax1.text(2025.3, ax1.get_ylim()[1] * 0.92 if ax1.get_ylim()[1] > 0 else 38,
         "IMF WEO\nNisan 2026 †", fontsize=7, color=PALETTE["orange"], ha="center")

# Önemli olaylar
events = {2008: "Küresel kriz", 2013: "Fed taper", 2018: "Döviz\nkrizi",
          2021: "Faiz\nindirimi", 2023: "Ortodoks\ndönüş"}
for yr, label in events.items():
    ax1.axvline(yr, color=PALETTE["grey"], linewidth=0.7, linestyle="--", alpha=0.6)
    y_pos = usdtry[list(years).index(yr)] if yr in years else 5
    ax1.text(yr + 0.05, y_pos + 0.5, label, fontsize=6.5, color=PALETTE["grey"],
             rotation=90, va="bottom")

ax1.set_title("Şekil 3.3 — USD/TL Döviz Kuru ve TCMB Brüt Rezervleri (2005–2026)",
              fontsize=11, fontweight="bold", pad=8)

lines = [l1, bars]
labels = ["USD/TL (yıllık ort.)", "Brüt rezervler (milyar $)"]
ax1.legend([l1, bars[0]], labels, loc="upper left", fontsize=8, framealpha=0.9)

fig.text(0.01, 0.005,
         "Kaynak: TCMB EVDS (2005–2024); IMF WEO Nisan 2026 (2025–2026, turuncu şerit). "
         "2025–2026 yazar tahmini (†).",
         fontsize=7, color=PALETTE["grey"])
plt.tight_layout(rect=[0, 0.04, 1, 1])
out_33 = FIG / "sekil_3_3_kur_rezerv_2005_2026.png"
fig.savefig(out_33, dpi=300, bbox_inches="tight")
plt.close(fig)
print(f"✅ Şekil 3.3 kaydedildi → {out_33}")

# ========== ŞEKİL 3.4 — Finansman, rezerv değişimi ve net hata/noksan (2005-2026) ==========

fig, ax1 = plt.subplots(figsize=(12, 5))
ax2 = ax1.twinx()

years = tcmb_full["year"].values
bop_res = tcmb_full["bop_reserve_assets"].values
nhn = tcmb_full["net_errors_omissions"].values
port = tcmb_full["portfolio_inv_liabilities"].values

x = np.arange(len(years))
width = 0.28

# Çubuklar — portföy, bop rezerv, nhn
b1 = ax1.bar(x - width, port, width=width, label="Portföy yat. borç (net, yıllık ort.)",
             color=PALETTE["blue"], alpha=0.80, edgecolor="white")
b2 = ax1.bar(x, bop_res, width=width, label="BOP rezerv varlıkları değişimi",
             color=PALETTE["green"], alpha=0.80, edgecolor="white")
b3 = ax1.bar(x + width, nhn, width=width, label="Net hata ve noksan",
             color=PALETTE["orange"], alpha=0.80, edgecolor="white")

ax1.axhline(0, color="black", linewidth=0.8)
ax1.set_ylabel("Milyon ABD Doları (aylık ortalama)", fontsize=9)
ax1.tick_params(axis="y", labelsize=8)
ax1.set_xlim(-0.8, len(years) - 0.2)
ax1.set_xticks(x)
ax1.set_xticklabels([str(y) for y in years], rotation=45, ha="right", fontsize=7.5)

# USD/TL overlay (sağ eksen — kırmızı çizgi)
usdtry = tcmb_full["usd_try"].values
l1, = ax2.plot(x, usdtry, color=PALETTE["red"], linewidth=2.0, marker="D",
               markersize=3.5, label="USD/TL (sağ eksen)")
ax2.set_ylabel("USD/TL", fontsize=9, color=PALETTE["red"])
ax2.tick_params(axis="y", labelcolor=PALETTE["red"], labelsize=8)

# IMF tahmini bölgesi
n = len(years)
ax1.axvspan(n - 2 - 0.5, n - 0.5, alpha=0.08, color=PALETTE["orange"], zorder=0)
ax1.text(n - 1.5, ax1.get_ylim()[1] * 0.88 if ax1.get_ylim()[1] > 0 else 3000,
         "IMF WEO\n2025–26 †", fontsize=7, color=PALETTE["orange"], ha="center")

ax1.set_title("Şekil 3.4 — Finansman, Rezerv Değişimi ve Net Hata/Noksan (2005–2026)",
              fontsize=11, fontweight="bold", pad=8)

handles = [b1, b2, b3, l1]
labels_leg = ["Portföy yat. borç (net, aylık ort.)",
              "BOP rezerv varlıkları değişimi",
              "Net hata ve noksan",
              "USD/TL (sağ eksen)"]
ax1.legend(handles, labels_leg, loc="upper left", fontsize=7.5, framealpha=0.9, ncol=2)

fig.text(0.01, 0.005,
         "Kaynak: TCMB EVDS BOP serisi (2005–2024, aylık ortalamalar); IMF WEO Nisan 2026 (2025–2026†, turuncu şerit). "
         "2025–2026 yazar tahmini.",
         fontsize=7, color=PALETTE["grey"])
plt.tight_layout(rect=[0, 0.04, 1, 1])
out_34 = FIG / "sekil_3_4_finansman_rezerv_nhn_2005_2026.png"
fig.savefig(out_34, dpi=300, bbox_inches="tight")
plt.close(fig)
print(f"✅ Şekil 3.4 kaydedildi → {out_34}")

print("\n✅ Tüm şekiller üretildi (DPI=300, 2025-2026 IMF WEO tahmini dahil).")
