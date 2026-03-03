import Foundation
import os

private let logger = Logger(subsystem: "com.dictationapp.DictationApp", category: "TranscriptionManager")

// MARK: - Transcription Notifications

/// Notification for transcription completion (ready for Phase 4 paste)
extension Notification.Name {
    static let transcriptionWillStart = Notification.Name("transcriptionWillStart")
    static let transcriptionDidComplete = Notification.Name("transcriptionDidComplete")
    static let transcriptionDidFail = Notification.Name("transcriptionDidFail")
}

// MARK: - Transcription Manager

/// Manages transcription workflow: audio file -> Groq API -> text result
/// Bridges recording completion to API transcription with language preference support
@MainActor
final class TranscriptionManager {
    static let shared = TranscriptionManager()

    private init() {}

    /// Minimum valid m4a file size: AAC container has overhead, so minimum meaningful recording
    /// is larger than the old WAV minimum. ~4KB covers AAC container + ~0.1s of audio at 32kbps.
    private let minimumFileSize: Int64 = 4_000

    /// Process a recorded audio file and transcribe it
    /// - Parameter audioURL: URL to the recorded WAV file
    /// - Returns: Transcribed text on success, nil on failure
    @discardableResult
    func handleRecordingCompletion(audioURL: URL) async -> String? {
        // Get language preference from UserDefaults
        // Stored by SettingsView @AppStorage("transcriptionLanguage")
        let languagePreference = UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "auto"
        let language: String? = languagePreference == "auto" ? nil : languagePreference

        // Validate recording file before sending to API
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: audioURL.path) else {
            logger.error("Recording file missing: \(audioURL.lastPathComponent, privacy: .public)")
            NotificationCenter.default.post(
                name: .transcriptionDidFail,
                object: nil,
                userInfo: ["error": APIError.invalidResponse]
            )
            return nil
        }

        if let attrs = try? fileManager.attributesOfItem(atPath: audioURL.path),
           let fileSize = attrs[.size] as? Int64 {
            // AAC at 32kbps = 4000 bytes/s for duration estimate (was 32000 for PCM WAV)
            let durationEstimate = Double(fileSize) / 4000.0
            logger.info("Recording file: \(audioURL.lastPathComponent, privacy: .public), size=\(fileSize) bytes, ~\(String(format: "%.1f", durationEstimate), privacy: .public)s")

            if fileSize < minimumFileSize {
                logger.warning("Recording too short (\(fileSize) bytes < \(self.minimumFileSize) minimum)")
                NotificationCenter.default.post(
                    name: .transcriptionDidFail,
                    object: nil,
                    userInfo: ["error": APIError.serverError(0, message: "Recording too short. Hold the hotkey longer.")]
                )
                return nil
            }
        }

        // Post notification that transcription is starting (for menu bar icon - ERR-04)
        NotificationCenter.default.post(
            name: .transcriptionWillStart,
            object: nil
        )

        do {
            logger.info("Starting transcription for: \(audioURL.lastPathComponent, privacy: .public)")
            let result = try await APIClient.shared.transcribe(audioURL: audioURL, language: language)
            logger.info("Transcription complete: \(result.text.prefix(80), privacy: .public)")

            // Post notification for Phase 4 paste integration
            NotificationCenter.default.post(
                name: .transcriptionDidComplete,
                object: result.text
            )

            return result.text
        } catch let error as APIError {
            logger.error("Transcription failed: \(error.userMessage, privacy: .public)")

            // Post error with full context for ErrorNotifier (ERR-01, ERR-02, ERR-04)
            NotificationCenter.default.post(
                name: .transcriptionDidFail,
                object: nil,
                userInfo: ["error": error]
            )
            return nil
        } catch let error as URLError {
            // Handle URLError specifically for better network error messages (ERR-04)
            logger.error("Network error during transcription: \(error.localizedDescription, privacy: .public)")

            let apiError: APIError
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                apiError = .networkError(error)
            case .timedOut:
                apiError = .timeout
            default:
                apiError = .networkError(error)
            }

            NotificationCenter.default.post(
                name: .transcriptionDidFail,
                object: nil,
                userInfo: ["error": apiError]
            )
            return nil
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription, privacy: .public)")

            NotificationCenter.default.post(
                name: .transcriptionDidFail,
                object: nil,
                userInfo: ["error": error]
            )
            return nil
        }
    }
}
