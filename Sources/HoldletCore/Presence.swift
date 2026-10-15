import Foundation
import CoreGraphics

public enum ScreenEdge: String, Codable, CaseIterable, Sendable {
    case top, right, bottom, left
    public var horizontal: Bool { self == .top || self == .bottom }
}

public struct EdgeDockPreferences: Codable, Equatable, Sendable {
    public var enabled = true
    public var edge: ScreenEdge = .top
    public var position: Double = 0.76
    public var displayID: UInt32?
    public var alerts = true
    public var sound = true
    public init() {}
}

public enum EdgeLayout {
    public static func handle(in visible: CGRect, edge: ScreenEdge, position: Double) -> CGRect {
        let size = edge.horizontal ? CGSize(width: min(118, visible.width), height: min(30, visible.height))
                                   : CGSize(width: min(30, visible.width), height: min(108, visible.height))
        let p = min(1, max(0, position.isFinite ? position : 0.5))
        switch edge {
        case .top, .bottom:
            return CGRect(x: visible.minX + (visible.width - size.width) * p,
                          y: edge == .top ? visible.maxY - size.height : visible.minY, width: size.width, height: size.height)
        case .left, .right:
            return CGRect(x: edge == .left ? visible.minX : visible.maxX - size.width,
                          y: visible.minY + (visible.height - size.height) * p, width: size.width, height: size.height)
        }
    }
    public static func nearestEdge(to point: CGPoint, in visible: CGRect) -> ScreenEdge {
        let distances: [(ScreenEdge, Double)] = [(.top, abs(point.y - visible.maxY)), (.right, abs(point.x - visible.maxX)),
                                                (.bottom, abs(point.y - visible.minY)), (.left, abs(point.x - visible.minX))]
        return distances.min { $0.1 < $1.1 }!.0
    }
    public static func position(of point: CGPoint, in visible: CGRect, edge: ScreenEdge) -> Double {
        let length = edge.horizontal ? visible.width : visible.height
        guard length > 0 else { return 0.5 }
        let value = edge.horizontal ? (point.x - visible.minX) / length : (point.y - visible.minY) / length
        return min(1, max(0, value))
    }
    public static func drawer(in visible: CGRect, handle: CGRect, edge: ScreenEdge, desired: CGSize) -> CGRect {
        let size = CGSize(width: min(desired.width, max(1, visible.width - 12)), height: min(desired.height, max(1, visible.height - 42)))
        var origin: CGPoint
        switch edge {
        case .top: origin = CGPoint(x: handle.midX - size.width / 2, y: handle.minY - size.height - 4)
        case .bottom: origin = CGPoint(x: handle.midX - size.width / 2, y: handle.maxY + 4)
        case .left: origin = CGPoint(x: handle.maxX + 4, y: handle.midY - size.height / 2)
        case .right: origin = CGPoint(x: handle.minX - size.width - 4, y: handle.midY - size.height / 2)
        }
        origin.x = max(visible.minX + 6, min(origin.x, visible.maxX - size.width - 6))
        origin.y = max(visible.minY + 6, min(origin.y, visible.maxY - size.height - 6))
        return CGRect(origin: origin, size: size)
    }
}

public enum WorkSchedule {
    public static func allows(_ date: Date, preferences: Preferences, calendar: Calendar = .current) -> Bool {
        guard preferences.respectWorkHours else { return true }
        let hour = calendar.component(.hour, from: date)
        let start = min(23, max(0, preferences.workStart)), end = min(24, max(0, preferences.workEnd))
        let days = preferences.workdays ?? Array(1...7)
        var shiftDay = date
        if start < end {
            guard hour >= start && hour < end else { return false }
        } else if start > end {
            guard hour >= start || hour < end else { return false }
            if hour < end { shiftDay = calendar.date(byAdding: .day, value: -1, to: date) ?? date }
        } // Equal times mean a full-day shift.
        return days.contains(calendar.component(.weekday, from: shiftDay))
    }
}

public struct AttentionCue: Equatable, Sendable {
    public let id: String
    public let itemID: String
}

public enum AttentionCuePlanner {
    public static func due(items: [AttentionItem], preferences: Preferences, now: Date, calendar: Calendar = .current) -> [AttentionCue] {
        guard preferences.dock.alerts, WorkSchedule.allows(now, preferences: preferences, calendar: calendar) else { return [] }
        return items.compactMap { item in
            guard !item.isDemo, item.state == .active, let due = item.snoozedUntil ?? item.dueAt,
                  item.isVisible(at: now) else { return nil }
            let lead = item.kind == .meeting && item.snoozedUntil == nil ? Double(preferences.meetingLeadMinutes * 60) : 0
            let alertAt = due.addingTimeInterval(-lead)
            let catchingUpcomingMeeting = item.kind == .meeting && item.snoozedUntil == nil && due > now && alertAt <= now
            guard alertAt <= now, alertAt > now.addingTimeInterval(-120) || catchingUpcomingMeeting else { return nil }
            return AttentionCue(id: "deadline.\(item.id).\(Int(due.timeIntervalSince1970))", itemID: item.id)
        }
    }
}

/// Treat each provider's first successful snapshot as a baseline. Later arrivals are eligible once.
public struct IncomingCueTracker: Sendable {
    private var known = Set<String>()
    private var baselined = Set<Source>()
    public init(items: [AttentionItem] = [], readySources: Set<Source> = [], now: Date = Date()) {
        known = Set(items.filter { Self.eligible($0, at: now) }.map(Self.fingerprint))
        baselined = readySources
    }
    public mutating func receive(items: [AttentionItem], readySources: Set<Source>, now: Date) -> [AttentionCue] {
        let incoming = items.filter { Self.eligible($0, at: now) }
        defer { known = Set(incoming.map(Self.fingerprint)); baselined.formUnion(readySources) }
        return incoming.filter { baselined.contains($0.source) && !known.contains(Self.fingerprint($0)) }
            .map { AttentionCue(id: Self.fingerprint($0), itemID: $0.id) }
    }
    private static func eligible(_ item: AttentionItem, at now: Date) -> Bool {
        !item.isDemo && [.gmail, .slack].contains(item.source) && item.state == .active && item.isVisible(at: now)
    }
    private static func fingerprint(_ item: AttentionItem) -> String { "arrival.\(item.id).\(item.replyToken ?? "initial")" }
}
