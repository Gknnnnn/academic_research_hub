# Metodoloji Yolculuğu, Altyapı ve Gelecek Planları — MGO Portföyü

## Metodolojik Evrim: Nasıl Bu Noktaya Geldik?

Dr. Özdemir'in metodolojik yolculuğu, standart OLS regresyonundan başlayıp dünyada yalnızca birkaç araştırma ekibinin kullandığı özel GAUSS kodlarına kadar uzanan geniş bir yelpazeyi kapsıyor. Bu yolculuğu anlamak, araştırma kalitesini ve yayın kapasitesini anlamanın anahtarı.

**Başlangıç noktası:** Panel sabit etkiler, rassal etkiler, Hausman testi — bunlar panel veri analizinin temel araç kutusunu oluşturuyor. Ancak bu araçlar önemli bir varsayım taşıyor: ülkeler arasında korelasyon yok, yani kesit bağımlılığı yok.

**Kritik sorun:** Enerji fiyatları, küresel ticaret, jeopolitik şoklar ve iklim değişkeni açısından ülkeler birbirinden bağımsız değil. ABD Merkez Bankası'nın faiz kararı Türkiye'yi, Brezilya'yı ve Güney Afrika'yı eş zamanlı etkiliyor. Bu kesit bağımlılığı göz ardı edildiğinde istatistiksel çıkarım ciddi biçimde bozuluyor.

**Çözüm: Nesil 2 Panel Testleri**

Pesaran'ın 2007 yılında geliştirdiği CIPS testi, kesit bağımlılığını Ortak Bağıntılı Etkiler (Common Correlated Effects) yaklaşımıyla modelliyor. Birim kök testinin ötesinde, Westerlund eşbütünleşme testi de bootstrap ile kombinlenerek güvenilir p-değerleri üretiyor.

## Fourier Dönüşümleri: Kırılmaları Modellemek

Klasik birim kök testleri yapısal kırılmaları keskin bir geçiş olarak modelliyor: bir tarihten önce bir rejim, o tarihten sonra başka bir rejim. Ama gerçek ekonomi böyle işlemiyor. 2008 küresel finansal krizi aniden gelmedi; aylarca öncesinden oluşan birikim süreçleri vardı.

Fourier dönüşümlü testler (Karul-Nazlıoğlu 2017, Fourier-LM panel birim kök), kırılmaları yumuşak geçişler biçiminde modelliyor. Hem zamanlama hem de şiddet parametresi veri tarafından belirleniyor. Bu, özellikle Türkiye ve Avrasya ülkelerinde siyasi dönüşüm dönemlerini modellemek için son derece güçlü.

**Kritik kural:** Bu testler yalnızca GAUSS yazılımıyla çalıştırılabilir. R veya Python'a el ile aktarılan versiyonlar Karul tarafından teyit edilemez; bu nedenle Özdemir'in Anayasası açıkça yasaklıyor.

## NK2024: Panel Nedenselliğin Sınırını Zorlamak

Nazlıoğlu-Karul 2024 (NK2024) panel Granger nedensellik testi, şu ana kadar geliştirilen en güncel yaklaşımlardan biri. Klasik Dumitrescu-Hurlin (2012) testi önemli bir eksikliğe sahip: kesit bağımlılığı varken yanıltıcı sonuçlar üretiyor.

NK2024 bu sorunu şöyle çözüyor: önce PANIC faktör modeli ile ortak faktörleri çıkartıyor, sonra artık bileşenler üzerinde panel VAR nedenselliği test ediyor. Holm düzeltmesiyle çoklu karşılaştırma problemi de gideriliyor.

Kodlar doğrulandı: `600-Methods/NK2024_GAUSS/` klasöründe `panic()` ve `panicca()` fonksiyonları mevcut. Bu metodoloji YK Finance-Growth makalesinde Pm=5.954 test istatistiğiyle zaten kullanıldı.

## Roudane Python Ekosistemi: 39 Paket

Özdemir, Roudane'ın ekonometri yazılım paketlerini sistematik biçimde değerlendirerek 39 paketi kurdu ve test etti. Bu paketler şu ana kategorileri kapsıyor:

- **Birim kök (A kümesi):** Doğrusal olmayan ESTAR testi, Fourier-ADF, wavelet ön-filtreli ADF, kantil ADF
- **Eşbütünleşme (B kümesi):** Student-t robust eşbütünleşme, çift kırılmalı eşbütünleşme, Fourier eşbütünleşme
- **NARDL (C kümesi):** Asimetrik ARDL, kantil ARDL, wavelet-NARDL
- **Kantil/Wavelet (D kümesi):** QQ regresyon, kantil-kantil kernel least squares
- **Nedensellik (E kümesi):** Frekans bazlı nedensellik, bootstrap nedensellik
- **Panel (F kümesi):** Panel NARDL, panel CS-ARDL

Önemli bir uyarı: birkaç pakette bilinen hatalar var. `pycupfm` LSDV bug nedeniyle kullanılamıyor; `pmct` sıfır boyut hatası veriyor. Bu tuzaklar belgelendi ve metodoloji kararı verirken kontrol listesinde.

## Global Panel Veri Altyapısı

Özdemir 261 değişken × 5 grup kombinasyonundan oluşan kapsamlı bir panel veri altyapısı kurdu. Kaynaklar: Dünya Bankası WDI, Dünya Yönetişim Göstergeleri (WGI), Our World in Data (OWID), Penn World Tables (PWT), IMF, GPR (Jeopolitik Risk) endeksi, FRED, FAOSTAT ve ILO.

Veri doluluk oranı %91'in üzerinde; yalnızca iki veri seti henüz tamamlanmadı: ECI (Ekonomik Karmaşıklık Endeksi) ve AgTFP (Tarımsal TFP).

Bu altyapı sayesinde yeni bir araştırma sorusu ortaya çıktığında veri toplama süreci minimize ediliyor. "İçinde veri olan" bir araştırmacı olarak başlamak çok önemli bir rekabet avantajı.

## Quarto ile Yeniden Üretilebilir Araştırma

Tüm makaleler Quarto (.qmd) dosyaları olarak yazılıyor ve hem DOCX hem PDF olarak render ediliyor. Bu yaklaşım üç avantaj sağlıyor:

**Birincisi, yeniden üretilebilirlik:** R kod blokları doğrudan makalenin içine gömülü. Katsayı değerleri, p-değerleri ve güven aralıkları kod çıktısından otomatik olarak çekiliyor. El ile sayı girişi yok.

**İkincisi, sürüm kontrolü:** Git ile her değişiklik kayıt altına alınıyor. "Dün çalışan versiyona dönebilir miyim?" sorusunun yanıtı her zaman evet.

**Üçüncüsü, teknik esneklik:** DOCX (dergi şablonu için), PDF (hakeme gönderim için) ve HTML (web önizleme için) aynı kaynak dosyadan üretiliyor.

## Zotero Kütüphanesi

5.907 referans, 405 koleksiyon. Bu kütüphane yalnızca bir referans yöneticisi değil; araştırma hafızası. Her eklenen referans DOI ile doğrulanmış, her atıf CrossRef üzerinden teyit edilmiş.

Hayalet atıf — gerçekte var olmayan referans — akademik kariyeri bitirebilir. 2026 yılında *Nature*'da yayımlanan bir çalışma, GPT-4o'nun ürettiği atıfların %20'sinin tamamen hayali olduğunu ortaya koydu. Özdemir bu riski sıfıra indirgemek için her DOI'yi elle tıklayarak doğruluyor.

## CE: Kognitif Ekonometri — Sınır Çalışması

Bu çalışma metodolojik açıdan en özgün olanı. AB-27 ülkelerinde makroekonomi ile bilişsel performans göstergeleri arasındaki ilişkiyi beş farklı model çerçevesinde araştırıyor.

Veri kaynağı alışılmadık: Eurobarometer (GESIS) bireysel bilişsel değerlendirme verileri makroekonomik panel veriyle birleştiriliyor. M1/M2 verileri henüz GESIS'ten bekleniyor; diğer beş model hazır. Şekil M9 dahil PDF tamamlandı, 879KB, 25 sayfa. Ekolojik ekonomi veya Journal of Cleaner Production hedefleniyor.

## TEFAS: Veri Toplamada Yaratıcı Çözümler

Türkiye'deki TEFAS (Türkiye Elektronik Fon Alım Satım Platformu) verileri, para politikası şoklarına yatırım fonu akışlarının nasıl tepki verdiğini incelemek için gerekli. Ancak TEFAS API'si devre dışı bırakıldı.

Alternatif stratejiler: manuel indirme, Safari WebDriver ile otomasyon, Takasbank'a doğrudan email. Bu tür veri engelleri akademik araştırmada sıkça karşılaşılan pratik zorluklardır; metodoloji genellikle veri erişim kısıtlamalarıyla şekilleniyor.

## EÜYM ile Portföy Optimizasyonu

Özdemir, 2026 yılında tüm portföyüne yeni bir karar metriki uyguladı: EÜYM (Beklenen Aylık ÜAK Verimi). Formül basit ama etkisi büyük:

EÜYM = (ÜAK puanı × Kabul oranı) / Kabul süresi (ay)

Bu metriği 40 projeye uyguladığında iki kritik sorun ortaya çıktı:

Birincisi, P6 Digital Assets için hedeflenen JIMF dergisi 250 dolar iade edilmez ücret talep ediyor. EÜYM yalnızca 0.33 — portföyün en düşük değeri. Çözüm: JIFMI veya IREF'e yönlendirme.

İkincisi, Currency Misalignment çalışması için hedeflenen Economic Modelling 125 dolar iade edilmez ücret istiyor. Alternatif: Journal of Policy Modeling, sıfır ücret ve EÜYM 1.80.

Bu iki yönlendirme değişikliği, aynı çalışma yoğunluğuyla portföy genelinde yıllık yaklaşık 0.5 ek EÜYM üretecek.

## Kariyer Takvimi ve Sonraki Büyük Adımlar

**Mayıs 2026 — Kısa Vade:**
- DATAMACLEA'26 konferansı (11-13 Mayıs), JEVONS bildirisi
- RSEP Barselona (14-16 Mayıs)
- BCRP (25 Mayıs) özet
- IGI Global bölüm (29 Mayıs)
- Karul GAUSS eğitimi sertifikası (+30 puan)

**Yaz-Güz 2026 — Orta Vade:**
- 3 Q1 SSCI yayını için aktif submission
- TÜBİTAK 1002-A başvurusu
- Food-Regime + Gravity-FoodSec + CE tamamlama

**2027 ve Sonrası — Uzun Vade:**
- Doçentlik başvurusu için minimum 120 ÜAK puanı
- Karul işbirliği → 1 ortak Q1 yayını
- Bäckman işbirliği → konut finansmanı
- TÜBİTAK 1001 lider araştırmacı başvurusu
- EkolEcon'da davranışsal nöroekonomi çalışması

## Araştırma Altyapısının Büyüklüğü

Son bir sayısal tablo: Özdemir'in araştırma altyapısı ne kadar büyük?

- 5.907 Zotero referansı
- 261 panel değişkeni × 5 veri grubu
- 39 kurulu Python paketi
- 40 aktif makale
- 19+ gönderime hazır paket
- 4 Claude Code hook ile otomatik kontrol
- 4 CI pipeline görevi
- 403 dosya GitHub'da
- 13 özel Claude becerisi (skills)

Bu altyapı, yeni bir araştırma sorusu ortaya çıktığında Özdemir'i minimum hazırlık süresiyle analiz aşamasına geçirmeye hazır tutuyor. Araştırma verimliliği yalnızca zekaya değil, aynı zamanda bu sistematik altyapıya dayanıyor.

## Sonuç: Araştırmacı mı, Sistematik mi?

Dr. Özdemir'i birçok çalışma arkadaşından ayıran şey, bir araştırma makinesine dönüşmüş olması değil. Aksine: her çalışmasında gerçek bir soru soruyor, her metodoloji tercihinde bir neden olduğunu biliyor ve her katsayıyı politika birimine çevirmeyi zorunlu görüyor.

"İktisat, insan tercihlerini ve kısıtlarını anlamaktır" anlayışı, 40 makalenin hepsinde ortak bir iplik gibi geçiyor: altın mı tutuyor insan, emisyon mu üretiyor, göç mü ediyor, kurum mu kuruyor — bunların hepsinin ardında bir tercih ve bir kısıt var. Akademik ekonometrinin görevi bu tercihleri ve kısıtları veriden okumak.
