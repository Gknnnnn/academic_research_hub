# Vault Migration Guide

Bu vault'ta iki yapı birlikte bulunuyor:

- Legacy klasörler: `01_...` ile `99_Exports`
- Aktif ROC klasörleri: `000-Inbox`, `100-Literature`, `200-Concepts`, `300-Projects`, `400-Data`, `500-Methods`, `600-Templates`, `700-Analysis-Output`, `800-Bibliography`, `900-Dashboard`

Karar:

- Yeni üretim sadece ROC yapısında devam eder.
- Legacy klasörler silinmez; dondurulur ve gerektiğinde arşivlenir.
- Açık eşleşmesi olan bazı dosyalar yeni yerine taşınmıştır.

Eşleme:

- `01_Literature_Review` -> `100-Literature`
- `02_Theoretical_Framework` -> `200-Concepts`
- `03_Data_Raw` -> `400-Data`
- `04_Data_Cleaned` -> `700-Analysis-Output`
- `05_Econometric_Models` -> `500-Methods`
- `06_Results_Tables` -> `700-Analysis-Output`
- `07_Manuscript_Drafts` -> `300-Projects`
- `08_Zotero_Sync` -> `800-Bibliography`
- `09_Python_Scripts` -> `500-Methods` veya `research-ops/scripts`
- `10_R_Scripts` -> `500-Methods/510-R-Scripts`
- `11_Notes_Obsidian` -> `200-Concepts` veya proje klasörleri
- `12_Graphics_Outputs` -> `700-Analysis-Output/720-Figures`
- `13_Conference_Papers` -> `300-Projects/310-Active-Papers`
- `14_Journal_Submissions` -> `300-Projects/320-Submitted-Papers`
- `15_Archive` -> legacy arşiv
- `16_Admin_Docs` -> vault dışı admin klasörü tercih edilir
- `99_Exports` -> `700-Analysis-Output` veya `800-Bibliography`

Taşınan dosyalar:

- `02_Theoretical_Framework/Metodolojik_Notlar.md` -> `200-Concepts/220-Econometric-Methods/Metodolojik_Notlar.md`
- `03_Data_Raw/WB_Data_Raw.csv` -> `400-Data/420-WorldBank/WB_Data_Raw_legacy.csv`
- `04_Data_Cleaned/ADF_Stationarity_Report.md` -> `700-Analysis-Output/730-Model-Diagnostics/ADF_Stationarity_Report.md`
- `07_Manuscript_Drafts/EKC_BRICST_Draft.md` -> `300-Projects/310-Active-Papers/EKC_BRICST/drafts/EKC_BRICST_Draft.md`

Not:

- Legacy script klasörleri şimdilik yerinde bırakıldı; kırılma riskine karşı yalnızca yönlendirme uygulanıyor.
- `venv`, `scripts`, `dashboard`, `lightrag_db` gibi teknik çalışma dizinleri mümkünse uzun vadede vault dışına çıkarılmalıdır.
