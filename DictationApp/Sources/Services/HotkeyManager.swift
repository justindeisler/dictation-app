import KeyboardShortcuts
import Foundation
import AppKit
import os

// MARK: - Keyboard Shortcut Names

/// Define the hotkey name with default Option+Space
extension KeyboardShortcuts.Name {
    static let toggleRecording = Self(
        "toggleRecording",
        default: .init(.space, modifiers: [.option])
    )
}

// MARK: - Recording State Notifications

/// Notification names for recording state changes
extension Notification.Name {
    static let recordingDidStart = Notification.Name("recordingDidStart")
    static let recordingDidStop = Notification.Name("recordingDidStop")
    static let recordingDidAutoStop = Notification.Name("recordingDidAutoStop")
}

// MARK: - Hotkey Manager

/// Manages global hotkey registration and recording toggle logic
/// Links to AudioRecorder and PermissionManager for complete workflow
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()
    private let logger = Logger(subsystem: "com.dictationapp.DictationApp", category: "HotkeyManager")

    /// Track whether microphone permission was confirmed this session
    var microphonePermissionGranted = false

    private init() {}

    /// Register the hotkey handler for Option+Space toggle
    func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                await self?.handleHotkeyPressed()
            }
        }

        // Observe auto-stop events to trigger transcription
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingAutoStopped),
            name: .recordingDidAutoStop,
            object: nil
        )
    }

    @objc private func handleRecordingAutoStopped(_ notification: Notification) {
        guard let audioURL = notification.object as? URL else { return }
        logger.info("Recording auto-stopped at time limit. Triggering transcription.")
        Task {
            await TranscriptionManager.shared.handleRecordingCompletion(audioURL: audioURL)
        }
    }

    /// Check if API key is configured (ERR-03)
    /// - Returns: true if API key exists, false otherwise
    private func checkAPIKeyBeforeRecording() -> Bool {
        guard KeychainManager.shared.hasAPIKey() else {
            // Get AppDelegate reference to show alert
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.showMissingAPIKeyAlert()
            }
            return false
        }
        return true
    }

    /// Handle hotkey press - toggle recording state with permission checks
    private func handleHotkeyPressed() async {
        logger.info("Hotkey pressed (Option+Space)")
        let recorder = AudioRecorder.shared
        let permission = PermissionManager.shared

        if recorder.isRecording {
            // Stop recording (REC-02)
            if let recordingURL = recorder.stopRecording() {
                logger.info("Recording stopped. File saved to: \(recordingURL.path)")
                NotificationCenter.default.post(
                    name: .recordingDidStop,
                    object: recordingURL
                )

                // Trigger transcription (TRX-01)
                Task {
                    await TranscriptionManager.shared.handleRecordingCompletion(audioURL: recordingURL)
                }
            }
        } else {
            // Check API key FIRST before even checking permissions (ERR-03)
            // No point recording if we can't transcribe
            guard checkAPIKeyBeforeRecording() else {
                return
            }

            // Check microphone permission (skip if already confirmed this session)
            if !microphonePermissionGranted {
                let micStatus = permission.checkMicrophonePermission()
                if micStatus == .granted {
                    microphonePermissionGranted = true
                } else if micStatus == .denied {
                    permission.showMicrophonePermissionGuidance()
                    return
                } else {
                    // .notDetermined — request permission (async, waits for user response)
                    let granted = await permission.requestMicrophonePermission()
                    if granted {
                        microphonePermissionGranted = true
                    } else {
                        permission.showMicrophonePermissionGuidance()
                        return
                    }
                }
            }

            // Start recording (REC-01)
            do {
                try recorder.startRecording()
                logger.info("Recording started")
                NotificationCenter.default.post(
                    name: .recordingDidStart,
                    object: nil
                )
            } catch {
                logger.error("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }
}
