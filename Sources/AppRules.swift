import Combine
import Foundation

enum KeyMode: String, CaseIterable {
    case function, media

    var isFunctionKeys: Bool { self == .function }
    var title: String { self == .function ? "Function Keys" : "Media Keys" }
}

/// What to do when an app without a rule becomes active.
enum OtherAppsPolicy: String, CaseIterable {
    case keep, media, function

    var mode: KeyMode? {
        switch self {
        case .keep: nil
        case .media: .media
        case .function: .function
        }
    }

    var title: String {
        switch self {
        case .keep: "Keep Current Mode"
        case .media: "Media Keys"
        case .function: "Function Keys"
        }
    }
}

/// Per-app fn modes, keyed by bundle identifier (survives renaming/moving the app). Persisted in UserDefaults.
final class AppRules: ObservableObject {
    private let defaults: UserDefaults

    @Published var rules: [String: KeyMode] {
        didSet { defaults.set(rules.mapValues(\.rawValue), forKey: "appRules") }
    }
    @Published var other: OtherAppsPolicy {
        didSet { defaults.set(other.rawValue, forKey: "otherAppsPolicy") }
    }
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: "perAppEnabled") }
    }
    @Published var hudOnAutoSwitch: Bool {
        didSet { defaults.set(hudOnAutoSwitch, forKey: "hudOnAutoSwitch") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.dictionary(forKey: "appRules") as? [String: String] ?? [:]
        rules = stored.compactMapValues(KeyMode.init(rawValue:))
        other = defaults.string(forKey: "otherAppsPolicy").flatMap(OtherAppsPolicy.init(rawValue:)) ?? .keep
        isEnabled = defaults.object(forKey: "perAppEnabled") as? Bool ?? true
        hudOnAutoSwitch = defaults.bool(forKey: "hudOnAutoSwitch")
    }

    /// The mode to switch to when `bundleID` becomes active, or nil to leave the current mode alone.
    func mode(for bundleID: String?) -> KeyMode? {
        guard isEnabled, let bundleID else { return nil }
        return rules[bundleID] ?? other.mode
    }
}
