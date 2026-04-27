# Araştırma Durumu — 2026-CE-Cognitive-Econometrics
_Son güncelleme: 2026-04-08_

## Araştırma Başlığı
**"Cognitive Frictions and Circular Economy Transition: Micro–Macro Evidence from EU-27 Eurobarometer Panels"**

**Ortak Araştırmacılar:** Dr. M. Gökhan Özdemir (Kırıkkale Ü., baş-yazar), Esra Hoca, Suat Hoca  
**Hedef Dergi:** Resources, Conservation and Recycling (Q1, IF ≈ 13)  
**Yedek:** Journal of Cleaner Production; Ecological Economics; Journal of Environmental Management  
**Gönderim Hedefi:** 2026-09-01 | Kill Date: 2026-12-01

---

## Mevcut Aşama

- [x] 1. Konu Belirleme & Soru Formülasyonu ✓
- [x] 2. Literatür Taraması ✓ (`notes/literature.md`, ~15 kaynak)
- [x] 3. Veri Toplama (makro arm tamamlandı; mikro arm kısmen)
- [x] 4. Ekonometrik Model Tasarımı ✓ (`notes/data_design.md`, M1-M5 spesifikasyonları)
- [x] 5. Analiz — Makro Arm (M3+M4) ✅ TAMAMLANDI
- [ ] 5. Analiz — Mikro Arm (M1+M2) ← **BEKLEYEN**
- [x] 6. Taslak Yazımı — §1–§4.4 ✓ (kısmen [[XX]] placeholder var, §4.4 v3 sayıları eklendi)
- [ ] 6. Taslak Yazımı — §5 Discussion + §6 Conclusion [[XX]] doldurulacak
- [ ] 7. Revizyon & Gönderim

**Aktif aşama:** 6 — §5 Discussion + §6 Conclusion yazımı; M2 pseudo-panel GMM

---

## Gerçek Veri Durumu (2026-04-08 envanteri)

### Mevcut (indirilmiş):
| Dosya | Dalga | Yıl | Durum |
|---|---|---|---|
| `ZA7781_v2.dta` | EB 95.1 | 2021 | ✅ indirildi |
| `ZA7952_v1-0-0.dta` | EB (unknown) | ~2022 | ✅ indirildi |
| `ZA8779_v1-0-0.dta` | EB 99.3 | 2023 | ✅ indirildi |
| `ZA8842_v1-0-0.dta` | Special EB 535 | 2024 | ✅ indirildi |

**Not:** Planlanan ZA7782/ZA7886/ZA7942 yerine ZA7781/ZA7952/ZA8842 var — çok yakın versiyonlar; `01_build_CBI.R` değişken eşlemesi güncellenmeli.

### CBI:
- `CBI_country_year.csv`: N=27 ülke × 3 wave-yılı (2021, 2022, 2024), kısmen NA boyutlar var
- `macro_CBI_panel_full.csv`: CBI 2010-2024 yıllara interpole edilmiş → **ZAMAN-DEĞİŞMEZ sorun**

### Makro (Eurostat):
- `400-Data/raw/eurostat/`: cei_cie020, cei_pc030, cei_srm020, cei_srm030, cei_wm011, edat_lfse_03, nama_10_pc — **TÜMÜ İNDİRİLDİ**
- `macro_CBI_panel_full.csv`: N=27, T=15 (2010-2024)

---

## Pilot Sonuçları Özeti (CE_pilot_v3 — 2026-04-08 güncel)

### Ön Testler:
| Test | Sonuç |
|---|---|
| Pesaran CD (tüm değişkenler) | p=0 — güçlü çapraz kesit bağımlılığı ✓ |
| CIPS (ln_cmu, ln_prod) | Durağan (5% red); ln_gdp, ln_educ → I(1) |
| Westerlund Gt | −1.398, p=0.081 — marjinal eşbütünleşme (10%) ⚠ |

### M1 — Mikro TWFE (2026-04-08 YENİ):
| Model | CBI katsayı | SE | p | N |
|---|---|---|---|---|
| **LPM-TWFE (M1a)** | **−0.099** | 0.008 | **<0.001 ***| 19,843 |
| Logit-TWFE (M1b) | −0.763 | 0.031 | <0.001 *** | 19,843 |
| Equal-weight CBI (M1c) | −0.082 | 0.007 | <0.001 *** | 21,678 |
- **9.9 puan** azalma (1 SD CBI artışı) → **makalenin ana bireysel düzey katkısı**
- Female: +4.6pp, Older: +0.1pp/yıl, More educated: +0.2pp/yıl (hepsi p<0.05)
- PC1 varyans payı: %33.8; loadings: LA2=0.72, LA1=0.69, SQ=0.60, PB=0.54, BC=0.46, OP=−0.40
- Kaynak: `600-Results/CE_pilot/M1_twfe_pilot.csv` + `M1_summary_table.csv`

### M3 — CS-ARDL/CMG (makro arm):
- ln_prod: β̂=**+1.177**, p<0.001 ← **en güçlü bulgu**
- CBI_eq_interp: β̂=−0.119, p=0.33 (NS) ← zaman-değişmezlik sorunu
- MG: ln_prod=+0.875, p=0.002; CBI=−0.013, p=0.70
- **Sorun:** CBI makro panelde zaman içinde sabit → FE/MG tanımlayamıyor

### M4 — Dumitrescu-Hurlin (ANA BULGU):
| Yön | Wbar | Zbar | p |
|---|---|---|---|
| **CBI→CMU** | **4.119** | **11.46** | **<0.001** ✓✓✓ |
| CMU→CBI | 2.327 | 4.875 | <0.001 (çift yönlü) |
| ln_gdp→CMU | 7.68 | 14.76 | <0.001 |
| ln_prod→CMU | 4.58 | 6.70 | <0.001 |

→ **CBI Granger-causes CMU** = makalenin temel nedensellik katkısı ✓

### Between Estimator (cross-country kanal):
- CBI_pca_2021: β̂=+0.290, p=0.104 — sınırda anlamlı, yön tutarlı
- ln_prod: β̂=+0.980, p=0.011 ✓

### Webb Bootstrap (macro):
- ln_gdp_pc: p_webb=0.000 ✓; recycle_muni: p=0.969 (NS); patents: p=0.176 (NS)
- R²=0.69

---

## KRİTİK SORUN: CBI Tanımlama Stratejisi

CBI, makro panelde 3 dalga (2021/22/24) dışında **zaman-değişmez**. FE/MG içsel tanımlama yapamıyor. **Çözüm:**
1. **Birincil strateji:** DH nedensellik (zaman-içi varyasyon gerektirmiyor) → zaten var ✓
2. **İkincil strateji:** Between estimator (ülkeler-arası CBI varyasyonu) → p=0.104 ★
3. **Yeni yaklaşım:** Mikro arm (M1 TWFE bireysel düzey) → CBI bireysel varyansa sahip → asıl tanımlama buradan
4. **v0.2 planı:** 3-dalga kısa panel (N=27, T=3) ile CBI zaman varyasyonu — ZA7782/ZA7886/ZA8779 wave-yıllarını birleştir

---

## Sıradaki Adımlar (Öncelik Sırasıyla)

1. [ ] **`01_build_CBI.R` pilot koşumu** — ZA7781/ZA7952/ZA8779/ZA8842 üzerinde değişken eşlemesini güncelle; mikro CE_Action binary değişkeni oluştur. Beklenen çıktı: `400-Data/processed/micro_CBI_clean.rds`
2. [ ] **`02_micro_TWFE.R` koşumu** — M1: bireysel TWFE (N≈106k); CBI katsayısını doldur; §4.1-§4.2 [[XX]] dolduruluyor
3. [ ] **Webb bootstrap (fwildclusterboot, G=27)** — M3 CS-ARDL için v0.2'ye ekle (CLAUDE.md zorunluluğu)
4. [ ] **§5 Discussion + §6 Conclusion** — Mevcut [[XX]] yertutuculları v3 sayıları ile doldur; CBI tanımlama limitasyonu §7'ye ekle
5. [ ] **Westerlund çoklu test** — Gt (−1.398, p=0.081) zayıf; Pedroni veya Gt + Ga birlikte raporla
6. [ ] **Zotero references.bib** tamamla — `sources/references.bib` var ama eksik kaynaklar var

---

## Açık Sorular & Bekleyen Kararlar

- CBI tanımlama: between-only mı, yoksa micro TWFE mi ana spec?
- Westerlund marjinal (p=0.081): Ga istatistiğini de raporla; Pedroni cross-check
- ZA numaraları mismatch (ZA7781 ≠ ZA7782): `01_build_CBI.R`'daki değişken isimleri gerçek .dta dosyalarıyla eşleşiyor mu?
- §5 Discussion: CBI bidirectionality (CMU→CBI de anlamlı) nasıl yorumlanır?

---

## Dosya Haritası

| Dosya | Durum |
|---|---|
| `04-Manuscript/00_main.tex` | ✅ derlenebilir; natbib+apalike |
| `04-Manuscript/sections/01_introduction.tex` | ✅ |
| `04-Manuscript/sections/02_literature.tex` | ✅ |
| `04-Manuscript/sections/03_methods.tex` | ✅ M1-M5 spesifikasyonları |
| `04-Manuscript/sections/04_results.tex` | ✅ §4.3+§4.4 gerçek sayılarla (v3); §4.1-§4.2 [[XX]] bekliyor |
| `04-Manuscript/sections/05_discussion.tex` | ⚠ [[XX]] yertutucullar |
| `04-Manuscript/sections/06_conclusion.tex` | ⚠ [[XX]] yertutucullar |
| `04-Manuscript/code/01_build_CBI.R` | ⚠ ZA numarası güncellenmeli |
| `04-Manuscript/code/02_micro_TWFE.R` | ⚠ koşturulmadı |
| `04-Manuscript/code/03_macro_CSARDL.R` | ✅ v3 çalıştırıldı |
| `04-Manuscript/code/04_pseudo_panel_GMM.R` | ⚠ koşturulmadı |
| `04-Manuscript/code/05_bartik_diagnostics.R` | ⚠ koşturulmadı |
| `600-Results/CE_pilot_v3/` | ✅ CD/CIPS/MG/CMG/PMG/DH/Westerlund/Between |
| `sources/references.bib` | ⚠ eksik kaynaklar var |
