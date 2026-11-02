// Renders media/social.png (1280×640), the GitHub social preview shown when the repo link is shared.
// Usage: swiftc render-social.swift -o /tmp/r && /tmp/r   (run from media/, needs icon.png)

import AppKit

let W: CGFloat = 1280, H: CGFloat = 640
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Same wallpaper as the demo
NSGradient(colors: [NSColor(red: 0.10, green: 0.09, blue: 0.27, alpha: 1),
                    NSColor(red: 0.27, green: 0.16, blue: 0.45, alpha: 1),
                    NSColor(red: 0.07, green: 0.33, blue: 0.42, alpha: 1)])!
    .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -35)

// GitHub crops the edges in some places, so keep everything inside a ~40px safe margin
let icon = NSImage(contentsOfFile: "icon.png")!
icon.draw(in: NSRect(x: 90, y: (H - 400) / 2, width: 400, height: 400))

func text(_ s: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, y: CGFloat) {
    NSAttributedString(string: s, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(white: 1, alpha: alpha),
    ]).draw(at: NSPoint(x: 540, y: y))
}
text("FnLockBar", size: 92, weight: .bold, alpha: 1, y: 360)
text("Always know if F1–F12 are", size: 36, weight: .regular, alpha: 0.85, y: 300)
text("function or media keys.", size: 36, weight: .regular, alpha: 0.85, y: 254)
text("Menu bar indicator · shortcut · per-app modes", size: 26, weight: .medium, alpha: 0.65, y: 186)
text("Free & open source · macOS 13+", size: 26, weight: .medium, alpha: 0.65, y: 148)

NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "social.png"))
print("Wrote social.png")
