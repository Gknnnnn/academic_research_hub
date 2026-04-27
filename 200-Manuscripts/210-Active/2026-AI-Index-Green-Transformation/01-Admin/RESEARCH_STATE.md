# Araştırma Durumu — 2026-AI-Index-Green-Transformation
_Son güncelleme: 2026-04-08_

## Araştırma Başlığı
**"Artificial Intelligence Capacity and Green Transformation: Cross-Country Panel Evidence"**
*(Başlık taslak — netleştirilecek)*

**Yazarlar:** Dr. M. Gökhan Özdemir (baş), Dr. Suat Serhat Yılmaz, Arş. Gör. Mustafa Türk
**Hedef Dergi:** Journal of Environmental Management (Q1, IF ≈ 8.9)
**Yedek:** Technological Forecasting & Social Change; Energy Policy; Ecological Economics
**Gönderim Hedefi:** 2026-06-30 | Kill Date: 2026-07-31

---

## Mevcut Aşama

- [x] 1. Konu Belirleme & Soru Formülasyonu ✓
- [x] 2. Research Gap Analizi ✓ (tek-proxy sorunu tespit edildi; çoklu AI indeks stratejisi belirlendi)
- [x] 3. Değişken Matrisi ✓ (`02-Methods/VARIABLE_MATRIX.md` — 5 AI değişkeni + 5 çevresel sonuç + kontroller)
- [x] 4. Mevcut Panel Altyapısı Denetimi ✓ (`400-Data/Global-Panels/Clean/panel_master_v1.csv`, N≈123 ülke, 2019-2023)
- [ ] 5. **AI İndeks İndirme & Merge** ← BLOCKER (Oxford + Tortoise + Stanford + IMF AIPI)
- [ ] 6. Panel Veri İnşası (AI indeksler × çevresel çıktılar × kontroller)
- [ ] 7. CD Testi + Slope Homogeneity (Pesaran CD, PY test)
- [ ] 8. Ön Testler (CIPS unit root, cointegration)
- [ ] 9. Ana Tahmin (CCEMG / AMG / Driscoll-Kraay FE + Hausman)
- [ ] 10. Taslak Yazımı

**Aktif aşama:** 5 — Veri entegrasyonu; emprik analiz henüz başlamadı.

---

## Gerçek Veri Durumu (2026-04-08 envanteri)

### Mevcut (genel panel havuzu):
| Kaynak | Değişken | Yıl aralığı | Ülke |
|---|---|---|---|
| `panel_master_v1.csv` | ecological_footprint, eci, gdp_pc, renewable_energy, urban, fdi, trade | 2019-2023 | ~123 |
| `panel_master_v1.csv` | carbon_intensity_gdp, adjusted_net_savings, resource_rents | 2019-2023 | ~108-120 |

### EKSİK (AI indeks dosyaları henüz indirilmedi):
| İndeks | Kaynak URL | Yıl kapsamı | Tahmini N |
|---|---|---|---|
| Oxford GAIR | https://oxfordinsights.com/ai-readiness/ | 2017-2023 | ~160 ülke |
| Tortoise Global AI Index | https://globalaiindex.com/ | 2019-2023 | ~62 ülke |
| Stanford HAI Vibrancy | https://aiindex.stanford.edu/ | 2017-2023 | ~36-50 ülke |
| IMF AI Preparedness Index | https://www.imf.org/ | 2023 kesit | ~174 ülke |

**Kısıt:** Stanford HAI en dar ülke kapsamı (N≈36) → ortak örneklem sorunu. Stanford baseline dışında bırakılabilir; IMF kesit robustness için kullanılır.

---

## Metodoloji Taslağı

### Ana Tasarım:
- Panel: N≈50-100 ülke, T≈4-7 yıl (kısa panel → CCEMG/AMG tercih)
- Bağımlı değişken (primer): `carbon_intensity_gdp` + `renewable_energy_share`
- Bağımlı değişken (ikincil): `ecological_footprint`, `adjusted_net_savings`
- Ana açıklayıcılar: `gair` (Oxford), `gai` (Tortoise), `ai_factor` (PCA composite)
- Moderatörler: `rq` (WGI Regulatory Quality), `ge` (WGI Govt Effectiveness)
- Kontroller: `gdppc`, `trade`, `urban`, `fdi`, `energy_pc`, `rd_gdp`

### Model Blokları (VARIABLE_MATRIX.md'den):
- **M1:** Y = f(gair, controls) — Oxford baseline
- **M2:** Y = f(gair, gai, vibrancy, controls) — multi-index
- **M3:** Y = f(ai_factor, controls) — PCA composite
- **M4:** Y = f(ai_factor × rq/ge, controls) — moderasyon/etkileşim
- **M5:** Y = f(ai_factor², controls) — nonlinear/EKC-type

### Tanımlama Stratejisi:
- Temel endişe: AI kapasitesi → çevresel çıktı yönündeki nedensellik için reverse causality riski (gelişmiş ülkeler hem yüksek AI hem iyi çevre yönetimi → OVB)
- IV/2SLS veya sistem GMM gerekli; olası IV: internet altyapısı (broadband, 1990s), IT human capital
- Driscoll-Kraay SE (cross-section dependence için)

---

## Sıradaki Adımlar (Öncelik Sırasıyla)

1. [ ] **Oxford GAIR CSV indir** (2017-2023, ülke düzeyi) → `400-Data/AI-Indices/oxford_gair.csv`
2. [ ] **Tortoise Global AI Index indir** (2019-2023) → `400-Data/AI-Indices/tortoise_gai.csv`
3. [ ] **IMF AIPI indir** (2023 kesit) → `400-Data/AI-Indices/imf_aipi.csv`
4. [ ] **`02-Methods/merge_ai_indices_and_run.py` çalıştır** (mevcut script, veri gelince)
5. [ ] **Panel birleştirme**: AI indeksleri × `panel_master_v1.csv` → N, T boyutlarını raporla
6. [ ] **Pesaran CD testi** + Pesaran-Yamagata slope homogeneity → estimator seçimi
7. [ ] **CIPS unit root** → I(1)/I(0) sınıflandırması
8. [ ] **Ana tahmin**: CCEMG/AMG (CD varsa) veya Driscoll-Kraay FE (CD yoksa)
9. [ ] **Taslak yazımı başlatma**: §1-§3 araştırma sorusu + metodoloji + veri bölümü

---

## Risk Matrisi

| Risk | Olasılık | Etki | Çözüm |
|---|---|---|---|
| Stanford HAI N≈36 → ortak örneklem çok dar | Yüksek | Yüksek | Stanford'u robustness katmanına al; baseline Oxford+IMF |
| AI indeksler farklı kavramları ölçüyor → multikollinearite | Orta | Orta | PCA ile ai_factor composite + ayrı ayrı sunma |
| AI endogeneity | Yüksek | Yüksek | IV: lagged broadband/internet, 2SLS zorunlu |
| Veri 2019-2023 → T=5 çok kısa | Orta | Yüksek | CS-ARDL yerine CCEMG/AMG tercih; time trend FE |
| Çakışma riski (AI yüksek = iyi çevre = gelişmiş ülke) | Yüksek | Yüksek | Gelir grupları ayrı örneklem + income IV |

---

## Dosya Haritası

| Dosya | Durum |
|---|---|
| `04-Manuscript/PROJECT_DRAFT.md` | ✅ 620 kelime — kavramsal çerçeve |
| `04-Manuscript/INTRODUCTION_AND_CONTRIBUTION_DRAFT.md` | ✅ 412 kelime — §1 taslak |
| `04-Manuscript/ONE_PAGE_PROJECT_SUMMARY.md` | ✅ özet |
| `02-Methods/VARIABLE_MATRIX.md` | ✅ tam değişken planı |
| `02-Methods/merge_ai_indices_and_run.py` | ⚠ veri bekliyor |
| `02-Methods/baseline_panel_estimation.py` | ⚠ veri bekliyor |
| `02-Methods/diagnostics_cd_hausman.py` | ⚠ veri bekliyor |
| `02-Methods/driscoll_kraay_ccemg.py` | ⚠ veri bekliyor |
| `03-Results/` | ❌ BOŞ — henüz hiç sonuç yok |
| `400-Data/AI-Indices/` | ❌ YOK — AI veri dosyaları henüz indirilmedi |
