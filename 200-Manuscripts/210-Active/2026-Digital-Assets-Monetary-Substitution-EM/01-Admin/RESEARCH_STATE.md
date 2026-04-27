# Araştırma Durumu
_Son güncelleme: 2026-04-11 — Bib denetimi + citation key düzeltme oturumu_

## Araştırma Başlığı
Macro Fragility, Digital Assets, and Monetary Substitution in Emerging Markets: A Multi-Estimator Panel Approach

## Yazarlar
- Onur Bilgin
- Zaim Reha Yaşar
- Mehmet Gökhan Özdemir (corresponding, mgozdemirera@kku.edu.tr)

## Hedef Dergi
**Emerging Markets Review** (Elsevier, Q1 SSCI, IF 4.6)

## Mevcut Aşama
- [x] 1. Konu Belirleme & Soru Formülasyonu
- [x] 2. Literatür Taraması
- [x] 3. Materyal / Veri Toplama
- [x] 4. Analiz (v1–v8 tamamlandı)
- [x] 5. Taslak Yazımı ✅ (EMR_Manuscript_v1.qmd — v4–v8 sonuçlarıyla)
- [ ] 6. Revizyon & Düzeltme ← **AKTİF** (lokal render + pre-submission audit kaldı)
- [ ] 7. Son Kontrol & Gönderim

**Aktif aşama:** 6 — Revizyon & Düzeltme (render + audit)

## Son Oturumda Yapılanlar (2026-04-11, Oturum 2)
- **Bib denetimi tamamlandı:**
  - 6 eksik methodological entry eklendi: westerlund2007, pesaran_shin_smith1999, bonhomme_manresa2015, eberhardt_bond2009, ilzetzki_reinhart_rogoff2019, calvo_reinhart2002
  - 3 kullanılmayan entry kaldırıldı: driscoll_kraay1998, chinn_ito2008, staiger_stock1997
  - ~20 in-text plain-text citation → proper @key dönüştürüldü
  - DOI doğrulaması CrossRef üzerinden yapıldı (23 entry)
- **Humanization pass** (önceki oturum): ~12 AI-telltale pattern düzeltildi
- **Cover letter** güncellendi: tarih, unvan, katkılar
- **CSL** Harvard (Cite Them Right) indirildi
- Auer et al. (2023) CBDC referansı lit review'a eklendi
- Chainalysis (2024) formal citation §4.1'e eklendi
- Sandbox kilitli → DOCX render lokal yapılmalı

## Önceki Oturum (2026-04-11, Oturum 1)
- Proje `_ARCHIVE_300-Projects` → `200-Manuscripts/210-Active/` taşındı
- EMR dergi gereksinimleri araştırıldı (Harvard ref, ≤250w abstract, EVISE, $150 submission fee)
- `submission_strategy.md` EMR hedefine güncellendi
- `EMR_Manuscript_v1.qmd` oluşturuldu (v4–v8 tüm sonuçlarla)
- Bu `RESEARCH_STATE.md` oluşturuldu

## Sıradaki Adımlar (Öncelik Sırasıyla)
1. [x] ~~Manuskripti v4–v8 sonuçlarıyla yeniden yaz~~ ✅
2. [x] ~~Abstract ≤250 kelime, EMR formatına uyarla~~ ✅ (248 kelime)
3. [x] ~~Referansları Harvard stiline dönüştür~~ ✅ (CSL + tüm @key'ler düzeltildi)
4. [x] ~~Cover letter yaz (EMR editörüne)~~ ✅
5. [x] ~~Humanization pass + AI detection mitigation~~ ✅
6. [x] ~~Bib denetimi (unused/missing/DOI)~~ ✅
7. [ ] **DOCX render** — `quarto render EMR_Manuscript_v1.qmd --to docx` (LOKAL)
8. [ ] **Pre-submission audit** — `python3 600-Methods/pre_submission_audit.py EMR_Manuscript_v1.docx`
9. [ ] **Ortak yazarlara gönder** (Bilgin, Yaşar onayı)
10. [ ] **EVISE gönderim** ($150 submission fee)

## Açık Sorular & Bekleyen Kararlar
- **Başlık güncellenmeli mi?** Mevcut: "...Quantile Panel Approach with a Proxy Evaluation" → v8 sonuçlarıyla narratif değişti: crypto_premium anlamlı çıktı, Google Trends hâlâ NS
- **Submission fee ($150) onayı** — Bilgin/Yaşar ile paylaşım kararı
- **OA vs subscription** — APC $3,320 vs subscription (APC 0)
- **Chainalysis GCAI verileri** — MX/NG 2020-22 hâlâ doğrulanmamış

## Anahtar Bulgular (Özet)
1. **Üçlü replikasyon:** CCEMG (+0.30), AMG (+0.32), MG-ARDL (+0.32) — inflation pass-through üç bağımsız estimator ile yakınsıyor
2. **Westerlund koentegrasyon:** G_t p=0.029, P_t p<0.0001 — log FX ~ cumulated CPI uzun dönem ilişki teyit
3. **MG-ARDL:** θ̂=+0.322 (MG consistent, Hausman rejects PMG). AR/NG high pass-through (~1.0), BR/IN/MX/ZA low (~0.005)
4. **DH nedensellik:** Çift yönlü, FX→inflation bir büyüklük mertebesi daha güçlü
5. **Bai-Perron kırılmalar:** AR 3 kırılma (2018-09 IMF, 2022-07 Fed, 2024-01 Milei), NG 2016-05 CBN
6. **Crypto_premium:** Webb bootstrap p=0.045** — anlamlı; Google Trends hâlâ NS
7. **Webb bootstrap:** M_base inflation p=0.000***, broad_money_instability p=0.000***

## Önemli Kaynaklar
- Calvo & Reinhart (2002) — Fear of Floating, temel çerçeve
- Ilzetzki, Reinhart & Rogoff (2019) — FX regime classification
- Pesaran (2006) — CCEMG
- Eberhardt & Bond (2009) — AMG
- Westerlund (2007) — Panel cointegration
- Webb (2023) — Wild cluster bootstrap for small N

## Dosya Haritası
- `04-Manuscript/EMR_Manuscript_v1.qmd` → **ANA TASLAK** (6-ülke, 8 estimator, tüm v4–v8 sonuçlarıyla) ✅
- `04-Manuscript/references.bib` → Referanslar (35 entry, denetlenmiş, DOI doğrulanmış) ✅
- `04-Manuscript/emerging-markets-review.csl` → Harvard (Cite Them Right) CSL ✅
- `04-Manuscript/cover_letter_EMR.md` → Cover letter (EMR editörüne) ✅
- `04-Manuscript/Digital_Assets_Monetary_Substitution_EM_Draft.qmd` → ESKİ taslak (4-ülke, ARŞİV)
- `03-Results/paper6_v6_master.md` → v4–v6 konsolide rapor (8 estimator)
- `03-Results/paper6_v8_webb_bootstrap.md` → Webb bootstrap sonuçları
- `03-Results/paper6_v7_chainalysis.md` → Chainalysis GCAI entegrasyonu
- `01-Admin/submission_strategy.md` → EMR hedefi (güncel)
- `01-Admin/JOURNAL_TARGETS.md` → Dergi hedef matrisi
- `01-Admin/RESEARCH_STATE.md` → Bu dosya
