import AppKit
import SwiftUI
import Combine

@MainActor
final class DesktopWindowController {
    private var windows: [NSWindow] = []
    private let poller: NowPlayingPoller
    private let settings: Settings
    private var screenObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    private var desiredVisibility = true
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

        settings.$isEditMode
            .receive(on: RunLoop.main)
            .sink { [weak self] editing in
                guard let self else { return }
                for window in self.windows {
                    window.ignoresMouseEvents = !editing
                    if editing {
                        window.level = .floating
                    } else {
                        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
                    }
                }
            }
            .store(in: &cancellables)
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
        window.level = settings.isEditMode ? .floating : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.ignoresMouseEvents = !settings.isEditMode
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
