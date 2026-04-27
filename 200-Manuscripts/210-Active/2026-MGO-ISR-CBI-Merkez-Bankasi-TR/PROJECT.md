# PROJECT: ISR CBI — Türkiye Merkez Bankası Bağımsızlığı (Tek Ülke ARDL)

**Objective:** De facto merkez bankası bağımsızlığı erozyonunun (2019-2023) enflasyon beklentileri üzerindeki etkisi — Türkiye tek-ülke, aylık zaman serisi.

**Authors:** Solo — Res. Asst. Dr. M. Gökhan Özdemir (KKÜ, ORCID: 0000-0002-6756-7285)

**Target Journal:** ISR / The Journal of International Scientific Researches (DergiPark, eISSN 2458-8725)

**⚠️ NOT (2026-04-22):** Önceki PROJECT.md YANLIŞ çalışmayı tanımlıyordu (BRICS-T+MINT panel, tahvil getiri farkı). Gerçek makale aşağıda tanımlanan tek-ülke ARDL çalışmasıdır.

## Data

| Seri | Kaynak | Kapsam |
|------|--------|--------|
| 12m/24m enflasyon beklentileri | CBRT EVDS3 (TP.PKAUO) | 2013M1–2025M12 |
| Politika faizi | CBRT BIST O/N | 2013M1–2025M12 |
| USD/TRY | CBRT EVDS | 2013M1–2025M12 |
| CPI (yıllık/aylık) | CBRT EVDS | 2013M1–2025M12 |
| Brüt rezervler | CBRT EVDS | 2013M1–2025M12 |
| De jure CBI (CBIE) | Romelli (2022, 2025) cbidata.org | 2015–2023 |
| De facto CBI olayları | Manuel kodlama (başkan görevden almaları + heterodoks dönem) | 2019–2023 |

**Temel örneklem:** N=144 (2013M1–2024M12); robustness N=156 (2025M12 dahil)

## Methodology

1. ADF + Zivot-Andrews + Clemente-Montañes-Reyes birim kök (yapısal kırılma duyarlı)
2. Bai-Perron yapısal kırılma testi (3 kırılma: 2018M04, 2021M12, 2024M01)
3. PSS (2001) sınır testi kointegrasyon (k=5; 12m: F=6.610 > %5 sınırı ✅; 24m: F=2.371 sonuçsuz)
4. İmzalı birikim ARDL-ECM: neg_cbi_stock + pos_cbi_stock (NARDL-ilhamlı, olay sayaçları için uyarlandı)
5. Hata düzeltme modeli (asimetrik: d_neg_cbi vs d_pos_cbi)
6. Ayrıştırma testi: görevden alma biriktiricisi vs. heterodoks rejim biriktiricisi (Tablo 1B)
7. Granger nedensellik ön testi (ters nedenselliği test: p=0.778/0.863 → dışsallık destekleniyor)
8. HAC standart hatalar (Newey-West, bant=4)
9. Sağlamlık: rezervler, swap, M2, fonlama maliyeti, CDS, verim farkı kontrolleri
10. Zamanlama placebo: ±3 aylık kaydırma

**Yazılım:** R (primary — lmtest, sandwich, strucchange, urca)

**Webb bootstrap:** UYGULANMAZ — tek ülke zaman serisi (küme yok)

## Temel Bulgular

- Heterodoks rejim biriktiricisi: β=1.780*** (12m, HAC t=7.69); β=0.730*** (24m, HAC t=6.70)
- Görevden alma biriktiricisi: istatistiksel sıfırdan ayırt edilemez (12m: t=0.10; 24m: t=−0.59)
- ECT: Bai-Perron alt-rejimlerin tamamında negatif (−0.13; −0.21**; −0.59**)
- Granger: gecikmeli beklentiler heterodoks rejimi öngörmüyor (F=0.366/0.248, p=0.778/0.863)

## Output

- Türkçe makale (ISR şablonu, Book Antiqua 11pt, APA 6.0)
- EN Extended Abstract ≈750 kelime (ISR §3 zorunluluğu)
- DOCX: `Turkey_CBI_ISR_submission_v0.9_corrected.qmd` → render edilecek

## Submission

- **GÖNDERİLDİ:** 21 Nisan 2026 | DergiPark ID: 1935599
- **Editör atama:** 1 Mayıs 2026'ya kadar bekleniyor
- **v0.9 düzeltmeleri (2026-04-22):** (1) abstract sırası TR→EN, (2) EN abstract 183→180 kelime, (3) 53 atıf `(Yazar & Yazar, Yıl)` formatına dönüştürüldü, (4) YAML yazar adı/ORCID/kurum tam eklendi

## Status

**Gönderildi — Sekretarya/Editör kararı bekleniyor (Eylül 2026 sayısı hedefi)**
