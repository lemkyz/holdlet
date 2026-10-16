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
    struct MailPage: Sendable {
        var items: [AttentionItem]
        var nextPageToken: String?
    }
    static func mailboxHistoryID(token: String, session: URLSession = HTTP.session) async throws -> String {
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/profile")!
        let json = try await HTTP.json(HTTP.request(url, bearer: token), session: session)
        guard let history = json["historyId"] as? String else { throw APIError.invalidResponse }
        return history
    }
    static func mailPage(token: String, query: String, pageToken: String? = nil,
                         session: URLSession = HTTP.session) async throws -> MailPage {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.provider("empty_gmail_query") }
        var fields = ["q": query, "maxResults": "50"]
        if let pageToken { fields["pageToken"] = pageToken }
        let url = try HTTP.url("https://gmail.googleapis.com/gmail/v1/users/me/threads", query: fields)
        let json = try await HTTP.json(HTTP.request(url, bearer: token), session: session)
        let ids = (json["threads"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        return MailPage(items: try await mailThreads(token: token, ids: ids, session: session),
                        nextPageToken: json["nextPageToken"] as? String)
    }
    static func mailThreads(token: String, ids: [String], session: URLSession = HTTP.session) async throws -> [AttentionItem] {
        let ids = Array(Set(ids)).sorted()
        guard ids.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isHexDigit) }) else { throw APIError.invalidResponse }
        var items: [AttentionItem] = []
        // Bounded concurrency avoids one network round-trip per thread in sequence.
        for offset in stride(from: 0, to: ids.count, by: 6) {
            let batch = Array(ids[offset..<min(offset + 6, ids.count)])
            let fetched = try await withThrowingTaskGroup(of: AttentionItem?.self) { group in
                for id in batch {
                    group.addTask {
                        let endpoint = try HTTP.url("https://gmail.googleapis.com/gmail/v1/users/me/threads/\(id)", query: ["format": "metadata"])
                        do {
                            let body = try await HTTP.json(HTTP.request(endpoint, bearer: token), session: session)
                            return ProviderParsing.gmailThread(body)
                        } catch let failure as ProviderFailure where failure.status == 404 {
                            return nil // A thread may be deleted between listing and reading it.
                        }
                    }
                }
                var result: [AttentionItem] = []
                for try await item in group { if let item { result.append(item) } }
                return result
            }
            items += fetched
        }
        return items.sorted { ($0.receivedAt ?? $0.createdAt) > ($1.receivedAt ?? $1.createdAt) }
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
    static func fetch(site raw: String, email: String, token: String, scope: JiraScope = .involved, scopedToken: Bool = false,
                      session: URLSession = HTTP.session) async throws -> [AttentionItem] {
        let site = try validatedSite(raw)
        let base: URL
        if scopedToken {
            let tenant = try await HTTP.json(HTTP.request(site.appendingPathComponent("_edge/tenant_info")), session: session)
            guard let cloudID = tenant["cloudId"] as? String, UUID(uuidString: cloudID) != nil else { throw APIError.invalidResponse }
            base = URL(string: "https://api.atlassian.com/ex/jira/\(cloudID)")!
        } else { base = site }
        var cursor: String?, seen = Set<String>(), items: [AttentionItem] = []
        for _ in 0..<50 {
            var fields = ["jql": scope.query,
                          "fields": "summary,status,duedate", "maxResults": "100"]
            if let cursor { fields["nextPageToken"] = cursor }
            let url = try HTTP.url(base.appendingPathComponent("rest/api/3/search/jql").absoluteString, query: fields)
            var request = HTTP.request(url)
            request.setValue("Basic \(Data("\(email):\(token)".utf8).base64EncodedString())", forHTTPHeaderField: "Authorization")
            let json = try await HTTP.json(request, session: session)
            guard json["issues"] is [[String: Any]] else { throw APIError.invalidResponse }
            items += ProviderParsing.jiraIssues(json, site: site)
            if json["isLast"] as? Bool == true { return unique(items) }
            guard let next = json["nextPageToken"] as? String, !next.isEmpty else {
                if json["isLast"] as? Bool == false { throw APIError.invalidResponse }
                return unique(items)
            }
            guard seen.insert(next).inserted else { throw APIError.invalidResponse }
            cursor = next
        }
        throw APIError.provider("jira_result_window_too_large")
    }
    private static func unique(_ items: [AttentionItem]) -> [AttentionItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}
