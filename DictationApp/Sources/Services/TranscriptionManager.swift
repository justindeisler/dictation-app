import Foundation

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

    /// Process a recorded audio file and transcribe it
    /// - Parameter audioURL: URL to the recorded WAV file
    /// - Returns: Transcribed text on success, nil on failure
    @discardableResult
    func handleRecordingCompletion(audioURL: URL) async -> String? {
        // Get language preference from UserDefaults
        // Stored by SettingsView @AppStorage("transcriptionLanguage")
        let languagePreference = UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "auto"
        let language: String? = languagePreference == "auto" ? nil : languagePreference

        // Post notification that transcription is starting (for menu bar icon - ERR-04)
        NotificationCenter.default.post(
            name: .transcriptionWillStart,
            object: nil
        )

        do {
            print("Starting transcription for: \(audioURL.lastPathComponent)")
            let result = try await APIClient.shared.transcribe(audioURL: audioURL, language: language)
            print("Transcription complete: \(result.text)")

            // Post notification for Phase 4 paste integration
            NotificationCenter.default.post(
                name: .transcriptionDidComplete,
                object: result.text
            )

            return result.text
        } catch let error as APIError {
            print("Transcription failed: \(error.userMessage)")

            // Post error with full context for ErrorNotifier (ERR-01, ERR-02, ERR-04)
            NotificationCenter.default.post(
                name: .transcriptionDidFail,
                object: nil,
                userInfo: ["error": error]
            )
            return nil
        } catch let error as URLError {
            // Handle URLError specifically for better network error messages (ERR-04)
            print("Network error during transcription: \(error.localizedDescription)")

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
            print("Transcription failed: \(error.localizedDescription)")

            NotificationCenter.default.post(
                name: .transcriptionDidFail,
                object: nil,
                userInfo: ["error": error]
            )
            return nil
        }
    }
}
