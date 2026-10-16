# Holdlet yayın hazırlığı

Değerlendirme tarihi: 16 Ekim 2026. Sonuç: kontrollü geliştirici demosu için kullanılabilir; genel kullanıcıya hazır ürün veya kurumsal dağıtım olarak sunulamaz. Bu değerlendirme kaynak incelemesi, mevcut test kanıtları, yerel paket kontrolleri ve sınırlı canlı hesap kabulüne dayanır. Bağımsız güvenlik denetimi değildir.

## Mevcut kanıt

| Alan | Durum | Kanıtın sınırı |
|---|---|---|
| Menü çubuğu ve ekran kenarı | Uygulandı | Açma, gizleme, kenar seçimi ve temel yerleşim kontrol edildi; fiziksel çoklu ekran ve Spaces matrisi tamamlanmadı |
| Tasarım | Yerel cam yüzeyler, sistem yazısı ve nötr renkler var | Referans görünüme uygun bir temel; bütün durumlarda okunabilirlik ve erişilebilirlik onayı verilmedi |
| Mac Takvim | Canlı eşitleme başarılı | Tek kullanıcı ve mevcut Mac; geniş cihaz/hesap matrisi yok |
| Gmail | Yerel yapılandırılmış uygulamada canlı giriş ve API eşitlemesi başarılı | Google test hesabı; genel indirme paketinde yayıncı yapılandırması yok |
| Doğrudan Google Takvim | Kod ve sentetik testler var | Kullanıcının Mac Takvim seçimi korundu, canlı doğrudan API kabulü yapılmadı |
| Slack ve Jira | Geliştirici bağlantıları mevcut | Genel OAuth ve gerçek kurum kabulü tamamlanmadı |
| Hatırlatma ve odak | Temel UI ve çekirdek testleri var | Uyku, çevrimdışı kalma, sistem Odak modu ve uzun kullanım matrisi eksik |
| Testler | 53 test ve son CI kontrolleri başarılı | Canlı bildirim teslimi, pil tüketimi ve tüm kurumsal ağları kanıtlamaz |
| Dağıtım | Önizleme paket kontrolü geçti | Genel beta kontrolü Developer ID imzası ve noter onayı olmadığı için başarısız |

## Yayın öncesi zorunlu işler

1. **İlk sürümün kapsamını daralt:** Takvim, Gmail ve kişisel takipler için açık ürün sözü. Slack/Jira ve Microsoft 365 hazır görünmemeli; genel kurumsal kapsam ayrı bir hedef.
2. **Standart Google girişi:** Yayıncıya ait onaylı yapılandırma, gerekli Google doğrulama süreci ve dağıtılan pakette giriş. Yeni kullanıcı geliştirici projesi veya test listesi düzenlememeli. Token yenileme, iptal, izin geri alma ve hesap değiştirme gerçek hesaplarla denenmeli.
3. **Güvenilir Mac kurulumu:** Developer ID imzası, notarization, temiz Mac kurulumu ve güncellemede izinlerin korunması. Son kaynak düzeltmeleri yeni ve açıkça sürümlenmiş bir indirme paketine girmeli. v0.2.1-alpha paketi son zaman aşımı düzeltmesinden önce oluşturuldu; 0.2.2 kaynakları bunu ve mail/kaydırma iyileştirmelerini içerir.
4. **Güvenilir günlük kullanım:** Gerçek oturum açılışı, pencere kapatma, yeniden başlatma, uyku/uyanma, bağlantı kopması, 401/403/429 ve sistem Odak modu. Birkaç günlük pilot ve gerçek bildirim teslimi kaydı.
5. **Yoğun hesaplar ve veri ömrü:** Sayfalama ve saklama sınırları. 0.2.2 ile Gmail 50 konuşmalık sayfalar halinde yüklenir; Jira 100 sonuçluk sayfalarla 5.000 işe kadar okunur. Doğrudan Google Takvim 250 etkinlik, Slack 100 sonuç sınırına sahip. Limit aşımı hata verir ve son başarılı görünümü korur. Eski takiplerin saklanmasına henüz genel bir süre sınırı uygulanmıyor.
6. **Son tasarım kabulü:** Açık/koyu ve hareketli duvar kâğıdı üzerinde kontrast; uzun Türkçe/İngilizce metin; küçük ekran; boş, yükleniyor, çevrimdışı ve hata durumları; klavye, VoiceOver, Saydamlığı Azalt ve Hareketi Azalt. README görseli yalnızca sentetik demodur, tüm kabulün yerine geçmez.
7. **Güvenlik ve destek:** Aşağıdaki veri saklama kararları, güvenlik incelemesi, gizlilik açıklaması, veri silme/erişim iptali yönlendirmesi ve güncelleme politikası.

## Güvenlik değerlendirmesi

Olumlu temel: tokenlar macOS Keychain'de, Google girişinde PKCE ve state doğrulaması, yalnızca IPv4 loopback üzerinde geçici geri dönüş dinleyicisi, sağlayıcılarla doğrudan HTTPS iletişimi. Mevcut arayüz için Gmail gövdeleri çekilmiyor. Gizli telemetri veya otomatik ileti gönderimi bulunmuyor.

Yerel durum dosyası izinleri inceleme sırasında dosyada 0600, dizinde 0700 olarak doğrulandı. Bununla birlikte başlıklar, gönderen bilgileri, toplantılar ve takipler uygulama tarafından şifrelenmeden tutuluyor. Keychain koruması bu dosyayı şifrelemez. Kurumsal pilot öncesi tehdit modeli, veri minimizasyonu, saklama süresi ve gerekirse uygulama düzeyinde şifreleme kararı verilmeli. Ekrandaki gizlilik anahtarı diskteki veriyi şifrelemez.

Bağlantıyı kaldırmak yerel kimlik bilgilerini siler; sağlayıcıdaki izni iptal etmek ayrıca gerekir. Güvenli ve doğrulanmış güncelleme kanalı, bağımsız güvenlik incelemesi, MDM/kurum politikası ve çoklu hesap ayrımı henüz tamamlanmadı. Takip edilen dosyalarda sınırlı token/özel anahtar desen taraması eşleşme bulmadı; bu, geçmiş dahil kapsamlı sır taraması veya sızma testi değildir.

## Sunumda doğru ifade

“Mac için açık kaynak toplantı ve takip yardımcısı. Ekran kenarında kalır. Mac Takvim ve yapılandırılmış Google test bağlantısıyla çalışan geliştirici önizlemesi.”

“Tüm şirketlerde hazır”, “anlık bildirim”, “hiçbir toplantıyı kaçırmaz”, “güvenlik denetiminden geçti” veya “genel kullanıma tamamen hazır” denmemeli. 0.2.2 ile Gmail değişiklik kontrolü Mac uyanıkken 15 saniyede bir, diğer kaynakların eşitlemesi üç dakikada birdir; push değildir. Mac kapalıyken canlı kaynak takibi yapılamaz.

İlgili kanıtlar: [doğrulama](VALIDATION.md), [bağlantı durumu](STATUS.md), [yol haritası](ROADMAP.md), [güvenlik](../SECURITY.md), [yayın adımları](RELEASING.md).
