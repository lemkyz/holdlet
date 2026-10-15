# Holdlet — adım adım bağlantı kurulumu

Bu geliştirici alfasında hazır bir ortak OAuth uygulaması yok. Kendi hesaplarınla deneme yapmak için aşağıdaki bilgileri bir kez hazırlıyorsun. İleride genel kullanıma yönelik doğrulanmış giriş akışı bu adımların yerini alacak.

**Token, istemci sırrı, şifre veya indirilen kimlik JSON dosyasını sohbete ya da GitHub'a ekleme.** Uygulamada ilgili güvenli alana gir. Holdlet erişim anahtarlarını macOS Keychain'e kaydeder. İş başlıkları ve ayarlar yerel dosyada tutulur; bu dosya uygulama tarafından şifrelenmez.

## Önce uygulamayı normal modda aç

Demo açıkken **Exit / Çık** veya Ayarlar'daki **Normal modu aç** düğmesini kullan. Yeni sürüm normal bir uygulama oturumu açar. Eski demo sürümündeysen menü çubuğu simgesine sağ tıkla → Quit Holdlet; ardından uygulamayı normal aç. Demo oturumunda gerçek hesap bağlantıları bilinçli olarak kapalıdır.

Uygulamayı sürekli tutacağın bir yere taşıdıktan sonra aç. Menü çubuğundan Ayarlar → Genel → Dil → Türkçe seç. **Bildirimleri aç**, ardından **5 saniye sonra test gönder** ile dene. Mac Odak modu veya sistem bildirim ayarları uyarıyı etkileyebilir. Başlangıçta çalışması için **Girişte başlat** seçeneğini aç; macOS ek izin isterse Giriş Öğeleri'nden onayla.

## 1. En hızlı yol: Google Cloud kurmadan takvim

1. Mac'in **Takvim** uygulamasını aç; Google hesabındaki toplantıların burada görünüp görünmediğine bak.
2. Görünmüyorsa Takvim → Hesap Ekle yoluyla hesabını ekle ve takvim eşitlemesini etkinleştir.
3. Holdlet → Ayarlar → Bağlantılar → **Mac Calendar** → erişime izin ver.
4. İzlemek istediğin takvimleri seç.
5. Gelecekteki saatli bir toplantıyı ekle/değiştir; Holdlet'te Yenile'ye bas. Son başarılı eşitleme zamanını kontrol et.

Bu yol yalnızca takvim içindir; Gmail kutusunu bağlamaz. Holdlet takvimine yazmaz. İlk sürüm yinelenmeyi önlemek için Mac Takvim ile doğrudan Google bağlantısını birlikte kullanmaz; Mac Takvim'e geçmek doğrudan Google/Gmail bağlantısını devre dışı bırakır.

## 2. Gmail + doğrudan Google Calendar

Hazırlayacağın bilgiler: **Desktop OAuth client ID** ve gerekiyorsa aynı istemcinin **client secret** değeri. Gmail şifreni uygulamaya girmezsin.

1. [Google Cloud Console](https://console.cloud.google.com/) içinde kendi projen oluştur/seç; örnek ad: `Holdlet Personal`.
2. API kitaplığından **Google Calendar API** ve **Gmail API** hizmetlerini etkinleştir.
3. **Google Auth Platform / OAuth consent screen** bölümünde uygulama adı ve destek e-postanı ayarla.
4. Kişisel test için hedef kitleyi hesabına uygun seç; harici test uygulamasında **Audience → Test users** alanına giriş yapacağın Google hesabını ekle. Şirket hesabındaki yönetici kuralları ayrıca geçerlidir.
5. **Clients → Create client** içinde türü **Desktop app** seç. Web application seçme.
6. Oluşan Client ID'yi Holdlet → Bağlantılar → Google Workspace alanına gir. İstemci sırrı gerekiyorsa aynı ekrandaki güvenli alana ekle.
7. **Google ile giriş yap** düğmesine bas. Varsayılan tarayıcıda doğru hesabı seç; istenen salt okunur takvim ve Gmail erişimini inceleyip izin ver.
8. Holdlet'e dön; Calendar ve Gmail için ayrı ayrı son başarılı eşitlemeyi kontrol et.

Uygulama birincil Google takvimini okur. Gmail'de varsayılan sorgu `is:unread is:important newer_than:7d`; Kurallar ekranından değiştirebilirsin. Gmail kapsamı `gmail.readonly` düzeyindedir; uygulama şu an yalnızca konuşma üst bilgilerini getirir, fakat verdiğin yetki bununla sınırlı değildir. Takvim kapsamı `calendar.events.readonly`.

Kontrol: uygun bir deneme maili oluştur; okuduğunda takip kaybolmamalı. Menüden **Yanıt bekleniyor** seç; konuşmaya başka bir hesaptan gelen yeni mesaj, başarılı eşitlemede aktif listeye dönmeli. Gelen etkinlik algılanır; mesajın sorunu gerçekten çözdüğü tahmin edilmez.

Hatalar: `redirect_uri_mismatch` için Desktop app türünü kontrol et; `access_denied` için test kullanıcılarını ve kurum izinlerini kontrol et. Süresi dolan test yetkisinde yeniden giriş gerekebilir. Herkese dağıtılacak ortak OAuth uygulaması için Google'ın ilgili doğrulama süreci ayrıdır.

[Google'ın resmî masaüstü OAuth rehberi](https://developers.google.com/identity/protocols/oauth2/native-app)

## 3. Slack

Hazırlayacağın bilgi: kurumsal izinlere uygun **kullanıcı OAuth tokenı**. Bot tokenı veya Slack şifresi değil.

1. [Slack uygulamaları](https://api.slack.com/apps) sayfasında kendi çalışma alanın için kurum içi uygulama oluştur/seç. Kurum uygulama kurulumunu sınırlandırıyorsa yöneticinin izin vermesi gerekir.
2. **OAuth & Permissions → User Token Scopes** bölümüne `search:read` ekle. Bot Token Scopes alanına eklemek bu bağlayıcı için yeterli değildir.
3. Uygulamayı çalışma alanına kur veya kapsam değiştiyse yeniden yetkilendir. Oluşan **User OAuth Token** değerini al.
4. Holdlet → Bağlantılar → Slack'teki güvenli token alanına gir.
5. Sorguyu başlangıçta `to:me after:{weekAgo}` bırak; Holdlet `{weekAgo}` değerini her eşitlemede yedi gün önceki tarihle değiştirir. İstersen `to:me after:2026-10-01` gibi sabit tarih kullan.
6. **Test et ve bağla** seç. Hata yoksa token Keychain'e kaydedilir.

En fazla 100 arama eşleşmesi desteklenir; aşılırsa sorguyu daralt. Yalnızca kullanıcı erişimin olan sonuçlar gelir. Yanıt verip vermediğin otomatik belirlenmez. Bu, kurum içi kişisel alfa kurulumu; herkese açık Slack Marketplace dağıtımı değildir.

[Slack token ve OAuth rehberi](https://docs.slack.dev/authentication/installing-with-oauth/) · [search:read kapsamı](https://docs.slack.dev/reference/scopes/search.read/)

## 4. Jira Cloud

Hazırlayacağın bilgiler: `https://sirketin.atlassian.net` adresi, Atlassian hesap e-postası ve kişisel API tokenı.

1. [Atlassian API tokenları](https://id.atlassian.com/manage-profile/security/api-tokens) sayfasını aç.
2. Bu alfadaki site tabanlı bağlantı için **Create API token** yolunu kullan. **Create API token with scopes** ile oluşturulan gateway tokenları bu sürümde desteklenmez. Atlassian genel olarak kapsamlı tokenları önerir; bunlar için ayrı gateway/OAuth desteği yol haritasındadır.
3. Anlaşılır ad ve deneme sürene uygun son kullanma tarihi seç. Tokenı oluştur ve kopyala.
4. Holdlet → Jira Cloud bölümünde siteyi, hesap e-postanı ve tokenı gir.
5. **Test et ve bağla** seç; sana atanmış açık işlerin ve bağlantı zamanının geldiğini doğrula.

Jira'ya yazma yapılmaz; ancak tokenın sağlayıcıdaki yetkileri yalnızca uygulamanın yaptığı okuma işlemleriyle sınırlanmış değildir. Tamamlanan Jira işi sonraki başarılı eşitlemede aktif listeden çıkar. Tarih alanındaki günler Mac saat diliminde 17:00 olarak gösterilir. Jira Data Center bu bağlayıcıyla çalışmaz.

[Atlassian'ın resmî API token rehberi](https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/)

## Başarılı kurulumun ölçütü

- Bildirim testi görülüyor.
- Kaynak için son başarılı eşitleme zamanı güncel.
- Gerçek bir etkinlik/iş kaynak uygulamadakiyle eşleşiyor.
- Erteleme ve tamamlandı durumları uygulamayı yeniden açınca korunuyor.
- Bağlantıyı kaldırınca kaynağın yerel işleri ve gelecekteki uyarıları kaldırılıyor.

Eşitleme Mac uyanıkken yaklaşık 3 dakikada birdir; anlık push değildir. Sonuç sayısı sınırı veya izin hatasında son başarılı veri korunur. Holdlet'ten bağlantıyı kaldırmak sağlayıcıdaki tokenı iptal etmek değildir; tam iptal için sağlayıcının hesap/uygulama ayarlarını da kullan.

## Apple imzası

Mevcut paket yerel geliştirme için ad-hoc imzalı. Herkesin kolayca indirebileceği güvenilir dağıtım için Apple Developer hesabı, Developer ID Application sertifikası ve notarizasyon kurulumu gerekir. Google/Slack/Jira'yı bağlaman Apple imzasını otomatik çözmez. [Yayın rehberi](RELEASING.md)
