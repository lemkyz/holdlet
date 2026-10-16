import AppKit
import SwiftUI
import Testing
@testable import HoldletApp

@MainActor
private final class ScrollSink: NSScrollView {
    var received = 0
    override func scrollWheel(with event: NSEvent) { received += 1 }
}

@MainActor
struct PanelInputTests {
    @Test func drawerGapsRemainHitTestableAndForwardScrollToItsOwnList() throws {
        let host = PanelHostingView(rootView: EmptyView())
        host.frame = NSRect(x: 0, y: 0, width: 390, height: 710)
        let wrapper = NSView(frame: host.bounds)
        let scroll = ScrollSink(frame: NSRect(x: 14, y: 80, width: 362, height: 600))
        wrapper.addSubview(scroll); host.addSubview(wrapper)
        #expect(host.acceptsFirstMouse(for: nil))
        #expect(!host.mouseDownCanMoveWindow)
        #expect(host.hitTest(NSPoint(x: 3, y: 300)) != nil)
        #expect(host.hitTest(NSPoint(x: -5, y: 300)) == nil)
        let event = try #require(NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0))
        host.scrollWheel(with: event)
        #expect(scroll.received == 1)
    }
}
