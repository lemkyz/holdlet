import AppKit
import Combine
import HoldletCore
import SwiftUI

/// A separate non-key window keeps the entry point visible without taking keyboard focus.
@MainActor
final class EdgeDockController {
    private let model: AppState
    private let window: NSPanel
    private let grip: EdgeGripView
    private var subscriptions = Set<AnyCancellable>()
    private var screenObserver: NSObjectProtocol?
    private var dragging = false
    private var attentionPending = false
    private var pulseTask: Task<Void, Never>?
    private var ledger: [String: Double]
    private let defaults: UserDefaults
    private let initialDisplayID: UInt32?
    private var incomingTracker: IncomingCueTracker
    private var lastPlacement: EdgeDockPreferences?
    var onToggle: (() -> Void)?
    var onExpand: (() -> Void)?
    var onCollapse: (() -> Void)?
    var onPlacementChanged: (() -> Void)?

    init(model: AppState) {
        self.model = model
        initialDisplayID = (NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        incomingTracker = IncomingCueTracker(items: model.snapshot.items,
            readySources: Set(model.enabledSources.filter { model.snapshot.health[$0.rawValue]?.lastSuccess != nil }), now: model.now)
        defaults = model.demoInstance ? (UserDefaults(suiteName: "io.github.lemkyz.holdlet.demo") ?? .standard) : .standard
        ledger = defaults.dictionary(forKey: "edgeCueLedger") as? [String: Double] ?? [:]
        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = true
        window.level = .floating; window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        grip = EdgeGripView()
        window.contentView = grip
        grip.onClick = { [weak self] in self?.onToggle?() }
        grip.onExpand = { [weak self] in self?.onExpand?() }
        grip.onCollapse = { [weak self] in self?.onCollapse?() }
        grip.onDrag = { [weak self] point in self?.drag(to: point) }
        grip.onDrop = { [weak self] point in self?.drop(at: point) }
        model.$snapshot.dropFirst().sink { [weak self] _ in
            // @Published emits before mutation; read the committed preferences on the next turn.
            DispatchQueue.main.async { self?.refresh(); self?.checkIncoming() }
        }.store(in: &subscriptions)
        model.$now.sink { [weak self] date in
            DispatchQueue.main.async { self?.checkDeadlines(at: date); self?.refreshLabel() }
        }.store(in: &subscriptions)
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh(); self?.onPlacementChanged?() }
        }
        refresh(); checkIncoming()
    }

    var screen: NSScreen? {
        NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == (model.preferences.dock.displayID ?? initialDisplayID) }
        ?? NSScreen.screens.first
    }
    var drawerFrame: NSRect? {
        guard let screen else { return nil }
        return EdgeLayout.drawer(in: screen.visibleFrame, handle: window.frame, edge: model.preferences.dock.edge,
                                 desired: CGSize(width: 390, height: 710))
    }
    func refresh() {
        guard !dragging else { return }
        if lastPlacement != model.preferences.dock {
            pulseTask?.cancel(); grip.highlighted = false; lastPlacement = model.preferences.dock
        }
        guard model.preferences.dock.enabled, let screen else { window.orderOut(nil); return }
        let frame = EdgeLayout.handle(in: screen.visibleFrame, edge: model.preferences.dock.edge, position: model.preferences.dock.position)
        window.setFrame(frame, display: true)
        grip.edge = model.preferences.dock.edge
        refreshLabel(); window.orderFrontRegardless()
    }
    func refreshLabel() {
        let urgent = model.active.filter { $0.state == .active && ($0.dueAt ?? .distantFuture) <= model.now }.count
        let label: String
        if urgent > 0 { label = "\(urgent)" }
        else if let meeting = model.nextMeeting, let due = meeting.dueAt { label = model.countdown(due) + (due > model.now && due.timeIntervalSince(model.now) < 3600 ? "m" : "") }
        else { label = "Holdlet" }
        grip.label = label
        grip.urgent = urgent > 0 || attentionPending
        grip.toolTip = model.text("Click to open. Drag to any screen edge. Scroll inward to open, outward to hide.",
                                  "Açmak için tıkla. Ekranın kenarına sürükle. İçeri kaydırarak aç, dışarı kaydırarak gizle.")
        grip.setAccessibilityLabel(model.text("Holdlet screen edge", "Holdlet ekran kenarı") + ", " + label)
        grip.needsDisplay = true
    }
    private func drag(to point: NSPoint) {
        if !dragging { pulseTask?.cancel(); dragging = true; onCollapse?() }
        window.setFrameOrigin(NSPoint(x: point.x - window.frame.width / 2, y: point.y - window.frame.height / 2))
    }
    private func drop(at point: NSPoint) {
        dragging = false
        let target = NSScreen.screens.first { $0.frame.contains(point) } ?? screen
        guard let target else { return }
        let edge = EdgeLayout.nearestEdge(to: point, in: target.visibleFrame)
        var dock = model.preferences.dock
        dock.edge = edge; dock.position = EdgeLayout.position(of: point, in: target.visibleFrame, edge: edge)
        dock.displayID = (target.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        model.updatePreferences { $0.edgeDock = dock }
        refresh(); onPlacementChanged?()
    }
    private func checkIncoming() {
        let ready = Set(model.enabledSources.filter { model.snapshot.health[$0.rawValue]?.lastSuccess != nil })
        let arrivals = incomingTracker.receive(items: model.snapshot.items, readySources: ready, now: model.now)
        guard model.preferences.dock.alerts, !model.isFocusing,
              WorkSchedule.allows(model.now, preferences: model.preferences) else { return }
        let eligible = arrivals.filter { ledger[$0.id] == nil }
        guard !eligible.isEmpty else { return }
        for item in eligible { record(item.id) }
        cue(playSound: model.preferences.dock.sound)
    }
    private func checkDeadlines(at date: Date) {
        let cues = AttentionCuePlanner.due(items: model.snapshot.items, preferences: model.preferences, now: date)
            .filter { ledger[$0.id] == nil }
        guard !cues.isEmpty else { return }
        for cue in cues { record(cue.id) }
        // Focus suppresses incoming chatter, but intentional deadlines still surface.
        cue(playSound: model.preferences.dock.sound && !model.preferences.notificationsEnabled)
    }
    private func record(_ id: String) {
        ledger[id] = Date().timeIntervalSince1970
        ledger = ledger.filter { $0.value > Date().addingTimeInterval(-30 * 86400).timeIntervalSince1970 }
        defaults.set(ledger, forKey: "edgeCueLedger")
    }
    func acknowledge() { attentionPending = false; refreshLabel() }
    func preview() { cue(playSound: model.preferences.dock.sound) }
    private func cue(playSound: Bool) {
        guard model.preferences.dock.enabled, !dragging else { return }
        attentionPending = true; refreshLabel()
        if playSound { NSSound(named: "Pop")?.play() }
        pulseTask?.cancel(); refresh()
        grip.highlighted = true; grip.needsDisplay = true
        let base = window.frame
        let edge = model.preferences.dock.edge
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        pulseTask = Task { [weak self] in
            guard let self else { return }
            if !reduceMotion {
                for _ in 0..<3 {
                    guard !Task.isCancelled, !self.dragging else { return }
                    var peek = base
                    switch edge {
                    case .top: peek.origin.y -= 10
                    case .bottom: peek.origin.y += 10
                    case .left: peek.origin.x += 10
                    case .right: peek.origin.x -= 10
                    }
                    await NSAnimationContext.runAnimationGroup { context in context.duration = 0.18; self.window.animator().setFrame(peek, display: true) }
                    try? await Task.sleep(nanoseconds: 220_000_000)
                    guard !Task.isCancelled, !self.dragging else { return }
                    await NSAnimationContext.runAnimationGroup { context in context.duration = 0.18; self.window.animator().setFrame(base, display: true) }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self.grip.highlighted = false; self.grip.needsDisplay = true
        }
    }
    func stop() {
        pulseTask?.cancel(); window.orderOut(nil)
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        subscriptions.removeAll()
    }
}

@MainActor
private final class EdgeGripView: NSView {
    var edge: ScreenEdge = .top { didSet { refreshContent() } }
    var label = "Holdlet" { didSet { refreshContent() } }
    var urgent = false { didSet { refreshContent() } }
    var highlighted = false { didSet { refreshContent() } }
    var onClick: (() -> Void)?
    var onExpand: (() -> Void)?
    var onCollapse: (() -> Void)?
    var onDrag: ((NSPoint) -> Void)?
    var onDrop: ((NSPoint) -> Void)?
    private var startPoint: NSPoint?
    private var didDrag = false
    private var scrollAmount: CGFloat = 0
    private let material = NSVisualEffectView()
    private let text = NSTextField(labelWithString: "Holdlet")
    private let image = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true; layer?.cornerRadius = 14; layer?.masksToBounds = true
        material.material = .hudWindow; material.blendingMode = .behindWindow; material.state = .active
        material.autoresizingMask = [.width, .height]; material.frame = bounds; addSubview(material)
        text.alignment = .center; text.lineBreakMode = .byTruncatingTail
        image.contentTintColor = .secondaryLabelColor
        material.addSubview(image); material.addSubview(text)
        setAccessibilityElement(true); setAccessibilityRole(.button); refreshContent()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(point) ? self : nil }
    override func accessibilityPerformPress() -> Bool { onClick?(); return true }
    private func refreshContent() {
        if edge.horizontal { text.stringValue = label }
        else if label == "Holdlet" { text.stringValue = "H" }
        else {
            let compact = String(label.split(separator: " ").first ?? Substring(label))
            text.stringValue = compact.hasSuffix("m") ? String(compact.dropLast()) : compact
        }
        text.font = .monospacedDigitSystemFont(ofSize: edge.horizontal ? 11 : (label.count > 4 ? 8 : 10), weight: .medium)
        text.textColor = urgent || highlighted ? .systemOrange : .labelColor
        let symbol: String
        switch edge { case .top: symbol = "chevron.down"; case .bottom: symbol = "chevron.up"; case .left: symbol = "chevron.right"; case .right: symbol = "chevron.left" }
        image.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        material.wantsLayer = true
        material.layer?.backgroundColor = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            ? NSColor.windowBackgroundColor.cgColor : NSColor.clear.cgColor
        layer?.borderColor = (highlighted ? NSColor.systemOrange : NSColor.labelColor.withAlphaComponent(0.18)).cgColor
        layer?.borderWidth = highlighted ? 1.5 : 0.6
        needsLayout = true
    }
    override func layout() {
        super.layout(); material.frame = bounds
        if edge.horizontal {
            image.frame = NSRect(x: 12, y: 9, width: 12, height: 12)
            text.frame = NSRect(x: 31, y: 7, width: max(1, bounds.width - 43), height: 16)
        } else {
            image.frame = NSRect(x: 9, y: bounds.height - 27, width: 12, height: 12)
            text.frame = NSRect(x: 1, y: bounds.midY - 8, width: max(1, bounds.width - 2), height: 16)
        }
    }
    override func mouseDown(with event: NSEvent) { startPoint = NSEvent.mouseLocation; didDrag = false }
    override func mouseDragged(with event: NSEvent) {
        let point = NSEvent.mouseLocation
        guard let startPoint, didDrag || hypot(point.x - startPoint.x, point.y - startPoint.y) > 5 else { return }
        didDrag = true; onDrag?(point)
    }
    override func mouseUp(with event: NSEvent) {
        if didDrag { onDrop?(NSEvent.mouseLocation) } else { onClick?() }
        startPoint = nil; didDrag = false
    }
    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began { scrollAmount = 0 }
        let delta: CGFloat
        switch edge {
        case .top: delta = -event.scrollingDeltaY
        case .bottom: delta = event.scrollingDeltaY
        case .left: delta = event.scrollingDeltaX
        case .right: delta = -event.scrollingDeltaX
        }
        scrollAmount += delta
        if abs(scrollAmount) > 12 {
            if scrollAmount > 0 { onExpand?() } else { onCollapse?() }
            scrollAmount = 0
        }
    }
}
