import AppKit

@MainActor
enum ApplicationMenu {
    static func make(text: (String, String) -> String, settingsTarget: AnyObject) -> NSMenu {
        let menu = NSMenu()
        let application = NSMenu(title: "Holdlet")
        let applicationItem = NSMenuItem(title: "Holdlet", action: nil, keyEquivalent: "")
        applicationItem.submenu = application
        menu.addItem(applicationItem)

        let settings = application.addItem(withTitle: text("Settings…", "Ayarlar…"),
            action: #selector(AppDelegate.settingsFromMenu), keyEquivalent: ",")
        settings.target = settingsTarget
        application.addItem(.separator())
        application.addItem(withTitle: text("Quit Holdlet", "Holdlet'ten çık"),
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // A manually bootstrapped AppKit app does not get SwiftUI's Edit menu.
        // Nil targets let AppKit send these shortcuts to the focused field editor,
        // including the native editor used by SwiftUI SecureField.
        let edit = NSMenu(title: text("Edit", "Düzen"))
        let editItem = NSMenuItem(title: edit.title, action: nil, keyEquivalent: "")
        editItem.submenu = edit
        menu.addItem(editItem)
        edit.addItem(withTitle: text("Undo", "Geri Al"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: text("Redo", "Yinele"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: text("Cut", "Kes"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: text("Copy", "Kopyala"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: text("Paste", "Yapıştır"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: text("Select All", "Tümünü Seç"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }
}
