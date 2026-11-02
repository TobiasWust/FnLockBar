// Renders media/app-rules.png: the real App Rules view with example rules, framed as a macOS window.
// Compiled together with Sources/ (minus main.swift) by make-screenshot.sh.

import AppKit
import SwiftUI

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "app-rules.png"
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Example rules in a throwaway defaults suite, so the real settings are untouched
let suite = "FnLockBarScreenshot-\(UUID().uuidString)"
let rules = AppRules(defaults: UserDefaults(suiteName: suite)!)
rules.rules = [
    "com.microsoft.VSCode": .function,
    "org.godotengine.godot": .function,
    "com.valvesoftware.steam": .function,
    "com.googlecode.iterm2": .function,
    "com.apple.Music": .media,
]
defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

// 1. Render the view (at the screen's backing scale, i.e. 2× on Retina)
let content = NSSize(width: 500, height: 400)
let host = NSHostingView(rootView: RulesView(rules: rules, selected: RulesSelection())
    .frame(width: content.width, height: content.height))
host.frame = NSRect(origin: .zero, size: content)
let win = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
win.appearance = NSAppearance(named: .aqua)
win.contentView = host
win.orderFrontRegardless()
RunLoop.main.run(until: Date().addingTimeInterval(1.0))
let viewRep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
host.cacheDisplay(in: host.bounds, to: viewRep)
win.orderOut(nil)
let viewImage = NSImage(size: content)
viewImage.addRepresentation(viewRep)

// 2. Compose: gradient backdrop, window with shadow, title bar with traffic lights
let titleBar: CGFloat = 32, margin: CGFloat = 56, radius: CGFloat = 12
let windowSize = NSSize(width: content.width, height: content.height + titleBar)
let canvas = NSSize(width: windowSize.width + margin * 2, height: windowSize.height + margin * 2)
let scale: CGFloat = 2
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width * scale),
                           pixelsHigh: Int(canvas.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = canvas // draw in points, store at 2×
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSGradient(colors: [NSColor(red: 0.10, green: 0.09, blue: 0.27, alpha: 1),
                    NSColor(red: 0.27, green: 0.16, blue: 0.45, alpha: 1),
                    NSColor(red: 0.07, green: 0.33, blue: 0.42, alpha: 1)])!
    .draw(in: NSRect(origin: .zero, size: canvas), angle: -35)

let frame = NSRect(x: margin, y: margin, width: windowSize.width, height: windowSize.height)
let windowPath = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor(white: 0, alpha: 0.45)
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.shadowBlurRadius = 34
shadow.set()
// Fixed light-mode window color: the view is rendered in light mode, whatever the Mac is set to
NSColor(white: 0.925, alpha: 1).setFill()
windowPath.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
windowPath.addClip()
NSColor(white: 0.965, alpha: 1).setFill()
NSRect(x: frame.minX, y: frame.maxY - titleBar, width: frame.width, height: titleBar).fill()
viewImage.draw(in: NSRect(x: frame.minX, y: frame.minY, width: content.width, height: content.height))
NSGraphicsContext.restoreGraphicsState()

NSColor(white: 0, alpha: 0.12).setStroke()
windowPath.lineWidth = 1
windowPath.stroke()

for (i, color) in [NSColor(red: 1, green: 0.37, blue: 0.34, alpha: 1),
                   NSColor(red: 1, green: 0.74, blue: 0.18, alpha: 1),
                   NSColor(red: 0.16, green: 0.79, blue: 0.25, alpha: 1)].enumerated() {
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: frame.minX + 14 + CGFloat(i) * 20, y: frame.maxY - titleBar / 2 - 6,
                                width: 12, height: 12)).fill()
}
let title = NSAttributedString(string: "FnLockBar – App Rules", attributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
    .foregroundColor: NSColor(white: 0.25, alpha: 1),
])
title.draw(at: NSPoint(x: frame.midX - title.size().width / 2, y: frame.maxY - titleBar / 2 - title.size().height / 2))

NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
