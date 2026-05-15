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
    /// is larger than the old WAV minimum. ~8KB ≈ 2s of audio at 32kbps + container overhead;
    /// anything smaller is either an accidental tap or a header-only stub that Whisper rejects.
    private let minimumFileSize: Int64 = 8_000

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

        // Guarantee temp-file cleanup on every exit path (success, API failure, network
        // error, validation rejection). Without this, /var/folders/.../T/ accumulates
        // recording-*.m4a files indefinitely and eventually starves new recordings.
        defer {
            do {
                try fileManager.removeItem(at: audioURL)
                logger.info("Cleaned up temp audio: \(audioURL.lastPathComponent, privacy: .public)")
            } catch {
                logger.warning("Failed to clean up temp audio \(audioURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
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
            let prompt = transcriptionPrompt(for: language)
            logger.info("Starting transcription for: \(audioURL.lastPathComponent, privacy: .public)")
            let result = try await APIClient.shared.transcribe(audioURL: audioURL, language: language, prompt: prompt)
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

    // MARK: - Whisper Prompt

    /// Build the `prompt` value sent to Groq Whisper to bias vocabulary, capitalization,
    /// and punctuation toward the user's actual domain (AI/software development with Claude Code).
    ///
    /// Language-aware on purpose: a full English sentence in the prompt would bias `auto`
    /// detection toward English. For `auto` we use bare terminology (no sentence structure
    /// → no language bias). For explicit `en`/`de` we provide a punctuated sample so Whisper
    /// mimics that punctuation style. ~120 tokens max (Whisper limit is ~224).
    private func transcriptionPrompt(for language: String?) -> String {
        switch language {
        case "en":
            return """
            Working with Claude Code, ChatGPT, and the Anthropic API. I use TypeScript, Python, Swift, and Rust to build AI-powered applications. The MCP server connects to backends via REST and GraphQL endpoints. After refactoring the async function, I deploy via GitHub Actions and verify on Vercel. Topics include LLMs, RAG, embeddings, vector databases, prompt engineering, agents, and tool use. Frameworks: React, Next.js, Vue, Svelte, Tauri, Supabase, Tailwind.
            """
        case "de":
            return """
            Ich arbeite mit Claude Code, ChatGPT und der Anthropic-API. Ich nutze TypeScript, Python, Swift und Rust, um KI-gestützte Anwendungen zu bauen. Der MCP-Server verbindet Backends über REST und GraphQL. Nach dem Refactoring der async-Funktion deploye ich über GitHub Actions und verifiziere auf Vercel. Themen: LLMs, RAG, Embeddings, Vektor-Datenbanken, Prompt Engineering, Agents, Tool Use. Frameworks: React, Next.js, Vue, Svelte, Tauri, Supabase, Tailwind.
            """
        default:
            // language == nil (auto-detect): bare vocabulary list, no sentence structure → no language bias.
            return "Claude Code, Anthropic, ChatGPT, OpenAI, Cursor, Sonnet, Opus, Haiku, MCP, RAG, LLM, async, await, TypeScript, Python, Swift, Rust, GitHub, Docker, Kubernetes, AWS, Vercel, Supabase, React, Next.js, Vue, Svelte, REST, GraphQL, JSON, YAML, SQL, PostgreSQL, MongoDB, Redis, webhook, repository, refactor, deployment, debugging, framework, callback, idempotent, prompt engineering, vector database, embedding, agent, tool use."
        }
    }
}
