import Foundation

public enum ProviderParsing {
    public static func googleEvents(_ json: [String: Any]) -> [AttentionItem] {
        (json["items"] as? [[String: Any]] ?? []).compactMap { event in
            guard event["status"] as? String != "cancelled", let id = event["id"] as? String,
                  let start = event["start"] as? [String: String], let due = DateParsing.iso(start["dateTime"]) else { return nil }
            let attendees = event["attendees"] as? [[String: Any]] ?? []
            if attendees.contains(where: { ($0["self"] as? Bool) == true && ($0["responseStatus"] as? String) == "declined" }) { return nil }
            let end = event["end"] as? [String: String]
            let description = event["description"] as? String ?? ""
            let linkText = [event["hangoutLink"] as? String, event["location"] as? String, description].compactMap { $0 }.joined(separator: " ")
            return AttentionItem(id: "google.primary.\(id)", source: .google, kind: .meeting,
                title: event["summary"] as? String ?? "Untitled meeting", detail: "Google Calendar · Primary calendar",
                dueAt: due, endAt: DateParsing.iso(end?["dateTime"]), url: LinkPolicy.safeWebURL(event["htmlLink"] as? String),
                meetingURL: LinkPolicy.meetingURL(in: linkText), reason: "Upcoming timed event on your primary calendar")
        }
    }

    public static func gmailThread(_ json: [String: Any]) -> AttentionItem? {
        guard let id = json["id"] as? String, let messages = json["messages"] as? [[String: Any]], let last = messages.last else { return nil }
        let payload = last["payload"] as? [String: Any]
        let headers = payload?["headers"] as? [[String: String]] ?? []
        let subject = headers.first { $0["name"]?.lowercased() == "subject" }?["value"] ?? "Untitled email"
        let sender = headers.first { $0["name"]?.lowercased() == "from" }?["value"] ?? "Gmail"
        let incoming = messages.last { message in
            let labels = message["labelIds"] as? [String] ?? []
            return !labels.contains("SENT") && !labels.contains("DRAFT")
        }
        return AttentionItem(id: "gmail.\(id)", source: .gmail, kind: .mail,
            title: subject, detail: sender, url: URL(string: "https://mail.google.com/mail/u/0/#all/\(id)"),
            reason: "Matches your Gmail query; reading an email does not complete this follow-up",
            replyToken: incoming?["id"] as? String,
            receivedAt: (last["internalDate"] as? String).flatMap(Double.init).map { Date(timeIntervalSince1970: $0 / 1000) },
            isUnread: messages.contains { ($0["labelIds"] as? [String] ?? []).contains("UNREAD") })
    }

    public static func slackMatches(_ json: [String: Any]) -> [AttentionItem] {
        let result = json["messages"] as? [String: Any]
        return (result?["matches"] as? [[String: Any]] ?? []).compactMap { message in
            guard let ts = message["ts"] as? String,
                  let channel = message["channel"] as? [String: Any], let channelID = channel["id"] as? String else { return nil }
            let text = message["text"] as? String ?? "Slack message"
            return AttentionItem(id: "slack.\(channelID).\(ts)", source: .slack, kind: .message,
                title: String(text.prefix(180)), detail: "Slack · \(channel["name"] as? String ?? "Conversation")",
                url: LinkPolicy.safeWebURL(message["permalink"] as? String),
                reason: "Matches your Slack search; reply status is not inferred")
        }
    }

    public static func jiraIssues(_ json: [String: Any], site: URL, calendar: Calendar = .current) -> [AttentionItem] {
        (json["issues"] as? [[String: Any]] ?? []).compactMap { issue in
            guard let key = issue["key"] as? String, let fields = issue["fields"] as? [String: Any] else { return nil }
            let status = fields["status"] as? [String: Any]
            let category = status?["statusCategory"] as? [String: Any]
            guard category?["key"] as? String != "done" else { return nil }
            return AttentionItem(id: "jira.\(site.host ?? "").\(key)", source: .jira, kind: .task,
                title: "\(key) · \(fields["summary"] as? String ?? "Issue")", detail: "Jira · \(status?["name"] as? String ?? "Assigned to you")",
                dueAt: DateParsing.endOfDay(fields["duedate"] as? String, calendar: calendar),
                url: site.appendingPathComponent("browse").appendingPathComponent(key), reason: "Matches your Jira scope and is not in a Done status")
        }
    }
}
