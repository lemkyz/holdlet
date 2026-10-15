import Foundation

public enum Source: String, Codable, CaseIterable, Identifiable, Sendable {
    case local, calendar, google, gmail, slack, jira, demo
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .local: "Holdlet"
        case .calendar: "Mac Calendar"
        case .google: "Google Calendar"
        case .gmail: "Gmail"
        case .slack: "Slack"
        case .jira: "Jira"
        case .demo: "Demo"
        }
    }
    public var symbol: String {
        switch self {
        case .local: "bell"
        case .calendar, .google: "calendar"
        case .gmail: "envelope"
        case .slack: "bubble.left.and.bubble.right"
        case .jira: "checklist"
        case .demo: "sparkle.magnifyingglass"
        }
    }
}

public enum ItemKind: String, Codable, CaseIterable, Sendable { case meeting, mail, message, task, reminder }
public enum FollowUpState: String, Codable, CaseIterable, Sendable { case active, waiting, completed }

public struct AttentionItem: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var source: Source
    public var kind: ItemKind
    public var title: String
    public var detail: String
    public var dueAt: Date?
    public var endAt: Date?
    public var url: URL?
    public var meetingURL: URL?
    public var reason: String
    public var state: FollowUpState
    public var snoozedUntil: Date?
    public var createdAt: Date
    public var isDemo: Bool
    public var replyToken: String?

    public init(id: String = UUID().uuidString, source: Source = .local, kind: ItemKind = .reminder,
                title: String, detail: String = "", dueAt: Date? = nil, endAt: Date? = nil,
                url: URL? = nil, meetingURL: URL? = nil, reason: String = "Added by you",
                state: FollowUpState = .active, snoozedUntil: Date? = nil,
                createdAt: Date = Date(), isDemo: Bool = false, replyToken: String? = nil) {
        self.id = id; self.source = source; self.kind = kind; self.title = title; self.detail = detail
        self.dueAt = dueAt; self.endAt = endAt; self.url = url; self.meetingURL = meetingURL
        self.reason = reason; self.state = state; self.snoozedUntil = snoozedUntil
        self.createdAt = createdAt; self.isDemo = isDemo
        self.replyToken = replyToken
    }
    public func isVisible(at now: Date) -> Bool {
        state != .completed && (snoozedUntil == nil || snoozedUntil! <= now)
        && (kind != .meeting || (endAt ?? dueAt?.addingTimeInterval(3600) ?? .distantFuture) > now)
    }
}

public struct ConnectionHealth: Codable, Equatable, Sendable {
    public var lastSuccess: Date?
    public var message: String
    public var isError: Bool
    public init(lastSuccess: Date? = nil, message: String = "Not connected", isError: Bool = false) {
        self.lastSuccess = lastSuccess; self.message = message; self.isError = isError
    }
}

public struct Preferences: Codable, Equatable, Sendable {
    public var demoMode = false
    public var language = "en"
    public var calendarEnabled = false
    public var googleEnabled = false
    public var slackEnabled = false
    public var jiraEnabled = false
    public var selectedCalendarIDs: [String] = []
    public var gmailQuery = "is:unread is:important newer_than:7d"
    public var slackQuery = "to:me after:{weekAgo}"
    public var jiraSite = ""
    public var jiraEmail = ""
    public var googleClientID = ""
    public var workStart = 8
    public var workEnd = 19
    public var respectWorkHours = true
    public var notificationsEnabled = false
    public var hideDetails = false
    public var meetingLeadMinutes = 5
    public var onboardingComplete = false
    public var panelPinned = false
    public init() {}
}

public struct Snapshot: Codable, Equatable, Sendable {
    public var version = 1
    public var items: [AttentionItem]
    public var preferences: Preferences
    public var health: [String: ConnectionHealth]
    public var focusEndsAt: Date?
    public var lastActiveAt: Date?
    public init(items: [AttentionItem] = [], preferences: Preferences = Preferences(),
                health: [String: ConnectionHealth] = [:], focusEndsAt: Date? = nil, lastActiveAt: Date? = nil) {
        self.items = items; self.preferences = preferences; self.health = health
        self.focusEndsAt = focusEndsAt; self.lastActiveAt = lastActiveAt
    }
}
