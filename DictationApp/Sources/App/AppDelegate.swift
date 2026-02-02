import AppKit
import SwiftUI

// MARK: - Menu Bar Icon State

/// Visual states for the menu bar icon
enum MenuBarIconState {
    case idle
    case recording

    var symbolName: String {
        switch self {
        case .idle: return "waveform"
        case .recording: return "waveform.circle.fill"
        }
    }

    var tintColor: NSColor? {
        switch self {
        case .idle: return nil  // Uses template mode (adapts to light/dark)
        case .recording: return .systemRed
        }
    }

    var isTemplate: Bool {
        switch self {
        case .idle: return true
        case .recording: return false  // Explicit color, not template
        }
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupRecordingStateObservers()
        HotkeyManager.shared.setupHotkey()

        // Check and request accessibility permission at launch (PRM-02)
        // Required for Phase 4 paste functionality
        if !PermissionManager.shared.checkAccessibilityPermission() {
            PermissionManager.shared.requestAccessibilityPermission()
        }
    }

    // MARK: - Recording State Observers

    private func setupRecordingStateObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingStarted),
            name: .recordingDidStart,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingStopped),
            name: .recordingDidStop,
            object: nil
        )
    }

    @objc func handleRecordingStarted() {
        updateMenuBarIcon(state: .recording)
    }

    @objc func handleRecordingStopped(_ notification: Notification) {
        updateMenuBarIcon(state: .idle)
        // notification.object contains the recording URL for Phase 3 transcription
    }

    // MARK: - Menu Bar Icon

    func updateMenuBarIcon(state: MenuBarIconState) {
        guard let button = statusItem?.button else { return }

        let accessibilityDesc = state == .recording ? "Recording" : "Dictation"

        if state == .recording {
            // Use symbol configuration with red color for recording state
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            if let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: accessibilityDesc)?
                .withSymbolConfiguration(config) {
                image.isTemplate = false  // Don't adapt to menu bar appearance
                button.image = image
            }
        } else {
            // Use template mode for idle state (adapts to light/dark)
            let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: accessibilityDesc)
            image?.isTemplate = true
            button.image = image
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // User decision: SF Symbol for icon (waveform per research)
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Dictation")
            button.image?.isTemplate = true  // Adapts to light/dark mode
        }

        let menu = NSMenu()

        // Settings (Cmd+,)
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())

        // About
        menu.addItem(NSMenuItem(title: "About DictationApp", action: #selector(showAbout), keyEquivalent: ""))

        // Check for Updates (placeholder per user's Claude discretion)
        menu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Recent transcriptions (placeholder for Phase 3)
        let recentMenu = NSMenu()
        recentMenu.addItem(NSMenuItem(title: "No recent transcriptions", action: nil, keyEquivalent: ""))
        let recentItem = NSMenuItem(title: "Recent Transcriptions", action: nil, keyEquivalent: "")
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)
        menu.addItem(NSMenuItem.separator())

        // Shortcuts info
        menu.addItem(NSMenuItem(title: "Keyboard Shortcuts", action: #selector(showShortcuts), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Launch at login toggle
        let launchToggle = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        // User decision: reflect actual system state
        launchToggle.state = LoginItemManager.shared.isEnabled() ? .on : .off
        menu.addItem(launchToggle)
        menu.addItem(NSMenuItem.separator())

        // Quit (Cmd+Q)
        menu.addItem(NSMenuItem(title: "Quit DictationApp", action: #selector(quit), keyEquivalent: "q"))

        menu.delegate = self
        statusItem?.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Update Launch at Login state each time menu opens
        if let launchItem = menu.item(withTitle: "Launch at Login") {
            launchItem.state = LoginItemManager.shared.isEnabled() ? .on : .off
        }
    }

    @objc func openSettings() {
        if settingsWindowController == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "DictationApp Settings"
            window.styleMask = [.titled, .closable]  // No resize - fixed layout
            window.setContentSize(NSSize(width: 500, height: 250))
            window.center()

            // User decision: separate floating window
            window.level = .floating
            window.isMovableByWindowBackground = true

            settingsWindowController = NSWindowController(window: window)
        }

        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func checkForUpdates() {
        // Placeholder - deferred to future enhancement
        let alert = NSAlert()
        alert.messageText = "Check for Updates"
        alert.informativeText = "You're running the latest version."
        alert.runModal()
    }

    @objc func showShortcuts() {
        let alert = NSAlert()
        alert.messageText = "Keyboard Shortcuts"
        alert.informativeText = "Option + Space: Toggle recording\n\nStart dictating and your words will appear in the active text field."
        alert.runModal()
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let manager = LoginItemManager.shared
        let currentState = manager.isEnabled()

        do {
            try manager.setEnabled(!currentState)
            // User decision: reflect actual system state after change
            sender.state = manager.isEnabled() ? .on : .off
        } catch {
            // Show error but don't change toggle state
            let alert = NSAlert()
            alert.messageText = "Unable to Change Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()

            // Ensure toggle reflects actual state
            sender.state = manager.isEnabled() ? .on : .off
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
