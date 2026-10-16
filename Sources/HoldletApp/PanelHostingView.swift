import AppKit
import SwiftUI

/// Keeps padding and gaps inside the drawer in the same input surface as its cards.
final class PanelHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(convert(point, from: superview)) else { return nil }
        return super.hitTest(point) ?? self
    }
    override func scrollWheel(with event: NSEvent) {
        if let scroll = firstScrollView(in: self) { scroll.scrollWheel(with: event) }
        // Never forward an unhandled drawer gesture through the responder chain.
    }
    private func firstScrollView(in view: NSView) -> NSScrollView? {
        for child in view.subviews {
            if let scroll = child as? NSScrollView { return scroll }
            if let scroll = firstScrollView(in: child) { return scroll }
        }
        return nil
    }
}
