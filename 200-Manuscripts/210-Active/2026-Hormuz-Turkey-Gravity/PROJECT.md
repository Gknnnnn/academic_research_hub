# PROJECT: Hegemonik Rekabet × Hürmüz × Türkiye Gravity

**Başlık (taslak):** "Hegemonik Rekabet ve Ticaret Güzergahı Dönüşümü: Hürmüz Senaryosu Altında Türkiye'nin Lojistik Pozisyonu Üzerine Bir Gravity Analizi"

**Ortak Yazar:** Öğr. Gör. İlteriş Kaan Barun (KKÜ MYO, Gayrimenkul Yönetimi, sicil A-5268)
**MGO:** Res. Asst. Dr. M. Gökhan Özdemir — §4 Ekonometri

**Hedef:** İzmir İktisat Dergisi (TR Dizin) | ~7.500 kelime
**ÜAK:** 10 puan (TR Dizin)
**Durum:** Kavramsal aşama → §4 geliştirme → tam taslak

## Metodoloji (MGO §4)
- Model: PPML Gravity (Santos-Silva & Tenreyro 2006)
- Birim: İkili ticaret — Türkiye × 80 partner, 2010–2024
- Bağımlı: ln(Ticaret_ij) [BACI HS92 toplam]
- Bağımsız: GPR_i, Hormuz_dummy, GeoDist_ij, BRI_j, GDP_i, GDP_j

## 🔴 BREAKING — Hicaz Demiryolu 20 Nisan 2026'da Resmen Duyuruldu

Türkiye, Suriye ve Ürdün, 20 Nisan 2026'da **Körfez-Avrupa Demiryolu Koridoru** için 1,3 milyar dolarlık yatırım anlaşması imzaladı.
- Kaynak: Jerusalem Post + TRT World + Gulf News (2026-04-20)
- Makalenin "senaryo" çerçevesi gerçek zamanlı bir politika gelişmesiyle örtüşüyor
- Bu bulgu §5 "Türkiye Stratejik Pozisyonu" bölümünü doğrudan güçlendiriyor
- **Akademik özgünlük**: Hicaz hattı × PPML gravity → literatürde hiç yapılmamış

## Veri Kaynakları
- BACI HS92: http://www.cepii.fr/CEPII/en/bdd_modele/download.asp?id=1
- GPR Index: https://www.matteoiacoviello.com/gpr.htm
- CEPII GeoDist: http://www.cepii.fr/CEPII/en/bdd_modele/download.asp?id=6
- WDI GDP: World Bank API

## Klasörler
- 01-Data/   → ham veri (tarih damgalı)
- 02-Code/   → R betikleri
- 03-Output/ → tablolar, şekiller
