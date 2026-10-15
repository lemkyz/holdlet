# Holdlet - adım adım bağlantı kurulumu

## Normal kullanım

1. Uygulamayı aç. **Ayarlar → Genel → Mac'imi hazırla** seçeneği Takvim ve bildirim izinlerini ister, girişte başlatmayı açar. macOS gerektiğinde senden onay ister.
2. **Bağlantılar → Takvim erişimine izin ver** ile Mac'inde eşitlenen takvimleri bağla. Google, Outlook, Exchange ve iCloud için ayrı bir Holdlet geliştirici projesi gerekmez.
3. Eksik bir hesap varsa **Google, Outlook veya Exchange takvimi ekle** doğrudan İnternet Hesapları ayarını açar. Hesabı ekleyip Takvim eşitlemesini aç.
4. Takvimleri seç, **Genel** ekranından beş saniyelik bildirim testini ve **Tutamağı dene** seçeneğini kullan.
5. Ayarlar'ı kapat. Menü simgesi ve tutamak kalır. Tutamağı ekranın dört kenarından birine veya başka monitöre sürükle. Tıklayarak, içeri kaydırarak veya Control + Option + H ile aç; Escape ile gizle.
6. Çalışma günlerini, mesaiyi ve toplantı hatırlatma süresini **Kurallar** ekranından seç. Gece mesaisi desteklenir.

Normal kurulumda token, JSON veya istemci kimliği istenmez. Bu önizlemede herkese açık Gmail/Slack/Jira hesap girişi yayıncı kaydını bekliyor. Hazır olmayan bir bağlantı çalışıyormuş gibi sunulmaz. Takvim yolu Gmail kutusuna veya Teams sohbetlerine erişmez.

Önceden reddedilmiş izinde düğme ilgili sistem ayarını açar. Sistem ayarında Holdlet'e izin verdikten sonra uygulamaya dönüp bağlantıyı tekrar dene. Pencereleri kapatmak uygulamayı kapatmaz. Menüden **Çık** seçmek uygulamayı kapatır; girişte başlatma bir sonraki Mac oturum açılışında devreye girer.

Demo hesabı gerçek bağlantı veya sistem kurulum izni istemez. Normal kullanıma dönmek için **Normal modu aç** seç.

## Yalnızca geliştirici ve kurum içi test kurulumu

Aşağıdaki adımlar normal kullanıcının görevi değildir. Yayıncı kayıtları hazır olana kadar katkı verenlerin adaptörleri sınamasına yöneliktir. Alanlar **Ayarlar → Tanılama → Geliştirici bağlantıları** içindedir.

**Token, istemci sırrı, şifre veya indirilen kimlik JSON dosyasını sohbete ya da GitHub'a ekleme.** Uygulamadaki güvenli alana gir. Erişim anahtarları Keychain'de tutulur; yerel iş dosyası uygulama tarafından şifrelenmez.

## 2. Gmail + doğrudan Google Calendar

Hazırlayacağın bilgiler: **Desktop OAuth client ID** ve gerekiyorsa aynı istemcinin **client secret** değeri. Gmail şifreni uygulamaya girmezsin.

1. [Google Cloud Console](https://console.cloud.google.com/) içinde kendi projen oluştur/seç; örnek ad: `Holdlet Personal`.
2. API kitaplığından **Google Calendar API** ve **Gmail API** hizmetlerini etkinleştir.
3. **Google Auth Platform / OAuth consent screen** bölümünde uygulama adı ve destek e-postanı ayarla.
4. Kişisel test için hedef kitleyi hesabına uygun seç; harici test uygulamasında **Audience → Test users** alanına giriş yapacağın Google hesabını ekle. Şirket hesabındaki yönetici kuralları ayrıca geçerlidir.
5. **Clients → Create client** içinde türü **Desktop app** seç. Web application seçme.
6. Oluşan Desktop istemcisinin JSON dosyasını indir. Holdlet → Tanılama → Geliştirici bağlantıları → Google Workspace → **Google bağlantısını kur** düğmesiyle bu dosyayı seç. Kimlik ve varsa istemci sırrı aynı dosyadan doldurulur. Web istemcisi dosyası kabul edilmez.
7. **Google ile giriş yap** düğmesine bas. Varsayılan tarayıcıda doğru hesabı seç; istenen salt okunur takvim ve Gmail erişimini inceleyip izin ver.
8. Holdlet'e dön; Gmail için son başarılı eşitlemeyi kontrol et. Doğrudan Google Takvim'i kullanacaksan ilgili seçeneği aç ve onun eşitlemesini de kontrol et. Apple Takvim zaten bağlıysa başlangıçta korunur.

Uygulama birincil Google takvimini okur. Gmail'de varsayılan sorgu `is:unread is:important newer_than:7d`; Kurallar ekranından değiştirebilirsin. Gmail kapsamı `gmail.readonly` düzeyindedir; uygulama şu an yalnızca konuşma üst bilgilerini getirir, fakat verdiğin yetki bununla sınırlı değildir. Takvim kapsamı `calendar.events.readonly`.

Kontrol: uygun bir deneme maili oluştur; okuduğunda takip kaybolmamalı. Menüden **Yanıt bekleniyor** seç; konuşmaya başka bir hesaptan gelen yeni mesaj, başarılı eşitlemede aktif listeye dönmeli. Gelen etkinlik algılanır; mesajın sorunu gerçekten çözdüğü tahmin edilmez.

Hatalar: `redirect_uri_mismatch` için Desktop app türünü kontrol et; `access_denied` için test kullanıcılarını ve kurum izinlerini kontrol et. Süresi dolan test yetkisinde yeniden giriş gerekebilir. Herkese dağıtılacak ortak OAuth uygulaması için Google'ın ilgili doğrulama süreci ayrıdır.

[Google'ın resmî masaüstü OAuth rehberi](https://developers.google.com/identity/protocols/oauth2/native-app)

## 3. Slack

Hazırlayacağın bilgi: kurumsal izinlere uygun **kullanıcı OAuth tokenı**. Bot tokenı veya Slack şifresi değil.

1. [Slack uygulamaları](https://api.slack.com/apps) sayfasında kendi çalışma alanın için kurum içi uygulama oluştur/seç. Kurum uygulama kurulumunu sınırlandırıyorsa yöneticinin izin vermesi gerekir.
2. **OAuth & Permissions → User Token Scopes** bölümüne `search:read` ekle. Bot Token Scopes alanına eklemek bu bağlayıcı için yeterli değildir.
3. Uygulamayı çalışma alanına kur veya kapsam değiştiyse yeniden yetkilendir. Oluşan **User OAuth Token** değerini al.
4. Holdlet → Tanılama → Geliştirici bağlantıları → Slack'teki güvenli token alanına gir.
5. Sorguyu başlangıçta `to:me after:{weekAgo}` bırak; Holdlet `{weekAgo}` değerini her eşitlemede yedi gün önceki tarihle değiştirir. İstersen `to:me after:2026-10-01` gibi sabit tarih kullan.
6. **Test et ve bağla** seç. Hata yoksa token Keychain'e kaydedilir.

En fazla 100 arama eşleşmesi desteklenir; aşılırsa sorguyu daralt. Yalnızca kullanıcı erişimin olan sonuçlar gelir. Yanıt verip vermediğin otomatik belirlenmez. Bu, kurum içi kişisel alfa kurulumu; herkese açık Slack Marketplace dağıtımı değildir.

[Slack token ve OAuth rehberi](https://docs.slack.dev/authentication/installing-with-oauth/) · [search:read kapsamı](https://docs.slack.dev/reference/scopes/search.read/)

## 4. Jira Cloud

Hazırlayacağın bilgiler: `https://sirketin.atlassian.net` adresi, Atlassian hesap e-postası ve kişisel API tokenı.

1. [Atlassian API tokenları](https://id.atlassian.com/manage-profile/security/api-tokens) sayfasını aç.
2. Bu alfadaki site tabanlı bağlantı için **Create API token** yolunu kullan. **Create API token with scopes** ile oluşturulan gateway tokenları bu sürümde desteklenmez. Atlassian genel olarak kapsamlı tokenları önerir; bunlar için ayrı gateway/OAuth desteği yol haritasındadır.
3. Anlaşılır ad ve deneme sürene uygun son kullanma tarihi seç. Tokenı oluştur ve kopyala.
4. Holdlet → Tanılama → Geliştirici bağlantıları → Jira Cloud bölümünde siteyi, hesap e-postanı ve tokenı gir.
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
