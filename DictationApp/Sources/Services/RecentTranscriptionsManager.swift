import Foundation

/// A single saved transcription with text and timestamp
struct RecentTranscription: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date

    init(text: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
    }
}

/// Persists recent transcriptions to UserDefaults
/// Follows ErrorNotifier.shared / PasteManager.shared singleton pattern
@MainActor
final class RecentTranscriptionsManager {
    static let shared = RecentTranscriptionsManager()

    private let key = "recentTranscriptions"
    private let maxItems = 50

    private init() {}

    /// Save a new transcription (prepended, newest first)
    func save(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var items = getRecent()
        let entry = RecentTranscription(text: trimmed)
        items.insert(entry, at: 0)

        // Trim to max capacity
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        persist(items)
    }

    /// Return all saved transcriptions, newest first
    func getRecent() -> [RecentTranscription] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentTranscription].self, from: data)) ?? []
    }

    /// Convenience: the single most-recent transcription
    func getMostRecent() -> RecentTranscription? {
        getRecent().first
    }

    /// Remove all saved transcriptions
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Remove a single item by index
    func delete(at index: Int) {
        var items = getRecent()
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        persist(items)
    }

    /// Remove a single item by ID
    func delete(id: UUID) {
        var items = getRecent()
        items.removeAll { $0.id == id }
        persist(items)
    }

    private func persist(_ items: [RecentTranscription]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
