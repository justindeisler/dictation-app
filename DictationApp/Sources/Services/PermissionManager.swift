import Foundation
import AVFAudio
import ApplicationServices
import AppKit

/// Permission status for system permissions
enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

/// Manages microphone and accessibility permissions
@MainActor
final class PermissionManager {
    static let shared = PermissionManager()

    private init() {}

    // MARK: - Microphone Permission

    /// Check current microphone permission status
    func checkMicrophonePermission() -> PermissionStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    /// Request microphone permission from user
    /// - Returns: true if permission was granted
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Show guidance alert when microphone permission is denied
    func showMicrophonePermissionGuidance() {
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = """
        DictationApp needs microphone access to record your voice.

        To enable:
        1. Open System Settings
        2. Go to Privacy & Security → Microphone
        3. Enable DictationApp
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Accessibility Permission

    /// Check if accessibility permission is granted
    /// - Returns: true if accessibility is trusted
    func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// Request accessibility permission by prompting user
    /// Opens system dialog asking user to grant accessibility access
    nonisolated func requestAccessibilityPermission() {
        // Use string directly to avoid Swift 6 concurrency warning with kAXTrustedCheckOptionPrompt
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Show guidance alert when accessibility permission is denied
    func showAccessibilityPermissionGuidance() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = """
        DictationApp needs accessibility access to paste transcribed text.

        To enable:
        1. Open System Settings
        2. Go to Privacy & Security → Accessibility
        3. Enable DictationApp
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
