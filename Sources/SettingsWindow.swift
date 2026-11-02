import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// Settings that aren't app rules. Actions that need the app delegate (hotkey, update alert) are injected.
final class GeneralSettings: ObservableObject {
    @Published var shortcutDisplay: String?
    @Published var showHUD = ChangeHUD.isEnabled {
        didSet { ChangeHUD.isEnabled = showHUD }
    }
    @Published var hudStyle = ChangeHUD.style {
        didSet {
            ChangeHUD.style = hudStyle
            previewHUD(hudStyle)
        }
    }
    var previewHUD: (ChangeHUD.Style) -> Void = { _ in }
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    var recordShortcut: () -> Void = {}
    var checkForUpdates: () -> Void = {}

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change Start at Login"
            alert.runModal()
        }
        reload()
    }

    /// Picks up changes made elsewhere (e.g. login items removed in System Settings).
    func reload() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

struct GeneralView: View {
    @ObservedObject var settings: GeneralSettings
    @ObservedObject var rules: AppRules

    var body: some View {
        Form {
            Section {
                LabeledContent("Toggle shortcut") {
                    HStack {
                        Text(settings.shortcutDisplay ?? "None")
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(settings.shortcutDisplay == nil ? .secondary : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .quaternaryLabelColor)))
                        Button("Record…") { settings.recordShortcut() }
                    }
                }
                Toggle("Start at Login", isOn: Binding(get: { settings.launchAtLogin },
                                                       set: { settings.setLaunchAtLogin($0) }))
            } footer: {
                Text("Clicking the menu bar icon also toggles the mode.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("HUD") {
                Toggle("Show HUD when the mode changes", isOn: $settings.showHUD)
                Picker("Size", selection: $settings.hudStyle) {
                    ForEach(ChangeHUD.Style.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .disabled(!settings.showHUD)
                Toggle("Also when switching apps automatically", isOn: $rules.hudOnAutoSwitch)
                    .disabled(!settings.showHUD || !rules.isEnabled)
            }

            Section("Updates") {
                LabeledContent("FnLockBar \(UpdateChecker.currentVersion)") {
                    Button("Check for Updates…") { settings.checkForUpdates() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Name and icon for a bundle identifier, falling back to the identifier if the app isn't installed.
private struct AppInfo {
    let name: String
    let icon: NSImage

    init(bundleID: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            name = bundleID
            icon = NSImage(systemSymbolName: "questionmark.app", accessibilityDescription: nil) ?? NSImage()
        }
    }
}

/// Holds the list selection. (Not @State: that's a macro in current SDKs, which plain swiftc
/// with only the Command Line Tools can't expand.)
final class RulesSelection: ObservableObject {
    @Published var id: String?
}

struct RulesView: View {
    @ObservedObject var rules: AppRules
    @ObservedObject var selected: RulesSelection

    private var sortedIDs: [String] {
        rules.rules.keys.sorted {
            AppInfo(bundleID: $0).name.localizedCaseInsensitiveCompare(AppInfo(bundleID: $1).name) == .orderedAscending
        }
    }

    private func binding(for id: String) -> Binding<KeyMode> {
        Binding(get: { rules.rules[id] ?? .function }, set: { rules.rules[id] = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Switch fn mode automatically when the frontmost app changes", isOn: $rules.isEnabled)

            VStack(spacing: 0) {
                List(selection: $selected.id) {
                    ForEach(sortedIDs, id: \.self) { id in
                        let info = AppInfo(bundleID: id)
                        HStack {
                            Image(nsImage: info.icon).resizable().frame(width: 22, height: 22)
                            Text(info.name).lineLimit(1)
                            Spacer()
                            Picker("", selection: binding(for: id)) {
                                ForEach(KeyMode.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                        .padding(.vertical, 2)
                    }
                }
                .overlay {
                    if rules.rules.isEmpty {
                        Text("No app rules yet.\nClick + to add an app, or use “For …” in the menu bar item.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }

                Divider()
                HStack(spacing: 0) {
                    Button(action: addApps) { Image(systemName: "plus").frame(width: 24, height: 20) }
                        .help("Add apps")
                    Divider().frame(height: 16)
                    Button(action: removeSelected) { Image(systemName: "minus").frame(width: 24, height: 20) }
                        .disabled(selected.id == nil)
                        .help("Remove the selected rule")
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(4)
            }
            .frame(minHeight: 220)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
            .disabled(!rules.isEnabled)

            Picker("Apps without a rule:", selection: $rules.other) {
                ForEach(OtherAppsPolicy.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .fixedSize()
            .disabled(!rules.isEnabled)

            Text("A manual toggle inside an app lasts until you switch apps; the rule applies again when you come back.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private func addApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            // Most people add apps to get real F-keys there (IDEs, games, DAWs)
            if let id = Bundle(url: url)?.bundleIdentifier, rules.rules[id] == nil { rules.rules[id] = .function }
        }
    }

    private func removeSelected() {
        guard let id = selected.id else { return }
        rules.rules[id] = nil
        selected.id = nil
    }
}

struct SettingsView: View {
    @ObservedObject var settings: GeneralSettings
    @ObservedObject var rules: AppRules
    let selection: RulesSelection

    var body: some View {
        TabView {
            GeneralView(settings: settings, rules: rules)
                .tabItem { Label("General", systemImage: "gearshape") }
            RulesView(rules: rules, selected: selection)
                .tabItem { Label("App Rules", systemImage: "square.grid.2x2") }
        }
        .frame(width: 500, height: 440)
    }
}

final class SettingsWindowController: NSWindowController {
    convenience init(settings: GeneralSettings, rules: AppRules) {
        let root = SettingsView(settings: settings, rules: rules, selection: RulesSelection())
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.title = "FnLockBar Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }
}
