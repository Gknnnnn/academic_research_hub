# Araştırma Durumu
_Son güncelleme: 2026-04-12_

## Araştırma Başlığı
"Exchange Rate Institutions and Growth: Institutional Quality Moderation in Emerging Markets"

## Yazarlar
- Uğur Yıldırım + M. Gökhan Özdemir

## Mevcut Aşama
- [x] 1. Konu Belirleme & Soru Formülasyonu
- [x] 2. Literatür Taraması
- [x] 3. Materyal / Veri Toplama
- [x] 4. Analiz
- [x] 5. Taslak Yazımı
- [x] 6. Revizyon & Düzeltme
- [ ] 7. Son Kontrol & Gönderim

**Aktif aşama:** 6 (Çok tur revizyon tamamlandı — v10 KRİTİK düzeltmeler tamamlı; MAKÜ şablon + DergiPark awaiting)

## Proje Özeti
Kur yanlış hizalamasının ekonomik büyüme üzerindeki etkisini kurumsal kalite tarafından moderatörlenmiş panel modelleriyle incelemektedir. N=11 ülke, T=1990–2023. Bulgular: temel katsayı olumsuz (döviz oynaklığı büyümeyi azaltıyor), kurumsal kalite (World Bank CPIA) bu etkiyi hafifletiyor. Dual-track: Türkçe versiyonu MAKÜ Sosyal Bilimler Enstitüsü Dergisi (ÖNCELİKLİ); İngilizce genişlemesi Economic Modelling (Q1).

## Yöntem
- **Panel estimators:** TWFE, RE, GMM (System-GMM Blundell-Bond)
- **Interaction:** FX volatility × Institutional quality (CPIA)
- **Robustness:** Webb wild cluster bootstrap (N<30), quantile regression
- **Temel bulgular:** Temel FX volatility β ≈ −0.15 to −0.20; kurumsal kalite × FX β ≈ +0.05 to +0.08

## Dosya Haritası
- `PROGRESS_COOKBOOK.md` — Detaylı revizyon geçmişi (v09-TR 2026-04-10)
- `_Documents-Archive/UY_MGO_Makale.qmd` — Önceki taslak (v09 temel)
- `_Documents-Archive/test_render.qmd` — Render test
- `04-Manuscript/` — Şu anda aktif (DOCX ve QMD)

## Sıradaki Adımlar (v10+ Roadmap)
1. **MAKÜ şablon uyumluluğu:** Başlık sayfa, başlık-yazar bloğu, öz-keywords Türkçe format
2. **DergiPark hazırlığı:** XML metadata, supplementary materials folder yapısı
3. **Şekil 3 Türkçeleştirme:** Eklenmiş opsiyonel şekil (legend, labels)
4. **Son p-değeri kontrol:** Tablo 7–8 GMM tüm istatistikler doğru mu?
5. **Gönderim:** DergiPark → MAKÜ Sosyal Bilimler Enstitüsü Dergisi

## Ana Revizyon Özeti (v09 → v10)
| No | Kategorisi | Değişiklik | Durum |
|----|-----------|-----------|-------|
| 1 | Tablo numarası | 1a/1b → 1/2; sekuensel yeniden numaralandırma | ✅ |
| 2 | Metin referansları | 14 noktada tüm "Tablo N" referansları güncellendi | ✅ |
| 3 | Şekil 3 başlığı | Bağımsız kalın metin → fig-cap entegrasyonu | ✅ |
| 4 | Denklem §3.2 | μ_t kaldırıldı; [^twoway] dipnotu (iki-yönlü FE) | ✅ |
| 5 | İngilizce → Türkçe | ~15 terim (Robustness, quantile, threshold, etc.) | ✅ |
| 6 | Tablo dipnot standartı | Tüm notlar: "Parantez içi … standart hatalardır." | ✅ |
| 7 | Geçiş paragrafları | 4 yeni geçiş (§3.1, §4.6, Tbl7, Tbl8 öncesi) | ✅ |
| 8 | Kod temizleme | stargazer kaldırıldı; modelsummary/kable | ✅ |
| 9 | Veri okuma hatası | Gereksiz read_csv() kaldırıldı | ✅ |
| 10 | Render kalitesi | DOCX+HTML sıfır uyarı | ✅ |

## Ana Bulgular
| Spesifikasyon | FX volatility coef | Inst quality × FX coef | p-değeri |
|---|---|---|---|
| TWFE | −0.165 | +0.062 | ** |
| RE | −0.152 | +0.058 | * |
| System-GMM | −0.187 | +0.074 | ** |

## Veri Özellikleri
- **N:** 11 ülke (Middle East, Sub-Saharan Africa, South Asia focus)
- **T:** 1990–2023 (34 yıl)
- **Total obs:** 374 (unbalanced panel)
- **Key variables:** Real GDP growth (%, WB), FX volatility (std of nominal ER), CPIA (World Bank)

---

## Dual-Track Stratejisi
| Track | Hedef | Dil | Durumu |
|-------|-------|-----|--------|
| **A** | MAKÜ Sosyal Bilimler Enstitüsü Dergisi | Türkçe | v10 HAZIR (DergiPark şablon bekleniyor) |
| **B** | Economic Modelling (Q1, IF 4.7) | English | Genişletme (extended dataset/methods) |

---
**Tahmini gönderim:** Track A (MAKÜ) 2026 Mayıs; Track B 2026 Temmuz  
**Hazırlık seviyesi:** 95% (A — formatı ve 5%)
