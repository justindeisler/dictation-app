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
    /// - requestTimeout (300s): detects stalled connections (no bytes for 5 min)
    /// - resourceTimeout (600s): total time budget for upload + Groq inference + download
    private static func makeTranscriptionSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
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
    /// - Returns: TranscriptionResult containing the transcribed text
    func transcribe(audioURL: URL, language: String?) async throws -> TranscriptionResult {
        // Validate file exists and check size
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: audioURL.path) else {
            logger.error("Audio file not found: \(audioURL.lastPathComponent, privacy: .public)")
            throw APIError.invalidResponse
        }

        let attributes = try fileManager.attributesOfItem(atPath: audioURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        logger.info("Transcribing \(audioURL.lastPathComponent, privacy: .public): \(fileSize) bytes")

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

        // End boundary
        body.append("--\(boundary)--\r\n")

        request.httpBody = body

        // Send request with retry logic for transient network errors
        logger.info("Sending transcription request to Groq API")
        var data: Data = Data()
        var response: URLResponse = URLResponse()
        let maxRetries = 2

        var lastError: Error?
        var succeeded = false

        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = UInt64(attempt) * 1_000_000_000  // 1s, 2s
                logger.info("Retrying transcription (attempt \(attempt + 1)/\(maxRetries + 1)) after \(attempt)s delay")
                try await Task.sleep(nanoseconds: delay)
            }

            do {
                (data, response) = try await transcriptionSession.data(for: request)
                lastError = nil
                succeeded = true
                break
            } catch let error as URLError where Self.isRetryable(error) {
                logger.warning("Transient network error (attempt \(attempt + 1)/\(maxRetries + 1), code=\(error.code.rawValue)): \(error.localizedDescription, privacy: .public)")
                lastError = error
                continue
            } catch let error as URLError where error.code == .timedOut {
                logger.error("Transcription request timed out")
                throw APIError.timeout
            } catch {
                logger.error("Network error: \(error.localizedDescription, privacy: .public)")
                throw APIError.networkError(error)
            }
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
