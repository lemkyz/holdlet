import AppKit
import HoldletCore
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: AppState
    @State private var googleClientID = ""
    @State private var googleSecret = ""
    @State private var slackToken = ""
    @State private var slackQuery = ""
    @State private var jiraSite = ""
    @State private var jiraEmail = ""
    @State private var jiraToken = ""
    @State private var gmailQuery = ""
    @State private var connecting = false
    @State private var confirmReset = false
    @State private var importedGoogleClient = false
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            if model.demoInstance {
                HStack {
                    Text(model.text("Isolated demo · account setup is disabled.", "Yalıtılmış demo · hesap kurulumu kapalı."))
                    Spacer()
                    Button(model.text("Open normal mode", "Normal modu aç")) { model.exitDemo() }
                }.font(.system(size: 12)).padding(12)
            }
            if let error = model.error {
                HStack { Image(systemName: "exclamationmark.triangle"); Text(error).textSelection(.enabled); Spacer(); Button { model.error = nil } label: { Image(systemName: "xmark") } }
                    .font(.system(size: 12)).padding(12).background(.orange.opacity(0.12))
            }
            if model.googleSigningIn {
                HStack { ProgressView().controlSize(.small); Text(model.text("Finish signing in in your browser…", "Tarayıcıda girişini tamamla…")); Spacer(); Button(model.text("Cancel", "İptal")) { model.googleAuth.cancel() } }.padding(12)
            }
            TabView(selection: $model.settingsPage) {
                general.tabItem { Label(model.text("General", "Genel"), systemImage: "slider.horizontal.3") } .tag("general")
                connections.disabled(model.demoInstance).tabItem { Label(model.text("Connections", "Bağlantılar"), systemImage: "link") } .tag("connections")
                rules.tabItem { Label(model.text("Rules", "Kurallar"), systemImage: "line.3.horizontal.decrease.circle") } .tag("rules")
                privacy.tabItem { Label(model.text("Privacy", "Gizlilik"), systemImage: "hand.raised") } .tag("privacy")
                diagnostics.tabItem { Label(model.text("Diagnostics", "Tanılama"), systemImage: "stethoscope") } .tag("diagnostics")
            }.padding(14)
            Link(model.text("Connection setup guide", "Adım adım bağlantı kurulumu"), destination: URL(string: model.preferences.language == "tr"
                ? "https://github.com/lemkyz/holdlet/blob/main/docs/KURULUM.tr.md"
                : "https://github.com/lemkyz/holdlet/blob/main/docs/SETUP.md")!)
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.bottom, 12)
        }.frame(minWidth: 620, idealWidth: 660, minHeight: 570, idealHeight: 650)
        .sheet(isPresented: $showAdvanced) {
            VStack(spacing: 0) {
                HStack { Text(model.text("Developer connections", "Geliştirici bağlantıları")).font(.headline); Spacer(); Button(model.text("Done", "Bitti")) { showAdvanced = false } }.padding(20)
                developer.disabled(model.demoInstance)
            }.frame(width: 640, height: 620)
        }
        .onAppear {
            googleClientID = model.preferences.googleClientID
            if googleClientID.isEmpty, let bundled = model.bundledGoogleConfiguration {
                googleClientID = bundled.clientID; googleSecret = bundled.clientSecret
            }
            jiraSite = model.preferences.jiraSite; jiraEmail = model.preferences.jiraEmail
            gmailQuery = model.preferences.gmailQuery; slackQuery = model.preferences.slackQuery
            Task { await model.refreshPermissionStatus() }
        }
    }

    private var general: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.text("Your work, within reach.", "İşlerin hep elinin altında.")).font(.system(size: 23, weight: .medium))
                    Text(model.text("Holdlet lives in the menu bar and at the screen edge. You can close this window.",
                        "Holdlet menü çubuğunda ve ekran kenarında kalır. Bu pencereyi kapatabilirsin.")).foregroundStyle(.secondary)
                    if !model.preferences.onboardingComplete {
                        Button(model.preparing ? model.text("Preparing…", "Hazırlanıyor…") : model.text("Set up my Mac", "Mac'imi hazırla")) {
                            Task { await model.prepareMac() }
                        }.buttonStyle(CapsuleAction(primary: true)).disabled(model.preparing || model.demoInstance)
                        Text(model.text("Requests Calendar and notification permission, and enables launch at login. macOS asks for your approval where needed.",
                            "Takvim ve bildirim iznini ister, girişte başlatmayı açar. Gerektiğinde macOS onayını sen verirsin.")).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 8)
                readinessRow(model.text("Calendar", "Takvim"), ready: model.calendar.authorized && model.preferences.calendarEnabled,
                    action: model.text("Connect", "Bağla")) { Task { await model.enableCalendar() } }
                readinessRow(model.text("Notifications", "Bildirimler"), ready: model.preferences.notificationsEnabled && model.notificationsAllowed,
                    action: model.text("Allow", "İzin ver")) { Task { await model.enableNotifications() } }
                readinessRow(model.text("Start automatically", "Otomatik başlat"), ready: SMAppService.mainApp.status == .enabled,
                    action: model.text("Enable", "Aç")) { model.setLaunchAtLogin(true) }
                if SMAppService.mainApp.status == .requiresApproval {
                    Button(model.text("Approve in Login Items", "Giriş Öğeleri'nde onayla")) { SMAppService.openSystemSettingsLoginItems() }
                }
            } header: { Text(model.text("Ready for every day", "Her gün hazır")) }
            Section {
                Toggle(model.text("Keep a handle at the screen edge", "Ekran kenarında tutamak göster"), isOn: dockPreference(\.enabled))
                Picker(model.text("Screen edge", "Ekran kenarı"), selection: dockPreference(\.edge)) {
                    ForEach(ScreenEdge.allCases, id: \.self) { Text(edgeName($0)).tag($0) }
                }
                Text(model.text("Drag the handle to another edge or display. Click it to open or hide Holdlet. Escape also hides the panel.",
                    "Tutamağı başka bir kenara veya monitöre sürükle. Tıklayarak Holdlet'i aç veya gizle. Escape de paneli gizler.")).font(.caption).foregroundStyle(.secondary)
                Toggle(model.text("Nudge the handle for reminders", "Hatırlatmada tutamağı hareket ettir"), isOn: dockPreference(\.alerts))
                Toggle(model.text("Play a reminder sound", "Hatırlatma sesi çal"), isOn: dockPreference(\.sound))
                Button(model.text("Preview the nudge", "Tutamağı dene")) { model.previewEdge?() }.disabled(!model.preferences.dock.enabled)
                Text(model.text("Three small nudges, with a static highlight when Reduce Motion is on. Focus sessions silence incoming-message nudges; deadlines still appear. System Focus controls macOS notifications.",
                    "Üç küçük hareket; Hareketi Azalt açıksa sabit işaret. Odak oturumunda yeni mesajlar sessiz kalır, son tarihler görünür. macOS bildirimlerini sistemin Odak ayarı yönetir.")).font(.caption).foregroundStyle(.secondary)
            } header: { Text(model.text("Always within reach", "Hep görünür")) }
            Section {
                Picker(model.text("Language", "Dil"), selection: preference(\.language)) { Text("English").tag("en"); Text("Türkçe").tag("tr") }
                Toggle(model.text("Launch at login", "Girişte başlat"), isOn: Binding(get: { SMAppService.mainApp.status == .enabled }, set: { model.setLaunchAtLogin($0) })).disabled(model.demoInstance)
                Toggle(model.text("Schedule macOS notifications", "macOS bildirimlerini planla"), isOn: Binding(get: { model.preferences.notificationsEnabled }, set: { enabled in
                    if enabled { Task { await model.enableNotifications() } } else { model.updatePreferences { $0.notificationsEnabled = false } }
                }))
                HStack {
                    Button(model.text("Notification settings", "Bildirim ayarları")) { openSystemSettings("com.apple.Notifications-Settings.extension") }
                    Button(model.text("Send test in 5 seconds", "5 saniye sonra test gönder")) { Task { await model.testNotification() } }.disabled(!model.preferences.notificationsEnabled)
                }
                Toggle(model.text("Open anywhere with Control + Option + H", "Control + Option + H ile her yerden aç"), isOn: Binding(get: { model.preferences.globalShortcutEnabled ?? true }, set: { enabled in model.updatePreferences { $0.globalShortcutEnabled = enabled } }))
                if (model.preferences.globalShortcutEnabled ?? true) && !model.shortcutAvailable {
                    Text(model.text("This shortcut is unavailable. Another app may already use it; the menu icon and edge handle still work.", "Kısayol kullanılamıyor. Başka bir uygulama kullanıyor olabilir; menü simgesi ve tutamak çalışmaya devam eder.")).font(.caption).foregroundStyle(.secondary)
                }
                Toggle(model.text("Show sample data", "Örnek verileri göster"), isOn: preference(\.demoMode))
                Text("Holdlet 0.2.0-alpha · macOS 14+").font(.caption).foregroundStyle(.secondary)
            } header: { Text(model.text("Preferences", "Tercihler")) }
        }.formStyle(.grouped)
    }

    private func readinessRow(_ title: String, ready: Bool, action: String, perform: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: ready ? "checkmark.circle.fill" : "circle")
            Spacer()
            if ready { Text(model.text("Ready", "Hazır")).font(.caption).foregroundStyle(.secondary) }
            else { Button(action, action: perform).disabled(model.demoInstance || model.preparing) }
        }
    }
    private func edgeName(_ edge: ScreenEdge) -> String {
        switch edge {
        case .top: model.text("Top", "Üst")
        case .bottom: model.text("Bottom", "Alt")
        case .left: model.text("Left", "Sol")
        case .right: model.text("Right", "Sağ")
        }
    }
    private func dockPreference<T>(_ path: WritableKeyPath<EdgeDockPreferences, T>) -> Binding<T> {
        Binding(get: { model.preferences.dock[keyPath: path] }, set: { value in
            model.updatePreferences { prefs in var dock = prefs.dock; dock[keyPath: path] = value; prefs.edgeDock = dock }
        })
    }
    private func openSystemSettings(_ pane: String) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:" + pane)!) }

    private var connections: some View {
        Form {
            Section {
                Text(model.text("Connect once. Keep your day in view.", "Bir kez bağla, gününü takip et.")).font(.system(size: 22, weight: .medium)).padding(.vertical, 6)
                Text(model.text("Calendar permission is handled by macOS. Account sign-in opens your browser when that service is available in this build.",
                    "Takvim iznini macOS verir. Bu pakette hazır olan hesap bağlantıları giriş için tarayıcını açar.")).font(.caption).foregroundStyle(.secondary)
            }
            Section {
                connectionStatus(.calendar)
                if model.preferences.calendarEnabled && model.calendar.authorized {
                    DisclosureGroup(model.text("Choose calendars", "Takvimleri seç")) {
                        ForEach(model.calendar.availableCalendars, id: \.calendarIdentifier) { calendar in
                            Toggle(calendar.title, isOn: Binding(get: {
                                model.preferences.selectedCalendarIDs.isEmpty || model.preferences.selectedCalendarIDs.contains(calendar.calendarIdentifier)
                            }, set: { checked in
                                var ids = model.preferences.selectedCalendarIDs
                                if ids.isEmpty { ids = model.calendar.availableCalendars.map(\.calendarIdentifier) }
                                ids.removeAll { $0 == calendar.calendarIdentifier }
                                if checked { ids.append(calendar.calendarIdentifier) }
                                if ids.isEmpty { ids = ["__none__"] }
                                model.updatePreferences { $0.selectedCalendarIDs = ids }; Task { await model.sync() }
                            }))
                        }
                    }
                    Button(model.text("Disconnect calendar", "Takvim bağlantısını kaldır")) { model.disconnect(.calendar) }
                } else {
                    Button(model.text("Allow calendar access", "Takvim erişimine izin ver")) { Task { await model.enableCalendar() } }
                    if !model.calendar.authorized {
                        Button(model.text("Open Calendar permission", "Takvim iznini aç")) { openSystemSettings("com.apple.preference.security?Privacy_Calendars") }
                    }
                }
                Button(model.text("Add Google, Outlook or Exchange calendar", "Google, Outlook veya Exchange takvimi ekle")) {
                    openSystemSettings("com.apple.Internet-Accounts-Settings.extension")
                }
                Text(model.text("Calendars already on this Mac work with one permission. Add another account in Internet Accounts, then enable Calendar for it.",
                    "Bu Mac'teki takvimler tek izinle çalışır. Yeni hesabı İnternet Hesapları'na ekleyip Takvim'i açabilirsin.")).font(.caption).foregroundStyle(.secondary)
            } header: { Text(model.text("Meetings · Google Meet, Teams, Zoom", "Toplantılar · Google Meet, Teams, Zoom")) }
            Section {
                connectionStatus(.gmail)
                if model.preferences.googleEnabled {
                    Button(model.text("Sign in again", "Yeniden giriş yap")) { Task { await model.reconnectGoogle() } }.disabled(model.googleSigningIn)
                    Toggle(model.text("Also use direct Google Calendar", "Doğrudan Google Takvim'i de kullan"), isOn: Binding(get: { model.preferences.usesGoogleCalendar }, set: { model.useGoogleCalendar($0) }))
                    Button(model.text("Disconnect Gmail", "Gmail bağlantısını kaldır")) { model.disconnect(.gmail) }
                } else if let config = model.bundledGoogleConfiguration {
                    Button(model.text("Continue with Google", "Google ile devam et")) { Task { await model.connectGoogle(clientID: config.clientID, clientSecret: config.clientSecret) } }.disabled(model.googleSigningIn)
                } else {
                    Label(model.text("Publisher setup pending", "Yayıncı bağlantısı hazırlanıyor"), systemImage: "clock")
                    Text(model.text("Gmail sign-in is not available in this preview package. Calendar connections work now. You do not need to create a developer project.",
                        "Bu önizleme paketinde Gmail girişi henüz hazır değil. Takvim bağlantısı kullanılabilir. Bir geliştirici projesi oluşturman gerekmiyor.")).font(.caption).foregroundStyle(.secondary)
                }
            } header: { Text(model.text("Important mail", "Önemli mailler")) }
            Section {
                connectionStatus(.slack)
                if model.preferences.slackEnabled { Button(model.text("Disconnect Slack", "Slack bağlantısını kaldır")) { model.disconnect(.slack) } }
                else { Text(model.text("Workspace sign-in is waiting for the publisher's Slack application. Your organization may need to approve it.",
                    "Çalışma alanıyla giriş için yayıncının Slack uygulaması gerekiyor. Kuruluşun ayrıca onay isteyebilir.")).font(.caption).foregroundStyle(.secondary) }
                connectionStatus(.jira)
                if model.preferences.jiraEnabled { Button(model.text("Disconnect Jira", "Jira bağlantısını kaldır")) { model.disconnect(.jira) } }
                else { Text(model.text("Jira account sign-in is pending publisher registration. Internal developer connections are available under Advanced.",
                    "Jira hesap girişi yayıncı kaydını bekliyor. Kurum içi geliştirici bağlantıları Gelişmiş bölümünde.")).font(.caption).foregroundStyle(.secondary) }
            } header: { Text(model.text("Workspace", "Çalışma alanı")) }
        }.formStyle(.grouped)
    }

    private var developer: some View {
        Form {
            Section {
                Text(model.text("For contributors and internal deployments. Ordinary users should use Connections; publisher registrations belong in the release build.",
                    "Katkı verenler ve kurum içi dağıtımlar için. Normal kullanım Bağlantılar ekranındadır; yayıncı kayıtları sürüm paketine aittir.")).font(.caption)
            } header: { Text(model.text("Developer connections", "Geliştirici bağlantıları")) }
            Section {
                connectionStatus(.calendar)
                if model.preferences.calendarEnabled {
                    if !model.calendar.authorized {
                        Button(model.text("Review Calendar permission", "Takvim iznini yenile")) { Task { await model.enableCalendar() } }
                        Button(model.text("Open Calendar privacy settings", "Takvim gizlilik ayarlarını aç")) {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                        }
                    }
                    Text(model.text("Timed events from the next 7 days. All-day and declined events are excluded.", "Önümüzdeki 7 günün saatli etkinlikleri. Tüm gün ve reddedilen etkinlikler gösterilmez.")).font(.caption)
                    ForEach(model.calendar.availableCalendars, id: \.calendarIdentifier) { calendar in
                        Toggle(calendar.title, isOn: Binding(get: {
                            model.preferences.selectedCalendarIDs.isEmpty || model.preferences.selectedCalendarIDs.contains(calendar.calendarIdentifier)
                        }, set: { checked in
                            var ids = model.preferences.selectedCalendarIDs
                            if ids.isEmpty { ids = model.calendar.availableCalendars.map(\.calendarIdentifier) }
                            if checked { if !ids.contains(calendar.calendarIdentifier) { ids.append(calendar.calendarIdentifier) } }
                            else { ids.removeAll { $0 == calendar.calendarIdentifier } }
                            // Empty selection means all calendars, so retain a sentinel for none.
                            if ids.isEmpty { ids = ["__none__"] }
                            model.updatePreferences { $0.selectedCalendarIDs = ids }
                            Task { await model.sync() }
                        }))
                    }
                    Button(model.text("Disconnect", "Bağlantıyı kaldır")) { model.disconnect(.calendar) }
                } else {
                    Button(model.text("Allow Mac Calendar access", "Mac Takvim erişimine izin ver")) { Task { await model.enableCalendar() } }
                }
            } header: { Text("Mac Calendar") } footer: {
                Text(model.text("Uses calendars already synced with Calendar.app. Gmail can stay connected alongside Mac Calendar.",
                    "Takvim uygulamasına eşitlenen takvimleri kullanır. Gmail, Mac Takvim ile birlikte bağlı kalabilir."))
            }
            Section {
                if model.preferences.usesGoogleCalendar { connectionStatus(.google) }
                connectionStatus(.gmail)
                if model.preferences.googleEnabled {
                    Toggle(model.text("Use direct Google Calendar", "Doğrudan Google Takvim kullan"), isOn: Binding(
                        get: { model.preferences.usesGoogleCalendar }, set: { model.useGoogleCalendar($0) }))
                    Text(model.text("Keep this off to use Mac Calendar while Gmail remains connected.", "Mac Takvim'i kullanırken Gmail bağlı kalsın istiyorsan bunu kapalı tut.")).font(.caption)
                    Button(model.text("Sign in again", "Yeniden giriş yap")) { Task { await model.reconnectGoogle() } }
                        .disabled(model.googleSigningIn)
                    Button(model.text("Disconnect Google", "Google bağlantısını kaldır")) { model.disconnect(.google) }
                } else {
                    if googleClientID.isEmpty {
                        Label(model.text("Google application setup required", "Google uygulama kurulumu gerekiyor"), systemImage: "wrench.and.screwdriver")
                        Text(model.text("This build does not include a configured Google OAuth application. Import a Desktop client JSON to test your account. A shared Google sign-in needs the publisher's registered OAuth app.",
                            "Bu pakette Google OAuth uygulaması tanımlı değil. Kendi hesabını denemek için Desktop istemci JSON dosyasını içe aktar. Ortak Google girişi için yayıncıya ait kayıtlı OAuth uygulaması gerekir.")).font(.caption)
                    }
                    Button(model.text(googleClientID.isEmpty ? "Set up Google connection…" : "Import another Desktop client…",
                        googleClientID.isEmpty ? "Google bağlantısını kur…" : "Başka masaüstü istemcisi seç…")) { importGoogleClient() }
                    if importedGoogleClient { Label(model.text("Desktop client loaded", "Masaüstü istemcisi yüklendi"), systemImage: "checkmark.circle").font(.caption) }
                    DisclosureGroup(model.text("Manual developer configuration", "Elle geliştirici kurulumu")) {
                        TextField(model.text("Desktop OAuth client ID", "Masaüstü OAuth istemci kimliği"), text: $googleClientID)
                        SecureField(model.text("Desktop client secret (if required)", "Masaüstü istemci sırrı (gerekiyorsa)"), text: $googleSecret)
                    }
                    if !googleClientID.isEmpty {
                    Button(model.text("Sign in with Google", "Google ile giriş yap")) {
                        Task {
                            await model.connectGoogle(clientID: googleClientID, clientSecret: googleSecret)
                            if model.preferences.googleEnabled { googleSecret = "" }
                        }
                    }.disabled(model.googleSigningIn)
                    }
                }
                Text(model.text("Read-only Google access. Primary calendar is optional; Gmail is independent of your calendar source. No connection is claimed until the service sync succeeds.",
                    "Google erişimi salt okunur. Birincil takvim isteğe bağlıdır; Gmail takvim kaynağından bağımsızdır. Servis eşitlemesi başarılı olmadan bağlı sayılmaz.")).font(.caption)
            } header: { Text("Google Workspace") }
            Section {
                connectionStatus(.slack)
                if model.preferences.slackEnabled {
                    Button(model.text("Disconnect Slack", "Slack bağlantısını kaldır")) { model.disconnect(.slack) }
                } else {
                    SecureField(model.text("User OAuth token · search:read", "Kullanıcı OAuth tokenı · search:read"), text: $slackToken)
                    TextField(model.text("Slack search query", "Slack arama sorgusu"), text: $slackQuery)
                    Button(model.text("Test and connect", "Test et ve bağla")) {
                        connecting = true
                        Task { await model.connectSlack(token: slackToken, query: slackQuery); slackToken = ""; connecting = false }
                    }.disabled(connecting || slackToken.isEmpty)
                }
                Text(model.text("Internal personal setup. Requires an approved user token with search:read; a bot token is insufficient. Up to 100 search matches. Does not infer whether you replied.",
                    "Kişisel kurum içi kurulum. search:read yetkili kullanıcı tokenı gerekir; bot tokenı yetmez. En fazla 100 eşleşme. Yanıt verip vermediğini tahmin etmez.")).font(.caption)
            } header: { Text("Slack") }
            Section {
                connectionStatus(.jira)
                if model.preferences.jiraEnabled {
                    Button(model.text("Disconnect Jira", "Jira bağlantısını kaldır")) { model.disconnect(.jira) }
                } else {
                    TextField("https://your-company.atlassian.net", text: $jiraSite)
                    TextField(model.text("Atlassian account email", "Atlassian hesap e-postası"), text: $jiraEmail)
                    SecureField(model.text("Unscoped personal API token", "Kapsamsız kişisel API tokenı"), text: $jiraToken)
                    Button(model.text("Test and connect", "Test et ve bağla")) {
                        connecting = true
                        Task { await model.connectJira(site: jiraSite, email: jiraEmail, token: jiraToken); jiraToken = ""; connecting = false }
                    }.disabled(connecting || jiraSite.isEmpty || jiraEmail.isEmpty || jiraToken.isEmpty)
                }
                Text(model.text("Jira Cloud only. Personal API token setup for alpha; scoped gateway tokens and Data Center are not supported. Reads your first 100 unfinished assigned issues. No Jira writes.",
                    "Yalnızca Jira Cloud. Alfa için kişisel API tokenı; kapsamlı gateway tokenları ve Data Center desteklenmez. Sana atanmış en fazla 100 açık işi okur. Jira'ya yazmaz.")).font(.caption)
            } header: { Text("Jira Cloud") }
        }.formStyle(.grouped)
    }

    private var rules: some View {
        Form {
            Section {
                Toggle(model.text("Only alert within work hours", "Yalnızca çalışma saatlerinde uyar"), isOn: preference(\.respectWorkHours))
                Picker(model.text("Start", "Başlangıç"), selection: preference(\.workStart)) { ForEach(0..<24) { Text(String(format: "%02d:00", $0)).tag($0) } }
                Picker(model.text("End", "Bitiş"), selection: preference(\.workEnd)) { ForEach(1...24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) } }
                Text(model.text("Overnight shifts are supported. Equal start and end mean all day. Hours follow this Mac's time zone.", "Geceye taşan mesai desteklenir. Başlangıç ve bitiş aynıysa tüm gün. Saatler bu Mac'in saat dilimini izler.")).font(.caption)
                Picker(model.text("Meeting reminder", "Toplantı hatırlatması"), selection: preference(\.meetingLeadMinutes)) {
                    ForEach([0, 2, 5, 10, 15], id: \.self) { Text("\($0) " + model.text("minutes before", "dakika önce")).tag($0) }
                }
                ForEach(1...7, id: \.self) { day in
                    Toggle(Calendar.current.weekdaySymbols[day - 1], isOn: Binding(get: { (model.preferences.workdays ?? Array(1...7)).contains(day) }, set: { enabled in
                        var days = model.preferences.workdays ?? Array(1...7)
                        days.removeAll { $0 == day }; if enabled { days.append(day) }
                        model.updatePreferences { $0.workdays = days.sorted() }
                    }))
                }
            } header: { Text(model.text("Timing", "Zamanlama")) }
            Section {
                DisclosureGroup(model.text("Advanced search filters", "Gelişmiş arama filtreleri")) {
                TextField(model.text("Gmail search query", "Gmail arama sorgusu"), text: $gmailQuery)
                TextField(model.text("Slack search query", "Slack arama sorgusu"), text: $slackQuery)
                Button(model.text("Save search rules", "Arama kurallarını kaydet")) {
                    model.updatePreferences { $0.gmailQuery = gmailQuery; $0.slackQuery = slackQuery }
                    Task { await model.sync() }
                }
                Text(model.text("Gmail: unread important mail from the last 7 days. Slack: use native search syntax; narrow the query if the service reports too many results. Sync runs every 3 minutes while awake.",
                    "Gmail: son 7 günün okunmamış önemli mailleri. Slack: kendi arama sözdizimini kullan; çok sonuç varsa sorguyu daralt. Mac uyanıkken 3 dakikada bir eşitlenir.")).font(.caption)
                }
            } header: { Text(model.text("What needs attention", "İlgilenilecek işler")) }
            Section {
                Text(model.text("Reading is not completing. Put a Gmail thread in Waiting for reply to watch for a new incoming message; it returns to your active list on the next successful sync. Slack reply tracking is manual. Jira dates use 17:00 in your Mac's time zone.",
                    "Okundu, tamamlandı demek değildir. Gmail'de Yanıt bekleniyor seçtiğin konuşmaya yeni gelen mesaj, başarılı eşitlemede aktif listeye döner. Slack yanıt takibi elle yönetilir. Jira tarihleri Mac saat diliminde 17:00 olarak yorumlanır.")).font(.caption)
            }
        }.formStyle(.grouped)
    }

    private var privacy: some View {
        Form {
            Section {
                Toggle(model.text("Hide item titles and senders", "İş başlıklarını ve gönderenleri gizle"), isOn: preference(\.hideDetails))
                Text(model.text("Use when sharing your screen. This is a manual privacy mode; automatic screen-share detection is not included. Notification content is hidden too.",
                    "Ekran paylaşırken kullan. Bu mod elle açılır; otomatik paylaşım algısı yoktur. Bildirim içeriği de gizlenir.")).font(.caption)
            }
            Section {
                Label(model.text("Credentials stay in macOS Keychain", "Kimlik bilgileri macOS Keychain'de"), systemImage: "key")
                Label(model.text("No analytics, ads, or AI service calls", "Analitik, reklam veya AI servisi çağrısı yok"), systemImage: "hand.raised")
                Label(model.text("Service requests go directly to connected providers", "Servis istekleri doğrudan bağlanan sağlayıcıya gider"), systemImage: "network")
                Text(model.text("Follow-ups and preferences are stored in a permission-restricted local JSON file. The file is not application-encrypted. FileVault is controlled by your system settings. Disconnect a source to remove its local items and credentials.",
                    "Takipler ve ayarlar izinleri kısıtlanmış yerel JSON dosyasında saklanır. Dosya uygulama tarafından şifrelenmez. FileVault sistem ayarlarına bağlıdır. Yerel iş ve anahtarları silmek için kaynağın bağlantısını kaldır.")).font(.caption)
                Button(model.text("Clear delivered Holdlet notifications", "Görünen Holdlet bildirimlerini temizle")) { model.notifications.clearDelivered() }
            } header: { Text(model.text("Data handling", "Veri işleme")) }
        }.formStyle(.grouped)
    }

    private var diagnostics: some View {
        Form {
            Section {
                ForEach(model.enabledSources) { source in connectionStatus(source) }
                Button(model.isSyncing ? model.text("Refreshing…", "Yenileniyor…") : model.text("Refresh all sources", "Tüm kaynakları yenile")) { Task { await model.sync() } }.disabled(model.isSyncing)
                Text(model.text("Connection errors preserve the last successful snapshot. A stale snapshot is not evidence that nothing new arrived.",
                    "Bağlantı hatasında son başarılı veriler korunur. Eski veriler, yeni iş gelmediği anlamına gelmez.")).font(.caption)
            } header: { Text(model.text("Connection health", "Bağlantı sağlığı")) }
            Section {
                Button(model.text("Developer connections…", "Geliştirici bağlantıları…")) { showAdvanced = true }
                Button(model.text("Show local data folder", "Yerel veri klasörünü göster")) { NSWorkspace.shared.activateFileViewerSelecting([model.stateFileURL]) }
                Button(model.text("Open notification settings", "Bildirim ayarlarını aç")) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!) }
                Button(model.text("Export redacted diagnostics…", "İçeriksiz tanılama dışa aktar…")) { exportDiagnostics() }
                Button(model.text("Back up and reset local state…", "Yerel durumu yedekle ve sıfırla…"), role: .destructive) { confirmReset = true }
                Text(model.text("Diagnostics contain counts and connection timestamps, never tokens or item content. Reset keeps a backup file and removes scheduled alerts; it does not revoke provider tokens.",
                    "Tanılama yalnızca sayılar ve bağlantı zamanları içerir; token veya iş içeriği içermez. Sıfırlama yedek oluşturur ve planlı uyarıları kaldırır; sağlayıcı tokenlarını iptal etmez.")).font(.caption)
            } header: { Text(model.text("Troubleshooting", "Sorun giderme")) }
        }.formStyle(.grouped)
        .confirmationDialog(model.text("Back up and reset Holdlet?", "Holdlet yedeklenip sıfırlansın mı?"), isPresented: $confirmReset) {
            Button(model.text("Back up and reset", "Yedekle ve sıfırla"), role: .destructive) { model.resetCorruptState() }
        }
    }

    private func connectionStatus(_ source: Source) -> some View {
        let status = model.snapshot.health[source.rawValue]
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(source.title, systemImage: source.symbol)
                Spacer()
                Text(status?.message ?? model.text("Not connected", "Bağlı değil"))
                    .font(.caption).foregroundStyle(status?.isError == true ? .orange : .secondary).textSelection(.enabled)
            }
            if let last = status?.lastSuccess {
                Text(model.text("Last successful sync: ", "Son başarılı eşitleme: ") + last.formatted())
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func preference<T>(_ keyPath: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(get: { model.preferences[keyPath: keyPath] }, set: { value in model.updatePreferences { $0[keyPath: keyPath] = value } })
    }
    private func importGoogleClient() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) <= 65_536 else { throw GoogleOAuthConfiguration.SetupError.invalidFile }
            let config = try GoogleOAuthConfiguration(desktopJSON: Data(contentsOf: url))
            googleClientID = config.clientID; googleSecret = config.clientSecret; importedGoogleClient = true
        } catch { model.error = error.localizedDescription }
    }
    private func exportDiagnostics() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "holdlet-diagnostics.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data: [String: Any] = ["version": "0.2.0-alpha", "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "itemCount": model.snapshot.items.count, "sources": model.enabledSources.map { source in
                ["source": source.rawValue, "hasError": model.snapshot.health[source.rawValue]?.isError ?? false,
                 "lastSuccess": model.snapshot.health[source.rawValue]?.lastSuccess.map { ISO8601DateFormatter().string(from: $0) } ?? "never"] as [String: Any]
            }]
        do { try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic) }
        catch { model.error = error.localizedDescription }
    }
}
