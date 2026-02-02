import Foundation

enum APIError: LocalizedError {
    case invalidAPIKey
    case rateLimitExceeded
    case serverError(Int)
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
        case .serverError(let code):
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
        // Short timeout for validation requests
        let validationConfig = URLSessionConfiguration.default
        validationConfig.timeoutIntervalForRequest = 10
        validationConfig.timeoutIntervalForResource = 10
        session = URLSession(configuration: validationConfig)

        // Longer timeout for transcription (audio processing takes time)
        let transcriptionConfig = URLSessionConfiguration.default
        transcriptionConfig.timeoutIntervalForRequest = 60
        transcriptionConfig.timeoutIntervalForResource = 60
        transcriptionSession = URLSession(configuration: transcriptionConfig)
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
            throw APIError.invalidResponse
        }

        let attributes = try fileManager.attributesOfItem(atPath: audioURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        guard fileSize <= maxFileSize else {
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

        // Add file field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
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

        // Send request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await transcriptionSession.data(for: request)
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
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(TranscriptionResult.self, from: data)
            } catch {
                throw APIError.invalidResponse
            }
        case 401:
            throw APIError.invalidAPIKey
        case 429:
            throw APIError.rateLimitExceeded
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
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
