import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var originalAPIKey: String = ""
    @State private var isValidating = false
    @State private var showValidationError = false
    @State private var validationError: String = ""

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
            }
            .formStyle(.grouped)
            .scrollDisabled(true)  // All settings visible at once
            .padding()

            Divider()

            // Button bar - explicit save behavior per user decision
            HStack(spacing: 12) {
                Button("Cancel") {
                    apiKey = originalAPIKey  // Discard changes
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
                .disabled(apiKey.isEmpty || apiKey == originalAPIKey || isValidating)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 500, height: 250)
        .onAppear {
            loadCurrentSettings()
        }
        .alert("API Key Validation Failed", isPresented: $showValidationError) {
            Button("OK") { }
        } message: {
            Text(validationError)
        }
    }

    private func loadCurrentSettings() {
        if let savedKey = KeychainManager.shared.loadAPIKey() {
            apiKey = savedKey
            originalAPIKey = savedKey
        }
    }

    private func validateAndSave() async {
        isValidating = true

        do {
            // User decision: auto-validate on save
            try await APIClient.shared.validateAPIKey(apiKey)

            // Save to Keychain
            try KeychainManager.shared.saveAPIKey(apiKey)

            // Update original to prevent re-save prompt
            originalAPIKey = apiKey

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
