# Araştırma Durumu
_Son güncelleme: 2026-04-12_

## Araştırma Başlığı
Hard Currencies, Emerging FX Stress, and Gold: Sub-Bloc Hierarchy and State-Dependent Safe-Haven Transmission

## Yazarlar
1. Nimet Varlık
2. Uğur Yıldırım
3. Mehmet Gokhan Ozdemir

## Mevcut Aşama
- [x] 1. Konu Belirleme & Soru Formülasyonu
- [x] 2. Literatür Taraması
- [x] 3. Materyal / Veri Toplama
- [x] 4. Analiz (pilot specifications)
- [x] 5. Taslak Yazımı (erken versiyonu)
- [ ] 6. Revizyon & Düzeltme
- [ ] 7. Son Kontrol & Gönderim

**Aktif aşama:** 5 (Taslak Yazımı — Metodoloji ve sonuçlar bölümü geliştirilmesi)

## Proje Özeti
Altın getirilerinin yönlendirilmesinde reserve-currency dinamikleri vs. emerging-market FX stress'in nispi önemini karşılaştıran çalışma. Temel soru: altın öncelikle hard-currency sistemi içinde ayarlamalarla mı, yoksa emerging-market bölgesindeki kırılganlıkla mı yönlendirilir? Bulgular: hard-currency specs ölçek metriklerinde daha iyi; EM stress selectivity (INR, ZAR signals) beraber modelde weak-out. Buluş: altın hem reserve-currency hierarchy hem EM-transmission bağlamında çalışır ama autonomous değil — conditional bağlantı.

## Yöntem
- Block-based Regression: hard currencies (USD, JPY, CHF, GBP) ayrı blok; EM FX stress (INR, MXN, ZAR, TRY, BRL) ayrı blok
- Günlük OLS/IV: altın getirilerine karşı (1) hard-currency block, (2) EM stress block, (3) combined specification
- Error metrics: RMSE, MAE (ölçek) + Directional accuracy (sıfa)
- Safe-haven indicator: DXY, Japanese Yen strength, Swiss Franc appreciations

## Dosya Haritası
- `/04-Manuscript/Hard_vs_EM_Currency_Stress_Gold_Draft.qmd` — Ana QMD
- `/04-Manuscript/references.bib` — Referanslar
- Abstract: reserve-currency vs. EM transmission dichotomy

## Sıradaki Adımlar
1. Block comparison metodoloji section final redaksyon
2. Tüm üç specification (hard-curr only, EM-stress only, combined) sonuçlar tabloları
3. Hedef dergi: Journal of International Money and Finance (Q1) veya International Review of Financial Analysis (Q1)
4. Cover letter hazırlama
5. Gönderim (2026-05 hedefi)

## Notlar
Şu ana dek altın çoğunlukla dolar-only prism'dan incelenmişti. Bu çalışma hard-currency hierarchy ve EM stress transmission ayrı kanallar olarak gösterir — bunlar interchangeable proxies değil. INR, ZAR selective channels EM-only spesifikasyonda material ama combined modellemede fade out.
