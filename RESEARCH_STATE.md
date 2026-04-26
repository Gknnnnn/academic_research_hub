# RESEARCH_STATE.md
_Son güncelleme: 2026-04-09 — Cowork Oturumu (3 Platform Sentezi + Atanma Stratejisi)_

---

## 🎯 AKTİF MİSYON
**Dr. Öğretim Üyesi atanma başvurusu** → **0-6 ay içinde en az 1 SSCI/SCI kabul**
- Mevcut SSCI: **0**
- Hedef: ≥1 SSCI kabulü (Kırıkkale Üniversitesi zorunlu kriter)
- Bugünkü tarih: 2026-04-09

---

## 🔴 EN ACİL: 3 PARALEL GÖNDERİM

### P1 — ARDL Climate-Agriculture Turkey [HAFTAYA GÖNDERİM]
- **Başlık:** "Climate Change and Agricultural Value Added in Turkey: Long-Run Elasticities from an ARDL Bounds Test, 1970–2021"
- **Dosya:** `200-Manuscripts/210-Active/2026-MGO-Climate-Agriculture-Turkey-ARDL/`
- **Durum:** v03 HAZIR (2026-04-09) · Cover letter JEM ✅ · Cover letter Ecol.Econ ✅
- **Hedef dergi:** Journal of Environmental Management (Q1, IF 8.9, SSCI) → 1. tercih
- **Kalan engeller:**
  - [x] ~~`tsso` birim notu~~ ✅ constant 2015 USD (FAOSTAT) — v04'e eklendi
  - [x] ~~`co2` birim notu~~ ✅ Mt CO₂e excl. LULUCF (WB WDI) — v04'e eklendi
  - [ ] Prof. Işık Hoca'ya co-author sign-off e-postası gönder (şablon hazır)
  - [ ] JEM submission portalına yükle (Elsevier Editorial Manager)
- **Tahmini gönderim:** Bu hafta veya gelecek hafta
- **Tahmini karar:** ~2-3 ay (Haziran-Temmuz 2026)

### P2 — Scopus Bibliometrics [3-4 HAFTADA GÖNDERİM]
- **Dosya:** `200-Manuscripts/210-Active/2026-Scopus-MGK-MGO/`
- **Durum:** v12 mevcut · Dockerfile + replication ✅ · Pre-submission checklist eksik
- **Hedef dergi:** HRPUB — Environment and Ecology Research (EER) ⚠ NOT WoS/SSCI (ÜAK saymaz)
- **Kalan engeller:**
  - [ ] Word count kontrolü
  - [ ] Abstract yapılandır (journal template)
  - [ ] JEL kodları ekle
  - [ ] Graphical abstract (gerekirse)
  - [ ] CRediT + Declaration of interests
  - [ ] Robustness protokolü tamamla

### P3 — UY-MGO Sustainability Nexus [5-6 HAFTADA GÖNDERİM]
- **Dosya:** `200-Manuscripts/210-Active/2026-UY-MGO-Makale/`
- **Hedef dergi:** Ecological Economics (Q1, IF 6.3) → Resources, Conservation and Recycling (Q1, IF 13.2)
- **Kalan engeller:** Pre-submission checklist (P2 ile aynı adımlar)

---

## 📊 PORTFÖY DURUMU (3 Platform Sentezi)

| Platform | Yayın | Atıf | h | Görüntü |
|---|---|---|---|---|
| Google Scholar | 44 | 39 | **4** | — |
| ResearchGate | 47 | 13 | 2 | 592 RIS |
| Academia.edu | 42+ | — | — | 27,161 |
| **BİRLEŞİK** | **~58** | **39+** | **4** | **27K+** |

---

## 📁 AKTİF MANUSCRIPT KLASÖRÜ (210-Active)

Kritik dosyalar:

| Proje | Durum | Hedef Dergi | Öncelik |
|---|---|---|---|
| 2026-MGO-Climate-Agriculture-Turkey-ARDL | **v03 HAZIR** | JEM (IF 8.9) | 🔴 HEMEN |
| 2026-Scopus-MGK-MGO | **v3 HAZIR** — Highlights/CRediT/ORCID/JEL eklendi | HRPUB EER (hrpub.org/id=40) | 🔴 KULLANICI KARARI — bu dergiye gidecek | ⚠ WoS tam indeksli değil |
| 2026-UY-MGO-Makale | Checklist eksik | Ecol.Econ (IF 6.3) | 🟠 5-6 hafta |
| 2026-Konya-HBI-Agricultural-Floor | Kongre teslim edildi ✅ | Q1 revizyon | 🟡 2. aşama |
| EKC_BRICST | Taslak mevcut | J.Env.Management | 🟡 2. aşama |
| 2026-Dincer-MGO-Migration-Carbon | 01-04 klasör yapısı | Energy Economics | 🟡 2. aşama |
| 2026-HBI-Tarim-Konya | Kongre sonrası | Q1 tarım | 🟡 2. aşama |
| 2026-IL-AZ-Gravity | Başlangıç | Eurasian Geog.Econ | 🟢 Uzun vade |
| 2026-MGO-Thesis-To-Book | Planlama | Monograf | 🟢 Uzun vade |

---

## ⚠️ ÇÖZÜLMESI GEREKEN TEKNİK SORUNLAR

### ARDL Makalesi — Birim Doğrulaması
- `tsso` = Tarımsal SGYO, milyon cari TL — EViews workfile'dan doğrula
- `co2` = Toplam emisyon, milyon metrik ton — kişi başına çevirmek gerekmez (istatistiksel anlamsız, kağıt bulgularını etkilemez)
- Regresyon natural log'da kurulduğundan elastikiyet katsayıları (β=+0.527, +0.375, -2.349) unit'ten bağımsız
- Ana bulgular: F=8.706*** (koentegrasyon), ECT=-0.277*** (yarı-ömür 2.1 yıl)

### Veri Dosyası
`data/turkey_climate_agri_1970_2021.xlsx` sütunları:
- `Yıl` | `Alan` (ha) | `tkd` (tarımsal katma değer, TL) | `co2` (mt) | `tsso` (milyon TL?) | `tsa` (°C) | `pr` (mm)

---

## 🗓️ 6 AYLIK EYLEM TAKVİMİ

| Zaman | Eylem |
|---|---|
| **Bu hafta (9-13 Nis)** | ARDL birim notları → Hoca sign-off e-postası → JEM'e gönder |
| **3-4. hafta** | Scopus-MGK-MGO checklist → gönder |
| **5-6. hafta** | UY-MGO checklist → gönder |
| **Ay 2-3** | ARDL hakem yanıtı & revizyon |
| **Ay 3-4** | Konya makalesini Q1 revizyon için hazırla |
| **Ay 4-5** | İlk SSCI kabulü beklentisi |

---

## 📚 AKADEMİK PORTFÖY YOL HARİTASI RAPORLARI

- v1.0: Google Scholar analizi → `/outputs/research-roadmap/Akademik_Portfoy_Yol_Haritasi_Ozdemir_2026.docx`
- v2.0: 3 platform sentezi → `/outputs/research-roadmap/Akademik_Portfoy_Yol_Haritasi_v2_Ozdemir_2026.docx`

---

## 🔑 SONRAKI OTURUM İÇİN BAĞLAM

Önce şunu sor: "Hangi çalışmadan devam edelim?"

**Seçenekler:**
1. ARDL makalesini gözden geçir + JEM'e gönderime hazırla
2. Scopus bibliometri çalışmasını bitir
3. UY-MGO çalışmasını tamamla
4. Konya Q1 revizyonuna başla
5. Genel portföy durumunu güncelle

---


---
**Last updated:** 2026-04-09 Session 2
**ARDL manuscript status:** v05 — 13 peer-review edits applied; submission-ready
**Immediate next step:** Open Elsevier Editorial Manager → submit v05 + cover letter to JEM


**P2 pre-submission fixes completed 2026-04-09:** v3.docx ready. Remaining: MGK affiliation confirm → portal submit to JEM (editorialmanager.com/jema).


---
## ⚠️ KRİTİK HAFIZA NOTU — P2 DERGI HEDEFİ

**P2 (2026-Scopus-MGK-MGO) → HRPUB Environment and Ecology Research (EER)**
- URL: https://www.hrpub.org/journals/jour_index.php?id=40
- Bu karar kullanıcı tarafından açıkça verildi (2026-04-09): "UNUTMA BUNU!!!"
- APC: ~$480 | Q4 | WoS tam indeksli DEĞİL | ÜAK atanma için SAYILMAZ
- Dr. Öğr. Üyesi atanma için bu yayın SSCI/SCI sayısını artırmaz
- Buna rağmen kullanıcının kararı bu dergi — tüm sonraki oturumlarda hatırla

**Submission portal:** https://www.hrpub.org/journals/jour_index.php?id=40
**Template:** `04-Manuscript/HRPUB_Manu_Template_V1.docx` — mevcut klasörde
