# Enerji, Çevre, Tarım ve Gıda Güvenliği Araştırmaları — MGO Portföyü

## Genel Bakış

Özdemir'in ikinci büyük araştırma kümesi enerji, çevre ve gıda sistemleri üzerine yoğunlaşıyor. Bu kümede iki farklı alt dal dikkat çekiyor: birincisi, çevre ile ekonomik büyüme arasındaki "ters U" ilişkisini test eden EKC (Environmental Kuznets Curve) çalışmaları; ikincisi, gıda güvenliği, tarımsal verimlilik ve gıda rejimleri üzerine yapılandırılmış politika odaklı çalışmalar. Her iki dal da yüksek etkili Q1 SSCI/SCIE dergilerini hedefliyor.

## EKC (Çevre Kuznets Eğrisi) Araştırmaları

### EKC BRICST — Ana Çalışma

Özdemir'in enerji portföyündeki en olgun çalışması BRICST (Brezilya, Rusya, Hindistan, Çin, Güney Afrika, Türkiye) panel EKC analizidir. Bu çalışma v39 sürümüne ulaşmış; yani yaklaşık 39 revizyon döngüsünden geçmiş, son derece gelişmiş bir çalışma.

Temel araştırma sorusu şu: BRICST ülkelerinde ekonomik büyüme ile CO2 emisyonları arasında gerçekten bir ters U ilişkisi var mı? Yani gelir bir eşiği aştıktan sonra emisyonlar gerçekten düşüyor mu?

Yöntem olarak CS-ARDL (Cross-Sectionally Augmented ARDL) kullanılıyor — bu, kesit bağımlılığını ve heterojen eğimleri kontrol eden nesil 2 bir tahmin yöntemi. Önemli bir teknik detay: N=9 ile küçük örneklem büyüklüğü, standart asimptotik çıkarım için yetersiz. Bu nedenle Webb wild cluster bootstrap zorunlu hale geliyor. Bu yöntem, hata terimlerinin küme bazında korelasyon gösterdiği durumlarda bootstrap simülasyonuyla daha güvenilir p-değerleri üretiyor.

Çalışma "Sent Back to Author" statüsünde Energy Policy'de; gönderim hazır v39 paketi mevcut. Ancak burada bir EÜYM sorunu var: Energy Policy kabul süresi 274 gün, yani 9.1 ay. EÜYM=0.49, Zone C'de. Resources Policy gibi daha hızlı bir Q1 dergiye geçmek bu çalışmanın verimini 0.49'dan 0.81'e taşıyacak.

### WQR P2: EKC NP BRICS-T Wavelet-QR

Bu çalışma klasik EKC testinin çok ötesine geçiyor. Wavelet ayrıştırması kullanarak kısa, orta ve uzun vadeli dinamikleri ayrıştırıyor; sonra kantil regresyon uygulayarak EKC ilişkisinin farklı emisyon düzeylerinde nasıl değiştiğini inceliyor. Yani "EKC var mı?" sorusunu değil, "EKC hangi zaman ufkunda ve hangi emisyon düzeylerinde ortaya çıkıyor?" sorusunu soruyor.

Bu metodolojik yenilik Q1 dergiler açısından son derece çekici. Hedef dergi Energy Policy; ancak aynı EÜYM sorunu burada da geçerli.

### WQR P3: G7 Wavelet QR

G7 ülkelerinde benzer wavelet-kantil analizi uygulanıyor. Bu çalışma Renewable Energy dergisini hedefliyor; kabul süresi yaklaşık 240 gün, EÜYM 0.67.

## İklim-Tarım İlişkisi

### Climate Agri Turkey ARDL

Türkiye özelinde iklim değişkenlerinin tarımsal çıktılar üzerindeki etkisini ARDL yöntemiyle inceleyen bu çalışma, Özdemir'in ortak yazarlı projelerinden biri. İşık hoca onayı bekleniyor; Journal of Environmental Management (JEM) hedefleniyor. JEM'in kabul süresi yaklaşık 240 gün, EÜYM 0.45. Alternatif olarak Environmental Science & Policy gibi daha hızlı bir dergi değerlendirilebilir.

Bu çalışmanın özgün katkısı: Türkiye'nin hem subtropikal hem karasal iklim bölgelerini barındırması, iklim şoklarının tarım üzerindeki etkisini son derece heterojen kılıyor. ARDL sınır testi bu heterojenliği uzun dönem ilişki çerçevesinde ele alıyor.

## Gıda Güvenliği Araştırmaları

### Food Regime Decoupling — JCP

"Gıda rejimi ayrışması" kavramını inceleyen bu çalışma, küresel gıda sistemleri ile ulusal besin güvencesi arasındaki bağlantının zayıflamasını test ediyor. BACI ticaret veritabanı, FAOSTAT gıda bilanço verileri ve AgTFP verimlilik verileri kullanılıyor.

Metodoloji açısından ilginç: küreselleşme ile gıda bağımlılığı arasındaki nedensellik, standart panel testleriyle değil, karmaşık eşbütünleşme testleriyle kurgulanıyor. Journal of Cleaner Production hedefleniyor; v02 Quarto belgesi olarak tamamlandı, gönderime hazır.

### Gravity Food Security

Yerçekimi modeli (gravity model) ticaret ekonomisinin temel araç kutusundan geliyor: iki ülke arasındaki ticaret, ekonomik büyüklükleriyle doğru, aralarındaki mesafeyle ters orantılı. Özdemir bu modeli gıda güvenliği bağlamına uyarlamış: hangi faktörler ülkelerin gıda güvenliği için gerekli ürünleri ithal etme kapasitesini artırıyor ya da kısıtlıyor?

BACI HS92 ticaret verileri (CEPII kaynaklı), Food Policy hedefleniyor; gönderime hazır, NO BLOCKER.

### PSE × AgTFP OECD

Bu çalışma, tarım desteklerinin (PSE — Producer Support Estimate) tarımsal toplam faktör verimliliği (AgTFP) üzerindeki etkisini OECD ülkelerinde panel GMM ile analiz ediyor. Temel soru: tarıma yapılan sübvansiyon verimliliği artırıyor mu, yoksa tam tersine verimlilik için motivasyonu azaltarak bloke mi ediyor?

OECD PSE veritabanı ile USDA AgTFP verileri birleştirilmiş; analiz tamamlandı, Food Policy hedefleniyor. Tüm 8 katsayı değeri ANAYASA denetimiyle çapraz teyit edildi.

### AgTFP MENA-SSA

Orta Doğu ve Kuzey Afrika (MENA) ile Sahra Altı Afrika (SSA) ülkelerinde tarımsal verimlilik dinamiklerini inceleyen panel analizi. AMG (Augmented Mean Group) tahmincisi kullanıldı; ortak yazar olmaksızın solo MGO çalışması. Makale kurtarıldı ve v02 hazır; Food Policy hedefleniyor, NO BLOCKER.

### SSA ML Food Security

Sahra Altı Afrika'da gıda güvenliğini tahmin etmek için makine öğrenmesi yöntemleri kullanılıyor. Bu çalışma iki şeyi bir araya getiriyor: birincisi, geleneksel panel ekonometrisi ile makine öğrenmesinin kesişimi; ikincisi, SSA'nın gıda güvensizliği sorununa metodolojik özgünlük katma girişimi.

British Food Journal hedefleniyor; EÜYM 1.20, Zone A. Gönderime hazır.

### Hexahelix Kadın-Gıda-Gelecek

Sundari ile ortak yazarlı olan bu çalışma, gıda sistemlerinde kadın katılımını "hexahelix" çerçevesinde (devlet, sanayi, akademi, sivil toplum, medya ve doğa) PLS-SEM yöntemiyle analiz ediyor. Food Policy hedefleniyor. Yapısal eşitlik modellemesinin tarımsal kalkınmaya uygulanması açısından yenilikçi bir çalışma.

## Sürdürülebilirlik ve Emisyon Araştırmaları

### AI Strategy Carbon DiD

Yapay zeka stratejisinin karbon emisyonları üzerindeki etkisini farklı farklar (Difference-in-Differences) yöntemiyle analiz ediyor. Temel soru: Ulusal düzeyde bir yapay zeka stratejisi açıklayan ülkeler, çevresel sürdürülebilirlik açısından ne fark yaratıyor?

Bu çalışmanın özgünlüğü şu: AI stratejisi uygulaması sanki bir "doğal deney" gibi kullanılıyor. DiD tasarımı bu yapay dışsallıktan yararlanarak nedensel çıkarım yapıyor. Energy Research & Social Science hedefleniyor; v11 PDF ve portal copypaste tamamlandı, gönderime hazır.

### Stagflasyon Makine Öğrenmesi

Stagflasyonu — hem yüksek enflasyon hem de düşük büyümenin birlikte yaşandığı nadir ama yıkıcı ekonomik durumu — öngörmek için Random Forest ve SHAP (SHapley Additive exPlanations) analizi kullanılıyor. R-kare değeri 0.60: oldukça iyi bir tahmin gücü.

International Journal of Forecasting (IJF) hedefleniyor; bu, tahmin literatürünün amiral gemisi. Ancak EÜYM 0.40, yani Zone C alt bandında. Bu derginin kabul süresi uzun, fakat alandaki prestiji nedeniyle gönderim devam ediyor.

### Sürdürülebilirlik Nexus — UY-MGO

Ortak yazar Uğur ile birlikte yazılan bu çalışma, CO2 emisyonlarından GDP büyümesine doğru nedenselliği Webb p-değeri 0.040 ile ortaya koyuyor. EMFT Plan A; Uğur incelemesi bekliyor.

## Göç-Karbon-Büyüme Nexusu

### Dincer-MGO Göç-Karbon

Göç ile karbon emisyonları arasındaki ilişkiyi panel AMG yöntemiyle inceleyen bu çalışma, yenilikçi bir hipotezi test ediyor: göç akışları, ülkelerin üretim yapısını ve dolayısıyla karbon yoğunluğunu değiştiriyor mu?

AMG katsayısı lnMIG için -0.368, yüzde 5 anlamlılık düzeyinde. Türkiye heterojenlik düzeltmesi yapıldı. ORCID teyidi ve Uğur incelemesi bekleniyor.

## Metodoloji Notu: Nesil 2 Panel Testleri

Bu kümedeki çalışmaların büyük çoğunluğunda nesil 2 panel testleri kullanılıyor. Bu önemli bir metodolojik tercih. Nesil 1 testler (LLC, IPS, Pedroni eşbütünleşme) kesit bağımlılığı olmadığını varsayıyor. Ancak enerji fiyatları, küresel ticaret ve çevre politikaları bağlamında ülkeler arasında güçlü bağımlılıklar var. Bu durumda nesil 1 testler boyut bozulması yaşıyor — yani gerçekte birim kök yokken "var" veya "yok" gibi yanlış sonuçlar üretiyor.

Pesaran CD testi bu bağımlılığı önce doğruluyor; ardından CIPS/CADF gibi nesil 2 testler uygun yöntemi belirliyor. Bu metodolojik özen, hakemler tarafından takdir gören bir kalite işareti.

## EKC Literatürünün Özeti

EKC hipotezi 1991'de Grossman ve Krueger tarafından ileri sürüldü: kişi başı gelir arttıkça kirlilik önce artıyor, sonra gelir belirli bir eşiği geçince düşüyor. Bu "çevresel dönüşüm" teorisi cazip görünse de ampirik kanıtlar oldukça karışık.

Özdemir bu tartışmaya üç katkı yapıyor: birincisi, BRICST gibi heterojen ülke gruplarında CS-ARDL ile uzun dönem ilişkiyi test ediyor; ikincisi, wavelet analizi sayesinde zaman ufku boyutunu ekliyor; üçüncüsü ise kangil yaklaşımıyla EKC'nin dağılımın farklı noktalarında nasıl değiştiğini gösteriyor.

Bu yaklaşımlar, "EKC var mı yok mu?" sorusunun yerine "hangi koşullar altında, hangi ülkelerde, hangi zaman diliminde EKC ortaya çıkıyor?" sorusunu sormasını sağlıyor. Bu, hem analitik hem de politika açısından çok daha değerli bir çerçeve.
