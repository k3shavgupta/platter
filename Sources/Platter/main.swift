import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let poller = NowPlayingPoller()
    private let settings = Settings()
    private var statusItem: NSStatusItem!
    private var desktopController: DesktopWindowController!
    private var controlWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        desktopController = DesktopWindowController(poller: poller, settings: settings)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(systemSymbolName: "opticaldisc", accessibilityDescription: "Platter")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.toolTip = "Platter"
        statusItem.menu = buildMenu()

        poller.start()
    }

    /// Re-opening Platter (double-clicking it in Finder or the Dock) surfaces the control
    /// panel. This is the reliable way in: on a crowded menu bar macOS parks the status
    /// item off-screen, leaving no other way to reach the settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControlPanel()
        return true
    }

    // MARK: Control panel

    private func showControlPanel() {
        if let window = controlWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = ControlPanelView(
            settings: settings,
            showOnDesktop: desktopController.isVisible,
            launchAtLogin: SMAppService.mainApp.status == .enabled,
            onToggleDesktop: { [weak self] value in
                self?.desktopController.setVisible(value)
                self?.syncMenuState()
            },
            onToggleLogin: { [weak self] value in
                self?.setLaunchAtLogin(value)
                self?.syncMenuState()
            },
            onQuit: { NSApp.terminate(nil) }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 330),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Platter"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        controlWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Show on Desktop", action: #selector(toggleVisible), keyEquivalent: "")
        showItem.target = self
        showItem.state = desktopController.isVisible ? .on : .off
        menu.addItem(showItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Platter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    /// Keeps the menu check marks in step with changes made from the control panel.
    private func syncMenuState() {
        guard let menu = statusItem?.menu else { return }
        menu.item(withTitle: "Show on Desktop")?.state = desktopController.isVisible ? .on : .off
        menu.item(withTitle: "Launch at Login")?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func openSettings() {
        showControlPanel()
    }

    @objc private func toggleVisible(_ sender: NSMenuItem) {
        let newValue = !desktopController.isVisible
        desktopController.setVisible(newValue)
        sender.state = newValue ? .on : .off
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let isEnabled = SMAppService.mainApp.status == .enabled
        setLaunchAtLogin(!isEnabled)
        sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
    }
}

/// NSApplication holds its delegate weakly, so the app must own it. Without this the
/// optimizer is free to release the delegate as soon as it is assigned, taking the
/// status item (which the delegate owns) down with it.
nonisolated(unsafe) private var retainedDelegate: AppDelegate?

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    retainedDelegate = delegate
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
