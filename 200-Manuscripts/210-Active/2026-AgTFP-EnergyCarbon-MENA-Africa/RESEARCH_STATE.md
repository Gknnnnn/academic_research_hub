# Araştırma Durumu
_Son güncelleme: 2026-04-10 (v0.3 — panel diagnostics + CS-ARDL pipeline complete)_

## Araştırma Başlığı
**"Agricultural TFP, Energy Efficiency, and Yield Dynamics Across Climate-Vulnerable and Frontier Economies: A Two-Stage DEA–Panel Analysis"**

Çalışma adı: **AgTFP-EnergyCarbon-MENA-Africa**

## Yazarlar
1. Dr. Mehmet Gökhan Özdemir (KKÜ) — Corresponding, Econometrics & DEA Lead
2. Prof. Dr. Hacı Bayram Işık (KKÜ) — Agricultural policy, TR context
⚠️ Okasha 2026-04-10 itibarıyla projeden çekildi. Mektup arşivlendi: `drafts/_archive/`

## Mevcut Aşama
- [x] 1. Konu Belirleme & Soru Formülasyonu
- [x] 2. Literatür Taraması & Research Gap (notes/research_gap_and_model.md)
- [x] 3. Veri Toplama & Temizleme — N=22, T=2000–2020, 462 obs, sıfır eksik değer
- [~] 4. Analiz (DEA + Panel Ekonometri) — DEVAM EDİYOR
- [ ] 5. Taslak Yazımı
- [ ] 6. Revizyon & Düzeltme
- [ ] 7. Son Kontrol & Gönderim

**Aktif aşama:** 4. Analiz

## Araştırma Sorusu
Küresel tarımsal verimlilik sınırı (Hollanda–İsrail–Danimarka) ile iklim kırılganlığı
en yüksek ekonomiler (MENA–SSA) arasındaki uçurum: AgTFP büyümesi enerji
yoğunluğunu ve karbon salımını azaltıyor mu? DEA-bazlı verimlilik skoru bu ilişkiye
aracılık ediyor mu?

## Örneklem Tasarımı (Gerçekleşen)

### Frontier Grubu (5): NLD, ISR, DNK, NZL, AUS
### MENA Grubu (7): TUR, EGY, MAR, TUN, JOR, SAU, PAK
### SSA Grubu (10): ETH, TZA, UGA, MOZ, ZWE, NER, SEN, ZMB, MDG, MWI

**N=22 | T=2000–2020 (21 yıl) | obs=462 | sıfır eksik değer**
Webb wild cluster bootstrap zorunlu (N=22 < 30)

## Veri Kaynakları
| Değişken | Kaynak | URL |
|---|---|---|
| AgTFP | USDA ERS | https://www.ers.usda.gov/data-products/international-agricultural-productivity/ |
| Agr. GHG emissions | FAOSTAT | https://www.fao.org/faostat/en/#data/GT |
| Agr. energy use | IEA / World Bank | WB: EN.ATM... / IEA |
| Mechanization (tractor/ha) | FAOSTAT | https://www.fao.org/faostat/en/#data/RM |
| GDP per capita | World Bank WDI | NY.GDP.PCAP.KD |
| Trade openness | World Bank WDI | NE.TRD.GNFS.ZS |
| Climate vulnerability | ND-GAIN | https://gain.nd.edu/our-work/country-index/ |
| Renewable energy share | World Bank WDI | EG.ELC.RNEW.ZS |

## Ekonometrik Yol Haritası

| Adım | Yöntem | Durum | Script | Sonuç |
|------|--------|-------|--------|-------|
| 1 | DEA VRS input-oriented | ✅ | `02_data_collection_optimized.py` | NLD=0.720, ISR=1.000, TUR=0.701, MAR=0.665 |
| 2 | Simar-Wilson (2007) double-bootstrap | ✅ (B1=25, prelim) | `03_simar_wilson.py` | SW bias-corr: NLD=0.7395, TUR=0.7222, MAR=0.6787 |
| 3 | Pesaran (2004) CD | ✅ | `04_panel_diagnostics.py` | ln_emek CD=41.96***, ln_verim CD=17.95*** — CD zorunlu |
| 4 | Pesaran-Yamagata (2008) Δ̃ | ✅ | `04_panel_diagnostics.py` | Δ̃=25.42***, Δ̃_adj=26.88*** → Heterojen eğim → CS-ARDL |
| 5 | CIPS unit root | ✅ | `04_panel_diagnostics.py` | Düzeyde I(1), Δ'da I(0) → ARDL uygun |
| 6 | Westerlund (2007) | ✅ obs. | `04_panel_diagnostics.py` | Gt=−2.08, Ga=−16.17, Pt=−6.84, Pa=−10.17 (bootstrap: yerel çalıştır) |
| 7 | CS-ARDL / PMG-ECM | ⬜ hazır | `05_cs_ardl.py` | Webb B=999 ile yerel çalıştır |
| 8 | Dumitrescu-Hurlin | ✅ | `06_dh_causality.py` | dea_bc→ln_verim p_boot=0.0020***; ln_gubre→ln_verim p_boot=0.0120**; ln_verim→ln_gubre p_boot=0.0421** |
| 9 | AMG + CCEMG sağlamlık | ✅ | `07_robustness.py` | CCEMG M1: ln_ticaret β=0.2936**; dea_bc β=−0.869 (NS); AMG M1: dea_bc β=+0.466 (NS) — sign yönü CS-ARDL ile doğrulanacak |
| 10 | Bai-Perron kırılmalar | ✅ | `08_structural_breaks.py` | 21/22 ülke m≥1 kırılma; CUSUM 22/22 aşım; ZA: 4/22 trend-durağan kırılmalı |

**SW tam çalıştırma:** `python3 code/03_simar_wilson.py` (B1=300, B2=200 — ~3 dak)
**CS-ARDL:** `python3 code/05_cs_ardl.py` (B_WEBB=999 — yerel çalıştır)
**Westerlund bootstrap:** `python3 code/04_panel_diagnostics.py` (B=499)

## Son Oturumda Yapılanlar (2026-04-10 — Oturum 2)
- Tüm ekonometrik pipeline scriptleri tamamlandı ve çalıştırıldı (06–08)
- Dumitrescu-Hurlin: `06_dh_causality.py` — K=2, B=499
  - dea_bc→ln_verim p_boot=0.0020*** (tek yönlü nedensellik ✓)
  - ln_gubre→ln_verim p_boot=0.0120** + ln_verim→ln_gubre p_boot=0.0421** (çift yönlü)
  - Toda-Yamamoto MG tüm çiftler NS → DH bootstrap birincil çıktı
- CCEMG & AMG: `07_robustness.py`
  - CCEMG M1: ln_ticaret β=0.2936** [Webb: 0.063, 0.530]; dea_bc β=−0.869 (NS)
  - CCEMG M2: ln_ticaret β=0.2705**, ln_ekipman β=0.3987* [Webb: 0.060, 0.737]
  - AMG M1: dea_bc β=+0.466 (NS, Webb içeriyor sıfır) — CCEMG ile ters işaret → dikkat notu
  - TWFE M1 (referans): ln_gubre β=0.0825**, ln_ticaret β=0.057 (NS)
- Yapısal kırılmalar: `08_structural_breaks.py`
  - Bai-Perron: 21/22 ülke ≥1 kırılma (BIC); MDG supF=202.6; SAU/JOR/ZMB yüksek
  - CUSUM: 22/22 ülke %5 bandı aşıyor → evrensel yapısal istikrarsızlık
  - ZA (ln_verim): 4/22 trend-durağan kırılmalı (ETH***, NER*, SEN*, TZA***)
  - ZA (ln_gubre): 10/22 trend-durağan (AUS***, DNK**, ETH**, TUR*** öne çıkıyor)

## Sıradaki Adımlar (Öncelik Sırasıyla)
1. [ ] **Yerel:** `python3 code/03_simar_wilson.py` (B1=300, B2=200) — tam SW sonuçları
2. [ ] **Yerel:** `python3 code/04_panel_diagnostics.py` (Westerlund bootstrap B=499)
3. [ ] **Yerel:** `python3 code/05_cs_ardl.py` (CS-ARDL + Webb B=999) — uzun dönem
4. [ ] USDA AgTFP gerçek indeksi indir (ERS InternationalTFPData.xlsx)
5. [ ] FAOSTAT GT tarımsal GHG indir → ek bağımlı değişken
6. [ ] ND-GAIN iklim kırılganlık indeksi → heterojenlik analizi
7. [ ] Makale taslağı: §1 Giriş + §2 Literatür + §3 Veri

## Hedef Dergiler
1. Global Food Security (IF≈9.5, Q1 SSCI)
2. Journal of Cleaner Production (IF≈9.8, Q1 SSCI)
3. Agricultural Systems (IF≈6.1, Q1 SSCI)
4. World Development (IF≈6.5, Q1 SSCI)

## Açık Sorular
- IEA tarımsal enerji verisi ülke kapsamı yeterli mi (özellikle SSA)?
- FAOSTAT GT emisyon serisi 2020 sonrası güncel mi?
- Simar-Wilson bootstrap R kütüphanesi: `Benchmarking` paketi yeterli mi?
- Işık'ın CRediT katkı tanımını netleştir

## Dosya Haritası
- `notes/literature.md` → Literat tarama notları (doldurulacak)
- `notes/analysis.md` → Analiz bulguları (doldurulacak)
- `data/` → Ham ve işlenmiş veri dosyaları
- `code/` → Python/R analiz kodları
- `output/` → Tablolar ve şekiller
- `sources/references.bib` → BibTeX referanslar
