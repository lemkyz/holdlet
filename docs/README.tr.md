# Holdlet

Toplantılarını, bekleyen dönüşlerini ve işlerini menü çubuğunda takip eden yerel Mac uygulaması. Görsel referans Apple Denetim Merkezi: nötr cam modüller, dairesel ikonlar ve kapsül kontroller.

**0.2 geliştirici önizlemesi.** Ekran kenarı tutamağı, menü çubuğu, Mac Takvim ve yerel takipler kullanılabilir. Herkese açık Gmail, Slack ve Jira girişi yayıncı kayıtlarını bekliyor. Normal kullanıcı ekranında geliştirici kimliği veya token istenmez.

```bash
git clone https://github.com/lemkyz/holdlet.git
cd holdlet
./scripts/test.sh
./scripts/build-app.sh
open dist/Holdlet.app
```

macOS 14+ ve Swift 6+ gerekir. Yerel paket ad-hoc imzalıdır; Apple Developer ID/notarizasyon tamamlanmamıştır.

İlk açılışta **Mac'imi hazırla** Takvim/bildirim izinlerini ister ve girişte başlatmayı açar. macOS gerektiğinde onayını sorar. Reddedilmiş izinlerde ilgili sistem ayarı doğrudan açılır.

- Pencereyi kapatsan da menü simgesi ve ekran kenarı tutamağı kalır.
- Tutamağı üst, alt, sağ veya sola, başka monitöre sürükleyebilirsin.
- Tıkla, içeri kaydır veya Control + Option + H kullan; panel açılır. Escape ile gizlenir.
- Hatırlatmada tutamak üç kısa hareket yapar; Hareketi Azalt açıksa sabit işaret gösterir.
- Takvim uygulamasında zaten eşitlenen Google, Outlook, Exchange ve iCloud takvimleri aynı macOS izniyle kullanılabilir.
- Çalışma günü ve geceye taşan mesai seçilebilir. Saat dilimi bu Mac'i izler.
- Yeni bağlanan mail kaynağı geçmiş maillerin tümü için uyarı vermez.
- Tokenlar Keychain'de, iş başlıkları ve ayarlar yerel dosyada tutulur. Dosya uygulama tarafından şifrelenmez.
- Eşitleme Mac uyanıkken 3 dakikada birdir; push değildir. Bilerek Çık seçersen uygulama kapanır, girişte başlatma bir sonraki oturum açılışında çalışır.

Geliştirici olarak kendi hesaplarınla test yapacaksan alanlar **Tanılama → Geliştirici bağlantıları** içindedir. Bunlar normal kurulumun gereği değildir.

[Türkçe adım adım kurulum](KURULUM.tr.md) · [İngilizce kurulum](SETUP.md) · [Doğrulama](VALIDATION.md) · [Yol haritası](ROADMAP.md)
