import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var originalAPIKey: String = ""
    @State private var isValidating = false
    @State private var showValidationError = false
    @State private var validationError: String = ""

    @AppStorage("transcriptionLanguage") private var languagePreference: String = "auto"
    @State private var originalLanguagePreference: String = "auto"

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Content area - single view layout per user decision
            Form {
                Section {
                    SecureField("Enter your Groq API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .help("Your API key from console.groq.com")

                    Link("Get your API key from console.groq.com",
                         destination: URL(string: "https://console.groq.com/keys")!)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("API Configuration")
                        .font(.headline)
                }

                Section {
                    Picker("Language", selection: $languagePreference) {
                        Text("Auto-detect").tag("auto")
                        Text("English").tag("en")
                        Text("German").tag("de")
                    }
                    .pickerStyle(.segmented)

                    Text("Specifying a language improves accuracy and speed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Transcription")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)  // All settings visible at once
            .padding()

            Divider()

            // Button bar - explicit save behavior per user decision
            HStack(spacing: 12) {
                Button("Cancel") {
                    apiKey = originalAPIKey  // Discard API key changes
                    languagePreference = originalLanguagePreference  // Discard language changes
                    closeWindow()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if isValidating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                    Text("Validating...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Save") {
                    Task {
                        await validateAndSave()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isValidating || !hasChanges)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 500, height: 320)
        .onAppear {
            loadCurrentSettings()
        }
        .alert("API Key Validation Failed", isPresented: $showValidationError) {
            Button("OK") { }
        } message: {
            Text(validationError)
        }
    }

    /// Check if any settings have changed from their original values
    private var hasChanges: Bool {
        let apiKeyChanged = !apiKey.isEmpty && apiKey != originalAPIKey
        let languageChanged = languagePreference != originalLanguagePreference
        return apiKeyChanged || languageChanged
    }

    private func loadCurrentSettings() {
        if let savedKey = KeychainManager.shared.loadAPIKey() {
            apiKey = savedKey
            originalAPIKey = savedKey
        }
        originalLanguagePreference = languagePreference
    }

    private func validateAndSave() async {
        isValidating = true

        do {
            // Only validate and save API key if it changed
            let apiKeyChanged = !apiKey.isEmpty && apiKey != originalAPIKey
            if apiKeyChanged {
                // User decision: auto-validate on save
                try await APIClient.shared.validateAPIKey(apiKey)

                // Save to Keychain
                try KeychainManager.shared.saveAPIKey(apiKey)
            }

            // Update originals to prevent re-save prompt
            // (Language is already saved via @AppStorage)
            originalAPIKey = apiKey
            originalLanguagePreference = languagePreference

            // Close window on success
            await MainActor.run {
                closeWindow()
            }
        } catch let error as APIError {
            // User decision: alert dialog on validation failure
            validationError = error.userMessage
            showValidationError = true
        } catch {
            validationError = "Unable to save API key. Please try again."
            showValidationError = true
        }

        isValidating = false
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

#Preview {
    SettingsView()
}
