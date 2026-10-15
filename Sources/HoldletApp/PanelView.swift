import HoldletCore
import SwiftUI

struct PanelView: View {
    @ObservedObject var model: AppState
    @State private var selected: PanelSection = .overview
    @State private var reminderTitle = ""
    @State private var reminderDate = Date().addingTimeInterval(900)
    @State private var adding = false
    @State private var selectedItem: AttentionItem?

    enum PanelSection: String, CaseIterable { case overview, meetings, mail, tasks, waiting, snoozed, completed }

    var body: some View {
        VStack(spacing: 10) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    if !model.preferences.onboardingComplete { welcome }
                    if model.preferences.demoMode { demoBanner }
                    if let error = model.error { message(error, symbol: "exclamationmark.triangle", isError: true) }
                    if let notice = model.notice { message(notice, symbol: "info.circle", isError: false) }
                    if adding { addReminder }
                    if let item = selectedItem { detail(item) }
                    if selected == .overview {
                        meetingCard
                        modules
                        workList(items: Array(model.openWork.filter { $0.state == .active }.prefix(4)))
                        focusCard
                    } else {
                        sectionHeader
                        workList(items: filteredItems)
                    }
                    healthFooter
                }.padding(.horizontal, 1).padding(.bottom, 14)
            }.scrollIndicators(.hidden)
        }
        .padding(14)
        .frame(width: 390).frame(maxHeight: .infinity)
        .background(Color.clear)
    }

    private var header: some View {
        HStack {
            Text("Holdlet").font(.system(size: 14, weight: .semibold))
            Spacer()
            Text(model.preferences.demoMode ? "Demo" : model.text("Workspace", "İş alanı"))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Button { model.updatePreferences { $0.panelPinned.toggle() } } label: {
                Image(systemName: model.preferences.panelPinned ? "pin.fill" : "pin")
            }.buttonStyle(.plain).accessibilityLabel(model.text("Pin panel", "Paneli sabitle"))
            Button { adding.toggle() } label: { Image(systemName: "plus") }
                .buttonStyle(.plain).help(model.text("Add reminder", "Hatırlatma ekle"))
                .accessibilityLabel(model.text("Add reminder", "Hatırlatma ekle"))
            Button { model.hidePanel?() } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.plain).accessibilityLabel(model.text("Hide to screen edge", "Ekran kenarına gizle"))
            Button { model.showSettings?() } label: { Image(systemName: "gearshape") }
                .buttonStyle(.plain).help(model.text("Settings", "Ayarlar"))
                .accessibilityLabel(model.text("Settings", "Ayarlar"))
        }.padding(.horizontal, 14).padding(.vertical, 12).glassSurface(radius: 22)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            CircleSymbol(symbol: "bell.badge")
            Text(model.text("Keep work from slipping away.", "Önemli işler gözden kaçmasın."))
                .font(.system(size: 21, weight: .medium))
            Text(model.text("Start with a local reminder or connect your calendar. Your data stays on this Mac unless you connect a service.",
                "Bir hatırlatmayla başla veya takvimini bağla. Bağladığın servisler dışında verilerin bu Mac'te kalır."))
                .font(.system(size: 12)).foregroundStyle(.secondary)
            HStack {
                Button(model.text("Set up", "Kurulum")) { model.showSettings?() }.buttonStyle(CapsuleAction(primary: true))
                Button(model.text("Try demo", "Demoyu dene")) {
                    model.updatePreferences { $0.demoMode = true; $0.onboardingComplete = true }
                }.buttonStyle(CapsuleAction())
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glassSurface()
    }

    private var demoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.rectangle")
            Text(model.text("Sample data · No real alerts", "Örnek veriler · Gerçek uyarı yok")).font(.system(size: 11))
            Spacer()
            Button(model.text("Exit", "Çık")) { model.exitDemo() }.buttonStyle(.plain)
        }.padding(12).glassSurface(radius: 18)
    }

    private var meetingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let meeting = model.nextMeeting, let due = meeting.dueAt {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.text("Next meeting", "Sıradaki toplantı")).font(.system(size: 12)).foregroundStyle(.secondary)
                        Text(model.title(meeting)).font(.system(size: 21, weight: .medium)).tracking(-0.4).lineLimit(3)
                        Text("\(model.time(due)) · \(meeting.isDemo ? "Demo" : meeting.source.title)")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 2) {
                        Text(model.countdown(due)).font(.system(size: 30, weight: .regular)).monospacedDigit()
                        if due > model.now, due.timeIntervalSince(model.now) < 3600 {
                            Text(model.text("minutes", "dakika")).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }.accessibilityLabel(model.text("Time until meeting", "Toplantıya kalan süre") + " " + model.countdown(due))
                }
                HStack {
                    if meeting.meetingURL != nil || meeting.isDemo {
                        Button { model.open(meeting, join: true) } label: { Label(model.text("Join", "Katıl"), systemImage: "arrow.up.right") }
                            .buttonStyle(CapsuleAction(primary: true))
                    }
                    Button(model.text("Details", "Ayrıntılar")) { selectedItem = meeting }.buttonStyle(CapsuleAction())
                    Spacer()
                    meetingMenu(meeting)
                }
            } else {
                HStack(spacing: 12) {
                    CircleSymbol(symbol: "calendar")
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.text("Room to focus", "Odaklanma zamanı")).font(.system(size: 18, weight: .medium))
                        Text(model.text("No upcoming meetings in connected calendars.", "Bağlı takvimlerde yaklaşan toplantı yok."))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                if !model.preferences.calendarEnabled && !model.preferences.googleEnabled {
                    Button(model.text("Connect a calendar", "Takvim bağla")) { model.openConnections() }.buttonStyle(CapsuleAction())
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glassSurface()
    }

    private var modules: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            module(symbol: "envelope", title: model.text("Important mail", "Önemli mailler"),
                detail: "\(model.active.filter { $0.kind == .mail }.count) " + model.text("follow-ups", "takip"), section: .mail)
            module(symbol: "checklist", title: model.text("Tasks & messages", "Görev ve mesajlar"),
                detail: "\(model.active.filter { [.task, .message, .reminder].contains($0.kind) }.count) " + model.text("open items", "açık iş"), section: .tasks)
        }
    }
    private func module(symbol: String, title: String, detail: String, section: PanelSection) -> some View {
        Button { selected = section } label: {
            VStack(alignment: .leading, spacing: 12) {
                CircleSymbol(symbol: symbol)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, minHeight: 108, alignment: .leading).padding(16).glassSurface()
        }.buttonStyle(.plain)
    }

    private var focusCard: some View {
        HStack(spacing: 12) {
            CircleSymbol(symbol: "timer")
            VStack(alignment: .leading, spacing: 4) {
                Text(model.text("Focus", "Odaklan")).font(.system(size: 13, weight: .medium))
                Text(model.isFocusing ? model.focusTime() : model.text("25 minutes", "25 dakika"))
                    .font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
            }
            Spacer()
            Button(model.isFocusing ? model.text("Stop", "Bitir") : model.text("Start", "Başlat")) {
                if model.isFocusing { model.stopFocus() } else { model.startFocus() }
            }.buttonStyle(CapsuleAction())
        }.padding(15).glassSurface()
    }

    private var sectionHeader: some View {
        HStack {
            Button { selected = .overview } label: { Label(model.text("Overview", "Genel"), systemImage: "chevron.left") }.buttonStyle(.plain)
            Spacer()
            Text(sectionName(selected)).font(.system(size: 12, weight: .medium))
        }.padding(.horizontal, 8).padding(.vertical, 5)
    }
    private var filteredItems: [AttentionItem] {
        switch selected {
        case .overview: model.openWork
        case .meetings: model.active.filter { $0.kind == .meeting }
        case .mail: model.active.filter { $0.kind == .mail }
        case .tasks: model.active.filter { [.task, .message, .reminder].contains($0.kind) }
        case .waiting: model.waiting
        case .snoozed: model.snoozed
        case .completed: model.completed
        }
    }
    private func sectionName(_ section: PanelSection) -> String {
        switch section {
        case .overview: model.text("Overview", "Genel")
        case .meetings: model.text("Meetings", "Toplantılar")
        case .mail: model.text("Important mail", "Önemli mailler")
        case .tasks: model.text("Tasks & messages", "Görev ve mesajlar")
        case .waiting: model.text("Waiting for reply", "Yanıt bekleniyor")
        case .snoozed: model.text("Snoozed", "Ertelenenler")
        case .completed: model.text("Completed", "Tamamlananlar")
        }
    }
    private func workList(items: [AttentionItem]) -> some View {
        VStack(spacing: 10) {
            if items.isEmpty {
                Text(model.text("Nothing waiting here.", "Burada bekleyen iş yok."))
                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(20)
                    .frame(maxWidth: .infinity).glassSurface()
            }
            ForEach(items) { item in
                HStack(spacing: 10) {
                    CircleSymbol(symbol: item.source.symbol, size: 33)
                    Button { selectedItem = item } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.title(item)).font(.system(size: 13, weight: .medium)).lineLimit(2)
                            Text(model.detail(item)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                            if let date = item.snoozedUntil ?? item.dueAt {
                                Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.system(size: 11)).foregroundStyle(date < model.now ? .orange : .secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    itemMenu(item)
                }.padding(14).glassSurface(radius: 23)
            }
        }
    }
    private func meetingMenu(_ item: AttentionItem) -> some View { itemMenu(item) }
    private func itemMenu(_ item: AttentionItem) -> some View {
        Menu {
            if item.url != nil || item.isDemo { Button(model.text("Open source", "Kaynağı aç")) { model.open(item) } }
            Button(model.text("Snooze 10 minutes", "10 dakika ertele")) { model.snooze(item, minutes: 10) }
            Button(model.text("Snooze 1 hour", "1 saat ertele")) { model.snooze(item, minutes: 60) }
            if item.snoozedUntil != nil { Button(model.text("Remove snooze", "Ertelemeyi kaldır")) { model.unsnooze(item) } }
            if item.state != .waiting { Button(model.text("Waiting for reply", "Yanıt bekleniyor")) { model.setState(item, .waiting) } }
            Button(item.state == .completed ? model.text("Reopen", "Yeniden aç") : model.text("Mark complete", "Tamamlandı")) {
                model.setState(item, item.state == .completed ? .active : .completed)
            }
            if item.source == .local { Button(model.text("Delete", "Sil"), role: .destructive) { model.removeLocal(item) } }
        } label: { Image(systemName: "ellipsis") }
        .menuStyle(.borderlessButton).fixedSize().accessibilityLabel(model.text("Item actions", "İş eylemleri"))
    }

    private func detail(_ original: AttentionItem) -> some View {
        let item = model.allItems.first { $0.id == original.id } ?? original
        return VStack(alignment: .leading, spacing: 12) {
            HStack { Text(model.title(item)).font(.system(size: 16, weight: .medium)); Spacer(); Button { selectedItem = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel(model.text("Close details", "Ayrıntıları kapat")) }
            Text(model.detail(item)).font(.system(size: 12)).foregroundStyle(.secondary)
            Text(model.preferences.hideDetails ? model.text("Details are hidden in Privacy mode.", "Gizlilik modunda ayrıntılar gizlenir.") : item.reason)
                .font(.system(size: 12))
            if let due = item.dueAt { Text(due, format: .dateTime.weekday().month().day().hour().minute().timeZone()).font(.system(size: 12)) }
            HStack {
                if item.url != nil || item.isDemo { Button(model.text("Open source", "Kaynağı aç")) { model.open(item) }.buttonStyle(CapsuleAction(primary: true)) }
                itemMenu(item)
            }
        }.padding(18).glassSurface()
    }

    private var addReminder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.text("New reminder", "Yeni hatırlatma")).font(.system(size: 14, weight: .medium))
            TextField(model.text("What should we remember?", "Neyi hatırlatalım?"), text: $reminderTitle).textFieldStyle(.roundedBorder)
            DatePicker(model.text("When", "Ne zaman"), selection: $reminderDate, in: Date()...).font(.system(size: 12))
            HStack {
                Button(model.text("Save", "Kaydet")) { model.addReminder(title: reminderTitle, due: reminderDate); reminderTitle = ""; adding = false }
                    .buttonStyle(CapsuleAction(primary: true)).disabled(reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reminderDate <= model.now)
                Button(model.text("Cancel", "Vazgeç")) { adding = false }.buttonStyle(CapsuleAction())
            }
            if !model.preferences.notificationsEnabled { Text(model.text("Enable notifications in Settings to receive an alert.", "Uyarı almak için Ayarlar'da bildirimleri aç.")).font(.system(size: 11)).foregroundStyle(.secondary) }
        }.padding(18).glassSurface()
    }
    private func message(_ text: String, symbol: String, isError: Bool) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol).foregroundStyle(isError ? .orange : .secondary)
            Text(text).font(.system(size: 12)).textSelection(.enabled)
            Spacer(minLength: 0)
            Button { if isError { model.error = nil } else { model.notice = nil } } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel(model.text("Dismiss", "Kapat"))
        }.padding(14).glassSurface(radius: 18)
    }
    private var healthFooter: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Menu(model.text("Follow-ups", "Takipler")) {
                    ForEach([PanelSection.meetings, .waiting, .snoozed, .completed], id: \.self) { section in
                        Button(sectionName(section)) { selected = section }
                    }
                }.menuStyle(.borderlessButton).fixedSize()
                Spacer()
                Button { Task { await model.sync() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).disabled(model.isSyncing).accessibilityLabel(model.text("Refresh", "Yenile"))
                Menu { Button(model.text("Settings", "Ayarlar")) { model.showSettings?() }; Divider(); Button(model.text("Quit Holdlet", "Holdlet'ten çık")) { NSApplication.shared.terminate(nil) } }
                    label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize()
            }.font(.system(size: 11))
            if model.enabledSources.isEmpty {
                Text(model.text("Local reminders · Connect sources in Settings", "Yerel hatırlatmalar · Kaynakları Ayarlar'dan bağla")).font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                ForEach(model.enabledSources) { source in
                    let health = model.snapshot.health[source.rawValue]
                    HStack(spacing: 5) {
                        Image(systemName: health?.isError == true ? "exclamationmark.circle" : "circle.fill").font(.system(size: 6))
                            .foregroundStyle(health?.isError == true ? .orange : .secondary)
                        Text(source.title)
                        Spacer()
                        if health?.isError == true { Text(model.text("Needs attention", "Kontrol gerekli")) }
                        else if let last = health?.lastSuccess { Text(last, style: .relative) }
                        else { Text(model.text("Not synced", "Eşitlenmedi")) }
                    }.font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }.padding(14).glassSurface(radius: 22)
    }
}
