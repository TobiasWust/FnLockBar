// FnLockBar — menu bar indicator + toggle for the fn key mode.
// Reads the live HID parameter (HIDFKeyMode), which is what BTT's
// "Set Function Key Mode" action changes (com.apple.keyboard.fnState is NOT updated by it).

import AppKit
import Carbon.HIToolbox
import IOKit
import IOKit.hidsystem
import ServiceManagement

enum FnMode {
    /// true = F1–F12 are standard function keys ("fn lock" on)
    static func isFunctionKeys() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let params = IORegistryEntryCreateCFProperty(service, kIOHIDParametersKey as CFString,
                                                           kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any],
              let mode = params[kIOHIDFKeyModeKey] as? Int else { return nil }
        return mode == 1
    }

    static func set(functionKeys: Bool) -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        var connect: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS else { return false }
        defer { IOServiceClose(connect) }
        var value: UInt32 = functionKeys ? 1 : 0
        let kr = IOHIDSetParameter(connect, kIOHIDFKeyModeKey as CFString, &value,
                                   IOByteCount(MemoryLayout<UInt32>.size))
        // keep the System Settings toggle in sync too
        CFPreferencesSetValue("com.apple.keyboard.fnState" as CFString, functionKeys as CFBoolean,
                              kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return kr == KERN_SUCCESS
    }
}

/// A global shortcut, registered via Carbon's RegisterEventHotKey (no Accessibility permission needed).
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    private static let defaultsKey = "shortcut"

    static func load() -> Shortcut? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
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
        53: "⎋", 36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦",
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

/// A system-style overlay that briefly shows the new mode, like the volume/brightness HUD.
final class ChangeHUD {
    static let defaultsKey = "showHUD"
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    private let size: CGFloat = 180
    private lazy var panel: NSPanel = {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let background = NSVisualEffectView(frame: panel.contentRect(forFrameRect: panel.frame))
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 22
        background.layer?.masksToBounds = true
        panel.contentView = background

        icon.frame = NSRect(x: 0, y: 62, width: size, height: 90)
        icon.alignment = .center
        icon.isBordered = false
        icon.drawsBackground = false
        icon.isEditable = false
        background.addSubview(icon)

        imageView.frame = NSRect(x: (size - 80) / 2, y: 66, width: 80, height: 80)
        imageView.symbolConfiguration = .init(pointSize: 60, weight: .medium)
        imageView.contentTintColor = .labelColor
        background.addSubview(imageView)

        caption.frame = NSRect(x: 0, y: 24, width: size, height: 22)
        caption.alignment = .center
        caption.font = .systemFont(ofSize: 15, weight: .semibold)
        caption.textColor = .secondaryLabelColor
        background.addSubview(caption)
        return panel
    }()
    private let icon = NSTextField(labelWithString: "")
    private let imageView = NSImageView()
    private let caption = NSTextField(labelWithString: "")
    private var hideWork: DispatchWorkItem?

    func show(functionKeys: Bool) {
        _ = panel // build views
        if functionKeys {
            icon.attributedStringValue = NSAttributedString(string: "fn", attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 64, weight: .bold),
                .foregroundColor: NSColor.labelColor,
            ])
            // Text fields draw from the top of their frame, so size to fit and center on the icon area.
            icon.sizeToFit()
            icon.setFrameOrigin(NSPoint(x: (size - icon.frame.width) / 2,
                                        y: imageView.frame.midY - icon.frame.height / 2))
            imageView.image = nil
            caption.stringValue = "Function Keys"
        } else {
            icon.stringValue = ""
            imageView.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Media keys")
            caption.stringValue = "Media Keys"
        }

        // Lower middle of the screen the mouse is on, where macOS shows its own HUDs.
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - size / 2, y: frame.minY + frame.height * 0.2))
        }

        hideWork?.cancel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak self] in
            guard let panel = self?.panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                panel.animator().alphaValue = 0
            }, completionHandler: { if panel.alphaValue == 0 { panel.orderOut(nil) } })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var last: Bool??
    private var shortcut = Shortcut.load()
    private lazy var hotKey = HotKey { [weak self] in self?.toggle() }
    private let hud = ChangeHUD()

    func applicationDidFinishLaunching(_ note: Notification) {
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        hotKey.register(shortcut)
        refresh()
        // Cheap registry read; catches changes made by BTT, System Settings, etc.
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        let state = FnMode.isFunctionKeys()
        guard state != last else { return }
        // Show the HUD for real changes only, not for the initial read at launch.
        if case .some(.some) = last, let state, ChangeHUD.isEnabled {
            hud.show(functionKeys: state)
        }
        last = state
        guard let button = item.button else { return }
        switch state {
        case .some(true):
            button.image = nil
            button.attributedTitle = NSAttributedString(string: "fn",
                attributes: [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)])
            button.toolTip = "F1–F12 are function keys (click to switch to media keys)"
        case .some(false):
            button.title = ""
            let img = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "Media keys")
            img?.isTemplate = true
            button.image = img
            button.toolTip = "F1–F12 are media keys (click to switch to function keys)"
        case .none:
            button.image = nil
            button.title = "fn?"
            button.toolTip = "Could not read fn key mode"
        }
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Toggle fn mode", action: #selector(toggle), keyEquivalent: "").target = self
            menu.addItem(.separator())
            let current = NSMenuItem(title: "Shortcut: \(shortcut?.display ?? "none")", action: nil, keyEquivalent: "")
            current.isEnabled = false
            menu.addItem(current)
            menu.addItem(withTitle: "Record Shortcut…", action: #selector(recordShortcut), keyEquivalent: "").target = self
            menu.addItem(.separator())
            let login = NSMenuItem(title: "Start at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            login.target = self
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(login)
            let hudItem = NSMenuItem(title: "Show HUD on Change", action: #selector(toggleHUD), keyEquivalent: "")
            hudItem.target = self
            hudItem.state = ChangeHUD.isEnabled ? .on : .off
            menu.addItem(hudItem)
            menu.addItem(withTitle: "About FnLockBar", action: #selector(showAbout), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Quit FnLockBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
        } else {
            toggle()
        }
    }

    @objc private func toggleHUD() {
        ChangeHUD.isEnabled.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change Start at Login"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func showAbout() {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style,
        ]
        func link(_ title: String, _ url: String) -> NSAttributedString {
            var attrs = base
            attrs[.link] = URL(string: url)!
            return NSAttributedString(string: title, attributes: attrs)
        }
        let credits = NSMutableAttributedString(string: "made with ❤️ by ", attributes: base)
        credits.append(link("wust", "https://wust.dev"))
        credits.append(NSAttributedString(string: "\n\n", attributes: base))
        credits.append(link("GitHub", "https://github.com/TobiasWust/FnLockBar"))
        credits.append(NSAttributedString(string: "  ·  ", attributes: base))
        credits.append(link("☕ Support on Ko-fi", "https://ko-fi.com/tobiaswust"))

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "FnLockBar",
            .credits: credits,
        ])
    }

    @objc private func recordShortcut() {
        hotKey.unregister() // so pressing the old shortcut while recording doesn't toggle

        let alert = NSAlert()
        alert.messageText = "Press the new shortcut"
        alert.informativeText = "Use at least one modifier (⌃⌥⇧⌘), or an F-key on its own.\nCurrent: \(shortcut?.display ?? "none")"
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Remove Shortcut")

        var recorded: Shortcut?
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let s = Shortcut(event: event) else { return event } // plain Esc still cancels
            recorded = s
            NSApp.stopModal(withCode: .OK)
            return nil
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if let monitor { NSEvent.removeMonitor(monitor) }

        switch response {
        case .OK: shortcut = recorded
        case .alertSecondButtonReturn: shortcut = nil
        default: break
        }
        Shortcut.save(shortcut)

        if !hotKey.register(shortcut), let taken = shortcut {
            let warn = NSAlert()
            warn.messageText = "\(taken.display) is already in use"
            warn.informativeText = "Another app has registered this shortcut. Try a different one."
            warn.runModal()
        }
    }

    @objc private func toggle() {
        guard let current = FnMode.isFunctionKeys() else { return }
        _ = FnMode.set(functionKeys: !current)
        refresh()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
