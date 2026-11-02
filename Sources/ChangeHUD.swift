import AppKit

/// A system-style overlay that briefly shows the new mode, like the volume/brightness HUD.
final class ChangeHUD {
    static let defaultsKey = "showHUD"
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    private let size: CGFloat = 180
    private lazy var panel: NSPanel = {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let background = NSVisualEffectView(frame: panel.contentRect(forFrameRect: panel.frame))
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 22
        background.layer?.masksToBounds = true
        panel.contentView = background

        icon.frame = NSRect(x: 0, y: 62, width: size, height: 90)
        icon.alignment = .center
        icon.isBordered = false
        icon.drawsBackground = false
        icon.isEditable = false
        background.addSubview(icon)

        imageView.frame = NSRect(x: (size - 80) / 2, y: 66, width: 80, height: 80)
        imageView.symbolConfiguration = .init(pointSize: 60, weight: .medium)
        imageView.contentTintColor = .labelColor
        background.addSubview(imageView)

        caption.frame = NSRect(x: 0, y: 24, width: size, height: 22)
        caption.alignment = .center
        caption.font = .systemFont(ofSize: 15, weight: .semibold)
        caption.textColor = .secondaryLabelColor
        background.addSubview(caption)
        return panel
    }()
    private let icon = NSTextField(labelWithString: "")
    private let imageView = NSImageView()
    private let caption = NSTextField(labelWithString: "")
    private var hideWork: DispatchWorkItem?

    func show(functionKeys: Bool) {
        _ = panel // build views
        if functionKeys {
            icon.attributedStringValue = NSAttributedString(string: "fn", attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 64, weight: .bold),
                .foregroundColor: NSColor.labelColor,
            ])
            // Text fields draw from the top of their frame, so size to fit and center on the icon area.
            icon.sizeToFit()
            icon.setFrameOrigin(NSPoint(x: (size - icon.frame.width) / 2,
                                        y: imageView.frame.midY - icon.frame.height / 2))
            imageView.image = nil
            caption.stringValue = "Function Keys"
        } else {
            icon.stringValue = ""
            imageView.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Media keys")
            caption.stringValue = "Media Keys"
        }

        // Lower middle of the screen the mouse is on, where macOS shows its own HUDs.
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - size / 2, y: frame.minY + frame.height * 0.2))
        }

        hideWork?.cancel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak self] in
            guard let panel = self?.panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                panel.animator().alphaValue = 0
            }, completionHandler: { if panel.alphaValue == 0 { panel.orderOut(nil) } })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }
}
