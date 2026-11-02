import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var last: Bool??
    private var shortcut = Shortcut.load()
    private lazy var hotKey = HotKey { [weak self] in self?.toggle() }
    private let hud = ChangeHUD()
    private let updates = UpdateChecker()
    private let rules = AppRules()
    private lazy var watcher = AppSwitchWatcher { [weak self] app in self?.applyRule(for: app) }
    private var rulesChanged: AnyCancellable?
    private let general = GeneralSettings()
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ note: Notification) {
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        hotKey.register(shortcut)
        refresh()

        general.shortcutDisplay = shortcut?.display
        general.recordShortcut = { [weak self] in self?.recordShortcut() }
        general.checkForUpdates = { [weak self] in self?.checkForUpdates() }

        // Per-app modes: apply to the app that's in front now, then on every switch.
        if let app = watcher.current { applyRule(for: app) }
        // objectWillChange fires before the new value is stored, so apply on the next run loop turn.
        rulesChanged = rules.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { if let app = self?.watcher.current { self?.applyRule(for: app) } }
        }

        // Cheap registry read; catches changes made by BTT, System Settings, etc.
        let poll = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
        poll.tolerance = 0.25 // lets macOS coalesce wake-ups with other timers

        updates.check()
        let daily = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.updates.check()
        }
        daily.tolerance = 60 * 60
    }

    /// Switches to the app's rule (or the "other apps" policy). Manual toggles stay until the next app switch.
    private func applyRule(for app: NSRunningApplication) {
        guard let mode = rules.mode(for: app.bundleIdentifier),
              let current = FnMode.isFunctionKeys(), current != mode.isFunctionKeys else { return }
        _ = FnMode.set(functionKeys: mode.isFunctionKeys)
        refresh(showHUD: ChangeHUD.isEnabled && rules.hudOnAutoSwitch)
    }

    private func refresh(showHUD: Bool = ChangeHUD.isEnabled) {
        let state = FnMode.isFunctionKeys()
        guard state != last else { return }
        // Show the HUD for real changes only, not for the initial read at launch.
        if case .some(.some) = last, let state, showHUD {
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
            button.setAccessibilityLabel("FnLockBar: function keys")
        case .some(false):
            button.title = ""
            let img = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "Media keys")
            img?.isTemplate = true
            button.image = img
            button.toolTip = "F1–F12 are media keys (click to switch to function keys)"
            button.setAccessibilityLabel("FnLockBar: media keys")
        case .none:
            button.image = nil
            button.title = "fn?"
            button.toolTip = "Could not read fn key mode"
            button.setAccessibilityLabel("FnLockBar: fn key mode unknown")
        }
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            if let release = updates.available {
                let update = NSMenuItem(title: "Update available: \(release.tag_name)…",
                                        action: #selector(openUpdate), keyEquivalent: "")
                update.target = self
                update.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
                menu.addItem(update)
                menu.addItem(.separator())
            }
            // Left-click toggles; everything set-once lives in Settings.
            if addRuleItem(to: menu) { menu.addItem(.separator()) }
            menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
            menu.addItem(withTitle: "About FnLockBar", action: #selector(showAbout), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Quit FnLockBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
        } else {
            toggle()
        }
    }

    // MARK: Per-app modes

    /// "For “Safari” ▸" — a rule for the app you were using when you opened the menu.
    /// Returns false when there's nothing to show (per-app modes off, or no app known yet).
    private func addRuleItem(to menu: NSMenu) -> Bool {
        guard rules.isEnabled, let app = watcher.current, let id = app.bundleIdentifier else { return false }
        func choice(_ title: String, _ value: String, on: Bool) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(setRuleForCurrentApp(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = on ? .on : .off
            return item
        }

        let rule = rules.rules[id]
        let sub = NSMenu()
        for mode in KeyMode.allCases { sub.addItem(choice(mode.title, mode.rawValue, on: rule == mode)) }
        sub.addItem(.separator())
        sub.addItem(choice("No Rule", "", on: rule == nil))

        let forApp = NSMenuItem(title: "For “\(app.localizedName ?? id)”", action: nil, keyEquivalent: "")
        forApp.image = app.icon.map { icon in
            let small = icon.copy() as! NSImage
            small.size = NSSize(width: 16, height: 16)
            return small
        }
        forApp.submenu = sub
        menu.addItem(forApp)
        return true
    }

    @objc private func setRuleForCurrentApp(_ sender: NSMenuItem) {
        guard let id = watcher.current?.bundleIdentifier, let raw = sender.representedObject as? String else { return }
        rules.rules[id] = KeyMode(rawValue: raw) // "" → nil removes the rule
    }

    @objc private func showSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController(settings: general, rules: rules) }
        general.reload()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.showWindow(nil)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openUpdate() {
        if let release = updates.available { NSWorkspace.shared.open(release.html_url) }
    }

    private func checkForUpdates() {
        updates.check { result in
            let alert = NSAlert()
            switch result {
            case .success(let release?):
                alert.messageText = "FnLockBar \(release.tag_name) is available"
                alert.informativeText = "You have \(UpdateChecker.currentVersion). Download the new version from GitHub, then replace the app."
                alert.addButton(withTitle: "Open Download Page")
                alert.addButton(withTitle: "Later")
            case .success(nil):
                alert.messageText = "You're up to date"
                alert.informativeText = "FnLockBar \(UpdateChecker.currentVersion) is the latest version."
            case .failure(let error):
                alert.messageText = "Couldn't check for updates"
                alert.informativeText = error.localizedDescription
            }
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn, case .success(let release?) = result {
                NSWorkspace.shared.open(release.html_url)
            }
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

    private func recordShortcut() {
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
        general.shortcutDisplay = shortcut?.display

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
