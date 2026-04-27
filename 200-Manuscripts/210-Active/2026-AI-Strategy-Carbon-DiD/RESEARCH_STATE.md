# Araştırma Durumu
_Son güncelleme: 2026-04-12_

## Araştırma Başlığı
National AI Strategy Adoption and Carbon Emissions: Evidence from a Staggered Difference-in-Differences Design

## Yazarlar
Arş. Gör. Dr. Mehmet Gökhan Özdemir (solo)

## Mevcut Aşama
- [x] 1. Konu Belirleme & Soru Formülasyonu
- [x] 2. Literatür Taraması
- [x] 3. Materyal / Veri Toplama
- [x] 4. Analiz
- [x] 5. Taslak Yazımı
- [x] 6. Revizyon & Düzeltme (v0.2 tamamlandı)
- [ ] 7. Son Kontrol & Gönderim

**Aktif aşama:** 6 (Revizyon — v0.2 PDF render temiz, v0.3 hazırlanıyor)

## Proje Özeti
40 ülkenin 2017–2021 arası Ulusal AI Stratejisi (NAIS) benimseyişini tedavi olarak kullanan staggered DiD çalışması. CO2 emit ve yenilenebilir enerji üzerindeki marjinal etkisini tahmin eder. Goodman-Bacon ayrıştırması COVID-19 dönem yanlılığını tanımlamıştır.

## Yöntem
- Difference-in-Differences: TWFE, Callaway-Sant'Anna CS-ATT
- Event Study: e=−2 to +4 relative time parameterization
- Goodman-Bacon Decomposition: treated-untreated vs. early-late weights
- Veri: OECD AI Policy Observatory + OWID (2005–2023, N=125, T=19)

## Dosya Haritası
- `/04-Manuscript/AI_Strategy_Carbon_DiD_v02.pdf` — Render (12 sayfa, temiz)
- `/04-Manuscript/00_main.tex` + `sections/00-06/` — LaTeX ana dosyası
- `/500-Code/run_final.R`, `02_analysis.R`, `03_figures.R` — Replicatable scripts
- `/400-Data/processed/ai_strategy_panel.csv` — Temizlemiş veri
- `/600-Results/main_results.rds`, `Table1_main.tex` — Sonuçlar

## Sıradaki Adımlar
1. v0.3: Not-yet-treated kontrolü, küçük kohort hariç tutma robustlığı
2. Heterogenite: Erken (2017-18) vs. geç (2020-21) benimseme
3. Cover letter: Energy Economics / JEEM
4. Gönderim hazırlığı (Mayıs 2026)
