# MCP Profile Matrix

Bu belge, farkli is akislari icin hangi MCP profilinin secilecegini hizli gostermek icin hazirlandi.

## 1) `economic-research`

Amac:
- literatur tarama
- veri ve yontem notlarini toplama
- aktif proje kesfi
- JEL, Zotero ve bibliyografya uzerinden konu sentezi

Aktif serverlar:
- `research_nexus`
- `fetch`
- `filesystem`
- `time`

Tipik gorevler:
- belirli bir konuda literatur snapshot cikarmak
- aktif proje durumunu ozetlemek
- yontem ve veri kisitlarini belgelemek
- teslim ve konferans tarihlerini netlestirmek

Neden iyi calisir:
- depo ici arastirma hafizasi ile dis kaynaklar birlesir
- yazma yetkisi gerektirmeden yuksek kesif degeri uretir

## 2) `paper-writing`

Amac:
- manuscript revizyonu
- bolum tutarlilik kontrolu
- kaynak ve arguman hatti duzeltme
- submission oncesi paket kontrolu

Aktif serverlar:
- `research_nexus`
- `filesystem`
- `time`

Gorev bazli acilabilecekler:
- `fetch`

Tipik gorevler:
- belirli draft klasorundeki belgeleri karsilastirmak
- eksik submission dosyalarini bulmak
- revizyon notlarini mevcut taslaga baglamak
- deadline ve resubmission takvimini netlestirmek

Neden iyi calisir:
- daha dar ve kontrollu bir profil sunar
- yazim asamasinda gereksiz web erisimini azaltir

## Hizli secim kurali

- konu arastirma, literatur ve veri tarafi agirsa: `economic-research`
- draft, revizyon ve submission tarafi agirsa: `paper-writing`

## Gecis mantigi

1. Fikir ve kaynak taramasinda `economic-research` ile basla.
2. Draft belirginlestiginde `paper-writing` moduna gec.
3. Web kaynagi sadece gercekten gerekiyorsa `fetch` ac.
