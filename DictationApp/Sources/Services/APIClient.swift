import Foundation

enum APIError: LocalizedError {
    case invalidAPIKey
    case rateLimitExceeded
    case serverError(Int)
    case networkError(Error)
    case invalidResponse
    case timeout

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
        }
    }
}

/// Handles all communication with the Groq API
/// Thread-safe singleton for API validation and future transcription requests
final class APIClient: Sendable {
    static let shared = APIClient()

    private let baseURL = "https://api.groq.com/openai/v1"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10  // 10 second timeout for validation
        config.timeoutIntervalForResource = 10
        // URLSession is Sendable and thread-safe
        session = URLSession(configuration: config)
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
}
