# MCP Research Playbook

Bu belge, aktif Codex MCP profilinin arastirma is akisinda nasil kullanilacagini kisaca tanimlar.

## Aktif profil

- `research_nexus`
- `fetch`
- `filesystem`
- `time`

## Hangi server ne icin

### `research_nexus`

En yuksek degerli arastirma sunucusudur.

Kullanin:
- aktif proje klasorlerini ozetlemek
- submission durum dosyalarini bulmak
- gate raporlarini okumak
- Zotero ve JEL indekslerinden hizli konu haritasi cikarmak
- belirli klasorlerde hedefli metin aramak

En iyi gorevler:
- "Bu proje klasorunun mevcut durumunu cikar"
- "Su konu icin literatur snapshot hazirla"
- "Son integrity raporlarini ozetle"

### `fetch`

Web icerigi cekmek ve dis kaynaklari hizlica okumak icin kullanin.

Kullanin:
- makale landing page icerigi cekmek
- proje veya veri seti dokumantasyonu okumak
- acik web kaynaklarindan tanim ve metod notu toplamak

En iyi gorevler:
- "Bu URL'deki icerigi ozetle"
- "Su sayfadaki veri tanimini cikar"
- "Yontem dokumantasyonundaki ana varsayimlari listele"

### `filesystem`

Depo icindeki dosyalara sinirli, dogrudan erisim saglar.

Kullanin:
- belirli markdown veya config dosyalarini okumak
- repo icinde hizli dosya kesfi yapmak
- bir klasordeki notlari veya ara ciktilari toplamak

En iyi gorevler:
- "Bu klasordeki markdown notlarini tara"
- "Su dosyadaki tabloyu bul"
- "Aktif proje altinda benzer notlari listele"

### `time`

Takvim, deadline ve zaman donusumu sorularinda kullanin.

Kullanin:
- teslim tarihi kontrolu
- timezone donusumu
- bugun, yarin, gecen hafta gibi ifadeleri netlestirmek

En iyi gorevler:
- "Europe/Istanbul'a gore bugun nedir"
- "Bu deadline New York saatine gore kacta"

## Onerilen kullanim sirasi

1. Konu veya proje sinirini `research_nexus` ile ciz.
2. Gerekirse dis kaynaklari `fetch` ile cek.
3. Yerel dosya dogrulamasi icin `filesystem` kullan.
4. Tarih ve teslim kontrolu gerekiyorsa `time` ile netlestir.

## Hazir prompt kaliplari

- "Aktif proje durumunu cikar, eksik dosyalari isaretle, sonraki 3 adimi oner."
- "Bu konu icin literature snapshot hazirla; JEL, Zotero ve ilgili notlari birlestir."
- "Su URL'yi oku, yontem, veri ve kisitlar olarak ozetle."
- "Bu klasorde submission'a hazir olmayan dosyalari bul."
- "Bu hafta icindeki deadline'lari Europe/Istanbul bazinda netlestir."

## Kacinin

- gereksiz genel web taramasi
- tum depoyu tek seferde yuklemek
- veri klasorlerinde yazma gerektirmeyen isler icin genis yetki vermek
- ayni isi hem `filesystem` hem `research_nexus` ile tekrarlamak

## Pratik kural

- Repo-ici yapisal arama: `research_nexus`
- Tekil dosya veya klasor okuma: `filesystem`
- Dis web kaynagi: `fetch`
- Tarih ve saat netlestirme: `time`
