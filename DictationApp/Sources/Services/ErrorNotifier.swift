import Foundation
@preconcurrency import UserNotifications

/// Error notification category identifiers
enum ErrorCategory {
    static let network = "ERROR_NETWORK"
    static let apiKey = "ERROR_API_KEY"
    static let rateLimit = "ERROR_RATE_LIMIT"
    static let general = "ERROR_GENERAL"
}

/// Centralized error notification service for transcription failures
/// Shows user-friendly notifications with throttling to prevent spam
@MainActor
final class ErrorNotifier {
    static let shared = ErrorNotifier()

    private let throttler = NotificationThrottler.shared

    private init() {}

    /// Register error notification categories with the notification center
    /// Call this during app setup alongside existing notification categories
    func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()

        // Get existing categories and add error categories
        center.getNotificationCategories { existingCategories in
            var allCategories = existingCategories

            // Add error categories (no actions needed, just informational)
            let errorCategories = [
                ErrorCategory.network,
                ErrorCategory.apiKey,
                ErrorCategory.rateLimit,
                ErrorCategory.general
            ]

            for categoryId in errorCategories {
                let category = UNNotificationCategory(
                    identifier: categoryId,
                    actions: [],
                    intentIdentifiers: [],
                    options: []
                )
                allCategories.insert(category)
            }

            center.setNotificationCategories(allCategories)
        }
    }

    /// Show a notification for a transcription error
    /// Automatically determines category and applies throttling
    /// - Parameter error: The error to display to the user
    func showTranscriptionError(_ error: Error) async {
        // Determine category and title based on error type
        let category: String
        let title: String

        if let apiError = error as? APIError {
            switch apiError {
            case .invalidAPIKey:
                category = ErrorCategory.apiKey
                title = "API Key Invalid"
            case .networkError:
                category = ErrorCategory.network
                title = "Network Error"
            case .timeout:
                category = ErrorCategory.network
                title = "Request Timed Out"
            case .rateLimitExceeded:
                category = ErrorCategory.rateLimit
                title = "Rate Limit Exceeded"
            case .fileTooLarge:
                category = ErrorCategory.general
                title = "Audio File Too Large"
            case .serverError, .invalidResponse:
                category = ErrorCategory.general
                title = "Transcription Failed"
            }
        } else {
            category = ErrorCategory.general
            title = "Error"
        }

        // Check throttler to prevent spam
        guard throttler.shouldShowNotification(category: category) else {
            return
        }

        // Get user-friendly message
        let message: String
        if let apiError = error as? APIError {
            message = apiError.userMessage
        } else {
            message = error.localizedDescription
        }

        // Create and show notification
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.categoryIdentifier = category

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Show immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Error notification shown: \(title) - \(message)")
        } catch {
            print("Failed to show error notification: \(error)")
        }
    }
}
