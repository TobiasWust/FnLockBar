import AppKit
import Carbon.HIToolbox

/// A global shortcut, registered via Carbon's RegisterEventHotKey (no Accessibility permission needed).
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    private static let defaultsKey = "shortcut"

    static func load() -> Shortcut? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              var shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) else { return nil }
        // Versions ≤ 1.2 stored Escape as "⎋", which the system font draws like a reload arrow
        shortcut.display = shortcut.display.replacingOccurrences(of: "⎋", with: "Esc")
        return shortcut
    }

    static func save(_ shortcut: Shortcut?) {
        if let shortcut, let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    private static let fKeys: [UInt16: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
    ]
    private static let namedKeys: [UInt16: String] = [
        53: "Esc", 36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
    ]

    /// nil if the event isn't usable as a global shortcut (needs a modifier, except for F-keys).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        let isFKey = Shortcut.fKeys[event.keyCode] != nil
        guard !flags.isEmpty || isFKey else { return nil }

        var carbon: UInt32 = 0
        var symbols = ""
        if flags.contains(.control) { carbon |= UInt32(controlKey); symbols += "⌃" }
        if flags.contains(.option) { carbon |= UInt32(optionKey); symbols += "⌥" }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey); symbols += "⇧" }
        if flags.contains(.command) { carbon |= UInt32(cmdKey); symbols += "⌘" }

        let key = Shortcut.fKeys[event.keyCode] ?? Shortcut.namedKeys[event.keyCode]
            ?? event.charactersIgnoringModifiers?.uppercased() ?? "#\(event.keyCode)"
        self.init(keyCode: UInt32(event.keyCode), carbonModifiers: carbon, display: symbols + key)
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.display = display
    }
}

final class HotKey {
    private var ref: EventHotKeyRef?
    private static var handler: (() -> Void)?
    private static var installed = false

    init(onPress: @escaping () -> Void) {
        HotKey.handler = onPress
        guard !HotKey.installed else { return }
        HotKey.installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            HotKey.handler?()
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// Returns false if macOS refused the combination (e.g. taken by another app).
    @discardableResult
    func register(_ shortcut: Shortcut?) -> Bool {
        unregister()
        guard let shortcut else { return true }
        let id = EventHotKeyID(signature: OSType(0x464E4C42), id: 1) // 'FNLB'
        return RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id,
                                   GetApplicationEventTarget(), 0, &ref) == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}
