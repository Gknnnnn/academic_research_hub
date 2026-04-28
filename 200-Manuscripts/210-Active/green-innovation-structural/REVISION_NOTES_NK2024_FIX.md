# Green Innovation — NK2024 Karul Kural İhlali: Revision Notu

**Tarih:** 2026-04-28  
**Tespit:** NK2024 panel nedensellik testi R implementasyonu kullanılmış. ANAYASA Karul-GAUSS Kuralı ihlali.

## Yapılacak Düzeltme (DOCX'te manuel)

### Nedensellik Bölümünde (causality/nedensellik bulguları tablosunu içeren kısım):

**Mevcut durum (ihlal):**
```
NK2024 panel causality test (Nazlıoğlu & Karul, 2024) results show...
```

**Düzeltilmiş durum (ANAYASA uyumlu):**
```
As a robustness check, the Dumitrescu-Hurlin (2012) heterogeneous panel
causality test is employed as the primary causality framework. 
[NK2024 results — if run in GAUSS — are reported in Appendix X as supplementary evidence.]
```

### Yöntem Bölümünde:

- NK2024'ü "primary" test olarak tanımlayan her cümleyi "robustness" veya "supplementary" olarak değiştir
- DH2012 (Dumitrescu-Hurlin) birincil nedensellik testi olarak konumlandır
- NK2024 için: "run using the GAUSS implementation provided by the authors" — GAUSS yoksa bu testi tamamen kaldır

### GAUSS yoksa güvenilir alternatif:
- **DH2012** (`plm::pgrangertest`, CRAN ✅) → birincil causality test olarak yeterli
- Footnote ekle: "Following Dumitrescu & Hurlin (2012), we apply the panel causality test
  robust to heterogeneous slope coefficients. The Nazlıoğlu-Karul (2024) PANIC-VAR extension
  requires GAUSS implementation (Karul, 2024) and is reserved for future work."

## Düzeltme Öncesi Kontrol Listesi

- [ ] Manuscript'te "NK2024" geçen tüm yerleri bul (Find & Replace)
- [ ] NK2024'ün birincil mi yoksa robustness mü olduğunu belirle
- [ ] NK2024 R kodu referansını kaldır
- [ ] DH2012 sonuçlarının tabloda yer aldığını teyit et (tab4_dh_causality.docx mevcut ✅)
- [ ] Cover letter'da NK2024'e atıf varsa kaldır
- [ ] v03.docx olarak kaydet ve ZIP'i yeniden oluştur

## Neden Bu Önemli?

Karul (PAÜ) ile işbirliği planlanıyor. NK2024'ün R replikasyonunu kullanan bir makale
Karul'a gönderilemez ve GAUSS gerektiren testlerin sonuçları GAUSS olmadan savunulamaz.
Bkz. CLAUDE.md → Damokles Kılıcı — Karul-GAUSS Metodoloji Kuralı.
