// Plain assertion tests for the app's pure logic. Run with Tests/run.sh.

import Foundation

var failures = 0
func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if condition { print("ok   \(message)") } else { print("FAIL \(message) (line \(line))"); failures += 1 }
}

func freshDefaults() -> UserDefaults {
    let name = "FnLockBarTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

// MARK: AppRules

do {
    let rules = AppRules(defaults: freshDefaults())
    expect(rules.isEnabled && rules.other == .keep && !rules.hudOnAutoSwitch, "defaults: enabled, keep, no auto HUD")
    expect(rules.mode(for: "com.example.none") == nil, "no rule + keep → leave mode alone")

    rules.rules["com.microsoft.VSCode"] = .function
    rules.rules["com.spotify.client"] = .media
    expect(rules.mode(for: "com.microsoft.VSCode") == .function, "rule → function keys")
    expect(rules.mode(for: "com.spotify.client") == .media, "rule → media keys")
    expect(rules.mode(for: nil) == nil, "app without bundle id → nil")

    rules.other = .media
    expect(rules.mode(for: "com.example.none") == .media, "no rule + media policy → media")
    expect(rules.mode(for: "com.microsoft.VSCode") == .function, "rule wins over policy")

    rules.isEnabled = false
    expect(rules.mode(for: "com.microsoft.VSCode") == nil, "disabled → nil even with rule")
}

do {
    let defaults = freshDefaults()
    let a = AppRules(defaults: defaults)
    a.rules = ["com.apple.dt.Xcode": .function]
    a.other = .function
    a.isEnabled = false
    a.hudOnAutoSwitch = true
    let b = AppRules(defaults: defaults)
    expect(b.rules == ["com.apple.dt.Xcode": .function], "rules persist")
    expect(b.other == .function && !b.isEnabled && b.hudOnAutoSwitch, "settings persist")

    defaults.set(["com.bad": "nonsense", "com.good": "media"], forKey: "appRules")
    expect(AppRules(defaults: defaults).rules == ["com.good": .media], "unknown stored values are dropped")
}

// MARK: UpdateChecker

for (a, b, newer) in [("1.1.0", "1.0.0", true), ("1.10.0", "1.9.2", true), ("1.1", "1.1.0", false),
                      ("1.0.0", "1.1.0", false), ("2", "1.99", true)] {
    expect(UpdateChecker.isNewer(a, than: b) == newer, "isNewer(\(a), \(b)) == \(newer)")
}

print(failures == 0 ? "\nAll tests passed" : "\n\(failures) test(s) failed")
exit(failures == 0 ? 0 : 1)
