import AppKit
import Combine
import Foundation
import HoldletCore
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    @Published var snapshot: Snapshot
    @Published var now = Date()
    @Published var isSyncing = false
    @Published var error: String?
    @Published var notice: String?
    @Published var googleSigningIn = false
    @Published var gmailNextPageToken: String?
    @Published var loadingMoreMail = false
    @Published private var gmailMatchingIDs: Set<String>?
    @Published var notificationStatus = ""
    @Published var notificationsAllowed = false
    @Published var settingsPage = "general"
    @Published var preparing = false
    @Published var shortcutAvailable = false
    let calendar = CalendarConnector()
    let googleAuth = GoogleAuth()
    let notifications: NotificationService
    let demoInstance: Bool
    var showPanel: (() -> Void)?
    var showSettings: (() -> Void)?
    var hidePanel: (() -> Void)?
    var previewEdge: (() -> Void)?
    private let disk: SnapshotStore
    private var clock: Timer?
    private var poll: Timer?
    private var mailPoll: Timer?
    private var gmailHistoryID: String?
    private var syncedGmailQuery: String?
    private var generation = 0
    private var readOnly = false
    private var retryAfter: [Source: Date] = [:]
    private var observers: [NSObjectProtocol] = []
    private var reconcileTask: Task<Void, Never>?
    private var demoItems: [AttentionItem] = []

    init(demoInstance: Bool = false) {
        self.demoInstance = demoInstance
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent(demoInstance ? "Holdlet-Demo" : "Holdlet")
        disk = SnapshotStore(url: folder.appendingPathComponent("state-v1.json"))
        // Foundation may reject using the current application's domain as a named suite.
        // The normal app must use .standard; named suites are only for isolated demos.
        let defaults = demoInstance ? (UserDefaults(suiteName: "io.github.lemkyz.holdlet.demo") ?? .standard) : .standard
        notifications = NotificationService(defaults: defaults)
        do { snapshot = demoInstance ? Snapshot() : try disk.load() }
        catch { snapshot = Snapshot(); self.error = "Saved data could not be read. The original file is preserved. Open Settings → Diagnostics."; readOnly = true }
        if !demoInstance && snapshot.preferences.gmailQuery == "is:unread is:important newer_than:7d" {
            snapshot.preferences.gmailQuery = "in:inbox"
        }
        if demoInstance { snapshot.preferences.demoMode = true; snapshot.preferences.onboardingComplete = true }
        if snapshot.preferences.demoMode { makeDemoItems() }
        notifications.onOpen = { [weak self] id in
            guard let self else { return }; self.showPanel?()
            if let id, let item = self.snapshot.items.first(where: { $0.id == id }) { self.open(item) }
        }
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        poll = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.sync() }
        }
        mailPoll = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.sync(mailOnly: true, onlyIfMailboxChanged: true) }
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }; self.now = Date()
                self.notice = self.text("Welcome back. Your open follow-ups are below.", "Tekrar merhaba. Açık takiplerin aşağıda.")
                self.reconcile(); await self.sync()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refreshPermissionStatus() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.sync() }
        })
        Task { await refreshPermissionStatus(); reconcile(); await sync() }
    }

    var preferences: Preferences { snapshot.preferences }
    var allItems: [AttentionItem] { snapshot.items + (preferences.demoMode ? demoItems : []) }
    var active: [AttentionItem] { AttentionEngine.prioritized(allItems, now: now) }
    var nextMeeting: AttentionItem? { AttentionEngine.nextMeeting(allItems, now: now) }
    var openWork: [AttentionItem] { active.filter { $0.kind != .meeting } }
    var mailItems: [AttentionItem] {
        allItems.filter { $0.kind == .mail && ($0.isDemo || ($0.source == .gmail && (gmailMatchingIDs == nil || gmailMatchingIDs!.contains($0.id)))) }
            .sorted { ($0.receivedAt ?? $0.createdAt) > ($1.receivedAt ?? $1.createdAt) }
    }
    func setGmailQuery(_ query: String) {
        guard query != preferences.gmailQuery else { return }
        updatePreferences { $0.gmailQuery = query }
        gmailHistoryID = nil; syncedGmailQuery = nil; gmailNextPageToken = nil; gmailMatchingIDs = []
        Task { await sync(mailOnly: true) }
    }
    func loadMoreMail() async {
        guard let cursor = gmailNextPageToken, !loadingMoreMail, !isSyncing else { return }
        loadingMoreMail = true; isSyncing = true
        defer { loadingMoreMail = false; isSyncing = false }
        let epoch = generation, query = preferences.gmailQuery
        do {
            let token = try await googleAuth.accessToken(clientID: preferences.googleClientID)
            let page = try await GoogleConnector.mailPage(token: token, query: query, pageToken: cursor)
            guard epoch == generation, query == preferences.gmailQuery else { return }
            merge(page.items, source: .gmail)
            gmailMatchingIDs = (gmailMatchingIDs ?? []).union(page.items.map(\.id))
            gmailNextPageToken = page.nextPageToken
            markSuccess(.gmail); save(); reconcile()
        } catch { if epoch == generation { self.error = connectionMessage(error) } }
    }
    var waiting: [AttentionItem] { allItems.filter { $0.state == .waiting } }
    var snoozed: [AttentionItem] { allItems.filter { $0.state != .completed && ($0.snoozedUntil ?? .distantPast) > now } }
    var completed: [AttentionItem] { allItems.filter { $0.state == .completed }.sorted { $0.createdAt > $1.createdAt } }
    var missed: Int { active.filter { $0.dueAt.map { $0 < now } == true && $0.kind != .meeting }.count }
    var isFocusing: Bool { (snapshot.focusEndsAt ?? .distantPast) > now }
    var stateFileURL: URL { disk.url }
    var enabledSources: [Source] {
        var sources: [Source] = []
        if preferences.calendarEnabled { sources.append(.calendar) }
        if preferences.usesGoogleCalendar { sources.append(.google) }
        if preferences.googleEnabled { sources.append(.gmail) }
        if preferences.slackEnabled { sources.append(.slack) }
        if preferences.jiraEnabled { sources.append(.jira) }
        return sources
    }
    func text(_ en: String, _ tr: String) -> String { preferences.language == "tr" ? tr : en }
    func title(_ item: AttentionItem) -> String { preferences.hideDetails ? text("Private item", "Özel iş") : item.title }
    func detail(_ item: AttentionItem) -> String { preferences.hideDetails ? item.source.title : item.detail }
    func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    func countdown(_ date: Date) -> String {
        let remaining = Int(date.timeIntervalSince(now))
        if remaining <= 0 { return text("Now", "Şimdi") }
        if remaining >= 3600 { return "\(remaining / 3600)h \((remaining % 3600) / 60)m" }
        return "\(max(1, (remaining + 59) / 60))"
    }

    func updatePreferences(_ change: (inout Preferences) -> Void) {
        change(&snapshot.preferences); generation += 1
        if preferences.demoMode && demoItems.isEmpty { makeDemoItems() }
        save(); reconcile()
    }
    func addReminder(title: String, due: Date) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, due > now else { return }
        snapshot.items.append(AttentionItem(title: String(title.prefix(300)), dueAt: due,
            reason: text("Added by you", "Sen ekledin")))
        save(); reconcile()
    }
    func setState(_ item: AttentionItem, _ state: FollowUpState) {
        mutate(item.id) { $0.state = state; $0.snoozedUntil = nil }; save(); reconcile()
    }
    func snooze(_ item: AttentionItem, minutes: Int) {
        mutate(item.id) { $0.snoozedUntil = now.addingTimeInterval(Double(minutes * 60)) }; save(); reconcile()
    }
    func unsnooze(_ item: AttentionItem) { mutate(item.id) { $0.snoozedUntil = nil }; save(); reconcile() }
    func removeLocal(_ item: AttentionItem) {
        guard item.source == .local else { return }; snapshot.items.removeAll { $0.id == item.id }; save(); reconcile()
    }
    func open(_ item: AttentionItem, join: Bool = false) {
        if item.isDemo { notice = text("Demo item. No real account is connected.", "Örnek iş. Gerçek hesap bağlı değil."); return }
        guard let url = (join ? item.meetingURL : item.url) ?? item.url,
              let safe = LinkPolicy.safeWebURL(url.absoluteString) else {
            notice = text("No web link on this item. Open the source app for details.", "Bu işte web bağlantısı yok. Kaynak uygulamadan ayrıntıları aç."); return
        }
        NSWorkspace.shared.open(safe)
    }
    func startFocus(minutes: Int = 25) {
        snapshot.focusEndsAt = now.addingTimeInterval(Double(minutes * 60)); save(); reconcile()
    }
    func stopFocus() { snapshot.focusEndsAt = nil; save(); reconcile() }
    func focusTime() -> String {
        let seconds = max(0, Int((snapshot.focusEndsAt ?? now).timeIntervalSince(now)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    func openConnections() { settingsPage = "connections"; showSettings?() }
    func prepareMac() async {
        guard !preparing, !demoInstance else { return }
        preparing = true; defer { preparing = false }
        await enableNotifications()
        await enableCalendar()
        setLaunchAtLogin(true)
        updatePreferences { $0.edgeDock = EdgeDockPreferences(); $0.onboardingComplete = true }
        notice = text("Holdlet stays in the menu bar and at the screen edge. Close this window whenever you like.",
                      "Holdlet menü çubuğunda ve ekran kenarında kalır. Bu pencereyi kapatabilirsin.")
    }
    func completeOnboarding() { updatePreferences { $0.onboardingComplete = true } }
    func exitDemo() {
        guard demoInstance else { updatePreferences { $0.demoMode = false }; return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--show"]
        configuration.createsNewApplicationInstance = true
        Task {
            do {
                _ = try await NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
                NSApplication.shared.terminate(nil)
            } catch { self.error = error.localizedDescription }
        }
    }

    func enableNotifications() async {
        do {
            if await notifications.permissionStatus() == .denied {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                notice = text("Enable Holdlet in Notifications, then return here.", "Bildirimler'de Holdlet'e izin verip buraya dön.")
                return
            }
            let granted = try await notifications.requestAuthorization()
            updatePreferences { $0.notificationsEnabled = granted }
            await refreshPermissionStatus()
            if !granted { error = text("Allow Holdlet notifications in System Settings → Notifications.", "Sistem Ayarları → Bildirimler'den Holdlet'e izin ver.") }
        } catch { self.error = error.localizedDescription }
    }
    func testNotification() async {
        do { try await notifications.test(language: preferences.language); notice = text("Test reminder scheduled for 5 seconds from now.", "Test hatırlatması 5 saniye sonrasına kuruldu.") }
        catch { self.error = error.localizedDescription }
    }
    func refreshPermissionStatus() async {
        let status = await notifications.permissionStatus()
        notificationsAllowed = status == .authorized || status == .provisional
        notificationStatus = notificationsAllowed ? text("Allowed", "İzin verildi") : text("Not allowed", "İzin yok")
    }
    func enableCalendar() async {
        if calendar.needsSettings {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
            notice = text("Enable Holdlet in Calendar permissions, then connect again.", "Takvim izinlerinde Holdlet'i açıp yeniden bağlan.")
            return
        }
        do {
            guard try await calendar.authorize() else { throw APIError.provider("calendar_permission_denied") }
            updatePreferences { $0.selectMacCalendar() }
            snapshot.items.removeAll { $0.source == .google }
            save(); reconcile()
            await sync()
        } catch { self.error = connectionMessage(error) }
    }
    func connectGoogle(clientID: String, clientSecret: String) async {
        guard !googleSigningIn else { return }
        googleSigningIn = true; defer { googleSigningIn = false }
        do {
            let configuration = try GoogleOAuthConfiguration(clientID: clientID, clientSecret: clientSecret)
            try await googleAuth.authorize(configuration: configuration)
            updatePreferences { $0.connectGoogle(clientID: configuration.clientID) }
            save(); reconcile()
            await sync()
        } catch is CancellationError {
            notice = text("Google sign-in canceled. Your existing connections are unchanged.", "Google girişi iptal edildi. Mevcut bağlantıların korunuyor.")
        } catch { self.error = connectionMessage(error) }
    }
    func useGoogleCalendar(_ enabled: Bool) {
        updatePreferences { $0.selectGoogleCalendar(enabled) }
        snapshot.items.removeAll { enabled ? $0.source == .calendar : $0.source == .google }
        save(); reconcile(); Task { await sync() }
    }
    func reconnectGoogle() async {
        do {
            let secret = try SecretStore.get("google.clientSecret") ?? ""
            await connectGoogle(clientID: preferences.googleClientID, clientSecret: secret)
        } catch { self.error = connectionMessage(error) }
    }
    var bundledGoogleConfiguration: GoogleOAuthConfiguration? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "HoldletGoogleClientID") as? String else { return nil }
        return try? GoogleOAuthConfiguration(clientID: id,
            clientSecret: Bundle.main.object(forInfoDictionaryKey: "HoldletGoogleClientSecret") as? String ?? "")
    }
    func connectSlack(token: String, query: String) async {
        do {
            let items = try await SlackConnector.fetch(token: token, query: query)
            try SecretStore.set(token, for: "slack.token")
            updatePreferences { $0.slackEnabled = true; $0.slackQuery = query }
            merge(items, source: .slack); markSuccess(.slack); save(); reconcile()
        } catch { self.error = error.localizedDescription }
    }
    func connectJira(site: String, email: String, token: String) async {
        do {
            let items = try await JiraConnector.fetch(site: site, email: email, token: token, scope: preferences.jiraScope ?? .involved, scopedToken: preferences.jiraScopedToken ?? false)
            try SecretStore.set(token, for: "jira.token")
            updatePreferences { $0.jiraEnabled = true; $0.jiraSite = site; $0.jiraEmail = email }
            merge(items, source: .jira); markSuccess(.jira); save(); reconcile()
        } catch { self.error = error.localizedDescription }
    }
    func disconnect(_ source: Source) {
        generation += 1
        do {
            let sources: Set<Source>
            switch source {
            case .google, .gmail:
                gmailNextPageToken = nil; gmailMatchingIDs = nil; gmailHistoryID = nil; syncedGmailQuery = nil
                googleAuth.cancel(); try SecretStore.delete("google.tokens"); try SecretStore.delete("google.clientSecret")
                snapshot.preferences.googleEnabled = false; snapshot.preferences.googleCalendarEnabled = false
                snapshot.preferences.googleClientID = ""; sources = [.google, .gmail]
            case .slack: try SecretStore.delete("slack.token"); snapshot.preferences.slackEnabled = false; sources = [.slack]
            case .jira:
                try SecretStore.delete("jira.token"); snapshot.preferences.jiraEnabled = false
                snapshot.preferences.jiraEmail = ""; snapshot.preferences.jiraSite = ""; sources = [.jira]
            case .calendar: snapshot.preferences.calendarEnabled = false; sources = [.calendar]
            default: return
            }
            snapshot.items.removeAll { sources.contains($0.source) }
            for value in sources { snapshot.health.removeValue(forKey: value.rawValue) }
            save(); reconcile(); notifications.clearDelivered()
        } catch { self.error = error.localizedDescription }
    }
    func setLaunchAtLogin(_ enabled: Bool) {
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
        catch { self.error = error.localizedDescription }
        objectWillChange.send()
    }

    func sync(mailOnly: Bool = false, onlyIfMailboxChanged: Bool = false) async {
        guard !isSyncing, !demoInstance else { return }
        isSyncing = true; defer { isSyncing = false }
        let epoch = generation, prefs = preferences
        if !mailOnly, prefs.calendarEnabled {
            do {
                let items = try calendar.fetch(calendarIDs: prefs.selectedCalendarIDs, now: Date())
                if epoch == generation { merge(items, source: .calendar); markSuccess(.calendar) }
            } catch { if epoch == generation { markFailure(.calendar, error) } }
        }
        if prefs.googleEnabled, canRetry(.gmail) || (!mailOnly && canRetry(.google)) {
            do {
                let token = try await googleAuth.accessToken(clientID: prefs.googleClientID)
                if !mailOnly, prefs.usesGoogleCalendar, canRetry(.google) {
                    do { let items = try await GoogleConnector.events(token: token, now: Date()); if epoch == generation { merge(items, source: .google); markSuccess(.google) } }
                    catch { if epoch == generation { markFailure(.google, error) } }
                }
                if canRetry(.gmail) {
                    do {
                        let history = try await GoogleConnector.mailboxHistoryID(token: token)
                        if !onlyIfMailboxChanged || history != gmailHistoryID || prefs.gmailQuery != syncedGmailQuery || snapshot.health[Source.gmail.rawValue]?.isError == true {
                            let page = try await GoogleConnector.mailPage(token: token, query: prefs.gmailQuery)
                            let matches = Set(page.items.map(\.id))
                            let waitingIDs = snapshot.items.filter { $0.source == .gmail && $0.state == .waiting && !matches.contains($0.id) }.map { String($0.id.dropFirst("gmail.".count)) }
                            let waiting = try await GoogleConnector.mailThreads(token: token, ids: waitingIDs)
                            if epoch == generation {
                                merge(page.items + waiting, source: .gmail)
                                gmailMatchingIDs = matches; gmailNextPageToken = page.nextPageToken
                                gmailHistoryID = history; syncedGmailQuery = prefs.gmailQuery
                                markSuccess(.gmail)
                            }
                        } else if mailOnly { return }
                    }
                    catch { if epoch == generation { markFailure(.gmail, error) } }
                }
            } catch {
                if epoch == generation {
                    if !mailOnly, prefs.usesGoogleCalendar { markFailure(.google, error) }
                    markFailure(.gmail, error)
                }
            }
        }
        if !mailOnly, prefs.slackEnabled, canRetry(.slack) {
            do {
                guard let token = try SecretStore.get("slack.token") else { throw APIError.missingCredentials }
                let items = try await SlackConnector.fetch(token: token, query: prefs.slackQuery)
                if epoch == generation { merge(items, source: .slack); markSuccess(.slack) }
            } catch { if epoch == generation { markFailure(.slack, error) } }
        }
        if !mailOnly, prefs.jiraEnabled, canRetry(.jira) {
            do {
                guard let token = try SecretStore.get("jira.token") else { throw APIError.missingCredentials }
                let items = try await JiraConnector.fetch(site: prefs.jiraSite, email: prefs.jiraEmail, token: token, scope: prefs.jiraScope ?? .involved, scopedToken: prefs.jiraScopedToken ?? false)
                if epoch == generation { merge(items, source: .jira); markSuccess(.jira) }
            } catch { if epoch == generation { markFailure(.jira, error) } }
        }
        save(); reconcile()
    }

    func resetCorruptState() {
        generation += 1; googleAuth.cancel()
        do {
            let backup = disk.url.deletingLastPathComponent().appendingPathComponent("state-backup-\(Int(Date().timeIntervalSince1970)).json")
            if FileManager.default.fileExists(atPath: disk.url.path) { try FileManager.default.moveItem(at: disk.url, to: backup) }
            snapshot = Snapshot(); readOnly = false; error = nil; save(); reconcile()
        } catch { self.error = error.localizedDescription }
    }

    private func tick() {
        now = Date()
        if let end = snapshot.focusEndsAt, end <= now {
            snapshot.focusEndsAt = nil
            notice = text("Your focus session is complete.", "Odak süren tamamlandı.")
            save()
        }
    }
    private func mutate(_ id: String, _ body: (inout AttentionItem) -> Void) {
        if let index = snapshot.items.firstIndex(where: { $0.id == id }) { body(&snapshot.items[index]) }
        if let index = demoItems.firstIndex(where: { $0.id == id }) { body(&demoItems[index]) }
    }
    private func merge(_ items: [AttentionItem], source: Source) {
        snapshot.items = AttentionEngine.merge(existing: snapshot.items, incoming: items, source: source)
    }
    private func markSuccess(_ source: Source) {
        snapshot.health[source.rawValue] = ConnectionHealth(lastSuccess: Date(), message: text("Connected", "Bağlı"))
        retryAfter.removeValue(forKey: source)
    }
    private func markFailure(_ source: Source, _ error: Error) {
        snapshot.health[source.rawValue] = ConnectionHealth(lastSuccess: snapshot.health[source.rawValue]?.lastSuccess,
            message: connectionMessage(error), isError: true)
        if case APIError.rateLimited(let seconds) = error { retryAfter[source] = Date().addingTimeInterval(Double(seconds)) }
    }
    private func connectionMessage(_ error: Error) -> String {
        if let error = error as? ProviderFailure { return error.message(language: preferences.language) }
        if case APIError.provider("authorization_timed_out") = error {
            return text("Google sign-in timed out. Choose Continue with Google again and finish in the newly opened tab. The old browser tab can be closed.",
                "Google girişinin bekleme süresi doldu. Google ile devam et düğmesine yeniden basıp yeni açılan sekmede tamamla. Eski tarayıcı sekmesini kapatabilirsin.")
        }
        if case APIError.provider("browser_could_not_open") = error {
            return text("Your browser could not open. Check your default browser, then try Google sign-in again.",
                "Tarayıcın açılamadı. Varsayılan tarayıcını kontrol edip Google girişini yeniden dene.")
        }
        if case APIError.provider(let code) = error, code == "calendar_permission_required" || code == "calendar_permission_denied" {
            return text("Calendar access needs approval. Review Calendar permission in Connections, or open macOS Calendar privacy settings.",
                "Takvim erişim izni gerekiyor. Bağlantılar'da Takvim iznini yenile düğmesini veya macOS Takvim gizlilik ayarlarını kullan.")
        }
        return error.localizedDescription
    }
    private func canRetry(_ source: Source) -> Bool { (retryAfter[source] ?? .distantPast) <= Date() }
    private func save() {
        guard !demoInstance, !readOnly else { return }
        do { try disk.save(snapshot) } catch { self.error = "Could not save your changes: \(error.localizedDescription)" }
    }
    private func reconcile() {
        guard !demoInstance else { return }
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled, let self else { return }
            do { try await self.notifications.reconcile(snapshot: self.snapshot) }
            catch { self.error = error.localizedDescription }
        }
    }
    private func makeDemoItems() {
        demoItems = [
            AttentionItem(id: "demo.meeting", source: .demo, kind: .meeting,
                title: text("Quarterly business review", "Çeyrek dönem değerlendirmesi"), detail: "14:30 · Google Meet · Demo",
                dueAt: Date().addingTimeInterval(12 * 60), endAt: Date().addingTimeInterval(42 * 60), reason: "Sample data", isDemo: true),
            AttentionItem(id: "demo.mail", source: .demo, kind: .mail,
                title: text("Contract · Final approval", "Sözleşme · Son onay"), detail: "Ayşe Demir · Gmail · Demo",
                dueAt: Date().addingTimeInterval(7200), reason: "Sample data", isDemo: true),
            AttentionItem(id: "demo.jira", source: .demo, kind: .task,
                title: "PAY-142 · Review", detail: "Jira · Demo", dueAt: Date().addingTimeInterval(10800), reason: "Sample data", isDemo: true),
            AttentionItem(id: "demo.slack", source: .demo, kind: .message,
                title: text("A decision is waiting for you", "Kararın bekleniyor"), detail: "Slack · Demo", reason: "Sample data", isDemo: true)
        ]
    }
}
