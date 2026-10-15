import AppKit
import Carbon

/// Register a single shortcut with the OS instead of monitoring the user's keystrokes.
@MainActor
final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?

    func register() -> Bool {
        stop()
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { shortcut.onPress?() }
            return noErr
        }, 1, &spec, context, &handler)
        guard installed == noErr else { return false }
        let id = EventHotKeyID(signature: 0x484C4554, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_H), UInt32(controlKey | optionKey), id,
                                        GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { stop(); return false }
        return true
    }
    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }
}
