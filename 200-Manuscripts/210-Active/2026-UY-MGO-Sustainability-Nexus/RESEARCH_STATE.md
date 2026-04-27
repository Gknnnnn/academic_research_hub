# Araştırma Durumu
_Son güncelleme: 2026-04-12_

## Araştırma Başlığı
"Energy Policy, Sustainability, and Economic Growth Nexus: Evidence from Panel Cointegration and Causality in Selected Developing Economies"

## Yazarlar
- Uğur Yıldırım + M. Gökhan Özdemir

## Mevcut Aşama
- [x] 1. Konu Belirleme & Soru Formülasyonu
- [x] 2. Literatür Taraması
- [x] 3. Materyal / Veri Toplama
- [x] 4. Analiz
- [x] 5. Taslak Yazımı
- [ ] 6. Revizyon & Düzeltme
- [ ] 7. Son Kontrol & Gönderim

**Aktif aşama:** 5–6 (Veri ve sonuçlar kilitli, TY parametrik bootstrap + Bai-Perron + §5–§6 tamamlama bekleniyor)

## Proje Özeti
Enerji politikası, sürdürülebilirlik ve ekonomik büyüme arasındaki uzun dönem dinamik ilişkisini Toda-Yamamoto (TY) VAR nedenselliği ve panel cointegration metodları ile incelemektedir. N=24 gelişmekte olan ülke, T=2000–2023. Bulgular: TY Wald testi 3 anlamlı çift bulmuş (specific pairs awaiting documentation); Webb bootstrap ARDL-ECM; robustness tamamlandı. Hedef: Energy Policy (Q1, IF 6.0+).

## Yöntem
- **Panel cointegration:** Johansen methodology, ARDL-ECM bounds testing
- **Causality:** Toda-Yamamoto (1995) VAR; Dumitrescu-Hurlin panel Granger
- **Robustness:** Webb wild cluster bootstrap (N<30, zorunlu), impulse response, variance decomposition
- **Temel bulgular:** TY 3 anlamlı çift; ECT ≈ −0.2 to −0.3 (hızlı adjustment); Johansen cointegration confirmed

## Dosya Haritası
- `04-Manuscript/Sustainability_Nexus_UY_MGO.qmd` — Source of truth
- `01-Admin/PROJECT_PORTFOLIO_CARD.md` — Proje durumu (priority score 19/25)
- `01-Admin/JOURNAL_TARGETS.md` — Energy Policy primary
- `01-Admin/RESEARCH_STATE.md` — Ön durumu (2026-04-08); now updated

## Veri Özellikleri (TAMAMLANDI)
| Değişken | Durum |
|----------|-------|
| Panel structure | N=24 ülke, T=24 yıl (576 obs) |
| Data sources | WB WDI, IEA, IRENA |
| Key variables | Real GDP growth, renewable energy share, carbon emissions, energy consumption |
| **Webb bootstrap** | ✅ Entegre |
| **Johansen cointegration** | ✅ Mevcut |

## Sıradaki Adımlar (KRİTİK)
1. **TY parametrik bootstrap:** p-değerleri (şu anda monte carlo'dan) bootstrap'e çevir
2. **Bai-Perron structural breaks:** Tüm serilerde break tarihleri test et (opsiyonel ancak tavsiye)
3. **§5 Results:** TY Wald özet tablo, Johansen cointegration tablo, impulse response graphs
4. **§6 Discussion:** Causality implications (unidirectional vs. bidirectional), policy channels
5. **Highlights & abstract:** 5 bullet points; nexus literature positioning

## Ana Bulgular (Placeholder)
| Nexus Pair | TY Wald | p-değeri | Direction | Yorum |
|------------|---------|----------|-----------|-------|
| [Energy → Growth] | [awaiting] | [awaiting] | → or ← | [awaiting] |
| [Sustainability → Energy] | [awaiting] | [awaiting] | → or ← | [awaiting] |
| [Growth → Sustainability] | [awaiting] | [awaiting] | → or ← | [awaiting] |

## Portfolio Bilgileri
| Değişken | Değer |
|----------|-------|
| Track | Prestige/Q1 |
| Current objective | Energy Policy submission hattına sok |
| Data status | ✅ TAMAMLANDI |
| Submission target | 2026-06-30 |
| Kill/Pause date | 2026-07-31 |
| Readiness | 2/5 (§5–§6 gerekli) |
| Priority score | 19/25 |

## Olası Riskler & Mitigasyon
| Risk | Şiddet | Mitigasyon |
|------|--------|-----------|
| Nexus kısım fazla geniş | Medium | Scope → energy policy impact only |
| Yazım penceresi dar | Medium | Section 5–6 parallel writing track |
| Journal-fit | Medium | Energy Policy nexus literature primer |

## Tarihçe & Milestones
- **2026-04-07:** Veri lock; preliminary TY results
- **2026-04-08:** RESEARCH_STATE.md ilk versiyonu
- **2026-04-12:** Bootstrap & robustness tamamlandı
- **2026-04-XX:** §5–§6 tamamlanma target

---
**Hedef dergi:** Energy Policy (Q1, IF 6.0+)  
**Tahmini gönderim:** 2026-06-30  
**Hazırlık seviyesi:** 60%  
**Kritik açık:** TY bootstrap + Results/Discussion sections (3–4 hafta)
