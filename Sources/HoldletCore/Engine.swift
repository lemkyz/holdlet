import Foundation

public enum AttentionEngine {
    /// Source snapshots replace source data, while preserving personal follow-up choices.
    public static func merge(existing: [AttentionItem], incoming: [AttentionItem], source: Source) -> [AttentionItem] {
        let previous = Dictionary(existing.filter { $0.source == source }.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var seen = Set<String>()
        let fresh = incoming.filter { $0.source == source && seen.insert($0.id).inserted }.map { item in
            var item = item
            if let old = previous[item.id] {
                item.state = old.state; item.snoozedUntil = old.snoozedUntil; item.createdAt = old.createdAt
                if item.source == .gmail, old.state == .waiting, let previousReply = old.replyToken,
                   let newReply = item.replyToken, previousReply != newReply {
                    item.state = .active; item.snoozedUntil = nil
                    item.reason = "New incoming message in a thread you were waiting on"
                }
                // A rescheduled event must become eligible for a new alert and visible again.
                if item.kind == .meeting, item.dueAt != old.dueAt {
                    item.state = .active; item.snoozedUntil = nil
                }
            }
            return item
        }
        // Completed/waiting choices for temporarily absent mail/messages survive a later sync.
        let retained = existing.filter {
            $0.source == source && !seen.contains($0.id) && $0.kind != .meeting
            && ($0.state != .active || $0.source == .gmail || $0.source == .slack)
        }
        return existing.filter { $0.source != source } + fresh + retained
    }

    public static func prioritized(_ items: [AttentionItem], now: Date) -> [AttentionItem] {
        items.filter { $0.isVisible(at: now) }.sorted {
            let a = rank($0, now: now), b = rank($1, now: now)
            if a != b { return a < b }
            if $0.dueAt != $1.dueAt { return ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
            if $0.receivedAt != $1.receivedAt {
                return ($0.receivedAt ?? .distantPast) > ($1.receivedAt ?? .distantPast)
            }
            return $0.id < $1.id
        }
    }
    private static func rank(_ item: AttentionItem, now: Date) -> Int {
        if item.state == .waiting { return 4 }
        if item.kind == .meeting, let due = item.dueAt, due < now.addingTimeInterval(1800) { return 0 }
        if let due = item.dueAt, due <= now { return 1 }
        if item.dueAt != nil { return 2 }
        return 3
    }

    public static func nextMeeting(_ items: [AttentionItem], now: Date) -> AttentionItem? {
        prioritized(items.filter { $0.kind == .meeting && $0.state == .active }, now: now).first
    }
}

public struct PlannedReminder: Equatable, Sendable {
    public let id: String
    public let itemID: String
    public let date: Date
    public let title: String
    public let body: String
}

public enum ReminderPlanner {
    public static func plan(items: [AttentionItem], preferences: Preferences, now: Date,
                            calendar: Calendar = .current) -> [PlannedReminder] {
        guard preferences.notificationsEnabled else { return [] }
        return items.compactMap { item -> PlannedReminder? in
            guard !item.isDemo, item.state != .completed,
                  let due = item.snoozedUntil ?? item.dueAt else { return nil }
            if item.kind == .meeting, (item.endAt ?? due.addingTimeInterval(3600)) <= now { return nil }
            let lead: Double = item.kind == .meeting && item.snoozedUntil == nil
                ? Double(preferences.meetingLeadMinutes * 60) : 0
            var fire = due.addingTimeInterval(-lead)
            // Past deadlines are surfaced in the panel; never replay stale alerts on every poll.
            if fire <= now {
                guard item.kind == .meeting, due > now else { return nil }
                fire = now.addingTimeInterval(2)
            }
            guard WorkSchedule.allows(fire, preferences: preferences, calendar: calendar) else { return nil }
            // Stable per deadline, even when opening/syncing repeatedly inside the lead window.
            let id = "holdlet.item.\(item.id).\(Int(due.timeIntervalSince1970))"
            return PlannedReminder(id: id, itemID: item.id, date: fire,
                                   title: preferences.hideDetails ? "Holdlet" : item.title,
                                   body: preferences.hideDetails ? "An item needs your attention." : item.detail)
        }.sorted { $0.date < $1.date }.prefix(48).map { $0 }
    }
}

public enum LinkPolicy {
    public static func safeWebURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }
    public static func meetingURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap { match -> URL? in
            guard let url = match.url, let safe = safeWebURL(url.absoluteString), let host = safe.host?.lowercased() else { return nil }
            let domains = ["meet.google.com", "zoom.us", "zoom.com", "teams.microsoft.com", "teams.live.com", "webex.com"]
            return domains.contains(where: { host == $0 || host.hasSuffix("." + $0) }) ? safe : nil
        }.first
    }
}

public enum DateParsing {
    public static func iso(_ text: String?) -> Date? {
        guard let text else { return nil }
        let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
    public static func endOfDay(_ text: String?, calendar: Calendar = .current) -> Date? {
        guard let text else { return nil }
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        return calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day)
    }
}
