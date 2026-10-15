import EventKit
import Foundation
import HoldletCore

@MainActor
final class CalendarConnector {
    let store = EKEventStore()
    var availableCalendars: [EKCalendar] { store.calendars(for: .event).sorted { $0.title < $1.title } }
    var authorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    var needsSettings: Bool { [.denied, .restricted].contains(EKEventStore.authorizationStatus(for: .event)) }
    func authorize() async throws -> Bool { try await store.requestFullAccessToEvents() }
    func fetch(calendarIDs: [String], now: Date) throws -> [AttentionItem] {
        guard authorized else { throw APIError.provider("calendar_permission_required") }
        let calendars = availableCalendars.filter { calendarIDs.isEmpty || calendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-3600),
            end: now.addingTimeInterval(7 * 86400), calendars: calendars)
        return store.events(matching: predicate).filter { !$0.isAllDay }.compactMap { event in
            guard let eventID = event.eventIdentifier else { return nil }
            if event.attendees?.contains(where: { $0.isCurrentUser && $0.participantStatus == .declined }) == true { return nil }
            let text = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }.joined(separator: " ")
            return AttentionItem(id: "calendar.\(eventID).\(Int(event.startDate.timeIntervalSince1970))",
                source: .calendar, kind: .meeting, title: event.title ?? "Untitled meeting",
                detail: event.calendar.title, dueAt: event.startDate, endAt: event.endDate,
                url: LinkPolicy.safeWebURL(event.url?.absoluteString), meetingURL: LinkPolicy.meetingURL(in: text),
                reason: "Upcoming timed event from a selected Mac calendar")
        }
    }
}

enum GoogleConnector {
    static func events(token: String, now: Date) async throws -> [AttentionItem] {
        let formatter = ISO8601DateFormatter()
        let url = try HTTP.url("https://www.googleapis.com/calendar/v3/calendars/primary/events", query: [
            "timeMin": formatter.string(from: now.addingTimeInterval(-3600)),
            "timeMax": formatter.string(from: now.addingTimeInterval(7 * 86400)),
            "singleEvents": "true", "orderBy": "startTime", "maxResults": "250"])
        let json = try await HTTP.json(HTTP.request(url, bearer: token))
        guard json["nextPageToken"] == nil else { throw APIError.provider("calendar_window_exceeds_250_events") }
        return ProviderParsing.googleEvents(json)
    }
    static func mail(token: String, query: String, waitingThreadIDs: [String] = []) async throws -> [AttentionItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.provider("empty_gmail_query") }
        let url = try HTTP.url("https://gmail.googleapis.com/gmail/v1/users/me/threads", query: ["q": query, "maxResults": "50"])
        let json = try await HTTP.json(HTTP.request(url, bearer: token))
        // Do not silently drop tracked items when a query exceeds the supported window.
        guard json["nextPageToken"] == nil else { throw APIError.provider("narrow_gmail_query_to_50_threads") }
        var items: [AttentionItem] = []
        let matches = (json["threads"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        let threadIDs = Array(Set(matches + waitingThreadIDs)).sorted()
        for id in threadIDs {
            guard id.allSatisfy({ $0.isHexDigit }) else { continue }
            let endpoint = try HTTP.url("https://gmail.googleapis.com/gmail/v1/users/me/threads/\(id)", query: ["format": "metadata"])
            let body = try await HTTP.json(HTTP.request(endpoint, bearer: token))
            if let item = ProviderParsing.gmailThread(body) { items.append(item) }
        }
        return items
    }
}

enum SlackConnector {
    static func fetch(token: String, query: String) async throws -> [AttentionItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.provider("empty_slack_query") }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let resolvedQuery = query.replacingOccurrences(of: "{weekAgo}", with: formatter.string(from: weekAgo))
        let url = try HTTP.url("https://slack.com/api/search.messages", query: ["query": resolvedQuery, "count": "100", "sort": "timestamp", "sort_dir": "desc", "highlight": "false"])
        let json = try await HTTP.json(HTTP.request(url, bearer: token))
        guard json["ok"] as? Bool == true else {
            let raw = json["error"] as? String ?? "unknown_error"
            let safeCode = String(raw.filter { $0.isLetter || $0 == "_" }.prefix(60))
            throw APIError.provider(safeCode)
        }
        let messages = json["messages"] as? [String: Any]
        let paging = messages?["paging"] as? [String: Any]
        guard (paging?["pages"] as? Int ?? 1) <= 1 else { throw APIError.provider("narrow_slack_query_to_100_matches") }
        return ProviderParsing.slackMatches(json)
    }
}

enum JiraConnector {
    static func validatedSite(_ raw: String) throws -> URL {
        guard let url = LinkPolicy.safeWebURL(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased(), host.hasSuffix(".atlassian.net"),
              url.port == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/" else { throw APIError.invalidURL }
        return url
    }
    static func fetch(site raw: String, email: String, token: String) async throws -> [AttentionItem] {
        let site = try validatedSite(raw)
        let url = try HTTP.url(site.appendingPathComponent("rest/api/3/search/jql").absoluteString, query: [
            "jql": "assignee = currentUser() AND statusCategory != Done ORDER BY duedate ASC, updated DESC",
            "fields": "summary,status,duedate", "maxResults": "100"])
        var request = HTTP.request(url)
        request.setValue("Basic \(Data("\(email):\(token)".utf8).base64EncodedString())", forHTTPHeaderField: "Authorization")
        let json = try await HTTP.json(request)
        guard (json["isLast"] as? Bool ?? true), json["nextPageToken"] == nil else { throw APIError.provider("jira_window_exceeds_100_issues") }
        return ProviderParsing.jiraIssues(json, site: site)
    }
}
