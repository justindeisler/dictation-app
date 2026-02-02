import Foundation
import ServiceManagement
import AppKit

enum LoginItemError: LocalizedError {
    case registrationFailed
    case unregistrationFailed

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Unable to enable launch at login"
        case .unregistrationFailed:
            return "Unable to disable launch at login"
        }
    }
}

@MainActor
final class LoginItemManager {
    static let shared = LoginItemManager()

    private let service = SMAppService.mainApp

    private init() {}

    /// Returns actual system state (user decision: reflect actual state)
    func isEnabled() -> Bool {
        service.status == .enabled
    }

    /// Enable or disable launch at login
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard service.status != .enabled else { return }

            do {
                try service.register()
            } catch {
                // User decision: show guidance if blocked
                showSystemSettingsGuidance()
                throw LoginItemError.registrationFailed
            }

            // Verify registration succeeded
            if service.status != .enabled {
                showSystemSettingsGuidance()
                throw LoginItemError.registrationFailed
            }
        } else {
            guard service.status != .notRegistered else { return }

            do {
                try service.unregister()
            } catch {
                throw LoginItemError.unregistrationFailed
            }
        }
    }

    /// User decision: show guidance to System Settings if macOS blocks
    private func showSystemSettingsGuidance() {
        let alert = NSAlert()
        alert.messageText = "Unable to Enable Launch at Login"
        alert.informativeText = """
        macOS blocked the request to launch at login.

        To enable manually:
        1. Open System Settings
        2. Go to General -> Login Items
        3. Add DictationApp under "Open at Login"
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Open System Settings to Login Items
            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
