# Araştırma Durumu — 2026-UY-MGO-Sustainability-Nexus
_Son güncelleme: 2026-04-08_

## Araştırma Başlığı
**"Nonlinear Dynamics in the Migration-Carbon-Growth Nexus: A Structural Evaluation of Green Finance and the EKC Hypothesis"**

**Yazarlar:** Dr. Öğr. Üyesi Uğur Yıldırım & Dr. M. Gökhan Özdemir
**Hedef Dergi:** Energy Policy (Q1, IF ≈ 9.0)
**Yedek:** Journal of Cleaner Production; Ecological Economics; Renewable & Sustainable Energy Reviews
**Gönderim Hedefi:** 2026-06-30 | Kill Date: 2026-07-31

---

## Mevcut Aşama

- [x] 1. Konu Belirleme & Soru Formülasyonu ✓
- [x] 2. Literatür Taraması ✓ (`04-Manuscript/references.bib`)
- [x] 3. Veri Toplama ✓ (`03-Results/data_UY_2000_2023.csv`, N=24, 2000-2023, Türkiye)
- [x] 4. Ekonometrik Tasarım ✓ (TY-VAR k=1, d_max=1, order=2)
- [x] 5. Ana Analiz — TY Wald ✓ (`03-Results/TY_wald_table.csv`)
- [x] 6. Bootstrap Robustness — Webb ARDL-ECM ✓ (`03-Results/webb_wild_bootstrap.txt`)
- [x] 7. Robustness — Johansen + ARDL ✓ (`03-Results/robustness_johansen_ardl.txt`)
- [x] 8. Taslak Yazımı — §1-§4 mevcut qmd ✓ (~1,703 kelime)
- [ ] 9. **§4 tablo güncelleme + bootstrap sonuçları eklenmeli** ← AKTİF
- [ ] 10. **§5 Discussion + §6 Conclusion** → [[XX]] yertutucullar doldurulacak
- [ ] 11. Revizyon & Gönderim

**Aktif aşama:** 9 — Ana bulguların raporlanması; bootstrap tutarlılık sorununu ele al.

---

## Sonuçlar Özeti

### Değişkenler:
- MIG = İşgücü göçü (iç göç / net göç oranı)
- CO2 = Karbon emisyonları (kişi başı, ton CO2e)
- GI = Yeşil Finansman Endeksi
- GDP = Reel GSYH (sabit fiyatlarla)
- Dönem: 2000-2023 (N=24), Türkiye tek ülke

### ADF Birim Kök Sonuçları (c+t):
| Değişken | ADF | p | Karar |
|---|---|---|---|
| MIG | −2.139 | 0.524 | I(1) |
| CO2 | −2.236 | 0.470 | I(1) |
| GDP | −2.983 | 0.137 | I(1) |
| GI  | −1.963 | 0.622 | I(1) |

→ Tüm seriler I(1) → d_max=1 → TY order = k+d_max = 1+1 = 2 ✓

### TY Wald Test Sonuçları (Asimptotik):
| Yön | Wald | df | p (asimptotik) |
|---|---|---|---|
| **MIG→GI** | **7.775** | 2 | **0.0205*** |
| **CO2→GDP** | **9.075** | 2 | **0.0107*** |
| **GDP→GI** | **6.482** | 2 | **0.0391*** |
| Diğer 9 çift | — | — | p > 0.10 (NS) |

### Webb Wild Bootstrap (ARDL-ECM, CO2 denklemi, B=999):
| Katsayı | t_hat | p_asymp | p_webb_999 |
|---|---|---|---|
| const  | 1.116 | 0.282 | 0.327 |
| L_CO2  | −1.016 | 0.326 | 0.276 |
| L_GDP  | 0.821 | 0.424 | 0.288 |
| L_MIG  | −0.004 | 0.997 | 0.997 |
| L_GI   | 0.240 | 0.814 | 0.750 |
| d_GDP  | −1.484 | 0.158 | 0.254 |
| d_MIG  | 1.053 | 0.309 | 0.349 |
| d_GI   | 0.488 | 0.633 | 0.555 |

→ CO2 ARDL-ECM: hiçbir katsayı p_webb<0.05'i geçmiyor.

**Not:** Bu Webb bootstrap CO2 hata-düzeltme modelinin katsayılarını test ediyor. TY Wald istatistiklerinin doğrudan bootstrap testi henüz tamamlanmadı.

---

## KRİTİK DEĞERLENDİRME

### Güçlü Yönler:
- **CO2→GDP** (p=0.0107**): Karbon emisyonlarının büyümeye Granger nedenselliği — teorik açıdan güçlü ve enerji bağımlılığı literatürüyle tutarlı
- **MIG→GI** (p=0.0205*): Göçün yeşil finansmanı tetiklemesi — özgün katkı, literaturde nadir
- **GDP→GI** (p=0.0391*): Büyüme → yeşil yatırım → politika tavsiyeleri için güçlü
- §1-§4 taslak mevcut, metodoloji sağlam

### Zayıf Yönler / Riskler:
- **Webb bootstrap**: TY Wald p-değerleri için doğrudan bootstrap yapılmadı — sadece ARDL-ECM katsayıları test edildi; YETERSİZ
- **N=24 küçük örneklem**: Asimptotik p-değerleri güvenilmez (kaynak: `TY_results_v2.txt` CAVEATS)
- **Bai-Perron yapısal kırılma**: Türkiye 2001/2008/2018 krizleri → kırılma testi eksik; CLAUDE.md zorunluluğu
- **COI eksik**: Bu kağıtta COI kullanılmıyor ama başlıktaki "EKC Hypothesis" → CO2 EKC testi eksik (nonlinear GDP term)

---

## Sıradaki Adımlar (Öncelik Sırasıyla)

1. [ ] **TY Wald bootstrap**: `02-Methods/analysis_VAR_TY_v2.py` içinde parametrik rezidü bootstrap (B=999) ekle → her çift için p_boot hesapla
2. [ ] **Bai-Perron yapısal kırılma testi**: `02-Methods/` altına yeni script — Türkiye'nin kritik kırılma yıllarını (2001, 2008, 2018) tespit et; SupF istatistikleri
3. [ ] **EKC nonlinear testi** (isteğe bağlı): GDP² → CO2 için nonlineer ARDL veya TY ile quadratic term — başlığa uyum sağlar
4. [ ] **§4 tablo güncelle**: Bootstrap p-değerlerini yan sütun olarak ekle
5. [ ] **§5 Discussion + §6 Conclusion** yazımı: Üç ana bulgu (MIG→GI, CO2→GDP, GDP→GI) politika tavsiyeleriyle sentezle; Jevons Paradoksu + Ekolojik Verimlilik Paradoksu teorik çerçevesine bağla
6. [ ] **Gönderim paketi**: .docx formatına dönüştür (pandoc) + Energy Policy şablonu

---

## Dosya Haritası

| Dosya | Durum | Notlar |
|---|---|---|
| `04-Manuscript/Sustainability_Nexus_UY_MGO.qmd` | ✅ ~1,703 kelime | §1-§4 mevcut, §5-§6 eksik |
| `03-Results/data_UY_2000_2023.csv` | ✅ | N=24, 2000-2023 |
| `03-Results/TY_wald_table.csv` | ✅ | Asimptotik TY sonuçları |
| `03-Results/TY_results_v2.txt` | ✅ | Detaylı TY çıktısı |
| `03-Results/webb_wild_bootstrap.txt` | ✅ | ARDL-ECM Webb B=999 |
| `03-Results/robustness_johansen_ardl.txt` | ✅ | Johansen + ARDL robustness |
| `03-Results/adf_table.csv` | ✅ | ADF unit root |
| `02-Methods/analysis_VAR_TY_v2.py` | ⚠ | TY Wald bootstrap eklenmeli |
| `04-Manuscript/references.bib` | ⚠ | Eksikler kontrol edilmeli |

---

## Açık Sorular & Bekleyen Kararlar

- TY Wald p-değerleri için parametrik bootstrap yapıldığında CO2→GDP (p=0.011) hayatta kalabilir mi?
- "EKC Hypothesis" başlıkta — GI (Green Finance Index) gerçekte EKC mi test ediyor? Başlık gözden geçirilmeli
- MIG verisi kaynağı: TurkStat iç göç mü, dış göç mü, yoksa her ikisi de mi? Tanımı netleştir
- §5 Discussion: CO2→GDP bulgusu "fosil yakıt bağımlı büyüme" argümanını güçlendiriyor — Energy Policy için güçlü bir kanca
