# Metodolojik Notlar — EKC & Panel Nedensellik

> **Oluşturulma:** 2026-03-29  
> **Proje:** Zotero Kütüphanesi (ID: 7714813) — EKC & Jevons Paradox Literatürü  
> **Hazırlayan:** Dr. Mehmet Gökhan Özdemir, Kırıkkale Üniversitesi, İktisat Teorisi ABD  
> **Hedef Dergiler:** Energy Economics · Ecological Economics · Journal of Environmental Management  

---

## 1. Temel Kaynak Makaleler

| # | Zotero Key | Yazar(lar) | Yıl | Dergi | Metodoloji |
|---|-----------|-----------|-----|-------|-----------|
| 1 | `35Y74DTY` | Abdi, A. H. | 2023 | *Environ. Sci. Pollut. Res.* | PMG, Dumitrescu–Hurlin, heterogeneous panel |
| 2 | `X8B5PM8J` | İnal et al. | 2022 | *Energy Reports* | Konya Bootstrap + EKC, panel nedensellik |

---

## 2. Temel EKC Modeli (PMG Çerçevesi)

Abdi (2023) metodolojisi temel alınarak aşağıdaki sembolik model türetilmiştir.

### 2.1 Uzun-Dönem Denklem

$$\text{CO}_{2,it} = \alpha_i + \beta_1 Y_{it} + \beta_2 Y_{it}^2 + \beta_3 \text{REN}_{it} + \beta_4 \text{EC}_{it} + \beta_5 \text{URB}_{it} + \varepsilon_{it}$$

**Değişken Açıklamaları:**

| Sembol | Açıklama |
|--------|----------|
| $\text{CO}_{2,it}$ | $i$ ülkesi, $t$ döneminde kişi başı CO₂ emisyonu |
| $Y_{it}$ | Kişi başı reel GSYİH (log) |
| $Y_{it}^2$ | GSYİH'nın karesi — EKC ters-U testi için |
| $\text{REN}_{it}$ | Yenilenebilir enerji tüketimi payı (%) |
| $\text{EC}_{it}$ | Ekonomik karmaşıklık endeksi (ECI) |
| $\text{URB}_{it}$ | Kentleşme oranı (%) |
| $\alpha_i$ | Ülkeye özgü sabit etki |
| $\varepsilon_{it}$ | Hata terimi |


### 2.2 EKC Eşik Koşulları

EKC hipotezinin geçerliliği için şu koşulların eş zamanlı sağlanması gerekmektedir:

$$\hat{Y}^* = \exp\!\left(-\frac{\hat{\beta}_1}{2\hat{\beta}_2}\right) \qquad \text{(çevresel dönüm noktası GSYİH düzeyi)}$$

$$\text{EKC desteklenir} \iff \hat{\beta}_1 > 0 \;\text{ ve }\; \hat{\beta}_2 < 0$$

> **Not:** $\hat{Y}^*$ değeri örneklem GSYİH aralığı içinde kalmalıdır; aksi hâlde EKC ekonomik olarak anlamsızdır (bkz. Stern, 2004).

---

## 3. Uzun-Dönem ARDL / PMG Hata Düzeltme Modeli

$$\Delta \text{CO}_{2,it} = \phi_i \bigl(\text{CO}_{2,i,t-1} - \boldsymbol{\theta}_i' \mathbf{X}_{it}\bigr) + \sum_{j=0}^{p-1}\boldsymbol{\delta}_{ij}' \Delta \mathbf{X}_{i,t-j} + \mu_{it}$$

**Parametre Yorumu:**

- $\phi_i < 0$: Uzun-dönem dengesine yakınsama hızı (error-correction coefficient)  
- $\boldsymbol{\theta}_i$: Uzun-dönem katsayı vektörü (PMG'de homojen kısıtlanır)  
- $\boldsymbol{\delta}_{ij}$: Kısa-dönem dinamik katsayılar (ülke bazında heterojen)  

> PMG tahmincisi (Pesaran, Shin & Smith, 1999): uzun-dönemde homojenlik + kısa-dönemde heterojenlikiçin verimli ve tutarlıdır.

---

## 4. Panel Birim Kök ve Eşbütünleşme Testleri

### 4.1 Çapraz Kesit Bağımlılığı (Pesaran CD Testi)

$$CD = \sqrt{\frac{2T}{N(N-1)}} \sum_{i=1}^{N-1}\sum_{j=i+1}^{N} \hat{\rho}_{ij} \xrightarrow{d} \mathcal{N}(0,1)$$

$H_0$: Çapraz kesit bağımsızlığı. CD istatistiği anlamlıysa ikinci nesil panel birim kök testleri zorunludur.

### 4.2 Eğim Homojenliği (Pesaran & Yamagata, 2008)

$$\tilde{\Delta} = \sqrt{N}\, \frac{N^{-1}\hat{S} - K}{\sqrt{2K}} \qquad \tilde{\Delta}_{adj} = \sqrt{N}\, \frac{N^{-1}\hat{S} - \mathbb{E}[\tilde{z}_{iT}]}{\sqrt{\text{Var}[\tilde{z}_{iT}]}}$$

> Zotero Referans: `LKXELW7W` — Pesaran & Yamagata (2008), *Journal of Econometrics*.


---

## 5. Dumitrescu–Hurlin (2012) Panel Nedensellik Testi

### 5.1 Test İstatistiği

$$W_{N,T}^{HNC} = \frac{1}{\sqrt{N}} \sum_{i=1}^{N} \frac{W_{i,T} - K}{\sqrt{2K}} \xrightarrow{d} \mathcal{N}(0,1)$$

- $W_{i,T}$: Bireysel Wald istatistiği ($i$. ülke için Granger nedensellik testi)  
- $K$: Gecikme sayısı  
- $N \to \infty$ altında asimptotik normallik geçerlidir  

### 5.2 Heterojen Panel Granger Regresyonu

Her ülke için ayrı ayrı çalışan bireysel denklem:

$$y_{i,t} = \alpha_i + \sum_{k=1}^{K} \gamma_i^{(k)} y_{i,t-k} + \sum_{k=1}^{K} \delta_i^{(k)} x_{i,t-k} + \varepsilon_{i,t}$$

$H_0^{HNC}$: $\delta_i^{(k)} = 0 \;\forall\, i, k$ (Homojen nedensellik yok)

> **Uygulama notu (Abdi, 2023):** CO₂ → REN tek yönlü nedensellik (Zotero: `35Y74DTY`).  
> CO₂ ↔ EC çift yönlü nedensellik bulgusu EKC literatürüyle tutarlıdır.

---

## 6. Konya (2006) Bootstrap Panel Nedensellik (İnal et al., 2022)

$$y_{1,t} = \alpha_{1,i} + \sum_{l=1}^{p_i} \beta_{11,i,l}\, y_{1,t-l} + \sum_{l=1}^{q_i} \beta_{12,i,l}\, y_{2,t-l} + \varepsilon_{1,i,t}$$

$$y_{2,t} = \alpha_{2,i} + \sum_{l=1}^{p_i} \beta_{21,i,l}\, y_{1,t-l} + \sum_{l=1}^{q_i} \beta_{22,i,l}\, y_{2,t-l} + \varepsilon_{2,i,t}$$

> **Avantaj:** Birim kök ve eşbütünleşme ön testleri gerektirmez; ülke bazında sonuç verir.  
> **Zotero Referans:** `X8B5PM8J` — İnal et al. (2022), *Energy Reports*.

---

## 7. Tanımlama Stratejisi ve Endojenlik

| Sorun | Yöntem | Açıklama |
|-------|--------|----------|
| Endojenlik | System-GMM (Blundell–Bond) | Araç değişken: $Y_{it-2}$, $Y_{it-3}$ |
| Çapraz kesit bağımlılığı | CD testi → CIPS birim kök | İkinci nesil panel testleri |
| Heterogeneity bias | PMG / MG tahmincisi | Pesaran, Shin & Smith (1999) |
| Çoklu doğrusallık | VIF < 10 kriteri | Variance Inflation Factor tablosu |
| Seri korelasyon | Arellano–Bond AR(2) | $p > 0.05$ koşulu |

---

## 8. Jevons Paradox Bağlantısı

> **Temel referans:** `Artificial_Intelligence_and_the_Jevons_Paradox.pdf`  
> **Konum:** `/Users/mehmetgokhanozdemir/Documents/Datamaclae26_ai_ecology/Literatür/`

**Tanım:** Enerji verimliliğindeki artışın enerji tüketimini azaltmak yerine artırmasına yol açan geri tepme (rebound) etkisi.

**Sembolik İfade:**

$$\eta_{\text{rebound}} = -\frac{\partial \ln E}{\partial \ln A} \cdot \frac{\partial \ln A}{\partial \ln s} > 1$$

Burada $E$ = enerji tüketimi, $A$ = AI/teknoloji benimseme oranı, $s$ = enerji verimliliği.

$\eta_{\text{rebound}} > 1$ koşulu **güçlü Jevons Paradoksu**'nu (backfire) temsil eder.


---

## 9. Sağlamlık Kontrolleri (Robustness Checks)

- [ ] Ekolojik ayak izi ($\text{EF}_{it}$) ile CO₂ yerine alternatif çevre değişkeni
- [ ] Kukla değişken eklenerek yapısal kırılma testi (Bai–Perron)
- [ ] Farklı gecikme kriterleri (AIC, BIC, HQIC) ile PMG yeniden tahmini
- [ ] Kıtasal alt örneklem (SSA vs. MENA vs. ASEAN) karşılaştırması
- [ ] Hausman testi: PMG vs. MG tutarlılık kıyaslaması

---

## 10. Zotero Linkleri

Bu nota ilişkin Zotero kütüphanesi kayıtları:

```
Zotero Library ID : 7714813
Abdi (2023)       : zotero://select/library/items/35Y74DTY
İnal et al. (2022): zotero://select/library/items/X8B5PM8J
```

> Tarayıcıda açmak için: `zotero://select/library/items/35Y74DTY`

---

## 11. APA 7th Referanslar

Abdi, A. H. (2023). Toward a sustainable development in sub-Saharan Africa: Do economic complexity and renewable energy improve environmental quality? *Environmental Science and Pollution Research*, *30*, 1–18. https://doi.org/10.1007/s11356-023-26364-z

İnal, V., Addi, H. M., Çakmak, E. E., Torusdağ, M., & Çalışkan, M. (2022). The nexus between renewable energy, CO₂ emissions, and economic growth: Empirical evidence from African oil-producing countries. *Energy Reports*, *8*, 1–15. https://doi.org/10.1016/j.egyr.2021.12.051

Dumitrescu, E.-I., & Hurlin, C. (2012). Testing for Granger non-causality in heterogeneous panels. *Economic Modelling*, *29*(4), 1450–1460. https://doi.org/10.1016/j.econmod.2012.02.014

Konya, L. (2006). Exports and growth: Granger causality analysis on OECD countries with a panel data approach. *Economic Modelling*, *23*(6), 978–992. https://doi.org/10.1016/j.econmod.2006.04.008

Pesaran, M. H., & Yamagata, T. (2008). Testing slope homogeneity in large panels. *Journal of Econometrics*, *142*(1), 50–93. https://doi.org/10.1016/j.jeconom.2007.05.010

Pesaran, M. H., Shin, Y., & Smith, R. P. (1999). Pooled mean group estimation of dynamic heterogeneous panels. *Journal of the American Statistical Association*, *94*(446), 621–634.

---

*Son güncelleme: 2026-03-29 — Claude (Anthropic) ile Zotero entegrasyonu*
