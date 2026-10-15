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
    @Published var notificationStatus = ""
    let calendar = CalendarConnector()
    let googleAuth = GoogleAuth()
    let notifications: NotificationService
    let demoInstance: Bool
    var showPanel: (() -> Void)?
    var showSettings: (() -> Void)?
    private let disk: SnapshotStore
    private var clock: Timer?
    private var poll: Timer?
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
        notifications = NotificationService(defaults: UserDefaults(suiteName: demoInstance ? "io.github.lemkyz.holdlet.demo" : "io.github.lemkyz.holdlet")!)
        do { snapshot = demoInstance ? Snapshot() : try disk.load() }
        catch { snapshot = Snapshot(); self.error = "Saved data could not be read. The original file is preserved. Open Settings → Diagnostics."; readOnly = true }
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
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }; self.now = Date()
                self.notice = self.text("Welcome back. Your open follow-ups are below.", "Tekrar merhaba. Açık takiplerin aşağıda.")
                self.reconcile(); await self.sync()
            }
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
    var waiting: [AttentionItem] { allItems.filter { $0.state == .waiting } }
    var snoozed: [AttentionItem] { allItems.filter { $0.state != .completed && ($0.snoozedUntil ?? .distantPast) > now } }
    var completed: [AttentionItem] { allItems.filter { $0.state == .completed }.sorted { $0.createdAt > $1.createdAt } }
    var missed: Int { active.filter { $0.dueAt.map { $0 < now } == true && $0.kind != .meeting }.count }
    var isFocusing: Bool { (snapshot.focusEndsAt ?? .distantPast) > now }
    var stateFileURL: URL { disk.url }
    var enabledSources: [Source] {
        var sources: [Source] = []
        if preferences.calendarEnabled { sources.append(.calendar) }
        if preferences.googleEnabled { sources += [.google, .gmail] }
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
        notificationStatus = status == .authorized ? text("Allowed", "İzin verildi") : text("Not allowed", "İzin yok")
    }
    func enableCalendar() async {
        do {
            guard try await calendar.authorize() else { throw APIError.provider("calendar_permission_denied") }
            updatePreferences { $0.calendarEnabled = true; $0.googleEnabled = false }
            snapshot.items.removeAll { $0.source == .google || $0.source == .gmail }
            save(); reconcile()
            await sync()
        } catch { self.error = error.localizedDescription }
    }
    func connectGoogle(clientID: String, clientSecret: String) async {
        googleSigningIn = true; defer { googleSigningIn = false }
        do {
            if !clientSecret.isEmpty { try SecretStore.set(clientSecret, for: "google.clientSecret") }
            try await googleAuth.authorize(clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines))
            updatePreferences {
                $0.googleClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
                $0.googleEnabled = true; $0.calendarEnabled = false
            }
            // Switching calendar providers removes duplicate events and their pending alerts.
            snapshot.items.removeAll { $0.source == .calendar }; save(); reconcile()
            await sync()
        } catch { self.error = error.localizedDescription }
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
            let items = try await JiraConnector.fetch(site: site, email: email, token: token)
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
                googleAuth.cancel(); try SecretStore.delete("google.tokens"); try SecretStore.delete("google.clientSecret")
                snapshot.preferences.googleEnabled = false; snapshot.preferences.googleClientID = ""; sources = [.google, .gmail]
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

    func sync() async {
        guard !isSyncing, !demoInstance else { return }
        isSyncing = true; defer { isSyncing = false }
        let epoch = generation, prefs = preferences
        if prefs.calendarEnabled {
            do {
                let items = try calendar.fetch(calendarIDs: prefs.selectedCalendarIDs, now: Date())
                if epoch == generation { merge(items, source: .calendar); markSuccess(.calendar) }
            } catch { if epoch == generation { markFailure(.calendar, error) } }
        }
        if prefs.googleEnabled, canRetry(.google) || canRetry(.gmail) {
            do {
                let token = try await googleAuth.accessToken(clientID: prefs.googleClientID)
                if canRetry(.google) {
                    do { let items = try await GoogleConnector.events(token: token, now: Date()); if epoch == generation { merge(items, source: .google); markSuccess(.google) } }
                    catch { if epoch == generation { markFailure(.google, error) } }
                }
                if canRetry(.gmail) {
                    do {
                        let waitingIDs = snapshot.items.filter { $0.source == .gmail && $0.state == .waiting }.map { String($0.id.dropFirst("gmail.".count)) }
                        guard waitingIDs.count <= 50 else { throw APIError.provider("limit_waiting_threads_to_50") }
                        let items = try await GoogleConnector.mail(token: token, query: prefs.gmailQuery, waitingThreadIDs: waitingIDs)
                        if epoch == generation { merge(items, source: .gmail); markSuccess(.gmail) }
                    }
                    catch { if epoch == generation { markFailure(.gmail, error) } }
                }
            } catch { if epoch == generation { markFailure(.google, error); markFailure(.gmail, error) } }
        }
        if prefs.slackEnabled, canRetry(.slack) {
            do {
                guard let token = try SecretStore.get("slack.token") else { throw APIError.missingCredentials }
                let items = try await SlackConnector.fetch(token: token, query: prefs.slackQuery)
                if epoch == generation { merge(items, source: .slack); markSuccess(.slack) }
            } catch { if epoch == generation { markFailure(.slack, error) } }
        }
        if prefs.jiraEnabled, canRetry(.jira) {
            do {
                guard let token = try SecretStore.get("jira.token") else { throw APIError.missingCredentials }
                let items = try await JiraConnector.fetch(site: prefs.jiraSite, email: prefs.jiraEmail, token: token)
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
            message: error.localizedDescription, isError: true)
        if case APIError.rateLimited(let seconds) = error { retryAfter[source] = Date().addingTimeInterval(Double(seconds)) }
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
