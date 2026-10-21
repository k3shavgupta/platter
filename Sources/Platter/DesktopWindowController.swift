import AppKit
import SwiftUI

/// Manages one borderless, click-through window per screen, pinned just above the
/// desktop picture (below icons) so the turntable scene reads as part of the desktop
/// itself rather than a floating app window.
@MainActor
final class DesktopWindowController {
    private var windows: [NSWindow] = []
    private let poller: NowPlayingPoller
    private let settings: Settings
    private var screenObserver: NSObjectProtocol?

    /// The user's on/off choice, independent of window state. `isVisible` used to read
    /// this back off `windows.first?.isVisible` — which meant any screen-parameter change
    /// silently re-showed the scene after the user had turned it off, because
    /// rebuildWindows() always ended each fresh window with orderFront(nil), with nothing
    /// remembering "off" across the rebuild.
    private var desiredVisibility = true

    /// The screen layout rebuildWindows() last built for, so a screen-parameter
    /// notification that didn't actually change anything — Dock/menu-bar changes post
    /// this too, not just monitor changes — doesn't tear down and recreate every window.
    private var lastScreenFrames: [CGRect] = []

    init(poller: NowPlayingPoller, settings: Settings) {
        self.poller = poller
        self.settings = settings
        rebuildWindows()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuildWindowsIfScreensChanged()
            }
        }
    }

    var isVisible: Bool { desiredVisibility }

    func setVisible(_ visible: Bool) {
        desiredVisibility = visible
        windows.forEach { visible ? $0.orderFront(nil) : $0.orderOut(nil) }
    }

    private func rebuildWindowsIfScreensChanged() {
        let frames = NSScreen.screens.map(\.frame)
        guard frames != lastScreenFrames else { return }
        rebuildWindows()
    }

    private func rebuildWindows() {
        windows.forEach { $0.close() }
        lastScreenFrames = NSScreen.screens.map(\.frame)
        windows = NSScreen.screens.map { makeWindow(for: $0) }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        // One level above the desktop picture, below desktop icons.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        let hosting = NSHostingView(rootView: DesktopSceneView(poller: poller, settings: settings, size: screen.frame.size))
        hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        window.setFrame(screen.frame, display: true)
        if desiredVisibility { window.orderFront(nil) }
        return window
    }
}
