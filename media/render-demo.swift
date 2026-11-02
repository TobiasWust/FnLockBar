// Renders the frames of the README demo animation (a mockup of FnLockBar in use).
// Usage: swift render-demo.swift <output-dir>   — see make-demo.sh

import AppKit

let W: CGFloat = 960, H: CGFloat = 600
let fps = 30.0
let duration = 9.0
let toggles = [0.9, 2.9] // scene 1: seconds at which ⌃⎋ flips the mode
let sceneTwo = 4.6       // scene 2: per-app modes, switching apps with ⌘⇥
let switches: [(t: Double, app: String, fn: Bool)] = [(5.4, "Code", true), (7.4, "Music", false)]
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "frames"

func clamp(_ x: Double) -> Double { max(0, min(1, x)) }
func smooth(_ x: Double) -> Double { let c = clamp(x); return c * c * (3 - 2 * c) }

/// 0 → 1 over `fadeIn` starting at `start`, holds, then 1 → 0 over `fadeOut` ending at `end`.
func envelope(_ t: Double, start: Double, end: Double, fadeIn: Double, fadeOut: Double) -> Double {
    if t < start || t > end { return 0 }
    return min(smooth((t - start) / fadeIn), smooth((end - t) / fadeOut))
}

func symbol(_ name: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .white) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        .applying(.init(paletteColors: [color]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
}

func drawText(_ s: String, at p: NSPoint, font: NSFont, color: NSColor = .white, centeredIn width: CGFloat? = nil) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let str = NSAttributedString(string: s, attributes: attrs)
    var origin = p
    if let width { origin.x += (width - str.size().width) / 2 }
    str.draw(at: origin)
}

func drawCentered(_ img: NSImage, in rect: NSRect, alpha: CGFloat = 1) {
    let r = NSRect(x: rect.midX - img.size.width / 2, y: rect.midY - img.size.height / 2,
                   width: img.size.width, height: img.size.height)
    img.draw(in: r, from: .zero, operation: .sourceOver, fraction: alpha)
}

func render(t: Double) {
    let lastSwitch = switches.last { t >= $0.t }
    let fnMode = lastSwitch?.fn ?? (toggles.filter { t >= $0 }.count % 2 == 1)
    let frontApp = lastSwitch?.app ?? "Finder"

    // Wallpaper
    NSGradient(colors: [NSColor(red: 0.10, green: 0.09, blue: 0.27, alpha: 1),
                        NSColor(red: 0.27, green: 0.16, blue: 0.45, alpha: 1),
                        NSColor(red: 0.07, green: 0.33, blue: 0.42, alpha: 1)])!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -35)

    // Menu bar
    let barH: CGFloat = 34
    NSColor(white: 0, alpha: 0.35).setFill()
    NSRect(x: 0, y: H - barH, width: W, height: barH).fill()
    let barY = H - barH + 8
    var x: CGFloat = 22
    for (i, title) in [frontApp, "File", "Edit", "View", "Go", "Window", "Help"].enumerated() {
        let font = NSFont.systemFont(ofSize: 15, weight: i == 0 ? .bold : .regular)
        drawText(title, at: NSPoint(x: x, y: barY), font: font)
        x += NSAttributedString(string: title, attributes: [.font: font]).size().width + 20
    }

    // Right side, laid out from the right edge
    var right = W - 18
    let clock = "Mon 2 Nov  19:24"
    let clockFont = NSFont.systemFont(ofSize: 15, weight: .regular)
    right -= NSAttributedString(string: clock, attributes: [.font: clockFont]).size().width
    drawText(clock, at: NSPoint(x: right, y: barY), font: clockFont)
    for name in ["switch.2", "magnifyingglass", "wifi", "battery.75percent"] {
        guard let img = symbol(name, size: 15) else { continue }
        right -= img.size.width + 18
        drawCentered(img, in: NSRect(x: right, y: H - barH, width: img.size.width, height: barH))
    }

    // FnLockBar's status item, with a soft pulse when it changes
    let itemW: CGFloat = 34
    right -= itemW + 14
    let itemRect = NSRect(x: right, y: H - barH + 4, width: itemW, height: barH - 8)
    let pulse = (toggles + switches.map(\.t))
        .map { envelope(t, start: $0, end: $0 + 0.9, fadeIn: 0.08, fadeOut: 0.5) }.max() ?? 0
    if pulse > 0 {
        NSColor(white: 1, alpha: 0.28 * pulse).setFill()
        NSBezierPath(roundedRect: itemRect, xRadius: 6, yRadius: 6).fill()
    }
    if fnMode {
        drawText("fn", at: NSPoint(x: itemRect.minX, y: barY - 1),
                 font: .monospacedSystemFont(ofSize: 16, weight: .bold), centeredIn: itemW)
    } else if let img = symbol("speaker.wave.2", size: 15) {
        drawCentered(img, in: itemRect)
    }

    // Change HUD
    // Toggles show it right away; app switches after the switcher pill fades ("Also on Automatic Switch")
    let huds = toggles.enumerated().map { ($0.element, $0.offset % 2 == 0) } + switches.map { ($0.t + 0.45, $0.fn) }
    for (start, showsFn) in huds {
        let a = envelope(t, start: start, end: start + 1.2, fadeIn: 0.06, fadeOut: 0.3)
        guard a > 0 else { continue }
        let size: CGFloat = 200
        let hud = NSRect(x: (W - size) / 2, y: H * 0.24, width: size, height: size)
        NSColor(white: 0.1, alpha: 0.78 * a).setFill()
        NSBezierPath(roundedRect: hud, xRadius: 24, yRadius: 24).fill()
        NSColor(white: 1, alpha: 0.1 * a).setStroke()
        NSBezierPath(roundedRect: hud.insetBy(dx: 0.5, dy: 0.5), xRadius: 24, yRadius: 24).stroke()

        let iconArea = NSRect(x: hud.minX, y: hud.minY + 64, width: size, height: 110)
        if showsFn {
            let font = NSFont.monospacedSystemFont(ofSize: 76, weight: .bold)
            let s = NSAttributedString(string: "fn", attributes: [.font: font, .foregroundColor: NSColor(white: 1, alpha: a)])
            let sz = s.size()
            s.draw(at: NSPoint(x: iconArea.midX - sz.width / 2, y: iconArea.midY - sz.height / 2))
        } else if let img = symbol("speaker.wave.2.fill", size: 68, weight: .medium) {
            drawCentered(img, in: iconArea, alpha: a)
        }
        drawText(showsFn ? "Function Keys" : "Media Keys", at: NSPoint(x: hud.minX, y: hud.minY + 30),
                 font: .systemFont(ofSize: 17, weight: .semibold), color: NSColor(white: 1, alpha: 0.7 * a),
                 centeredIn: size)
    }

    // App switcher pill (scene 2), like ⌘⇥
    for s in switches {
        let a = envelope(t, start: s.t - 0.25, end: s.t + 0.45, fadeIn: 0.1, fadeOut: 0.2)
        guard a > 0 else { continue }
        let pill = NSRect(x: (W - 280) / 2, y: H * 0.42, width: 280, height: 96)
        NSColor(white: 0.1, alpha: 0.78 * a).setFill()
        NSBezierPath(roundedRect: pill, xRadius: 22, yRadius: 22).fill()
        if let img = symbol("macwindow", size: 40, weight: .medium, color: NSColor(white: 1, alpha: a)) {
            drawCentered(img, in: NSRect(x: pill.minX + 24, y: pill.minY, width: 60, height: pill.height))
        }
        drawText(s.app, at: NSPoint(x: pill.minX + 98, y: pill.midY - 16),
                 font: .systemFont(ofSize: 26, weight: .semibold), color: NSColor(white: 1, alpha: a))
    }

    // Keystroke overlay (⌃ esc for toggles, ⌘ tab for app switches), bottom right
    let presses = toggles.map { ($0, [("⌃", "control"), ("esc", "")]) } // "⎋" renders like a reload arrow
        + switches.map { ($0.t, [("⌘", "command"), ("tab", "")]) }
    for (start, keys) in presses {
        let a = envelope(t, start: start - 0.3, end: start + 0.7, fadeIn: 0.12, fadeOut: 0.2)
        guard a > 0 else { continue }
        let pressed = t >= start - 0.06 && t <= start + 0.14
        let keyW: CGFloat = 78, keyH: CGFloat = 70, gap: CGFloat = 12
        var kx = W - 32 - CGFloat(keys.count) * keyW - CGFloat(keys.count - 1) * gap
        let ky: CGFloat = 32 - (pressed ? 3 : 0)
        for (glyph, label) in keys {
            let r = NSRect(x: kx, y: ky, width: keyW, height: keyH)
            NSColor(white: pressed ? 0.82 : 0.96, alpha: a).setFill()
            NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12).fill()
            let ink = NSColor(white: 0.15, alpha: a)
            drawText(glyph, at: NSPoint(x: r.minX, y: r.minY + (label.isEmpty ? 20 : 30)),
                     font: .systemFont(ofSize: label.isEmpty ? 20 : 24, weight: .medium), color: ink, centeredIn: keyW)
            drawText(label, at: NSPoint(x: r.minX, y: r.minY + 10), font: .systemFont(ofSize: 12, weight: .medium),
                     color: ink, centeredIn: keyW)
            kx += keyW + gap
        }
    }

    // Title
    drawText("FnLockBar", at: NSPoint(x: 36, y: 64), font: .systemFont(ofSize: 30, weight: .bold))
    // Subtitle crossfades between the two scenes (and back before the loop restarts)
    let two = min(smooth((t - sceneTwo) / 0.3), smooth((duration - 0.05 - t) / 0.3))
    let subtitleFont = NSFont.systemFont(ofSize: 16, weight: .regular)
    drawText("Always know if F1–F12 are function or media keys.", at: NSPoint(x: 36, y: 36),
             font: subtitleFont, color: NSColor(white: 1, alpha: 0.75 * (1 - two)))
    drawText("Per-app modes: real F-keys in Code, media keys in Music.", at: NSPoint(x: 36, y: 36),
             font: subtitleFont, color: NSColor(white: 1, alpha: 0.75 * two))
}

try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let frameCount = Int(duration * fps)
for i in 0..<frameCount {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    render(t: Double(i) / fps)
    NSGraphicsContext.restoreGraphicsState()
    let path = String(format: "%@/frame_%04d.png", outDir, i)
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
print("Rendered \(frameCount) frames to \(outDir)")
