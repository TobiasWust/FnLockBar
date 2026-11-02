# FnLockBar

A tiny macOS menu bar app that shows whether your F1–F12 keys are currently **function keys** or **media keys** — lets you flip between them with a click or a global shortcut — and can switch automatically per app (real F-keys in your IDE, media keys everywhere else).

![FnLockBar demo: pressing ⌃esc toggles the mode and a HUD shows the new state; then switching apps with ⌘tab flips to function keys in Code and back to media keys in Music](media/demo.gif)

| Menu bar | Meaning |
| --- | --- |
| **`fn`** | F1–F12 act as standard function keys ("fn lock" on) |
| 🔊 | F1–F12 act as media keys (brightness, volume, …) |

No more guessing which mode you're in.

## Features

- **Live indicator** – always reflects the real state, no matter what changed it (FnLockBar, System Settings, BetterTouchTool, …).
- **Click to toggle** – left-click the icon to switch modes.
- **Global shortcut** – record any shortcut (e.g. `⌃⎋`) to toggle from anywhere. No Accessibility permission required.
- **Per-app modes** – give apps a fixed mode (e.g. VS Code, Xcode and games → function keys) and FnLockBar switches automatically when they come to the front.
- **Change HUD** – a system-style overlay briefly shows the new mode whenever it changes (can be turned off).
- **Start at Login** – one switch in Settings.
- **Update check** – tells you in the menu when a new release is out (or check manually in *Settings → General*).
- Native Swift / AppKit, no dependencies, near-zero CPU.

**Left-click** the icon to toggle. **Right-click** for the menu – it's deliberately short:

```
For “Safari” ▸        rule for the app you were just using
Settings…       ⌘,    shortcut, login, HUD, updates, app rules
About FnLockBar
Quit FnLockBar  ⌘Q
```

When a new version is out, an *Update available* item appears at the top.

## Per-app modes

- **For “App” ▸** in the menu – sets a rule for the app you were just using: *Function Keys*, *Media Keys* or *No Rule*.
- **Settings → App Rules** – lists all rules; **+** adds apps from `/Applications`, **−** removes the selected rule. It also sets what happens in **apps without a rule** (*Keep Current Mode* by default, *Media Keys* or *Function Keys*) and has the on/off switch for per-app modes, which keeps your rules when off.
- **Settings → General → HUD** – *Also when switching apps automatically* shows the HUD for automatic switches too (off by default, so app switching stays quiet).

A manual toggle (click, shortcut, BTT, …) inside an app with a rule lasts until you switch apps – when you come back, the rule applies again. Rules are stored by bundle identifier, so renaming or moving an app doesn't break them.

## Good to know

- **External keyboards:** the fn setting is a macOS preference that Apple keyboards follow. Many third-party keyboards (Logitech, Keychron, …) handle the F-row in their own firmware or companion app and ignore it – FnLockBar will still show and switch the macOS setting, but those keys may not change. Check your keyboard's own fn lock (often `fn` + `Esc`) or its software.
- **Update check:** once at launch and then once a day, FnLockBar asks the public GitHub API for the latest release. Nothing about you or your Mac is sent, and nothing is installed automatically – you get a menu item linking to the download.

## Install

Requires macOS 13+ (Apple Silicon or Intel).

### Download

1. Grab **FnLockBar.zip** from the [latest release](https://github.com/TobiasWust/FnLockBar/releases/latest).
2. Unzip it and move **FnLockBar.app** to `/Applications` (or `~/Applications`).
3. Open it.

FnLockBar isn't notarized by Apple, so the first launch is blocked by Gatekeeper. Either go to **System Settings → Privacy & Security** and click **Open Anyway**, or remove the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/FnLockBar.app
```

### Build from source

Needs the Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh
```

```bash
open ~/Applications/FnLockBar.app
```

`build.sh` compiles everything in `Sources/` for arm64 and x86_64, wraps it in an ad-hoc signed `.app` bundle and installs it to `~/Applications`. Re-run it after changing the code (quit the running app first).

The pure logic (rule resolution, settings persistence, version comparison) has a small test suite:

```bash
Tests/run.sh
```

### Releasing

Push a version tag and GitHub Actions builds the app and attaches `FnLockBar.zip` to a new release:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

## Recording a shortcut

1. Right-click the menu bar icon → **Settings…** → **General** → **Record…**
2. Press the combination you want. It needs at least one modifier (⌃⌥⇧⌘), or can be a bare F-key.
3. Plain `Esc` cancels, **Remove Shortcut** clears it.

The shortcut is stored in `UserDefaults` (`de.tobiaswust.FnLockBar`) and survives restarts. If another app already owns the combination, FnLockBar tells you.

## How it works

macOS keeps the fn mode in two places:

- `com.apple.keyboard.fnState` in the global defaults – what System Settings shows.
- `HIDFKeyMode` in the IOKit `IOHIDSystem` parameters – what the keyboard driver actually uses.

Tools like BetterTouchTool only change the IOKit parameter, so the defaults value goes stale. FnLockBar therefore **reads `HIDFKeyMode`** (polled every 0.5 s – a cheap registry read) and, when toggling, writes **both**: the IOKit parameter via `IOHIDSetParameter` and the defaults key, so System Settings stays in sync.

You can check the live value yourself:

```bash
ioreg -c IOHIDSystem -r -d1 -k HIDParameters | grep -o '"HIDFKeyMode"=[0-9]'
```

The global shortcut uses Carbon's `RegisterEventHotKey`, and *Start at Login* uses `SMAppService.mainApp`. Per-app modes listen for `NSWorkspace.didActivateApplicationNotification` (no polling), ignore FnLockBar's own windows and debounce fast ⌘-Tab cycling; the mode is only written when it actually changes.

## Coming from BetterTouchTool?

FnLockBar can fully replace a BTT "Set Function Key Mode" trigger. If you keep both bound to the same shortcut, BTT will usually swallow the keys first (or both toggle and cancel each other out) – disable the BTT trigger or use a different combination.

---

made with ❤️ by [wust](https://wust.dev) · if FnLockBar saves you some guessing, [buy me a coffee on Ko-fi ☕](https://ko-fi.com/tobiaswust)
