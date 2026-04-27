"""
Merkez Bankası Bağımsızlığı — Veri Toplama Scripti
====================================================
M. Gökhan Özdemir | Kırıkkale University
Oluşturma: 2026-04-09

KULLANIM:
  1. EVDS API anahtarınızı alın: https://evds3.tcmb.gov.tr (ücretsiz)
  2. Aşağıdaki satırda API_KEY'i girin veya .env dosyasına EVDS_API_KEY=... ekleyin
  3. python 01_collect_data.py

ÇIKTI:
  data/raw/tcmb_monthly_2005_2025.csv   — TCMB aylık makro panel
  data/raw/cbi_turkey_annual.csv         — CBI endeksi (Garriga 2016 + güncel)
  data/processed/cbi_panel_merged.csv    — Birleştirilmiş analiz verisi

GEREKLİ PAKETLER:
  pip install pandas requests python-dotenv openpyxl
"""

import os
import sys
import requests
import pandas as pd
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────────────────────────────────────
# AYARLAR
# ─────────────────────────────────────────────────────────────────────────────
API_KEY   = os.getenv("EVDS_API_KEY") or os.getenv("EVDS3_API_KEY") or "BURAYA_API_ANAHTARINIZI_GİRİN"
START     = "01-01-2005"   # Enflasyon hedeflemesi başlangıcı
END       = "01-03-2025"
BASE_URL  = "https://evds3.tcmb.gov.tr/igmevdsms-dis"
OUT_DIR   = Path(__file__).parent / "raw"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# ─────────────────────────────────────────────────────────────────────────────
# EVDS SERİ KODLARI (CBI Makalesi için)
# ─────────────────────────────────────────────────────────────────────────────
SERIES = {
    # Para politikası
    "policy_rate"    : "TP.BISPOLFAIZ.TUR",  # Türkiye merkez bankası politika faizi
    "o_n_rate"       : "TP.TF.TFE.ONS",   # Gecelik borç verme faizi
    # Enflasyon (gerçekleşen)
    "cpi_annual"     : "TP.FG.J0",         # TÜFE yıllık % değişim
    "cpi_monthly"    : "TP.FG.J01",        # TÜFE aylık % değişim
    # Enflasyon beklentileri (anket — piyasa katılımcıları)
    "inf_exp_12m"    : "TP.PKAUO.S01.E.U", # 12 ay sonrası yıllık TÜFE beklentisi
    "inf_exp_24m"    : "TP.PKAUO.S01.F.U", # 24 ay sonrası yıllık TÜFE beklentisi
    # Döviz kuru
    "usd_try"        : "TP.DK.USD.A",      # USD/TRY aylık ortalama
    "eur_try"        : "TP.DK.EUR.A",      # EUR/TRY aylık ortalama
    # Kredi & para arzı
    "m2"             : "TP.PA1.T2",        # M2 para arzı
    "credit_growth"  : "TP.KT01.INM01",   # Toplam kredi büyümesi
    # Rezervler
    "gross_reserves" : "TP.AB.B3",         # Brüt döviz rezervleri (Mn USD)
    # Büyüme (çeyreklik — aylık interpolasyon gerekir)
    "gdp_growth"     : "TP.GSYIH03.B01",   # GSYİH büyüme oranı
}

CORE_SERIES = {
    "policy_rate": SERIES["policy_rate"],
    "cpi_annual": SERIES["cpi_annual"],
    "cpi_monthly": SERIES["cpi_monthly"],
    "inf_exp_12m": SERIES["inf_exp_12m"],
    "inf_exp_24m": SERIES["inf_exp_24m"],
    "usd_try": SERIES["usd_try"],
    "eur_try": SERIES["eur_try"],
    "gross_reserves": SERIES["gross_reserves"],
}

OPTIONAL_SERIES = {
    "o_n_rate": SERIES["o_n_rate"],
    "m2": SERIES["m2"],
    "credit_growth": SERIES["credit_growth"],
    "gdp_growth": SERIES["gdp_growth"],
}

# ─────────────────────────────────────────────────────────────────────────────
# TCMB BAŞKANI DEĞİŞİM TARİHLERİ (Yapısal Kırılma / Dummy)
# ─────────────────────────────────────────────────────────────────────────────
GOVERNOR_CHANGES = {
    "2011-04": ("Erdem Basci",      "normal",       "Regular appointment"),
    "2016-04": ("Murat Cetinkaya",  "normal",       "Regular appointment"),
    "2019-07": ("Murat Uysal",      "political",    "Cetinkaya dismissed — refused to cut rates"),
    "2020-11": ("Naci Agbal",       "technocrat",   "Uysal dismissed — after FX interventions"),
    "2021-03": ("Sahap Kavcioglu",  "political",    "Agbal dismissed 2 days after rate hike"),
    "2023-06": ("Hafize Gaye Erkan","normalization", "Post-election U-turn — orthodox policy"),
    "2024-02": ("Fatih Karahan",    "normalization", "Continuation of orthodox policy"),
}

# ─────────────────────────────────────────────────────────────────────────────
# EVDS VERİ ÇEKME
# ─────────────────────────────────────────────────────────────────────────────
def fetch_series(codes_dict: dict, start: str, end: str, freq: str = "5") -> pd.DataFrame:
    """Tüm serileri tek API çağrısında çeker (aylık freq=5)."""
    codes_str = "-".join(codes_dict.values())
    agg_str = "-".join(["avg"] * len(codes_dict))
    formula_str = "-".join(["0"] * len(codes_dict))
    headers = {"key": API_KEY, "Accept": "application/json"}
    url = (
        f"{BASE_URL}/series={codes_str}"
        f"&startDate={start}"
        f"&endDate={end}"
        f"&type=json"
        f"&aggregationTypes={agg_str}"
        f"&formulas={formula_str}"
        f"&frequency={freq}"
    )
    resp = requests.get(url, headers=headers, timeout=30)

    if resp.status_code == 403:
        print("✗ API anahtarı geçersiz veya eksik!")
        print("  → https://evds3.tcmb.gov.tr adresinden ücretsiz anahtar alın")
        print("  → API_KEY değişkenine veya .env'e EVDS_API_KEY=... ya da EVDS3_API_KEY=... ekleyin")
        sys.exit(1)

    resp.raise_for_status()
    items = resp.json().get("items", [])
    if not items:
        raise ValueError("Boş veri döndü — seri kodlarını kontrol edin.")

    df = pd.DataFrame(items)
    df["date"] = pd.to_datetime(df["Tarih"], dayfirst=True, errors="coerce")
    df = df.drop(columns=["Tarih"], errors="ignore").set_index("date").sort_index()

    # Sütunları anlamlı isimlerle yeniden adlandır
    rev = {}
    for label, code in codes_dict.items():
        rev[code] = label
        rev[code.replace(".", "_")] = label
    df = df.rename(columns=rev)
    for col in df.columns:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def fetch_optional_series(codes_dict: dict, start: str, end: str, freq: str = "5"):
    """Opsiyonel serileri tek tek dener; çalışanları birleştirir, düşenleri raporlar."""
    frames = []
    status_rows = []

    for label, code in codes_dict.items():
        try:
            df_one = fetch_series({label: code}, start, end, freq=freq)
            non_missing = int(df_one[label].notna().sum()) if label in df_one.columns else 0
            if label in df_one.columns and non_missing > 0:
                frames.append(df_one[[label]])
                status_rows.append({
                    "series": label,
                    "code": code,
                    "status": "ok",
                    "non_missing_obs": non_missing
                })
            else:
                status_rows.append({
                    "series": label,
                    "code": code,
                    "status": "empty",
                    "non_missing_obs": non_missing
                })
        except Exception as exc:
            status_rows.append({
                "series": label,
                "code": code,
                "status": "failed",
                "non_missing_obs": 0,
                "error": str(exc)[:240]
            })

    merged = pd.concat(frames, axis=1) if frames else pd.DataFrame()
    status_df = pd.DataFrame(status_rows)
    return merged, status_df


def add_governor_dummies(df: pd.DataFrame) -> pd.DataFrame:
    """Vali değişim tarihlerini ikili dummy ve kategorik değişken olarak ekler."""
    df["governor_change"] = 0
    df["appointment_type"] = "normal"
    df["governor_name"] = ""

    for date_str, (name, appt_type, note) in GOVERNOR_CHANGES.items():
        year, month = map(int, date_str.split("-"))
        mask = (df.index.year == year) & (df.index.month == month)
        df.loc[mask, "governor_change"] = 1
        df.loc[mask, "appointment_type"] = appt_type
        df.loc[mask, "governor_name"] = name

    # Siyasi atama dummyleri (NARDL pozitif/negatif baskı için)
    df["political_dismissal"] = (df["appointment_type"] == "political").astype(int)
    df["orthodox_return"]     = (df["appointment_type"] == "normalization").astype(int)
    return df


# ─────────────────────────────────────────────────────────────────────────────
# ANA AKIŞ
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("="*60)
    print("TCMB EVDS Veri Toplama — CBI Makale Verisi")
    print(f"Dönem: {START} → {END}")
    print("="*60)

    if "BURAYA_API_ANAHTARINIZI_GİRİN" in API_KEY:
        print("\n⚠️  API anahtarı girilmemiş!")
        print("  1. https://evds3.tcmb.gov.tr adresinden ücretsiz hesap açın")
        print("  2. Profil → API Key bölümünden anahtarı kopyalayın")
        print("  3. Bu script'in başındaki API_KEY değişkenine girin")
        print("     VEYA .env dosyasına: EVDS_API_KEY=anahtariniz")
        print("     VEYA .env dosyasına: EVDS3_API_KEY=anahtariniz")
        sys.exit(0)

    print("\n[1/4] Çekirdek TCMB serileri çekiliyor...")
    df_tcmb = fetch_series(CORE_SERIES, START, END, freq="5")
    print(f"  ✓ {len(df_tcmb)} aylık gözlem, {len(df_tcmb.columns)} çekirdek değişken")

    print("[2/4] Opsiyonel seriler tek tek doğrulanıyor...")
    df_optional, optional_status = fetch_optional_series(OPTIONAL_SERIES, START, END, freq="5")
    if not df_optional.empty:
        df_tcmb = df_tcmb.join(df_optional, how="left")
    ok_count = int((optional_status["status"] == "ok").sum()) if not optional_status.empty else 0
    fail_count = int((optional_status["status"] != "ok").sum()) if not optional_status.empty else 0
    print(f"  ✓ {ok_count} opsiyonel seri eklendi")
    print(f"  • {fail_count} opsiyonel seri eksik/başarısız")

    print("[3/4] Vali değişim dummyleri ekleniyor...")
    df_tcmb = add_governor_dummies(df_tcmb)
    print(f"  ✓ {df_tcmb['governor_change'].sum()} değişim tarihi işaretlendi")

    # Ham veriyi kaydet
    out_path = OUT_DIR / "tcmb_monthly_2005_2025.csv"
    df_tcmb.to_csv(out_path)
    print(f"  ✓ Kaydedildi: {out_path}")

    status_path = OUT_DIR / "tcmb_optional_series_status.csv"
    optional_status.to_csv(status_path, index=False)
    print(f"  ✓ Opsiyonel seri durum raporu: {status_path}")

    print("[4/4] Özet istatistikler...")
    print(df_tcmb[["policy_rate", "cpi_annual", "inf_exp_12m", "usd_try"]].describe().round(2))

    print("\n✅ Veri toplama tamamlandı.")
    print(f"   → {out_path}")
    print(f"   → {status_path}")
    print("\nSonraki adım: Rscripts/02_nardl_analysis.R")
