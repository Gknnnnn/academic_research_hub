# PROJECT: Safe-Haven Dynamics and Turkish Bank Resilience Under Currency War Conditions
**Proje No:** KG-MGO-05  
**Durum:** 🔵 INCUBATION — Uzun vadeli (6-12 ay)  
**Tarih:** 2026-04-24  
**Hedef Dergi:** International Review of Financial Analysis (SSCI Q1, IF=9.8) veya JIMF (Q1)  
**ÜAK:** 30 pt × 0.8 = 24 pt (2 yazar)

---

## Araştırma Sorusu

> TRY değer kaybı rejimlerinde altın Türk hanehalkları için güvenli liman işlevi görür mü?  
> Bu talep artışı altın mevduat kanalıyla banka fonlamayı zorlaştırır mı?  
> Peki bu mikro banka baskısı systemic risk seviyesine ulaşır mı?

**Neden önemli:** KG-MGO-02 (Gold Deposit NARDL) mikro kanalı ölçer.  
Bu proje ise **makro-finansal geri beslemeyi** bütünleşik modeller.

---

## Yazarlar & CRediT

| Yazar | Kurum | Katkı |
|-------|-------|-------|
| **M. Gökhan Özdemir (MGO)** | KKÜ İktisat Teorisi | Conceptualization, Methodology, NARDL+Quantile, CW portföy bağlantısı |
| **İlkut Elif Kandil Göker** | Ankara Üniversitesi | Banka düzeyi veri, Z-score, Bankometer, Writing–RE |

---

## Üç Katmanlı Model Yapısı

```
KATMAN 1 (Hanehalkı): TRY değer kaybı → altın talep artışı (safe-haven)
    Metot: Quantile regression (hane varlık tercihi — TCMB anket verisi)

KATMAN 2 (Banka): Altın talep artışı → altın mevduat ↑ → NIM/ROA baskısı
    Metot: NARDL panel (KG-MGO-02'nin genişletmesi)

KATMAN 3 (Sistem): Banka baskısı → Z-score ↓ → systemic risk ↑?
    Metot: Panel quantile + SRISK (Brownlees-Engle 2017) yaklaşımı
```

---

## Veri (Kapsamlı)

| Değişken | Kaynak |
|----------|--------|
| Hane altın varlık tercihi | TCMB Hanehalkı Finansal Varlıklar Anketi |
| Altın mevduat hacmi | BDDK aylık |
| Z-score, SRISK banka bazlı | BDDK + hesaplama |
| TRY/USD + altın fiyatı | TCMB EVDS + FRED |
| GPR endeksi (Caldara-Iacoviello) | FRED: GPRD |

---

## Neden Uzun Vade

- 3 veri katmanı: hane + banka + sistem → veri toplama 1 ay
- SRISK hesaplama metodoloji yoğun
- 2 ülke karşılaştırması (Türkiye + Hindistan, INR benzer durum) eklenebilir
- **Önce KG-MGO-01 + KG-MGO-02 tamamla** → bu çalışmaya hazırlık

---

## Taslak Başlık

```
"Currency War Safe-Haven Demand, Gold Deposits, and Turkish Bank Resilience: 
A Unified Macro-Financial Analysis"
```

**Hedef submission:** 2027 Q1 (doçentlik sonrası büyük makale)
