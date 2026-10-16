import AppKit
import Combine
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var settings: NSWindow?
    private var state: AppState!
    private var statusTimer: Timer?
    private var dismissMonitor: Any?
    private var dock: EdgeDockController?
    private var presenceSubscription: AnyCancellable?
    private let shortcut = GlobalShortcut()
    private var shortcutEnabled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let demo = CommandLine.arguments.contains("--demo")
        state = AppState(demoInstance: demo)
        state.showPanel = { [weak self] in self?.showPanel() }
        state.showSettings = { [weak self] in self?.showSettings() }
        state.hidePanel = { [weak self] in self?.panel.orderOut(nil) }
        state.previewEdge = { [weak self] in self?.dock?.preview() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.grid.2x2.fill", accessibilityDescription: "Holdlet")
            button.imagePosition = .imageLeading; button.target = self; button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 390, height: 710),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false; panel.delegate = self
        panel.contentView = PanelHostingView(rootView: PanelView(model: state))
        dock = EdgeDockController(model: state)
        dock?.onToggle = { [weak self] in
            guard let self else { return }
            if self.panel.isVisible { self.panel.orderOut(nil) } else { self.showPanel() }
        }
        dock?.onExpand = { [weak self] in self?.showPanel() }
        dock?.onCollapse = { [weak self] in self?.panel.orderOut(nil) }
        dock?.onPlacementChanged = { [weak self] in
            guard let self, self.panel.isVisible else { return }; self.showPanel(activate: false)
        }
        shortcut.onPress = { [weak self] in
            guard let self else { return }
            if self.panel.isVisible { self.panel.orderOut(nil) } else { self.showPanel() }
        }
        updateShortcut()
        presenceSubscription = state.$snapshot.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatus(); self?.updateShortcut() }
        }
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.state.preferences.panelPinned else { return }; self.panel.orderOut(nil)
            }
        }
        statusTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateStatus() }
        }
        updateStatus()
        if !state.preferences.onboardingComplete && !demo { showSettings() }
        else if demo || CommandLine.arguments.contains("--show") { showPanel() }
        if CommandLine.arguments.contains("--smoke-test") {
            showPanel()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                print("Holdlet normal startup OK")
                NSApp.terminate(nil)
            }
        }
    }
    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: state.text("Open Holdlet", "Holdlet'i aç"), action: #selector(openFromMenu), keyEquivalent: "")
            menu.addItem(withTitle: state.text("Settings…", "Ayarlar…"), action: #selector(settingsFromMenu), keyEquivalent: ",")
            menu.addItem(.separator()); menu.addItem(withTitle: state.text("Quit Holdlet", "Holdlet'ten çık"), action: #selector(quit), keyEquivalent: "q")
            for item in menu.items { item.target = self }
            statusItem.menu = menu; statusItem.button?.performClick(nil); statusItem.menu = nil
        } else if panel.isVisible { panel.orderOut(nil) } else { showPanel() }
    }
    @objc private func openFromMenu() { showPanel() }
    @objc private func settingsFromMenu() { showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func showPanel(activate: Bool = true) {
        dock?.acknowledge()
        if state.preferences.dock.enabled, let frame = dock?.drawerFrame {
            let opening = !panel.isVisible
            let animate = opening && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            if animate {
                var start = frame
                switch state.preferences.dock.edge {
                case .top: start.origin.y += 14
                case .bottom: start.origin.y -= 14
                case .left: start.origin.x -= 14
                case .right: start.origin.x += 14
                }
                panel.setFrame(start, display: true); panel.alphaValue = 0
                panel.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.18
                    panel.animator().setFrame(frame, display: true); panel.animator().alphaValue = 1
                }, completionHandler: nil)
            } else { panel.setFrame(frame, display: true); panel.alphaValue = 1; panel.orderFrontRegardless() }
            if activate { panel.makeKey(); NSApp.activate(ignoringOtherApps: true) }
            return
        }
        guard let button = statusItem.button, let window = button.window else { return }
        let buttonRect = window.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = window.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let height = min(710, visible.height - 12)
        panel.setContentSize(NSSize(width: 390, height: height))
        let x = min(max(visible.minX, buttonRect.maxX - 390), visible.maxX - 390)
        panel.setFrameOrigin(NSPoint(x: x, y: max(visible.minY, buttonRect.minY - height - 4)))
        panel.orderFrontRegardless(); panel.makeKey(); NSApp.activate(ignoringOtherApps: true)
    }
    private func showSettings() {
        panel.orderOut(nil)
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 650),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Holdlet"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(model: state))
            window.minSize = NSSize(width: 620, height: 570); window.center(); settings = window
        }
        settings?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func updateShortcut() {
        let enabled = state.preferences.globalShortcutEnabled ?? true
        guard enabled != shortcutEnabled else { return }
        shortcutEnabled = enabled
        if enabled { state.shortcutAvailable = shortcut.register() }
        else { shortcut.stop(); state.shortcutAvailable = false }
    }
    private func updateStatus() {
        guard let button = statusItem.button else { return }
        if let meeting = state.nextMeeting, let date = meeting.dueAt {
            let seconds = date.timeIntervalSinceNow
            button.title = seconds < 3600 ? " \(state.countdown(date))\(seconds > 0 ? "m" : "")" : ""
            button.toolTip = state.preferences.hideDetails ? "Holdlet" : state.title(meeting)
        } else {
            button.title = state.missed > 0 ? " \(state.missed)" : ""
            button.toolTip = "Holdlet"
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPanel(); return true }
    func applicationWillTerminate(_ notification: Notification) {
        if let dismissMonitor { NSEvent.removeMonitor(dismissMonitor) }
        shortcut.stop(); dock?.stop(); statusTimer?.invalidate(); presenceSubscription?.cancel()
        state.googleAuth.cancel()
    }
}

@main
@MainActor
struct HoldletMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
