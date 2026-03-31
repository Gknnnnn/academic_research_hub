# ADF Birim Kök Testi Raporu — BRICS-T EKC Analizi

> **Oluşturulma:** 2026-03-29 11:22  
> **Kaynak:** World Bank API (`wbgapi`)  
> **Dönem:** 2003–2022  
> **Ülkeler:** Türkiye, Brezilya, Rusya, Hindistan, Çin, Güney Afrika  
> **Yöntem:** Augmented Dickey–Fuller (ADF), intercept+trend / intercept  
> **Gecikme Seçimi:** AIC (maxlag=4)  

---

## 1. Test Mantığı

$$H_0: \text{Birim kök mevcut (durağan değil)} \quad H_1: \text{Durağan}$$

Karar kriteri: $p < 0.05$ → $H_0$ reddedilir → seri durağandır.

- **Düzey testi** (intercept + trend): Serinin düzeyde durağanlığını sınar → I(0)
- **Birinci fark testi** (intercept): Fark alındıktan sonra durağanlığı sınar → I(1)

---

## 2. Sonuç Tablosu

| Ülke | Değişken | Form | ADF İst. | p-değeri | Karar | Entegrasyon |
|------|----------|------|----------|----------|-------|------------|
| Brazil | lnCO2 | level | -1.4292 | 0.8521 | BİRİM KÖK ✗ | — |
| Brazil | lnCO2 | diff | -4.6823 | 0.0001 | DURAĞAN ✓ | I(1) ✓ |
| Brazil | lnGDP | level | -1.7483 | 0.7292 | BİRİM KÖK ✗ | — |
| Brazil | lnGDP | diff | -3.1473 | 0.0232 | DURAĞAN ✓ | I(1) ✓ |
| Brazil | lnGDP2 | level | -1.7332 | 0.736 | BİRİM KÖK ✗ | — |
| Brazil | lnGDP2 | diff | -3.1433 | 0.0235 | DURAĞAN ✓ | I(1) ✓ |
| China | lnCO2 | level | -3.3241 | 0.0624 | BİRİM KÖK ✗ | — |
| China | lnCO2 | diff | -2.1917 | 0.2093 | BİRİM KÖK ✗ | I(2)? |
| China | lnGDP | level | -4.5744 | 0.0011 | DURAĞAN ✓ | I(0) ✓ |
| China | lnGDP | diff | -1.5635 | 0.5019 | BİRİM KÖK ✗ | I(2)? |
| China | lnGDP2 | level | -3.5815 | 0.0314 | DURAĞAN ✓ | I(0) ✓ |
| China | lnGDP2 | diff | -1.1721 | 0.6855 | BİRİM KÖK ✗ | I(2)? |
| India | lnCO2 | level | 0.8147 | 1.0 | BİRİM KÖK ✗ | — |
| India | lnCO2 | diff | -3.7148 | 0.0039 | DURAĞAN ✓ | I(1) ✓ |
| India | lnGDP | level | -2.7029 | 0.2349 | BİRİM KÖK ✗ | — |
| India | lnGDP | diff | -4.1618 | 0.0008 | DURAĞAN ✓ | I(1) ✓ |
| India | lnGDP2 | level | -3.1756 | 0.0894 | BİRİM KÖK ✗ | — |
| India | lnGDP2 | diff | -4.2294 | 0.0006 | DURAĞAN ✓ | I(1) ✓ |
| Russia | lnCO2 | level | -2.8041 | 0.1955 | BİRİM KÖK ✗ | — |
| Russia | lnCO2 | diff | -4.1123 | 0.0009 | DURAĞAN ✓ | I(1) ✓ |
| Russia | lnGDP | level | -2.8295 | 0.1863 | BİRİM KÖK ✗ | — |
| Russia | lnGDP | diff | -2.5923 | 0.0946 | BİRİM KÖK ✗ | I(2)? |
| Russia | lnGDP2 | level | -2.793 | 0.1995 | BİRİM KÖK ✗ | — |
| Russia | lnGDP2 | diff | -2.5955 | 0.0939 | BİRİM KÖK ✗ | I(2)? |
| South Africa | lnCO2 | level | -2.4058 | 0.3765 | BİRİM KÖK ✗ | — |
| South Africa | lnCO2 | diff | -2.1518 | 0.2242 | BİRİM KÖK ✗ | I(2)? |
| South Africa | lnGDP | level | -2.029 | 0.5855 | BİRİM KÖK ✗ | — |
| South Africa | lnGDP | diff | -3.2748 | 0.016 | DURAĞAN ✓ | I(1) ✓ |
| South Africa | lnGDP2 | level | -2.0114 | 0.5952 | BİRİM KÖK ✗ | — |
| South Africa | lnGDP2 | diff | -3.28 | 0.0158 | DURAĞAN ✓ | I(1) ✓ |
| Turkey | lnCO2 | level | -3.0333 | 0.123 | BİRİM KÖK ✗ | — |
| Turkey | lnCO2 | diff | -4.066 | 0.0011 | DURAĞAN ✓ | I(1) ✓ |
| Turkey | lnGDP | level | -3.6357 | 0.027 | DURAĞAN ✓ | I(0) ✓ |
| Turkey | lnGDP | diff | -3.6931 | 0.0042 | DURAĞAN ✓ | I(1) ✓ |
| Turkey | lnGDP2 | level | -3.5872 | 0.0309 | DURAĞAN ✓ | I(0) ✓ |
| Turkey | lnGDP2 | diff | -3.6931 | 0.0042 | DURAĞAN ✓ | I(1) ✓ |

---

## 3. Ekonometrik Yorum

Panel EKC analizinde serilerin entegrasyon mertebeleri kritik öneme sahiptir:

- Tüm seriler **I(1)** ise → **Pedroni/Westerlund eşbütünleşme testi** uygulanır.
- I(0) ve I(1) serileri birlikte mevcutsa → **ARDL (PMG/MG)** tahmincisi tercih edilir.
- I(2) seri varsa → **Toda–Yamamoto** modifiye nedensellik testi kullanılmalıdır.

**EKC hipotezi için beklenen örüntü:**

$$\Delta \ln\text{CO}_{2,it} \sim I(0) \Rightarrow \text{Düzeyde durağan (nadir)}$$
$$\ln\text{CO}_{2,it} \sim I(1), \quad \ln\text{GDP}_{it} \sim I(1) \Rightarrow \text{Eşbütünleşme sınanmalı}$$

---

## 4. Önerilen Sonraki Adımlar

- [ ] **CD testi** (Pesaran, 2004): Çapraz kesit bağımlılığını sına
- [ ] **CIPS / CADF** (2. nesil birim kök): CD sonucu anlamlıysa uygula
- [ ] **Westerlund (2007)** eşbütünleşme testi: ECT tabanlı panel testi
- [ ] **PMG tahminci** (`statsmodels` ARDL veya Stata xtpmg)
- [ ] **Dumitrescu–Hurlin** panel nedensellik testi

---

## 5. Dosya Referansları

- Ham veri: `03_Data_Raw/WB_Data_Raw.csv`
- ADF CSV : `04_Data_Cleaned/ADF_Results.csv`
- Bu rapor: `04_Data_Cleaned/ADF_Stationarity_Report.md`

---

## 6. APA 7th Referanslar

Dickey, D. A., & Fuller, W. A. (1979). Distribution of the estimators for autoregressive time series with a unit root. *Journal of the American Statistical Association*, *74*(366), 427–431.

Said, S. E., & Dickey, D. A. (1984). Testing for unit roots in autoregressive-moving average models of unknown order. *Biometrika*, *71*(3), 599–607.

Pesaran, M. H. (2007). A simple panel unit root test in the presence of cross-section dependence. *Journal of Applied Econometrics*, *22*(2), 265–312.

*Script: wb_bricst_ekc.py | Kırıkkale Üniversitesi — Dr. M. G. Özdemir*