# FnLockBar

A tiny macOS menu bar app that shows whether your F1–F12 keys are currently **function keys** or **media keys** — and lets you flip between them with a click or a global shortcut.

| Menu bar | Meaning |
| --- | --- |
| **`fn`** | F1–F12 act as standard function keys ("fn lock" on) |
| 🔊 | F1–F12 act as media keys (brightness, volume, …) |

No more guessing which mode you're in.

## Features

- **Live indicator** – always reflects the real state, no matter what changed it (FnLockBar, System Settings, BetterTouchTool, …).
- **Click to toggle** – left-click the icon to switch modes.
- **Global shortcut** – record any shortcut (e.g. `⌃⎋`) to toggle from anywhere. No Accessibility permission required.
- **Start at Login** – one checkbox in the menu.
- Native Swift / AppKit, a single source file, no dependencies, near-zero CPU.

Right-click the icon for the menu: *Toggle fn mode*, *Record Shortcut…*, *Start at Login*, *About*, *Quit*.

## Install

Requires macOS 13+ and the Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh
```

```bash
open ~/Applications/FnLockBar.app
```

`build.sh` compiles `main.swift`, wraps it in an ad-hoc signed `.app` bundle and installs it to `~/Applications`. Re-run it after changing the code (quit the running app first).

## Recording a shortcut

1. Right-click the menu bar icon → **Record Shortcut…**
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

The global shortcut uses Carbon's `RegisterEventHotKey`, and *Start at Login* uses `SMAppService.mainApp`.

## Coming from BetterTouchTool?

FnLockBar can fully replace a BTT "Set Function Key Mode" trigger. If you keep both bound to the same shortcut, BTT will usually swallow the keys first (or both toggle and cancel each other out) – disable the BTT trigger or use a different combination.

---

made with ❤️ by [wust](https://wust.dev)
