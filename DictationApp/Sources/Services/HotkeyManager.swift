import KeyboardShortcuts
import Foundation

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
}

// MARK: - Hotkey Manager

/// Manages global hotkey registration and recording toggle logic
/// Links to AudioRecorder and PermissionManager for complete workflow
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private init() {}

    /// Register the hotkey handler for Option+Space toggle
    func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                await self?.handleHotkeyPressed()
            }
        }
    }

    /// Handle hotkey press - toggle recording state with permission checks
    private func handleHotkeyPressed() async {
        let recorder = AudioRecorder.shared
        let permission = PermissionManager.shared

        if recorder.isRecording {
            // Stop recording (REC-02)
            if let recordingURL = recorder.stopRecording() {
                print("Recording stopped. File saved to: \(recordingURL.path)")
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
            // Check microphone permission before recording (PRM-01)
            let micStatus = permission.checkMicrophonePermission()

            if micStatus == .notDetermined {
                let granted = await permission.requestMicrophonePermission()
                if !granted {
                    permission.showMicrophonePermissionGuidance()
                    return
                }
            } else if micStatus == .denied {
                permission.showMicrophonePermissionGuidance()
                return
            }

            // Start recording (REC-01)
            do {
                try recorder.startRecording()
                print("Recording started...")
                NotificationCenter.default.post(
                    name: .recordingDidStart,
                    object: nil
                )
            } catch {
                // Error handling - basic for Phase 2, expanded in Phase 5
                print("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }
}
