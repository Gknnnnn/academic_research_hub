# Araştırma Durumu
_Son güncelleme: 2026-04-12_

## Araştırma Başlığı
Circular Economy and Cognitive Barriers to Adoption: A Multilevel Panel Econometric Study of EU-27

## Yazarlar
Arş. Gör. Dr. Mehmet Gökhan Özdemir (solo/primary)

## Mevcut Aşama
- [x] 1. Konu Belirleme & Soru Formülasyonu
- [x] 2. Literatür Taraması
- [x] 3. Materyal / Veri Toplama (GESIS ZA7782/ZA7886/ZA8779/ZA7942 indirilmesi bekleniyor)
- [ ] 4. Analiz (Pilot CS-ARDL makro arm tamamlandı, mikro TWFE/pseudo-panel GMM bekleniyor)
- [x] 5. Taslak Yazımı (§1–3 + metodoloji çerçevesi ✓)
- [ ] 6. Revizyon & Düzeltme
- [ ] 7. Son Kontrol & Gönderim

**Aktif aşama:** 4 (Analiz — Makro arm §4.3+§4.4 gerçek sayılarla tamamlandı; Mikro M1/M2 GESIS bekleniyor)

## Proje Özeti
Eurobarometer mikro veri (bilişsel faktörler, dairesel ekonomi hazırlığı) ve Eurostat makro veri (teknoloji, yatırım, çevre göstergeleri) birleştiren EU-27 üzerinde multilevel panel. Araştırma boşluğu: SEM/mikro ile makro panel ekonometri arasındaki köprü eksikliği. Beş model: M1 TWFE (LPM), M2 Sistem-GMM pseudo-panel, M3 CS-ARDL, M4 Dumitrescu-Hurlin, M5 Bartik IV.

## Yöntem
- Veri: Eurobarometer ZA7782/7886/8779/7942 (mikro, ağırlıklı) + Eurostat (makro)
- CBI Endeksi: 5-boyutlu PCA, 10 soru, cronbach-α, KMO, srvyr ağırlıklı agregasyon
- M1: TWFE LPM/Logit + kohort sabit etkileri + Bartik IV
- M2: plm::pgmm Sistem-GMM + Hansen J + AR(1)/AR(2)
- M3: CS-ARDL PMG/MG + Pesaran CD + CIPS + Westerlund kointegrasyon
- M4: Dumitrescu-Hurlin bootstrap nedensellik
- M5: Bartik shift-share IV (doğrudan teknoloji transfer mekanizması)
- Robustluk: Webb wild cluster bootstrap (n=27 < 30)

## Dosya Haritası
- `/04-Manuscript/00_main.tex` — Derlenebilir master (JEL: D91, Q53, Q56, C23, C26)
- `/04-Manuscript/sections/01-06/` — Giriş, Literatür, Metodoloji, Sonuçlar, Tartışma, Sonuç
- `/04-Manuscript/data/CBI_codebook.xlsx` — 6 sheet (PCA formülü, veri haritası)
- `/04-Manuscript/code/01_build_CBI.R` — Endeks oluşturma
- `/04-Manuscript/code/02_micro_TWFE.R` — M1 TWFE
- `/04-Manuscript/code/03_macro_CSARDL.R` — M3/M4 CS-ARDL + DH
- `/04-Manuscript/code/04_pseudo_panel_GMM.R` — M2 Sistem-GMM
- `/sources/references.bib` — 31 Zotero girdi
- `/01-Admin/RESEARCH_STATE.md` — Güncellendi (Oturum 2)

## Sıradaki Adımlar
1. GESIS hesabı açılış ve ZA7782/ZA7886/ZA8779/ZA7942 indirme (Oturum 3)
2. 01_build_CBI.R pilot koşturma ve PCA ağırlıkları raporlama
3. Makro veri (Eurostat) tam pull — 03_macro_CSARDL.R pilot
4. M1/M2 micro-panel tahminleri (Oturum 4)
5. Sonuçlar tabloları ve şekiller (Oturum 5)
6. Tüm modellerin convergence kontrol ve robustluk testi

## Notlar
Araştırma boşluğu doğrulanmış: bilişsel faktörler ile makro panel ekonometri köprüsü literaturda eksik. Yalnızca SEM veya yalnızca makro panel çalışmaları mevcut. Bu durum özgünlüğü güçlendiriyor. Hedef: Q1 çevre/enerji/ekonomi dergisi (2026-H2).
