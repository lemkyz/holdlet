import AppKit
import Testing
@testable import HoldletApp

@MainActor
struct ApplicationMenuTests {
    @Test func editingShortcutsRouteToTheFocusedFieldEditor() throws {
        let target = NSObject()
        let menu = ApplicationMenu.make(text: { en, _ in en }, settingsTarget: target)
        let edit = try #require(menu.items.first { $0.title == "Edit" }?.submenu)
        let shortcuts = ["x": "cut:", "c": "copy:", "v": "paste:", "a": "selectAll:", "z": "undo:"]
        for (key, action) in shortcuts {
            let item = try #require(edit.items.first { $0.keyEquivalent == key && $0.keyEquivalentModifierMask == .command })
            #expect(item.action == NSSelectorFromString(action))
            #expect(item.target == nil)
        }
        let redo = try #require(edit.items.first { $0.action == NSSelectorFromString("redo:") })
        #expect(redo.keyEquivalent == "z")
        #expect(redo.keyEquivalentModifierMask == [.command, .shift])
        let settings = try #require(menu.items.first?.submenu?.items.first)
        #expect(settings.keyEquivalent == ",")
        #expect(settings.target === target)
    }

    @Test func turkishMenuKeepsNativeEditingActions() throws {
        let menu = ApplicationMenu.make(text: { _, tr in tr }, settingsTarget: NSObject())
        let edit = try #require(menu.items.first { $0.title == "Düzen" }?.submenu)
        let paste = try #require(edit.items.first { $0.title == "Yapıştır" })
        #expect(paste.action == #selector(NSText.paste(_:)))
        #expect(paste.keyEquivalent == "v")
        #expect(paste.target == nil)
    }
}
