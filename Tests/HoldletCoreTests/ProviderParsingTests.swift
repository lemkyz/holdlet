import Foundation
import Testing
@testable import HoldletCore

struct ProviderParsingTests {
    @Test func testGoogleExcludesAllDayCancelledAndDeclinedEvents() {
        let base: [String: Any] = ["id": "a", "summary": "Review", "start": ["dateTime": "2026-10-15T14:30:00+03:00"], "hangoutLink": "https://meet.google.com/abc-defg-hij"]
        var canceled = base; canceled["status"] = "cancelled"
        var allDay = base; allDay["start"] = ["date": "2026-10-15"]
        var declined = base; declined["attendees"] = [["self": true, "responseStatus": "declined"]]
        let items = ProviderParsing.googleEvents(["items": [base, canceled, allDay, declined]])
        XCTAssertEqual(items.count, 1); XCTAssertNotNil(items[0].meetingURL)
        XCTAssertEqual(items[0].dueAt, DateParsing.iso("2026-10-15T11:30:00Z"))
    }
    @Test func testGmailReadsHeadersCaseInsensitivelyAndUsesThreadIdentity() {
        let json: [String: Any] = ["id": "abcdef", "messages": [["payload": ["headers": [["name": "SUBJECT", "value": "Approval"], ["name": "From", "value": "Example Person"]]]]]]
        let item = ProviderParsing.gmailThread(json)
        XCTAssertEqual(item?.id, "gmail.abcdef"); XCTAssertEqual(item?.title, "Approval")
        XCTAssertEqual(item?.detail, "Example Person"); XCTAssertEqual(item?.url?.host, "mail.google.com")
    }
    @Test func testSlackIdentityIncludesChannelAndUnsafePermalinkIsRejected() {
        let json: [String: Any] = ["messages": ["matches": [["ts": "123.456", "channel": ["id": "C123", "name": "team"], "text": "Decision?", "permalink": "file:///tmp/test"]]]]
        let items = ProviderParsing.slackMatches(json)
        XCTAssertEqual(items.first?.id, "slack.C123.123.456"); XCTAssertNil(items.first?.url)
    }
    @Test func testJiraDoneIssueExcludedAndDueDateHasLocalMeaning() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let active: [String: Any] = ["key": "TEST-1", "fields": ["summary": "Review", "duedate": "2026-10-15", "status": ["name": "In Progress", "statusCategory": ["key": "indeterminate"]]]]
        let done: [String: Any] = ["key": "TEST-2", "fields": ["status": ["statusCategory": ["key": "done"]]]]
        let items = ProviderParsing.jiraIssues(["issues": [active, done]], site: URL(string: "https://example.atlassian.net")!, calendar: calendar)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].dueAt, DateParsing.iso("2026-10-15T14:00:00Z"))
        XCTAssertEqual(items[0].url?.path, "/browse/TEST-1")
    }
    @Test func testMissingProviderCollectionsProduceEmptySnapshots() {
        XCTAssertTrue(ProviderParsing.googleEvents([:]).isEmpty)
        XCTAssertTrue(ProviderParsing.slackMatches([:]).isEmpty)
        XCTAssertNil(ProviderParsing.gmailThread([:]))
    }
}
