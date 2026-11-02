import AppKit

/// A system-style overlay that briefly shows the new mode, like the volume/brightness HUD.
final class ChangeHUD {
    enum Style: String, CaseIterable {
        case large, small

        var title: String { self == .large ? "Large" : "Small" }
    }

    static let defaultsKey = "showHUD"
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static var style: Style {
        get { UserDefaults.standard.string(forKey: "hudStyle").flatMap(Style.init(rawValue:)) ?? .large }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "hudStyle") }
    }

    private lazy var panel: NSPanel = {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 180, height: 180),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.masksToBounds = true
        background.autoresizingMask = [.width, .height]
        panel.contentView = background

        for label in [icon, caption] {
            label.isBordered = false
            label.drawsBackground = false
            label.isEditable = false
            background.addSubview(label)
        }
        imageView.contentTintColor = .labelColor
        background.addSubview(imageView)
        return panel
    }()
    private let background = NSVisualEffectView()
    private let icon = NSTextField(labelWithString: "")
    private let imageView = NSImageView()
    private let caption = NSTextField(labelWithString: "")
    private var hideWork: DispatchWorkItem?

    /// Lays out the HUD for a mode and returns its view, without showing anything (also used for screenshots).
    @discardableResult
    func prepare(functionKeys: Bool, style: Style = ChangeHUD.style) -> NSView {
        _ = panel // build views
        caption.stringValue = functionKeys ? "Function Keys" : "Media Keys"
        switch style {
        case .large: layoutLarge(functionKeys: functionKeys)
        case .small: layoutSmall(functionKeys: functionKeys)
        }
        return background
    }

    /// 180×180 square: big glyph above the caption.
    private func layoutLarge(functionKeys: Bool) {
        let size: CGFloat = 180
        panel.setContentSize(NSSize(width: size, height: size))
        background.layer?.cornerRadius = 22
        caption.font = .systemFont(ofSize: 15, weight: .semibold)
        caption.textColor = .secondaryLabelColor
        caption.alignment = .center
        caption.frame = NSRect(x: 0, y: 24, width: size, height: 22)

        let iconArea = NSRect(x: 0, y: 66, width: size, height: 80)
        if functionKeys {
            setFnIcon(pointSize: 64, centeredIn: iconArea)
        } else {
            setSpeakerIcon(pointSize: 60, in: NSRect(x: (size - 80) / 2, y: iconArea.minY, width: 80, height: 80))
        }
    }

    /// Compact pill: small glyph left of the caption, sized to fit.
    private func layoutSmall(functionKeys: Bool) {
        let height: CGFloat = 44, padding: CGFloat = 16, iconWidth: CGFloat = 26, gap: CGFloat = 8
        caption.font = .systemFont(ofSize: 14, weight: .semibold)
        caption.textColor = .labelColor
        caption.alignment = .left
        caption.sizeToFit()
        let width = padding + iconWidth + gap + ceil(caption.frame.width) + padding + 2
        panel.setContentSize(NSSize(width: width, height: height))
        background.layer?.cornerRadius = height / 2
        caption.setFrameOrigin(NSPoint(x: padding + iconWidth + gap, y: (height - caption.frame.height) / 2))

        let iconArea = NSRect(x: padding, y: 0, width: iconWidth, height: height)
        if functionKeys {
            setFnIcon(pointSize: 18, centeredIn: iconArea)
        } else {
            setSpeakerIcon(pointSize: 16, in: iconArea.insetBy(dx: 0, dy: 10))
        }
    }

    private func setFnIcon(pointSize: CGFloat, centeredIn area: NSRect) {
        imageView.image = nil
        icon.attributedStringValue = NSAttributedString(string: "fn", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: pointSize, weight: .bold),
            .foregroundColor: NSColor.labelColor,
        ])
        // Text fields draw from the top of their frame, so size to fit and center on the icon area.
        icon.sizeToFit()
        icon.setFrameOrigin(NSPoint(x: area.midX - icon.frame.width / 2, y: area.midY - icon.frame.height / 2))
    }

    private func setSpeakerIcon(pointSize: CGFloat, in frame: NSRect) {
        icon.stringValue = ""
        imageView.symbolConfiguration = .init(pointSize: pointSize, weight: .medium)
        imageView.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Media keys")
        imageView.frame = frame
    }

    func show(functionKeys: Bool, style: Style = ChangeHUD.style) {
        prepare(functionKeys: functionKeys, style: style)

        // Lower middle of the screen the mouse is on, where macOS shows its own HUDs.
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + frame.height * 0.2))
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
