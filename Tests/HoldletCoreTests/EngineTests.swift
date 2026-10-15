import Foundation
import Testing
@testable import HoldletCore

struct EngineTests {
    let now = ISO8601DateFormatter().date(from: "2026-10-15T09:00:00Z")!
    var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!; return calendar
    }
    func preferences() -> Preferences {
        var preferences = Preferences(); preferences.notificationsEnabled = true; preferences.respectWorkHours = false; return preferences
    }
    @Test func testMergePreservesCompletionAndSnooze() {
        let snooze = now.addingTimeInterval(600)
        let original = AttentionItem(id: "a", source: .gmail, title: "Old", state: .completed, snoozedUntil: snooze)
        let incoming = AttentionItem(id: "a", source: .gmail, title: "Updated")
        let merged = AttentionEngine.merge(existing: [original], incoming: [incoming], source: .gmail)
        XCTAssertEqual(merged.count, 1); XCTAssertEqual(merged[0].title, "Updated")
        XCTAssertEqual(merged[0].state, .completed); XCTAssertEqual(merged[0].snoozedUntil, snooze)
    }
    @Test func testCanceledMeetingRemovedButOtherSourceRetained() {
        let meeting = AttentionItem(id: "a", source: .calendar, kind: .meeting, title: "Canceled")
        let local = AttentionItem(id: "b", title: "Keep")
        XCTAssertEqual(AttentionEngine.merge(existing: [meeting, local], incoming: [], source: .calendar), [local])
    }
    @Test func testRescheduledMeetingBecomesActive() {
        var old = AttentionItem(id: "a", source: .google, kind: .meeting, title: "Call", dueAt: now, state: .completed)
        old.snoozedUntil = now.addingTimeInterval(900)
        var changed = old; changed.dueAt = now.addingTimeInterval(3600)
        let merged = AttentionEngine.merge(existing: [old], incoming: [changed], source: .google)
        XCTAssertEqual(merged[0].state, .active); XCTAssertNil(merged[0].snoozedUntil)
    }
    @Test func testDuplicateProviderIDsDoNotDuplicateRows() {
        let item = AttentionItem(id: "a", source: .slack, title: "Hello")
        XCTAssertEqual(AttentionEngine.merge(existing: [], incoming: [item, item], source: .slack).count, 1)
    }
    @Test func testWaitingFollowUpSurvivesQueryRemoval() {
        let item = AttentionItem(id: "a", source: .gmail, title: "Reply?", state: .waiting)
        XCTAssertEqual(AttentionEngine.merge(existing: [item], incoming: [], source: .gmail), [item])
    }
    @Test func testReadingMailDoesNotSilentlyCompleteFollowUp() {
        let item = AttentionItem(id: "a", source: .gmail, title: "Read but not done")
        XCTAssertEqual(AttentionEngine.merge(existing: [item], incoming: [], source: .gmail), [item])
    }
    @Test func testIncomingGmailReplyResurfacesWaitingThread() {
        let old = AttentionItem(id: "a", source: .gmail, title: "Follow-up", state: .waiting, replyToken: "old-incoming")
        var fresh = old; fresh.replyToken = "new-incoming"
        let result = AttentionEngine.merge(existing: [old], incoming: [fresh], source: .gmail)
        XCTAssertEqual(result[0].state, .active)
        XCTAssertTrue(result[0].reason.contains("New incoming"))
    }
    @Test func testVisibleExcludesCompletedSnoozedAndEndedMeetings() {
        let items = [
            AttentionItem(id: "done", title: "Done", state: .completed),
            AttentionItem(id: "snoozed", title: "Later", snoozedUntil: now.addingTimeInterval(1)),
            AttentionItem(id: "ended", kind: .meeting, title: "Ended", dueAt: now.addingTimeInterval(-3600), endAt: now),
            AttentionItem(id: "active", title: "Visible")
        ]
        XCTAssertEqual(AttentionEngine.prioritized(items, now: now).map(\.id), ["active"])
    }
    @Test func testNextMeetingWinsOverOverdueTask() {
        let task = AttentionItem(id: "task", kind: .task, title: "Late", dueAt: now.addingTimeInterval(-20))
        let meeting = AttentionItem(id: "meeting", kind: .meeting, title: "Call", dueAt: now.addingTimeInterval(600))
        XCTAssertEqual(AttentionEngine.prioritized([task, meeting], now: now).first?.id, "meeting")
    }
    @Test func testRemindersSkipDemoCompletedAndUndatedItems() {
        let due = now.addingTimeInterval(600)
        let items = [AttentionItem(title: "Demo", dueAt: due, isDemo: true),
            AttentionItem(title: "Done", dueAt: due, state: .completed), AttentionItem(title: "Undated")]
        XCTAssertTrue(ReminderPlanner.plan(items: items, preferences: preferences(), now: now).isEmpty)
    }
    @Test func testMeetingLeadAndSnoozeAreIndependent() {
        var item = AttentionItem(id: "call", kind: .meeting, title: "Call", dueAt: now.addingTimeInterval(900))
        var plan = ReminderPlanner.plan(items: [item], preferences: preferences(), now: now)
        XCTAssertEqual(plan.first?.date, now.addingTimeInterval(600))
        item.snoozedUntil = now.addingTimeInterval(420)
        plan = ReminderPlanner.plan(items: [item], preferences: preferences(), now: now)
        XCTAssertEqual(plan.first?.date, item.snoozedUntil)
    }
    @Test func testLeadWindowUsesStableIDWithoutReplayingOldDeadline() {
        let item = AttentionItem(id: "call", kind: .meeting, title: "Call", dueAt: now.addingTimeInterval(120))
        let first = ReminderPlanner.plan(items: [item], preferences: preferences(), now: now)
        let later = ReminderPlanner.plan(items: [item], preferences: preferences(), now: now.addingTimeInterval(20))
        XCTAssertEqual(first.first?.id, later.first?.id)
        XCTAssertTrue(ReminderPlanner.plan(items: [AttentionItem(title: "Old task", dueAt: now)], preferences: preferences(), now: now).isEmpty)
    }
    @Test func testRescheduleChangesNotificationIdentifier() {
        var item = AttentionItem(id: "a", title: "Task", dueAt: now.addingTimeInterval(600))
        let first = ReminderPlanner.plan(items: [item], preferences: preferences(), now: now).first?.id
        item.dueAt = now.addingTimeInterval(1200)
        XCTAssertNotEqual(first, ReminderPlanner.plan(items: [item], preferences: preferences(), now: now).first?.id)
    }
    @Test func testWorkHoursUseSuppliedTimeZone() {
        var preferences = preferences(); preferences.respectWorkHours = true; preferences.workStart = 8; preferences.workEnd = 19
        let item = AttentionItem(title: "Evening", dueAt: ISO8601DateFormatter().date(from: "2026-10-15T18:30:00Z"))
        var istanbul = utc; istanbul.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        XCTAssertEqual(ReminderPlanner.plan(items: [item], preferences: preferences, now: now, calendar: utc).count, 1)
        XCTAssertTrue(ReminderPlanner.plan(items: [item], preferences: preferences, now: now, calendar: istanbul).isEmpty)
    }
    @Test func testDSTFallbackDoesNotAlterAbsoluteReminderTime() {
        var newYork = utc; newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let before = DateParsing.iso("2026-11-01T01:30:00-04:00")!
        let after = DateParsing.iso("2026-11-01T01:30:00-05:00")!
        let items = [AttentionItem(id: "a", title: "Before", dueAt: before), AttentionItem(id: "b", title: "After", dueAt: after)]
        let plans = ReminderPlanner.plan(items: items, preferences: preferences(), now: before.addingTimeInterval(-3600), calendar: newYork)
        XCTAssertEqual(plans.count, 2); XCTAssertEqual(plans[1].date.timeIntervalSince(plans[0].date), 3600)
    }
    @Test func testPrivacyRedactsNotificationContent() {
        var preferences = preferences(); preferences.hideDetails = true
        let item = AttentionItem(title: "Confidential deal", detail: "Customer email", dueAt: now.addingTimeInterval(60))
        let plan = ReminderPlanner.plan(items: [item], preferences: preferences, now: now).first!
        XCTAssertFalse(plan.title.contains("deal")); XCTAssertFalse(plan.body.contains("Customer"))
    }
    @Test func testNotificationCapacityIsBounded() {
        let items = (0..<90).map { AttentionItem(id: "\($0)", title: "Task", dueAt: now.addingTimeInterval(Double(60 + $0))) }
        XCTAssertEqual(ReminderPlanner.plan(items: items, preferences: preferences(), now: now).count, 48)
    }
    @Test func testPersistenceRoundTripAndRestrictedPermissions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SnapshotStore(url: directory.appendingPathComponent("state.json"))
        let snapshot = Snapshot(items: [AttentionItem(title: "Persist", dueAt: now, snoozedUntil: now.addingTimeInterval(600))], focusEndsAt: now.addingTimeInterval(1500))
        try store.save(snapshot); XCTAssertEqual(try store.load(), snapshot)
        let attributes = try FileManager.default.attributesOfItem(atPath: store.url.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }
    @Test func testCorruptStateFailsInsteadOfSilentlyResetting() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = Data("broken".utf8); try data.write(to: url)
        XCTAssertThrowsError(try SnapshotStore(url: url).load())
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
    @Test func testSafeLinksRejectExecutableSchemesAndLookalikes() {
        XCTAssertNil(LinkPolicy.safeWebURL("file:///etc/passwd"))
        XCTAssertNil(LinkPolicy.safeWebURL("javascript:alert(1)"))
        XCTAssertNil(LinkPolicy.safeWebURL("https://user:password@example.com"))
        XCTAssertNil(LinkPolicy.meetingURL(in: "https://zoom.us.evil.example/call"))
        XCTAssertNotNil(LinkPolicy.meetingURL(in: "Join https://acme.zoom.us/j/123"))
        XCTAssertNotNil(LinkPolicy.meetingURL(in: "https://meet.google.com/abc-defg-hij"))
    }
}
