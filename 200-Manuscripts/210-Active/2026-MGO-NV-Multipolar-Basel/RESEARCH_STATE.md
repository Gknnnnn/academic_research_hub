# Araştırma Durumu
_Son güncelleme: 2026-04-12_

## Araştırma Başlığı
"Geopolitical Risk, Economic Complexity, and Environmental Sustainability in a Multipolar World: Evidence from BRICS-T+MINT Economies"

## Yazarlar
- M. Gökhan Özdemir (corresponding) — Kırıkkale University
- Nimet Varlık — Kırıkkale University

## Mevcut Aşama
- [x] 1. Konu Belirleme & Soru Formülasyonu
- [x] 2. Literatür Taraması
- [x] 3. Materyal / Veri Toplama
- [x] 4. Analiz
- [x] 5. Taslak Yazımı
- [ ] 6. Revizyon & Düzeltme
- [ ] 7. Son Kontrol & Gönderim

**Aktif aşama:** 5 (Taslak yazımı — v0.1 tamamlandı, v0.2+ revizyon)

## Proje Özeti
2022 sonrası jeopolitik şokun BRICS-T+MINT ekonomileri (N=9) üzerinde ekonomik karmaşıklık (ECI), ekolojik ayakizi (EF) ve döviz rezerv bileşimi ile bağlantısını incelemektedir. Panel analizi (1995–2024) ve VAR (1999Q1–2025Q4) kullanarak, jeopolitik risk ile EF arasında statüsü bölüm-spesifik olduğunu; Rusya'da Bai-Perron structural break 2020'de (SWIFT öncesi); ve GPR → reserve dynamics Granger nedenselliğinin post-2016 SDR dönemiyle ortaya çıktığını göstermektedir.

## Yöntem
- **Panel:** TWFE, DiD, Bai-Perron structural break testleri
- **Zaman serisi:** VAR + Webb wild cluster bootstrap (G=9 clusters, zorunlu)
- **Cointegration:** Pesaran CD, CCEMG, Westerlund testleri (sonraki turda)
- **Temel bulgular:**
  - GPR–EF: β=0.020 (full period, p=0.570) → β=0.098 (post-2019, p<0.001, Webb p=0.006)
  - Russia ECI: −0.368 unit collapse 2022 post (DiD p<0.01)
  - Russia USD share: −32.6 pp 2018 sonrası; SWIFT öncesi de-risking

## Dosya Haritası
- `multipolar_basel_v0.1.qmd` — Çekirdek taslak (150 sayfa)
- `output/multipolar_basel_v0.2.docx` — Revize edilmiş DOCX
- `output/multipolar_basel_v0.6.docx` — En son versiyon (eksik bölümler)
- `nimet_briefing.qmd` — Nimet için summary briefing

## Sıradaki Adımlar
1. **§4 Results tamamla:** Yıllık GPR × EF interaction terms; COFER VAR full results
2. **Bai-Perron diagnostics:** Ülke-spesifik break tarihleri; confidence intervals
3. **Discussion yeniden yaz:** Basel III/IV implikasyonları; geopolitical omitted variable
4. **Robustness:** CCEMG (CD-robust), Westerlund cointegration, threshold panel
5. **Cover letter hazırla:** Innovation → "geopolitical fragmentation as emergent OVB in EKC"

## Ana Bulgular
| Bulgu | Değer | Perde / Not |
|-------|-------|------------|
| GPR–EF (full) | β=0.020, p=0.570 | Anlamsız; CD kurulu mı? |
| GPR–EF (post-2019) | β=0.098, p<0.001 | Anlamlı; Webb p=0.006 |
| Russia ECI (2022) | −0.368 unit | DiD p<0.01; CAATSA öncesi start |
| Russia EF (2022) | +26.0% artış | Post-SWIFT |
| Russia USD reserve | −32.6 pp (2018 sonrası) | CAATSA yanıtı; SWIFT öncesi |
| GPR → reserve (post-2016) | F(2,96)=6.540, p=0.002 | Granger causality |

## Veri & Metodoloji Notları
- **Panel:** N=9 BRICS-T+MINT, T=30 (1995–2024)
- **Quarterly VAR:** 108 obs (1999Q1–2025Q4)
- **GPR kaynağı:** Caldara & Iacoviello (2022) EPU
- **ECI:** ECI index (Atlas of Complexity)
- **EF:** Global Footprint Network
- **COFER:** IMF Currency Composition of Foreign Exchange Reserves

---
**Hedef dergi:** Energy Economics, Ecological Economics (Q1)  
**Tahmini gönderim:** 2026 Ağustos  
**Hazırlık seviyesi:** 65%  
**Kritik açık:** CD/CIPS/Westerlund pre-tests gerekli
