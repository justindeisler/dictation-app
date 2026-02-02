import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
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
        launchToggle.state = .off  // Will be updated in Plan 03
        menu.addItem(launchToggle)
        menu.addItem(NSMenuItem.separator())

        // Quit (Cmd+Q)
        menu.addItem(NSMenuItem(title: "Quit DictationApp", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc func openSettings() {
        // Placeholder - implemented in Plan 02
        print("Settings clicked")
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
        // Placeholder - implemented in Plan 03
        sender.state = sender.state == .on ? .off : .on
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
