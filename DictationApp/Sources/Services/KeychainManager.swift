import Foundation
import KeychainAccess

/// Manages secure storage of sensitive data in the macOS Keychain
@MainActor
final class KeychainManager {
    static let shared = KeychainManager()

    private let keychain = Keychain(service: "com.dictationapp.DictationApp")
    private let apiKeyKey = "groq_api_key"

    private init() {}

    func saveAPIKey(_ key: String) throws {
        try keychain.set(key, key: apiKeyKey)
    }

    func loadAPIKey() -> String? {
        try? keychain.get(apiKeyKey)
    }

    func deleteAPIKey() throws {
        try keychain.remove(apiKeyKey)
    }

    func hasAPIKey() -> Bool {
        loadAPIKey() != nil
    }
}
