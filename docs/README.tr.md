# Holdlet

Toplantılarını, bekleyen dönüşlerini ve işlerini menü çubuğunda takip eden yerel Mac uygulaması. Görsel referans Apple Denetim Merkezi: nötr cam modüller, dairesel ikonlar ve kapsül kontroller.

**Geliştirici alfası.** Yerel uygulama ve çekirdek testler çalışır. Google/Slack/Jira gerçek hesap kabul testleri, kendi kimlik bilgilerini bağlamanı gerektirir. Kurumsal sertifikalı veya bütün entegrasyonları hazır bir son ürün olarak sunulmaz.

```bash
git clone https://github.com/lemkyz/holdlet.git
cd holdlet
./scripts/test.sh
./scripts/build-app.sh
open dist/Holdlet.app
```

macOS 14+ ve Swift 6+ gerekir. Yerel paket ad-hoc imzalıdır; Apple Developer ID/notarizasyon tamamlanmamıştır.

İlk açılışta örnek verilerle deneyebilir veya **+** ile hatırlatma ekleyebilirsin. Ayarlar → Genel'den dili Türkçe seç, bildirimleri etkinleştir ve test gönder. Girişte başlatmayı istersen aç. Ayarlar → Bağlantılar'dan Mac Takvim'i en hızlı şekilde bağlayabilirsin.

- Gmail/Calendar: kendi Google masaüstü OAuth istemcin gerekir.
- Slack: kurum içi kullanıcı tokenı ve `search:read` izni gerekir.
- Jira Cloud: siten, hesap e-postan ve kapsamsız kişisel API tokenın gerekir.
- Eşitleme Mac uyanıkken 3 dakikada birdir; push değildir.
- Okunan mail otomatik tamamlanmaz. Gmail'de “Yanıt bekleniyor” işaretli konuşmaya yeni gelen mesaj aktif listeye döner.
- Slack yanıt durumu elle takip edilir.
- Tokenlar Keychain'de, iş başlıkları ve ayarlar yerel dosyada tutulur. Dosya uygulama tarafından şifrelenmez.

[Türkçe adım adım kurulum](KURULUM.tr.md) · [İngilizce kurulum](SETUP.md) · [Doğrulama](VALIDATION.md) · [Yol haritası](ROADMAP.md)
