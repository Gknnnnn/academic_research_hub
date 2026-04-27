# PROJECT: Financial Development & Economic Growth — NK2024 Panel Causality

**Author:** Öğr. Gör. Dr. Adayı Yusuf Çelik  
**Analysis support:** Res. Asst. Dr. M. Gökhan Özdemir, Kırıkkale University  
**Title:** Financial Development and Economic Growth Nexus: Evidence from Factor Model-Based Panel Causality Approach  
**Type:** Conference paper (bildiri)  
**Status:** Analysis complete → manuscript writing

## Data
- **Panel:** G7 (Canada, France, Germany, Italy, Japan, UK, USA), N=7
- **Variables:** lnfd (log financial development), lngdp (log real GDP)
- **Period:** [CONFIRM WITH YUSUF — annual data]
- **Source:** [CONFIRM — World Bank WDI / IFS?]

## Method Pipeline
1. CSD test: LM, CDLM, CD (Pesaran) → ✅ CSD confirmed
2. Unit root: PANIC + PANICCA ADF → both I(1) at levels, I(0) at Δ
3. Causality: NK2024 LA-VAR PANIC + PANICCA (primary)
4. Benchmarks: EK2011 LA-VAR, DH2012 VAR, Konya SUR

## Key Results
- NK2024 PANIC: lnfd→lngdp Pm=1.802** (p=0.036) — supply-leading, weak
- NK2024 PANICCA: lngdp→lnfd Pm=5.954*** (p=0.000) — demand-following, strong
- EK2011: lngdp→lnfd 45.693*** > CV 22.871 ✅
- DH2012: lngdp→lnfd 13.851*** (bootstrap CV 5.115) ✅
- **Dominant direction: demand-following (Robinson 1952)**

## Files
- `03-Results/BÜYÜME FİNANSAL KALKINMA ANALİZSONUÇLARI.docx` — raw results
- `04-Manuscript/yk_finance_growth_nk2024_v01.qmd` — full paper QMD
