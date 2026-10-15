import CoreGraphics
import Foundation
import Testing
@testable import HoldletCore

struct PresenceTests {
    private let now = DateParsing.iso("2026-10-19T23:00:00Z")! // Monday
    private var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }

    @Test func placementsStayOnNegativeCoordinateExternalDisplay() {
        let display = CGRect(x: -1728, y: 80, width: 1728, height: 1080)
        for edge in ScreenEdge.allCases {
            for position in [-20.0, 0, 0.5, 1, 100, Double.nan] {
                let handle = EdgeLayout.handle(in: display, edge: edge, position: position)
                #expect(display.contains(handle))
                let drawer = EdgeLayout.drawer(in: display, handle: handle, edge: edge, desired: CGSize(width: 390, height: 710))
                #expect(display.contains(drawer))
            }
        }
    }
    @Test func smallDisplayDoesNotHideDrawerBelowScreen() {
        let display = CGRect(x: 0, y: -500, width: 800, height: 480)
        for edge in ScreenEdge.allCases {
            let handle = EdgeLayout.handle(in: display, edge: edge, position: 0.95)
            let drawer = EdgeLayout.drawer(in: display, handle: handle, edge: edge, desired: CGSize(width: 390, height: 710))
            #expect(display.contains(drawer)); #expect(drawer.height < 480)
        }
    }
    @Test func dropChoosesTheUsersIntendedEdge() {
        let display = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        #expect(EdgeLayout.nearestEdge(to: CGPoint(x: -900, y: 890), in: display) == .top)
        #expect(EdgeLayout.nearestEdge(to: CGPoint(x: -1435, y: 400), in: display) == .left)
        #expect(EdgeLayout.position(of: CGPoint(x: 800, y: -50), in: display, edge: .left) == 0)
    }
    @Test func overnightShiftBelongsToDayItStarted() {
        var prefs = Preferences(); prefs.workStart = 22; prefs.workEnd = 6; prefs.workdays = [2] // Monday only
        #expect(WorkSchedule.allows(now, preferences: prefs, calendar: utc))
        #expect(WorkSchedule.allows(now.addingTimeInterval(3 * 3600), preferences: prefs, calendar: utc))
        #expect(!WorkSchedule.allows(now.addingTimeInterval(8 * 3600), preferences: prefs, calendar: utc))
        #expect(!WorkSchedule.allows(now.addingTimeInterval(24 * 3600), preferences: prefs, calendar: utc))
    }
    @Test func daySelectionAndEqualHoursAreExplicit() {
        var prefs = Preferences(); prefs.workStart = 8; prefs.workEnd = 8; prefs.workdays = []
        #expect(!WorkSchedule.allows(now, preferences: prefs, calendar: utc))
        prefs.workdays = [2]
        #expect(WorkSchedule.allows(now, preferences: prefs, calendar: utc))
        prefs.respectWorkHours = false
        #expect(WorkSchedule.allows(now.addingTimeInterval(86400), preferences: prefs, calendar: utc))
    }
    @Test func dueCueHonorsSnoozeDemoWorkHoursAndCompletion() {
        var prefs = Preferences(); prefs.respectWorkHours = false
        let due = AttentionItem(id: "due", title: "Deadline", dueAt: now.addingTimeInterval(-10))
        var snoozed = due; snoozed.id = "later"; snoozed.snoozedUntil = now.addingTimeInterval(60)
        var completed = due; completed.id = "done"; completed.state = .completed
        var demo = due; demo.id = "demo"; demo.isDemo = true
        #expect(AttentionCuePlanner.due(items: [due, snoozed, completed, demo], preferences: prefs, now: now).map(\.itemID) == ["due"])
        prefs.respectWorkHours = true
        #expect(AttentionCuePlanner.due(items: [due], preferences: prefs, now: now, calendar: utc).isEmpty)
    }
    @Test func rescheduledMeetingGetsNewCueWithoutReplayingAncientDeadlines() {
        var prefs = Preferences(); prefs.respectWorkHours = false
        var meeting = AttentionItem(id: "meeting", kind: .meeting, title: "Call", dueAt: now.addingTimeInterval(290))
        let first = AttentionCuePlanner.due(items: [meeting], preferences: prefs, now: now).first
        meeting.dueAt = now.addingTimeInterval(295)
        let second = AttentionCuePlanner.due(items: [meeting], preferences: prefs, now: now).first
        #expect(first != nil && second != nil); #expect(first?.id != second?.id)
        let old = AttentionItem(id: "old", title: "Yesterday", dueAt: now.addingTimeInterval(-86400))
        #expect(AttentionCuePlanner.due(items: [old], preferences: prefs, now: now).isEmpty)
    }
    @Test func lateSyncInsideMeetingLeadWindowStillSurfaces() {
        var prefs = Preferences(); prefs.respectWorkHours = false; prefs.meetingLeadMinutes = 15
        let meeting = AttentionItem(id: "late-sync", kind: .meeting, title: "Call", dueAt: now.addingTimeInterval(60))
        #expect(AttentionCuePlanner.due(items: [meeting], preferences: prefs, now: now).count == 1)
    }
    @Test func initialMailSnapshotDoesNotBecomeAnAlertStorm() {
        var tracker = IncomingCueTracker()
        let old = AttentionItem(id: "old", source: .gmail, kind: .mail, title: "Existing")
        #expect(tracker.receive(items: [old], readySources: [.gmail], now: now).isEmpty)
        let fresh = AttentionItem(id: "new", source: .gmail, kind: .mail, title: "New")
        #expect(tracker.receive(items: [old, fresh], readySources: [.gmail], now: now).map(\.itemID) == ["new"])
        #expect(tracker.receive(items: [old, fresh], readySources: [.gmail], now: now).isEmpty)
    }
    @Test func firstMailAfterEmptySuccessfulSyncCanAlert() {
        var tracker = IncomingCueTracker()
        #expect(tracker.receive(items: [], readySources: [.gmail], now: now).isEmpty)
        let fresh = AttentionItem(id: "new", source: .gmail, kind: .mail, title: "New")
        #expect(tracker.receive(items: [fresh], readySources: [.gmail], now: now).count == 1)
    }
    @Test func waitingThreadNewReplyCanSurfaceAgain() {
        var old = AttentionItem(id: "thread", source: .gmail, kind: .mail, title: "Reply", replyToken: "a")
        var tracker = IncomingCueTracker(items: [old], readySources: [.gmail], now: now)
        old.replyToken = "b"
        #expect(tracker.receive(items: [old], readySources: [.gmail], now: now).count == 1)
    }
    @Test func existingStateDecodesWithVisibleEdgeWithoutNewFields() throws {
        var data = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(Preferences())) as? [String: Any])
        for key in ["edgeDock", "workdays"] { data.removeValue(forKey: key) }
        let old = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: data))
        #expect(old.dock.enabled); #expect(old.dock.edge == .top); #expect(old.workdays == nil)
    }
}
