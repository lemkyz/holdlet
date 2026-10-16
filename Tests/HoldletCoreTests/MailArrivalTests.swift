import Foundation
import Testing
@testable import HoldletCore

struct MailArrivalTests {
    @Test func loadingOldPagesDoesNotCreateIncomingMailAlerts() {
        let now = Date()
        var tracker = IncomingCueTracker(items: [], readySources: [.gmail], now: now)
        let old = AttentionItem(id: "gmail.old", source: .gmail, kind: .mail, title: "Old", receivedAt: now.addingTimeInterval(-86400))
        let fresh = AttentionItem(id: "gmail.new", source: .gmail, kind: .mail, title: "New", receivedAt: now)
        #expect(tracker.receive(items: [old], readySources: [.gmail], now: now).isEmpty)
        let arrivals = tracker.receive(items: [old, fresh], readySources: [.gmail], now: now)
        #expect(arrivals.map(\.itemID) == ["gmail.new"])
        #expect(tracker.receive(items: [old, fresh], readySources: [.gmail], now: now).isEmpty)
    }
    @Test func existingMailWithoutReceivedDateStillDecodes() throws {
        let original = AttentionItem(source: .gmail, kind: .mail, title: "Synthetic")
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "receivedAt")
        let restored = try JSONDecoder().decode(AttentionItem.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored.receivedAt == nil)
        #expect(restored.title == original.title)
    }
}
