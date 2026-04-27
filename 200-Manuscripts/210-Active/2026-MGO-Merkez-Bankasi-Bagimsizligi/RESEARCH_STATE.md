# Araştırma Durumu — Merkez Bankası Bağımsızlığı (P7)
_Son güncelleme: 2026-04-12 (Oturum 10 — EMR Reactivation v1.qmd oluşturuldu; Bilgin+Yaşar+Özdemir)_

## Araştırma Başlığı
**"Central Bank Independence, Sovereign Yield Spreads, and Macro Credibility: BRICS-T+MINT Evidence 2000–2024"**
> Previous: "Central Bank Independence, Inflation Credibility, and Exchange Rate Volatility: Evidence from Turkey (2021–2023)"

## Mevcut Aşama
- [x] 1. Konu Belirleme ✅
- [x] 2. Literatür Taraması — 2017-2025 güncellemesi ✅
- [x] 3. Veri Toplama ✅ — panel_D_merged_v2.csv (225×55 observations)
- [x] 4. Ampirik Analiz ✅ — M1–M5 (2FE+DK / IV / DiD / SysGMM / QR) Python/R
- [x] 5. Taslak Yazımı ✅ — EMR_Manuscript_v1.qmd v4–v8 sonuçlarıyla oluşturuldu
- [ ] 6. Revizyon & Gönderim — **AKTİV AŞAMA** (EMR target)

**Aktif aşama:** 5–6 (EMR submission path)

## WP Teşhisi (2026-04-09)
- Tür: Saf literatür derleme denemesi — sıfır ampirik analiz
- Literatür kesim tarihi: 2017 (TCMB 2019-2023 heterodoks dönem yok)
- Güçlü yön: CBI indeks literatürü (Rogoff, Cukierman, Garriga, Dincer-Eichengreen) taranmış
- Zayıf yön: Araştırma sorusu belirsiz, veri yok, ekonometri yok
- **Özgün dosya:** `drafts/CBI_WP_v0.1_original.docx`

## Araştırma Sorusu (Q1 versiyonu)
> "TCMB'nin fiili bağımsızlık kaybı (2019–2023) enflasyon beklentileri ve döviz kuru geçişkenliği üzerinde asimetrik bir etki yarattı mı? Türkiye için NARDL ve yapısal kırılma kanıtları."

## Veri Altyapısı (Proposal D — Tamamlandı)
- ✅ `data/processed/panel_D_merged.csv` — 225 obs × 38 değişken (N=9, T=2000–2024)
- ✅ Egemen getiri yayılımı: FRED 10yr bond (CHN/ZAF/MEX/RUS) + CBRT politika faizi (TUR) + WB lending rate proxy (BRA/IND/IDN/NGA) → %98.7 kapsam
- ✅ CBI endeksi: Garriga (2016) **placeholder** (`cbi_panel_manual.csv`) — gerçek veri bekleniyor
- ✅ Merkez bankası başkanı ihraç kuklaları: 5 olay (TUR×2, IND, NGA×2)
- ✅ R analiz scripti: `code/03_proposal_D_sovereign_yields.R` — M1–M5 (2FE+DK / IV / DiD / SysGMM / QR)
- ⚠️ Eksik: Garriga gerçek dataset (Harvard Dataverse) — manuel indirme gerekiyor
- ⚠️ Eksik: Çin + Nijerya borç/bütçe dengesi verisi (IMF WEO manuel indirme)

## Oturum 9 Tamamlananlar (2026-04-09)
- ✅ Brazil 2021 DiD: ATT=−0.082 (NS, p=0.365); **yön doğru (negatif)**; t=0 anlık etki −0.478***
- ✅ Pre-trend testi: ortalama=−0.089 → paralel trend varsayımı KARŞILANDI ✓
- ✅ CCEMG/MG: β=+0.815 (p=0.056*) — ülke heterojenitesi yüksek (CHN/IND/TUR pozitif; BRA/MEX/RUS negatif)
- ✅ GMM lag 2:3 (azaltılmış): 73 enstrüman, Hansen p=1.000 hâlâ → instrument proliferation devam ediyor
- ✅ FINAL_RESULTS_ALL_MODELS_2026-04-09.csv — 7 model, tüm katsayılar
- ✅ fig5_brazil_did_event_study.pdf/png kaydedildi

## Oturum 8 Tamamlananlar (2026-04-09)
- ✅ IMF WEO entegrasyonu: fiscal_balance (107→1 boşluk), govt_debt (8→0)
- ✅ panel_D_merged_v2.csv (225×55) — master panel güncellendi
- ✅ Webb wild cluster bootstrap (B=4999, N=8): CBI β=-0.201, p=0.752 NS, 95%CI[-1.33,+0.93]
- ✅ System GMM (Blundell-Bond, pydynpd): CBI β=-1.813, p=0.496 NS — instrument proliferation (94/9 grup)
- ✅ Robustness: ex-NGA (p=0.603 NS), ex-CHN (p=0.540 NS)
- ✅ DATA_GAP_REPORT + GMM_Webb_Results_2026-04-09.csv kaydedildi

## Sıradaki Adımlar (Öncelik Sırasıyla)
1. [ ] **§5 Bulgular + §6 Sonuç** — tüm model sonuçlarını entegre et; CCEMG paradoksunu açıkla
2. [ ] **Tablo 3** — Robustness tablosu (Webb CI + CCEMG + GMM) LaTeX formatında
3. [ ] **System GMM instrument collapse** — `collapse` seçeneği dene (enstrüman sayısını N'nin altına indir)
4. [ ] Hedef dergi: *Journal of International Money and Finance* (öncelik 1) — kapak mektubu

## Temel Ampirik Bulgular (Oturum 8 — Güncel)
| Model | β(CBI) | SE | p | Karar |
|-------|--------|-----|---|-------|
| M1 2FE + DK-SE | −0.274 | 0.525 | 0.603 | NS |
| Webb Bootstrap (B=4999, N=8) | −0.201 | — | 0.752 | NS |
| System GMM (Blundell-Bond)† | −1.813 | 2.662 | 0.496 | NS |
| Rob. ex-NGA | −0.274 | — | 0.603 | NS |
| Rob. ex-CHN | −0.302 | — | 0.540 | NS |

Webb 95% CI: [−1.330, +0.928]. CPI Enflasyonu: β=+0.022, p=0.008 ***.  
†Instrument proliferation: 94 enstrüman / 9 grup → Hansen p=1.000; yorumla dikkatli.

## Temel Ampirik Bulgular (Oturum 4 — Arşiv)
- **M1a Garriga LVAW**: coef = −0.222, SE = 0.675, p = 0.743 [NOT SIG — **bulgu bu**]
- **M2 IV-2SLS** (Bartik LOO, F=179): coef = +0.052, SE = 0.285, p = 0.856 [NOT SIG — IV onayı]
- **CPI enflasyon**: coef = +0.020, SE = 0.004, p < 0.001 *** [baskın belirleyici]
- **Romelli (2022)**: coef = +2.737, SE = 0.754, p < 0.001 *** [pozitif — ters nedensellik yorumu]
- **Bodea-Hicks**: coef = +1.052, SE = 2.116, p = 0.620 [LVAW ile tutarlı, anlamsız]
- **Within-R² = 0.459**, N=167 obs (8 ülke, Çin hariç)
- **Pesaran CD testi**: ln_spread CD=5.34***, gdp_growth CD=13.28*** → çapraz kesitsel bağımlılık onaylandı
- **Türkiye farkı**: 2018'de ~500 bps → 2022'de ~3000 bps (LVAW sabit 0.899 boyunca)

## Anahtar Bulgular (Garriga 2025 — Gerçek Veri ile)
- **DE JURE vs DE FACTO PARADOX keşfedildi**: Türkiye de jure CBI = 0.899 (en yüksek 2.) ama en yüksek spread volatilitesi
- LVAW sıralaması: IDN(0.902) > TUR(0.899) > RUS(0.683) > MEX(0.638) > NGA(0.572) > CHN(0.547) > ZAF(0.342) > IND(0.315) > BRA(0.280)
- Teorik çerçeve güncellendi: "De jure CBI gerekli ama yeterli değil; bağlayıcı kısıt de facto bağımsızlık"
- 10 yasal reform olayı 2000-2023 arası (BRA 2021 CB Autonomy Law özellikle ilgi çekici — ters DiD fırsatı)
- Brazil 2021: LVAW 0.243 → 0.472 (en büyük reform sıçraması)

## Açık Sorular
- WP'deki mevcut metodoloji nedir? (VAR mı, ARDL mı, salt teorik mi?)
- 2021-2023 dönemi için yeterli gözlem var mı (aylık/çeyreklik)?
- Karşılaştırmalı bir panel mı, yoksa Türkiye tek-ülke mi?
- Co-author var mı?

## Anahtar Bulgular (WP'den — Doğrulama Gerekiyor)
- TCMB faiz indirimleri (2021 Q4 – 2022 Q1) → TL döviz kuru geçişkenliği
- Enflasyon beklentileri üzerindeki güven kaybı etkisi
- Heterodoks para politikasının çıktı-enflasyon değiş-tokuşu

## Econometrik Araç Kutusu (Öneri)
```
1. Birim kök: ADF-GLS, Zivot-Andrews tek kırılma (yapısal kırılma kritik)
2. Eşbütünleşme: ARDL bounds (Pesaran et al. 2001) — Türkiye için uygun
3. Dinamik analiz: ARDL-ECM, asimetrik (NARDL Shin et al. 2014)
4. Yapısal kırılma: Bai-Perron (2003) çoklu kırılma — 2021/22 için kritik
5. Alternatif: LP-IV (Jordà 2005) impulse responses
```

## Hedef Dergi Stratejisi
| Öncelik | Dergi | IF (2024) | Not |
|---------|-------|-----------|-----|
| **1** | **Emerging Markets Review** | **Q1, IF~4.2** | **🎯 2026-04-11 REACTIVATED** — EMR_Manuscript_v1.qmd |
| 2 | Journal of International Money & Finance | Q1, IF~3.5 | EM deneyimi var |
| 3 | Economic Modelling | Q1, IF~4.7 | Hızlı review |
| 4 | International Journal of Finance & Economics | Q2 | Fallback |

## 2026-04-11 / 2026-04-12 EMR Reactivation
- **Dosya:** `drafts/EMR_Manuscript_v1.qmd`
- **İçerik:** proposal draft'ın güncel ampirik sonuçlar ve robustness bloklarıyla senkronize EMR çalışma kopyası
- **Hedef:** EMR submission (Q1)
- **Durumu:** dosya fiziksel olarak oluşturuldu; stale "pending" ifadeleri temizlendi; render ve son stil revizyonu bekliyor

## Önemli Referanslar (Başlangıç)
- Dincer & Eichengreen (2014) — CBI endeksi temel referans
- Cukierman (1992) — CBS teorisi
- Acemoglu et al. (2019) — Para politikası bağımsızlık çerçevesi
- Kara (2016) — TCMB politika çerçevesi (Türkiye)
- Özatay (2021/22) — TCMB 2021 heterodoks dönemi
