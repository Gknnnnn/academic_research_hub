# Araştırma Durumu
_Son güncelleme: 2026-04-14_

## Araştırma Başlığı
Climate Change and Agricultural Value Added in Turkey: Long-Run Elasticities from an ARDL Bounds Test, 1970–2021

## Yazarlar
- **Arş. Gör. Dr. Mehmet Gökhan Özdemir** (corresponding author)
- **Prof. Dr. Hacı Bayram Işık** (co-author, supervisor of first author's doctoral dissertation)

## Mevcut Aşama
- [x] 1. Konu Belirleme & Soru Formülasyonu
- [x] 2. Literatür Taraması
- [x] 3. Materyal / Veri Toplama
- [x] 4. Analiz (ARDL, bounds testing, ECM)
- [x] 5. Taslak Yazımı
- [x] 6. Revizyon & Düzeltme (v10 tamamlandı — unit fixes + R ARDL + functional-form robustness + fabrike atıf temizliği + adversarial sparring + JEM-style peer review + humanizer pass + **KPSS/DF-GLS/ZA unit-root battery + wild-bootstrap CIs + Appendix A4 confirmed**)
- [ ] 7. Son Kontrol & Gönderim (**Sadece Işık hoca sign-off bekleniyor**)

**Aktif aşama:** 6→7 geçiş. **v12 submission-ready** — tüm teknik koşullar, v10 sparring blockerları (B1–B3) ve revision-round maddeleri (R1–R3) karşılandı. Tek açık koşul: Işık hocadan formal onay + e-posta. Gönderim: onay alındığında aynı hafta.

## Proje Özeti
Türkiye'de iklim değişikliği, tarımsal verimlilik ve sustainability ilişkisini ARDL bounds testing yaklaşımıyla inceleyen zaman serisi çalışması. Uzun dönem kointegrasyon ilişkisini ve Error Correction Model (ECM) dinamiklerini tahmin eder. Sıcaklık, yağış, su stresi ve tarımsal çıktı endeksleri arasındaki bağlantı. Replication report ve peer review sparring raporu hazırlanmış.

## Yöntem
- ARDL Bounds Testing: kısa-uzun dönem ayrımı, cointegration F-statistic (Pesaran 2001)
- Error Correction Model (ECM): kısa dönem dinamikleri ve hata düzeltme hızı
- Spesifikasyon: lag uzunluğu AIC/SBC seçim kriteri
- Veri: Türkiye zaman serisi, 1980–2021 (WB, TurkStat, IEA sources)

## Dosya Haritası
- `/Climate_Agriculture_Turkey_ARDL_v05.docx` — Son DOCX (2026-04-09)
- `/Climate_Agriculture_Turkey_ARDL_v02.qmd` — QMD source
- `/2026-MGO-Climate-Agriculture-Turkey-ARDL_v0.1.docx` — İlk draft
- `/2026-MGO-Climate-Agriculture-Turkey_OnlineAppendix_v2.docx` — Online appendix (tablolar, diagnostics)
- `/2026-MGO-EcologicalEconomics-CoverLetter.docx` — Draft cover letter
- `/2026-MGO-PeerReview-AcademicSparring-Report.docx` — Sparring raporu (academic feedback)
- `/2026-MGO-Replication-Report-v1.docx` — Replication metodoloji
- `/Cover_Letter_JEM.docx`, `/Cover_Letter_JEM.md` — Alternatif cover letter
- `README.md` — Project documentation

## Sıradaki Adımlar
1. ~~**Online Appendix Table A4**~~ ✅ **TAMAMLANDI** — TSA_anom θ=+0.059, p=0.198 (NS ✓); F_bounds=5.323*** (1%); v10.qmd'de tam tablo mevcut.
2. **Işık hoca sign-off** — Cover_Letter_JEM.md'deki `[INSERT IŞIK HOCA EMAIL]` placeholder doldurulmalı; formal onay zinciri kapatılmalı.
3. ~~**RESEARCH_STATE tutarlılığı**~~ ✅ yazar kadrosu manuscript ile hizalı (Özdemir + Işık).
4. Hedef dergi: **Journal of Environmental Management** (Q1, IF≈8.0) — cover letter hazır; EE alternatifi gerekirse paralel hazırlanabilir.
5. Gönderim hedefi: 2026-05 (Işık hoca sign-off tamamlandığında aynı hafta gönderim — **A4 koşulu kaldırıldı**).

## v10 Düzeltme Notları (2026-04-14)
Yedinci revizyon turu — **submission-blocker üç koşulun empirik olarak kapatılması**:

- **Tablo 1 — Genişletilmiş birim kök bataryası**: ADF sütununa ek olarak KPSS ve DF-GLS/ERS sütunları eklendi. Entegrasyon kararı: lnAVA I(1), lnTSA I(1), lnTSSO I(1), lnALAN I(1), lnCO₂ I(1); lnPR I(0) [ZA break=1988, stat=−4.698, sınır CV=−4.80'ın üzerinde; not olarak belirtildi]. References.bib'e `kwiatkowski1992testing` (JoE 1992) ve `elliott1996efficient` (Econometrica 1996) eklendi — toplam 31 atıf, 0 çözümsüz.
- **Tablo 2 Panel B — Wild-bootstrap 95% CI sütunu**: B=2000, Rademacher ±1 ağırlıkları; R ARDL paketi CECM üzerinden. Tüm OLS tahminleri bootstrap aralıklarının içinde: lnPR=[+0.15,+0.66]*, lnTSA=[−0.42,+0.88] NS, lnTSSO=[+0.20,+0.77]***, lnALAN=[−4.05,−1.13]***, lnCO₂=[−0.87,+0.23] NS. Tablo 2 notuna metodoloji açıklaması eklendi.
- **§5.4 sıcaklık fonksiyonel form**: "bekliyoruz... korunmasını" koşullu dili → "TSA anomalisi katsayısı = +0.059, p = 0.198 — istatistiksel anlamsızlık teyit edildi" kesin onaylama diline yükseltildi.
- **Online Appendix Table A4 — Yarı-logaritmik sıcaklık anomalisi sağlamlık testi**: `code/compute_blockers.R` Block 3 ile empirik olarak üretildi. F_bounds=5.323*** (1% düzeyinde kointegrasyon); ECT=−0.393***; TSA_anom θ=+0.059, p=0.198 (NS ✓); lnTSSO=+0.328***; lnALAN=−1.930***; tüm tanı testleri geçti. Appendix olarak QMD'ye eklendi (fabrikasyon yok).
- **Render**: `Climate_Agriculture_Turkey_ARDL_v10.docx` (31K, 6 tablo, 0 çözümsüz atıf) + `Climate_Agriculture_Turkey_ARDL_v10.pdf` (99K, xelatex clean).
- **Submission durumu**: Tüm teknik ön koşullar karşılandı. Tek açık: Işık hoca formal sign-off.

## v06 Düzeltme Notları (2026-04-14)
Aşağıdaki kritik Q1-reviewer kırmızı bayrakları giderildi:
- **Unit mislabeling** — `ln CO₂` "Mt CO₂e" olarak etiketliydi; descriptive stats (mean=1.37) aslında **t CO₂ cap⁻¹** (WB WDI `EN.ATM.CO2E.PC`) olduğunu gösteriyor. §3, Tablo 1, Tablo 2 Panel B, §5.2 düzeltildi.
- **Tablo 1'e "Unit (pre-log)" ve "Source" sütunları** eklendi; tüm değişkenler için birim + WB/FAO series ID açıkça belirtildi.
- **Tablo 2 Panel B ve Tablo 4 notları**: parantez içi birim + note-level unit listesi eklendi.
- **Tablo 3 (short-run) notu**: herhangi bir birim değişikliği gerekmiyor (Δln formu).
- **Log-temperature metodolojik zayıflık**: §5.4'te robustness paragrafı + Appendix A4 yönlendirmesi eklendi (fabrikasyon yok — A4 empirik olarak üretilecek).
- **Stata `ardl` → R `ARDL`** (Natsiopoulos & Tzeremes 2022); references.bib'te kripfganz2018ardl entry'si swap edildi.
- **Cover Letter**: tarih 14 April 2026'ya güncellendi; novelty paragrafı birim-doğru ve robustness set (a-d) eklendi.

## v09 Düzeltme Notları (2026-04-14)
Altıncı revizyon turu — **v08 sparring iç tutarsızlıklarının giderilmesi** (sıfır yeni tahmin):

- **Table 2 Panel B başlığı**: "Long-Run Elasticities" → "Long-Run Cointegrating Coefficients" (sparring M1-B — tablo başlığı ile §6 body prose arasındaki çelişki giderildi).
- **§5.2 bölüm başlığı**: "Long-Run Elasticities" → "Long-Run Cointegrating Coefficients" (aynı tutarlılık düzeltmesi).
- **Highlights bullet (land)**: "elasticity −2.349*** — marginal land expansion harmful" → "long-run coefficient −2.349*** — consistent with expansion onto marginal land" (causal dil kaldırıldı; "elasticity" disclaimed language ile tutarlı hale getirildi).
- **Table 2 Panel C half-life**: "≈ 2.1 years" → "2.14 years (95% CI: 1.3–4.3 years, Delta method)" — ECT SE=0.064 zaten tabloda mevcuttu; delta-method aritmetiği uygulandı (sparring Attack 6-B / peer review m13).
- **§5.4 "is preserved"**: Present-tense assertion → "we expect... to be preserved" conditional framing. A4 empirik olarak üretilene kadar bu dil daha savunulabilir (sparring Re-Attack 3 / peer review M3).
- **§6 land policy**: Causal recommendation → conditional: "if the negative coefficient reflects extensification onto marginal land... then policies promoting consolidation are warranted; this interpretation should be confirmed by structural identification." (sparring Re-Attack 5-B / peer review M1).
- **§6 USD CI footnote**: 2021 AVA base (USD ~64 billion at constant 2015 prices) ve "asymptotic Delta-method SE" kaynağı açıkça belirtildi (sparring New Attack 2-B / peer review M8).
- **Table 3 notu**: Endogeneity disclaimer eklendi — "Short-run capital and land coefficients are interpreted as predictive associations; the endogeneity caveat extending from the long-run equation" (sparring New Attack 10 / peer review M7).
- **Render**: `Climate_Agriculture_Turkey_ARDL_v09.docx` (30245 B, 6 tablo, 0 unresolved citations) + `.pdf` (86727 B, xelatex clean).

## v08 Düzeltme Notları (2026-04-14)
Beşinci revizyon turu — **adversarial review + humanizer pass**:

- **Academic sparring report** (`v07_Academic_Sparring_Report.docx`): 9-saldırı hostile Q1 reviewer critique; identification, T=52 small-sample, temperature log transformation, CO₂ specification, land-area coefficient magnitude, half-life arithmetic, novelty claim, policy overconfidence, unit-root battery. Submission-blocker: Appendix A4 + bootstrap + KPSS/DF-GLS; revision-round: mechanism evidence + CI framing + CO₂ decision.
- **JEM-style peer review** (`v07_Peer_Review_Report.docx`): Major M1–M6 + minor m1–m12; verdict "Major revisions". Referee-box prose and 9-row condition-status table.
- **Humanizer report** (`v07_Humanizer_Report.docx`): 6 before/after passages targeting rule-of-three enumerations, copula avoidance ("exhibits"/"circumscribe"), negative parallelism, em dash stacks, "fills that gap" sign-posting; Q1-register preserved (no informal voice).
- **Humanizer edits applied to v02.qmd**: Abstract three-finding enum; §1 novelty claim (reframed around mixed-integration contribution); §5.2 aggregate-attenuation claim; §5.4 functional-form paragraph; §6 fourfold policy (now narrative with CI-framed USD range); §6 limitations paragraph (tightened to three limitations + softened "elasticity" → "long-run conditional association" language per M1/Attack 1).
- **Render**: `Climate_Agriculture_Turkey_ARDL_v08.docx` (29983 B, 6 tables, 0 unresolved citations) + `.pdf` (85562 B, xelatex clean). Pandoc 3.1.11 + citeproc.
- **Substantive bonus improvements** via humanizer: policy USD band (addresses m5), novelty reframe (addresses m2), "conditional association" language (addresses M1). No coefficient/p-value changes.

## v07 Düzeltme Notları (2026-04-14)
Dördüncü revizyon turu — **submission-blocker kaliteli atıf doğrulaması**:

- **Fabrike atıf tespiti**: CrossRef DOI çözümlemesi + canlı WebSearch ile dört atıfın **hiçbirinin var olmadığı** doğrulandı:
  - `demirhan2020effects` (Ecological Indicators), `tang2021effects` (STOTEN China ARDL), `albayrak2019climate` (TJAF), `celik2021agricultural` (Energy & Environment) — tümü DOI 404 veya yanlış makaleye yönlendirme.
- **Verifiye edilmiş değiştirmeler** (CrossRef DOI + yayıncı doğrulamalı):
  - `demirdogen2024impact` — Demirdogen, Karapinar & Özertan (2024) *Regional Environmental Change* 24(1):12 — Turkish wheat climate-impact. DOI 10.1007/s10113-023-02172-6
  - `dumrul2017economic` — Dumrul & Kılıçarslan (2017) *Journal of Business, Economics and Finance* 6(4):336–347 — **Turkish ARDL climate-ag predecessor**. DOI 10.17261/pressacademia.2017.766
  - `yurtkuran2021effect` — Yurtkuran (2021) *Renewable Energy* 171:1236–1245 — Turkey bootstrap ARDL agriculture-renewable-CO₂. DOI 10.1016/j.renene.2021.03.009
  - `pata2021linking` — Pata (2021) *Renewable Energy* 173:197–208 — BRIC renewable-agriculture-CO₂-EF. DOI 10.1016/j.renene.2021.03.125
  - `ghosh2023climate` — Ghosh, Eyasmin & Adeleye (2023) *PLOS Climate* 2(7):e0000244 — Bangladesh ARDL/ECM climate-agriculture. DOI 10.1371/journal.pclm.0000244
- **QMD re-write**: §1 novelty gap (Albayrak/Çelik → Dumrul/Yurtkuran); §2 cross-country ARDL paralleli (Tang → Ghosh); §2 Turkish ag-renewable-CO₂ strand eklendi; §5.2 comparable analyses (Tang → Ghosh + Ortiz-Bobea); §5.4 functional-form precedent (Tang → Ghosh). Toplam 9 in-text atıf değiştirildi.
- **Audit**: missing=0, unused=0, 29 atıf/29 bib entry. Render pandoc 3.1.11 + citeproc clean (317 para, 6 tablo, ??? yok).
