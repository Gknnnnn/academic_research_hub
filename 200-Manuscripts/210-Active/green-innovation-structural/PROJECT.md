# Green Innovation Structural — ECI × Clean Innovation × BRICS-T+MINT

## Objective
Estimate structural relationship: ECI ~ ln(CI: clean innovation) + ln(REN) + controls;
test spill-over effects on structural transformation.

## Data
- **Source:** EKC_BRICST 9-country panel (Brazil, Russia, India, China, South Africa, Turkey, Mexico, Indonesia, Nigeria), 1995–2021
- **Note:** EKC_BRICST ile aynı N=9 veri seti — farklı bağımlı değişken (ECI vs CO₂). İki makale ortak temiz veri kullanır; editöre gerekirse açıklanacak.
- **Variables:** ECI (Hidalgo-Hausmann), clean-tech patents (CI), REN share, R&D, trade, FDI, resource rents, EF

## Methodology

1. Pesaran CD test (tüm seriler p<0.01 → CSD mevcut ✅)
2. CIPS unit root (CD-robust; ECI/CI/REN/EF → I(1); GDP/FDI borderline)
3. Westerlund kointegrasyon (M1 Gt=−2.994 p=0.000 ✅)
4. CS-ARDL (ECT: M1=−0.932***, M2=−1.116***)
5. Heterogeneous slope (MG/PMG)
6. **Nedensellik — EYLEM B UYGULANDI (2026-04-22):**
   - **DH (Dumitrescu-Hurlin 2012) birincil test** — `plm::pgrangertest`, lag=2, Ztilde
   - Script: `07_dh_causality_primary.R` — verified output `12_dh_causality_primary.csv`
   - NK2024 (Nazlıoğlu-Karul 2024) GAUSS hazırlığı yapıldı; GAUSS Lite CrossOver ile kurulacak
   - GAUSS bridge: `08_gauss_bridge_export.R` → `gauss_input/` → GAUSS → `gauss_output/`
   - NK2024 GAUSS kurulunca robustness olarak eklenecek (birincil değil)
7. MMQR (quantile heterogeneity)
8. Bai-Perron yapısal kırılma (CI: 2007; ECI: 2014)
9. Webb wild cluster bootstrap (N=9<30; B=999, 6-point ✅)
10. Subsample robustness (BRICS vs. MINT; Drop-RUS)

## Temel Bulgular (v04_DH_verified, 2026-04-22)

| Test | Sonuç |
|------|-------|
| CD test | Tüm seriler p<0.01 ✅ |
| CIPS | ECI/CI/REN/EF → I(1) |
| Westerlund | Gt=−2.994 p=0.000 ✅ |
| CS-ARDL ECT | −0.932*** (M1), −1.116*** (M2) |
| **DH (plm, lag=2) — BİRİNCİL** | CI↔ECI bidirectional (p=0.002***, p=0.000***); GDP→ECI p=0.000***; fdi_w→ECI p=0.061*; REN→ECI NS (p=0.178); EF→ECI NS (p=0.135); ECI→EF p=0.018** |
| NK2024 (R — Damokles ihlali, çıkarıldı) | Referans için: CI→ECI p=0.042**; GDP→ECI p=0.024**; REN→ECI NS (p=0.423) — DH ile tutarlı |
| MMQR τ=0.50 | ln_gdp β=+0.599 p=0.023 |
| MMQR τ=0.90 | FDI β=−0.087 p=0.015 (Dutch disease) |

**⚠️ DH eski değerleri uyarısı:** 06_nk2024.R'daki `dh_ref` hardcoded değerleri (Z=4.098 vb.)
hiçbir lag seçimiyle eşleşmiyor — eski implementasyondan. Geçerli değerler `07_dh_causality_primary.R` çıktısındaki.

## Output

- Q1 target: Journal of Cleaner Production (IF≈10); `editorialmanager.com/jclepro`
- Reserve: Business Strategy & Environment; Technological Forecasting
- DOCX: `green_innovation_manuscript_v03_JCP.docx` (35K) — güncellenmeli (DH tablo revize)
- Figures: `fig2_dh_causality_network.tiff` güncellenmeli (yeni DH sonuçları)
- 22/22 referans Zotero-doğrulandı ✅

## GAUSS Lite Kurulum (CrossOver yolu — Mac M1)

1. CrossOver Mac kur: `codeweavers.com` (~$64)
2. Windows 10 bottle oluştur → `GAUSS_Light_21_Win_64.zip` kur (mevcut: `100-Inbox/Materyaller/`)
3. NK2024 GAUSS kodu al: `sites.google.com/site/caginkarul/research` veya `caginkarul@pau.edu.tr`
4. `08_gauss_bridge_export.R` çalıştır → `gauss_input/` hazır
5. GAUSS'ta `nk2024_gi_struct_TEMPLATE.prg` çalıştır → `gauss_output/nk2024_results.csv`
6. NK2024 sonuçları robustness olarak ekle

## Pending Before Submission

- [x] **Tablo 4 güncellendi ✅ (2026-04-26):** `03-Results/tables/word/tab4_dh_causality.docx` — Ztilde sütunu + doğrulanmış değerler (ln REN → ECI NS corrected)
- [x] **fig2 güncellendi ✅ (2026-04-26):** `03-Results/figures/fig2_dh_causality_network.{pdf,png,tiff}` — 12_dh_causality_primary.csv tabanlı
- [x] **Table A7 oluşturuldu ✅ (2026-04-26):** `03-Results/tables/word/tabA7_csdm_robustness.docx` — csdm MG/CCE/DCCE/CS-ARDL, Appendix'e eklenecek
- [x] Funding beyanı: "no specific grant" ✅ (Cover_Letter_JCP_v04.md)
- [x] Cover letter v04: MGO email ✅
- [ ] **v06_JCP.docx oluştur:** Word'de v05'i aç → Table 4'ü tab4_dh_causality ile değiştir → tabA7_csdm_robustness'ı Appendix'e ekle → kaydet
- [ ] GAUSS Lite CrossOver kurulunca: NK2024 robustness ekle (birincil değil)

## csdm Robustness (2026-04-26) — ✅ ÇALIŞTIRILDI

**CD(FE residuals) = 0.631 p=0.528 → CSD absent in residuals** (individual series CSD p<0.01 ayrı)
All contemporaneous slopes NS across MG/CCE/DCCE/CS-ARDL → consistent with ECT interpretation.
ECT=−0.932*** (Python linearmodels) remains the primary evidence of the long-run relationship.
Appendix Table A7 template → `600-Methods/590-Dynamic-Hetero-Panel-Frontier/RESULTS_GI_CSDM_20260426.md`
Cite: csdm v1.0.1 (CRAN 2026-03-23); Juodis et al. (2024) JoE 240(1).

## Status

**SUBMISSION READY — DH nedensellik doğrulandı ✅ (2026-04-22) | csdm robustness ✅ (2026-04-26)**
**Bekleyen:** Tablo 4 + fig2 DH güncellemesi → Appendix Table A7 csdm → JCP submit
