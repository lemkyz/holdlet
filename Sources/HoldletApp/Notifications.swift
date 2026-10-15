import AppKit
import Foundation
import HoldletCore
import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let defaults: UserDefaults
    private var reconciling = false
    private var latestSnapshot: Snapshot?
    var onOpen: ((String?) -> Void)?
    private var ledger: [String: Double] {
        get { defaults.dictionary(forKey: "notificationLedger") as? [String: Double] ?? [:] }
        set { defaults.set(newValue, forKey: "notificationLedger") }
    }
    init(defaults: UserDefaults) { self.defaults = defaults; super.init(); center.delegate = self }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
    func permissionStatus() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }

    func reconcile(snapshot: Snapshot) async throws {
        latestSnapshot = snapshot
        guard !reconciling else { return }
        reconciling = true; defer { reconciling = false }
        var failure: Error?
        while let next = latestSnapshot {
            latestSnapshot = nil
            do { try await apply(snapshot: next) } catch { failure = error }
        }
        if let failure { throw failure }
    }
    private func apply(snapshot: Snapshot) async throws {
        let now = Date()
        let plans = ReminderPlanner.plan(items: snapshot.items, preferences: snapshot.preferences, now: now)
        var desired = Set(plans.map(\.id))
        let focusID = snapshot.focusEndsAt.map { "holdlet.focus.\(Int($0.timeIntervalSince1970))" }
        if let focusID, let end = snapshot.focusEndsAt, end > now, snapshot.preferences.notificationsEnabled { desired.insert(focusID) }
        let pending = await center.pendingNotificationRequests()
        let obsolete = pending.filter {
            ($0.identifier.hasPrefix("holdlet.item.") || $0.identifier.hasPrefix("holdlet.focus."))
            && !desired.contains($0.identifier)
        }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: obsolete)
        let existing = Set(pending.map(\.identifier))
        var recorded = ledger.filter { $0.value > now.addingTimeInterval(-30 * 86400).timeIntervalSince1970 }
        for id in obsolete where (recorded[id] ?? 0) > now.timeIntervalSince1970 { recorded.removeValue(forKey: id) }
        for plan in plans {
            let alreadyFired = (recorded[plan.id].map { $0 <= now.timeIntervalSince1970 } ?? false)
            if alreadyFired && !existing.contains(plan.id) { continue }
            let content = UNMutableNotificationContent()
            content.title = plan.title; content.body = plan.body; content.sound = .default
            content.userInfo = ["itemID": plan.itemID]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, plan.date.timeIntervalSinceNow), repeats: false)
            try await center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
            recorded[plan.id] = plan.date.timeIntervalSince1970
        }
        if let end = snapshot.focusEndsAt, let focusID, desired.contains(focusID) {
            let content = UNMutableNotificationContent(); content.title = "Holdlet"
            content.body = snapshot.preferences.language == "tr" ? "Odak süren tamamlandı." : "Your focus session is complete."
            content.sound = .default
            try await center.add(UNNotificationRequest(identifier: focusID, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)))
            recorded[focusID] = end.timeIntervalSince1970
        }
        ledger = recorded
    }

    func test(language: String) async throws {
        let content = UNMutableNotificationContent(); content.title = "Holdlet"
        content.body = language == "tr" ? "Test hatırlatması. Bağlantın hazır." : "Test reminder. You're ready."
        content.sound = .default
        try await center.add(UNNotificationRequest(identifier: "holdlet.test.\(UUID().uuidString)", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }
    func clearDelivered() { center.removeAllDeliveredNotifications() }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        let itemID = response.notification.request.content.userInfo["itemID"] as? String
        Task { @MainActor [weak self] in self?.onOpen?(itemID); completionHandler() }
    }
}
