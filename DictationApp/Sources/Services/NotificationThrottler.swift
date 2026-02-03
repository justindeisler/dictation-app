import Foundation

/// Prevents notification spam by throttling repeated notifications of the same category
/// Used by ErrorNotifier to suppress duplicate error notifications within a time window
@MainActor
final class NotificationThrottler {
    static let shared = NotificationThrottler()

    /// Tracks last notification time per category
    private var lastNotificationTimes: [String: Date] = [:]

    /// Minimum interval between notifications of the same category (5 seconds)
    private let minimumInterval: TimeInterval = 5.0

    private init() {}

    /// Check if a notification for the given category should be shown
    /// - Parameter category: The notification category identifier
    /// - Returns: true if notification should be shown, false if suppressed
    func shouldShowNotification(category: String) -> Bool {
        let now = Date()

        if let lastTime = lastNotificationTimes[category] {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed < minimumInterval {
                print("Suppressing duplicate notification for \(category) (elapsed: \(String(format: "%.1f", elapsed))s)")
                return false
            }
        }

        lastNotificationTimes[category] = now
        return true
    }

    /// Reset throttle state for a specific category (useful for testing)
    /// - Parameter category: The notification category to reset
    func reset(category: String) {
        lastNotificationTimes.removeValue(forKey: category)
    }

    /// Reset all throttle state (useful for testing)
    func resetAll() {
        lastNotificationTimes.removeAll()
    }
}
