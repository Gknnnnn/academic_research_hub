# PROJECT: IPO Underpricing and Intellectual Capital — Distributional Evidence from BIST Post-COVID Wave
**Proje No:** MGO-IPO-VAIC  
**Durum:** 🟡 PLANNING — VERİ: BIST KAP (IPO'lar, N≈154, 2019–2024)  
**Tarih:** 2026-04-24 | **Son güncelleme:** 2026-04-25 (SOLO MGO — KG çıkarıldı)  
**Hedef Dergi:** Borsa Istanbul Review (SSCI Q2) — doğrudan kapsam içi  
**ÜAK:** 20 pt (SOLO)

---

## Araştırma Sorusu

> BIST 2019-2024 IPO dalgasında (N≈154) ihraçcı entelektüel sermayesi (VAIC)  
> aşırı fiyatlamayı (underpricing) dağılımın kuyruk noktalarında azaltır mı?  
> Perakende yatırımcı finansal okuryazarlığı bu ilişkiyi değiştirir mi?

**Hipotez:** VAIC etkisi en aşırı underpriced IPO'larda (yüksek underpricing quantilleri) daha büyük — bilgi asimetrisinin yüksek olduğu ortamda entelektüel sermaye sinyali daha değerli.

---

## Yazarlar & CRediT

| Yazar | Kurum | Katkı |
|-------|-------|-------|
| **Res. Asst. Dr. M. Gökhan Özdemir** | KKÜ İktisat Teorisi | Conceptualization, Methodology, Software, Data Curation, Formal Analysis, Writing–OD, Validation |

**Authorship:** SOLO MGO (KG çıkarıldı 2026-04-25) | **ÜAK:** 20 pt SOLO

---

## Veri

| Değişken | Kaynak | Açıklama |
|----------|--------|----------|
| IPO ilk gün getirisi (underpricing) | BIST / KAP | (P₁/P₀ - 1) × 100 |
| VAIC (Value Added Intellectual Coefficient) | Yıllık raporlar + KAP | HCE + SCE + CEE |
| Firma büyüklüğü (log aktif) | KAP | IPO öncesi |
| Piyasa koşulları (BIST100 getirisi) | Borsa Istanbul | IPO tarihinden -30 gün |
| Underwriter prestiji | SPK sicili | Tier-1 vs Tier-2 aracı kurum |
| Satış yapısı | KAP | Yeni hisse vs ikincil satış oranı |
| Finansal okuryazarlık (moderation) | OECD/INFE Türkiye 2022 anket | Ortalama il bazlı (yatırımcı lokasyonu proxy) |

**Örneklem:** BIST IPO 2019–2024, N≈154 (Arslan et al. 2025'te tespit edilen)  
**Hariç:** REIT, finansal kuruluş, düzeltilmiş fiyat olmayan IPO'lar

---

## Metodoloji

### Aşama 1 — OLS Baseline
```r
lm(UNDERPRICING ~ VAIC + SIZE + MARKET_RET + UNDERWRITER + OFFER_TYPE, data=ipo)
```

### Aşama 2 — Quantile Regression (ANA KATKI)
```r
library(quantreg)
qr_fit <- rq(UNDERPRICING ~ VAIC + SIZE + MARKET_RET + UNDERWRITER,
             tau = c(0.10, 0.25, 0.50, 0.75, 0.90),
             data = ipo_data,
             method = "br")
# Webb wild bootstrap CI (N=154 → küçük örneklem)
boot_ci <- summary(qr_fit, se="boot", bsmethod="wild", R=1000)
```

### Aşama 3 — Moderation (Finansal Okuryazarlık)
```r
lm(UNDERPRICING ~ VAIC * FIN_LITERACY + controls, data=ipo)
```

### Aşama 4 — IV (Endojenlik)
VAIC endojen olabilir → IV: sektör medyan VAIC (Bartik-style instrument)

---

## Tahmini Zaman Çizelgesi

| Aşama | Süre | Sorumlu |
|-------|------|---------|
| IPO veri seti toplama (N=154) | 2 hafta | MGO — BIST KAP |
| VAIC hesaplama (yıllık raporlar) | 1 hafta | MGO |
| Quantile regression + bootstrap | 1 hafta | MGO |
| Moderation + IV | 1 hafta | MGO |
| QMD yazım | 1,5 hafta | Ortak |
| **TOPLAM** | **~7 hafta** | |

**Hedef submission:** Ağustos 2026

---

## Taslak Başlık

```
"Intellectual Capital Signalling and IPO Underpricing: 
Distributional Evidence from Borsa Istanbul's Post-COVID Wave"
```
