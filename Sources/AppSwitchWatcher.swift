import AppKit

/// Reports when another app becomes frontmost. Event-driven (no polling); ignores FnLockBar's own windows
/// and apps without a bundle identifier, and debounces rapid ⌘-Tab cycling.
final class AppSwitchWatcher {
    /// The last frontmost app other than FnLockBar — what "this app" means in the menu.
    private(set) var current: NSRunningApplication?
    private var pending: DispatchWorkItem?
    private var observer: NSObjectProtocol?

    init(onSwitch: @escaping (NSRunningApplication) -> Void) {
        current = Self.external(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = Self.external(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
            else { return }
            current = app
            pending?.cancel()
            let work = DispatchWorkItem { onSwitch(app) }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
    }

    deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    private static func external(_ app: NSRunningApplication?) -> NSRunningApplication? {
        guard let app, let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return nil }
        return app
    }
}
