import Foundation
import os

private let logger = Logger(subsystem: "com.dictationapp.DictationApp", category: "APIClient")

enum APIError: LocalizedError {
    case invalidAPIKey
    case rateLimitExceeded
    case serverError(Int, message: String? = nil)
    case networkError(Error)
    case invalidResponse
    case timeout
    case fileTooLarge(size: Int64, limit: Int64)

    var errorDescription: String? {
        userMessage
    }

    var userMessage: String {
        switch self {
        case .invalidAPIKey:
            return "The API key is invalid. Please check your key at console.groq.com"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait a few minutes and try again."
        case .serverError(let code, let message):
            if let message = message {
                return "Server error (\(code)): \(message)"
            }
            return "Server error (\(code)). Please try again later."
        case .networkError:
            return "Unable to connect to Groq API. Please check your internet connection."
        case .invalidResponse:
            return "Unexpected response from API. Please try again."
        case .timeout:
            return "Request timed out. Please check your internet connection and try again."
        case .fileTooLarge(let size, let limit):
            let sizeMB = Double(size) / 1_000_000
            let limitMB = Double(limit) / 1_000_000
            return String(format: "Audio file too large (%.1f MB). Maximum size is %.0f MB.", sizeMB, limitMB)
        }
    }
}

/// Handles all communication with the Groq API
/// Thread-safe singleton for API validation and transcription requests
final class APIClient: Sendable {
    static let shared = APIClient()

    private let baseURL = "https://api.groq.com/openai/v1"
    private let session: URLSession
    private let transcriptionSession: URLSession

    /// Maximum file size for Groq free tier (25 MB)
    private let maxFileSize: Int64 = 25_000_000

    private init() {
        session = Self.makeSession(timeout: 10)               // Validation requests
        transcriptionSession = Self.makeTranscriptionSession()
    }

    private static func makeSession(timeout: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        return URLSession(configuration: config)
    }

    /// Transcription session with generous timeouts for long recordings on Groq free tier.
    /// - requestTimeout (300s): detects stalled connections (no bytes for 5 min — accounts for
    ///   slow upstream connections sending a 2-3 MB body without any response yet).
    /// - resourceTimeout (900s / 15 min): total time budget for upload + Groq inference + download.
    ///   AudioRecorder caps recordings at 600s. At 32 kbps AAC that's ~2.4 MB. Worst case:
    ///   60s upload on poor wifi + 90s Groq inference + buffer → comfortable headroom up to 15 min.
    ///   Setting allowsExpensiveNetworkAccess so cellular hotspot tethering still works.
    private static func makeTranscriptionSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 900
        config.waitsForConnectivity = true              // queue requests when offline; resume when network returns
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        return URLSession(configuration: config)
    }

    /// Validates API key by calling the models endpoint (fast, free)
    func validateAPIKey(_ key: String) async throws {
        guard let url = URL(string: "\(baseURL)/models") else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return  // Valid API key
        case 401:
            throw APIError.invalidAPIKey
        case 429:
            throw APIError.rateLimitExceeded
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    /// Transcribes audio file using Groq Whisper API
    /// - Parameters:
    ///   - audioURL: URL to the WAV audio file
    ///   - language: Optional language code (e.g., "en", "de"). nil for auto-detection.
    ///   - prompt: Optional context prompt (≤224 tokens) to bias vocabulary, punctuation,
    ///             and homophone resolution. Crucial for technical terms like "Claude" vs "Cloud".
    /// - Returns: TranscriptionResult containing the transcribed text
    func transcribe(audioURL: URL, language: String?, prompt: String? = nil) async throws -> TranscriptionResult {
        // Validate file exists and check size
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: audioURL.path) else {
            logger.error("Audio file not found: \(audioURL.lastPathComponent, privacy: .public)")
            throw APIError.invalidResponse
        }

        let attributes = try fileManager.attributesOfItem(atPath: audioURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let fileSizeKB = Double(fileSize) / 1024.0
        logger.info("Transcribing \(audioURL.lastPathComponent, privacy: .public): \(fileSize) bytes (\(String(format: "%.1f", fileSizeKB)) KB)")

        guard fileSize <= maxFileSize else {
            logger.error("File too large: \(fileSize) > \(self.maxFileSize)")
            throw APIError.fileTooLarge(size: fileSize, limit: maxFileSize)
        }

        // Load API key (MainActor isolated)
        guard let apiKey = await KeychainManager.shared.loadAPIKey() else {
            throw APIError.invalidAPIKey
        }

        // Load audio data
        let audioData = try Data(contentsOf: audioURL)

        // Create multipart request
        guard let url = URL(string: "\(baseURL)/audio/transcriptions") else {
            throw APIError.invalidResponse
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Add file field — use actual file extension to set correct MIME type
        let fileExtension = audioURL.pathExtension.lowercased()
        let mimeType = fileExtension == "m4a" ? "audio/mp4" : "audio/wav"
        let uploadFilename = "audio.\(fileExtension)"
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(uploadFilename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // Add model field (TRX-02: whisper-large-v3-turbo)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("whisper-large-v3-turbo\r\n")

        // Add language field if specified
        if let language = language, language != "auto" {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            body.append("\(language)\r\n")
        }

        // Add prompt field if specified. Whisper uses this as vocabulary/style context:
        // biases recognition toward listed terms ("Claude" not "Cloud") and toward the
        // prompt's punctuation/capitalization style.
        if let prompt = prompt, !prompt.isEmpty {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
            body.append("\(prompt)\r\n")
        }

        // End boundary
        body.append("--\(boundary)--\r\n")

        request.httpBody = body
        let bodyKB = Double(body.count) / 1024.0

        // Send request with retry logic for transient network errors AND retryable HTTP
        // statuses (429 with Retry-After honoring, 5xx with exponential backoff).
        // Without HTTP-level retry, a single Groq blip surfaces as a user-facing failure.
        logger.info("Sending transcription request to Groq API (body \(String(format: "%.1f", bodyKB)) KB)")
        var data: Data = Data()
        var response: URLResponse = URLResponse()
        let maxRetries = 2

        var lastError: Error?
        var succeeded = false
        var nextDelaySeconds: UInt64 = 0

        for attempt in 0...maxRetries {
            if attempt > 0 {
                logger.info("Retrying transcription (attempt \(attempt + 1)/\(maxRetries + 1)) after \(nextDelaySeconds)s delay")
                try await Task.sleep(nanoseconds: nextDelaySeconds * 1_000_000_000)
            }

            // Wall-clock timing for diagnosis of long-recording slowness.
            let attemptStart = Date()
            do {
                (data, response) = try await transcriptionSession.data(for: request)
                let elapsed = Date().timeIntervalSince(attemptStart)
                logger.info("Transcription request completed in \(String(format: "%.2f", elapsed))s (attempt \(attempt + 1))")
            } catch let error as URLError where Self.isRetryable(error) {
                let elapsed = Date().timeIntervalSince(attemptStart)
                logger.warning("Transient network error after \(String(format: "%.2f", elapsed))s (attempt \(attempt + 1)/\(maxRetries + 1), code=\(error.code.rawValue)): \(error.localizedDescription, privacy: .public)")
                lastError = error
                nextDelaySeconds = Self.networkBackoffSeconds(attempt: attempt)
                continue
            } catch let error as URLError where error.code == .timedOut {
                let elapsed = Date().timeIntervalSince(attemptStart)
                logger.error("Transcription request timed out after \(String(format: "%.2f", elapsed))s")
                throw APIError.timeout
            } catch {
                let elapsed = Date().timeIntervalSince(attemptStart)
                logger.error("Network error after \(String(format: "%.2f", elapsed))s: \(error.localizedDescription, privacy: .public)")
                throw APIError.networkError(error)
            }

            // Got a response — inspect status to decide on HTTP-level retry.
            guard let httpResponse = response as? HTTPURLResponse else {
                // Non-HTTP response — fall through; status switch below will throw invalidResponse.
                lastError = nil
                succeeded = true
                break
            }

            let status = httpResponse.statusCode
            let retryable = status == 429 || (500...599).contains(status)
            if retryable && attempt < maxRetries {
                nextDelaySeconds = Self.httpBackoffSeconds(status: status, response: httpResponse, attempt: attempt)
                logger.warning("HTTP \(status) — retrying after \(nextDelaySeconds)s (attempt \(attempt + 1)/\(maxRetries + 1))")
                continue
            }

            // Either a final status (2xx/4xx-non-429) or exhausted retries on a retryable status.
            // Fall through to the switch below which handles all status codes uniformly.
            lastError = nil
            succeeded = true
            break
        }

        if !succeeded {
            if let urlError = lastError as? URLError {
                logger.error("All \(maxRetries + 1) attempts failed. Last error (code=\(urlError.code.rawValue)): \(urlError.localizedDescription, privacy: .public)")
                if urlError.code == .timedOut {
                    throw APIError.timeout
                }
            }
            throw APIError.networkError(lastError!)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Response is not HTTPURLResponse")
            throw APIError.invalidResponse
        }

        logger.info("API response status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            do {
                let result = try decoder.decode(TranscriptionResult.self, from: data)
                logger.info("Transcription succeeded: \(result.text.prefix(80), privacy: .public)")
                return result
            } catch {
                logger.error("Failed to decode response: \(error.localizedDescription, privacy: .public)")
                throw APIError.invalidResponse
            }
        case 401:
            logger.error("API key invalid (401)")
            throw APIError.invalidAPIKey
        case 429:
            logger.error("Rate limited (429)")
            throw APIError.rateLimitExceeded
        default:
            let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            logger.error("API error: status=\(httpResponse.statusCode), body=\(rawBody, privacy: .public)")
            if let errorBody = try? JSONDecoder().decode(GroqErrorResponse.self, from: data) {
                throw APIError.serverError(httpResponse.statusCode, message: errorBody.error.message)
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Retry Helpers

    private static func isRetryable(_ error: URLError) -> Bool {
        switch error.code {
        case .networkConnectionLost, .cannotConnectToHost, .cannotParseResponse:
            return true
        default:
            return false
        }
    }

    /// Exponential backoff for transient network errors: 2s, 5s, 10s.
    private static func networkBackoffSeconds(attempt: Int) -> UInt64 {
        switch attempt {
        case 0: return 2
        case 1: return 5
        default: return 10
        }
    }

    /// Backoff for retryable HTTP statuses. Honors Retry-After on 429
    /// (seconds form; capped at 30 s). Falls back to exponential 2/5/10 s.
    private static func httpBackoffSeconds(status: Int, response: HTTPURLResponse, attempt: Int) -> UInt64 {
        if status == 429,
           let retryAfter = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = UInt64(retryAfter.trimmingCharacters(in: .whitespaces)) {
            return min(seconds, 30)
        }
        return networkBackoffSeconds(attempt: attempt)
    }
}

// MARK: - Groq Error Response

private struct GroqErrorResponse: Decodable {
    let error: ErrorDetail

    struct ErrorDetail: Decodable {
        let message: String
        let type: String?
    }
}

// MARK: - Data Extension for Multipart

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
