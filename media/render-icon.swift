// Renders the app icon: a white "fn" keycap on the purple gradient used in the demo.
// Usage: swift render-icon.swift <output.png>  (1024×1024) — see make-icon.sh

import AppKit

let S: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: 824×824 body centered on a 1024 canvas, ~185 corner radius
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

let shadow = NSShadow()
shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 24
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.black.setFill()
bodyPath.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
bodyPath.addClip()
NSGradient(colors: [NSColor(red: 0.16, green: 0.13, blue: 0.40, alpha: 1),
                    NSColor(red: 0.36, green: 0.20, blue: 0.58, alpha: 1),
                    NSColor(red: 0.10, green: 0.42, blue: 0.52, alpha: 1)])!
    .draw(in: body, angle: -45)
NSGraphicsContext.restoreGraphicsState()

// Keycap: a darker base with a lighter top, like a real key seen from slightly above
let cap = NSRect(x: 262, y: 270, width: 500, height: 500)
let capShadow = NSShadow()
capShadow.shadowColor = NSColor(white: 0, alpha: 0.4)
capShadow.shadowOffset = NSSize(width: 0, height: -18)
capShadow.shadowBlurRadius = 36
NSGraphicsContext.saveGraphicsState()
capShadow.set()
NSColor(white: 0.80, alpha: 1).setFill()
NSBezierPath(roundedRect: cap, xRadius: 96, yRadius: 96).fill()
NSGraphicsContext.restoreGraphicsState()

let top = NSRect(x: cap.minX + 22, y: cap.minY + 40, width: cap.width - 44, height: cap.height - 58)
NSGradient(starting: NSColor(white: 1, alpha: 1), ending: NSColor(white: 0.92, alpha: 1))!
    .draw(in: NSBezierPath(roundedRect: top, xRadius: 78, yRadius: 78), angle: -90)

let label = NSAttributedString(string: "fn", attributes: [
    .font: NSFont.monospacedSystemFont(ofSize: 250, weight: .bold),
    .foregroundColor: NSColor(red: 0.20, green: 0.15, blue: 0.42, alpha: 1),
])
let size = label.size()
label.draw(at: NSPoint(x: top.midX - size.width / 2, y: top.midY - size.height / 2 + 6))

NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
