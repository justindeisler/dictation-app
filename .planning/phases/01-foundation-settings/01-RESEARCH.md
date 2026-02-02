# Phase 1: Foundation & Settings - Research

**Phase**: 01-foundation-settings
**Research Date**: 2026-02-02
**Status**: Ready for planning

## Purpose

This research document answers: "What do I need to know to PLAN Phase 1 well?"

It provides technical implementation details, proven patterns, critical decisions, and known pitfalls specific to establishing the foundation: menu bar presence, settings window, API key storage, and launch at login.

---

## User Decisions from CONTEXT.md

### Locked Choices (Research These Deeply)

**Settings Window Design**:
- Single view layout - all settings visible at once
- Native macOS visual style
- Separate floating window (not popup/sheet)
- Explicit save behavior (Save/Cancel buttons)

**API Key Handling**:
- Masked input (password style)
- Auto-validate on save
- Alert dialog on validation failure
- Notify on first failed transcription (not on app launch)

**Menu Bar Presence**:
- SF Symbol for icon
- Extended menu: Settings, About, Check for Updates, Recent transcriptions, Shortcuts info, Quit
- Left-click shows dropdown menu
- Recording status shown via icon change only

**Launch at Login**:
- Toggle in menu bar menu only
- No first-run prompt
- Show guidance to System Settings if macOS blocks

### Claude's Discretion

- Launch at login toggle state: actual system state vs app preference
- Exact SF Symbol choice
- Settings window layout and spacing
- "Check for Updates" implementation

---

## Critical Technical Decisions

### 1. Sandboxing Decision (BLOCKING)

**Context**: This is the most critical architectural decision for Phase 1. It determines distribution model, entitlements, and technical constraints for all future phases.

**The Conflict**:
- **App Store Distribution** requires sandboxing
- **CGEvent.post()** (needed for paste in Phase 4) conflicts with sandboxing
- Phase 1 must establish the foundation that enables or blocks future functionality

**Research Findings**:

**Sandboxed Apps (App Store)**:
- ✅ Broader distribution reach
- ✅ User trust from App Store
- ❌ CGEvent.post() severely limited or fails silently
- ❌ Accessibility API restrictions
- ❌ More complex entitlement management
- Source: [Apple Developer Forums - Accessibility in sandboxed apps](https://developer.apple.com/forums/thread/707680)

**Non-Sandboxed Apps (Developer ID)**:
- ✅ Full CGEvent.post() support
- ✅ Full Accessibility API access
- ✅ Simpler development/testing
- ❌ Requires notarization for distribution
- ❌ Users may be more cautious about downloads
- Source: [jano.dev - Accessibility Permission](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)

**Recommendation for Phase 1**:
- **START non-sandboxed** to enable full functionality
- Configure Info.plist WITHOUT App Sandbox entitlement
- Add proper code signing from day 1
- Test CGEvent.post() early (Phase 2/3) to validate decision
- Decision can be revisited before distribution if App Store becomes priority

**Implementation in Phase 1**:
```xml
<!-- Info.plist - Do NOT add com.apple.security.app-sandbox -->
<key>LSUIElement</key>
<true/>  <!-- Menu bar only, no dock icon -->

<!-- Required entitlements for non-sandboxed app -->
<key>NSMicrophoneUsageDescription</key>
<string>DictationApp records audio to transcribe your speech.</string>

<key>NSAppleEventsUsageDescription</key>
<string>DictationApp needs to paste transcribed text into other applications.</string>
```

---

### 2. Menu Bar Implementation: NSStatusItem vs MenuBarExtra

**User Decision**: Menu bar app with specific menu structure and icon behavior.

**Technical Options**:

**Option A: MenuBarExtra (Pure SwiftUI)**
```swift
@main
struct DictationApp: App {
    var body: some Scene {
        MenuBarExtra("Dictation", systemImage: "waveform") {
            Button("Settings") { }
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}
```
- ✅ Clean SwiftUI API
- ✅ Minimal code
- ❌ **Only macOS 13+** (too restrictive)
- ❌ Limited to menu-style UI, no custom popup windows
- ❌ No access to underlying NSStatusItem for advanced control
- Source: [nilcoalescing.com - MenuBarExtra](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/)

**Option B: NSStatusItem (AppKit + SwiftUI Hybrid)**
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Dictation")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        // ... more menu items
        statusItem?.menu = menu
    }
}
```
- ✅ Full control over menu bar item
- ✅ Works on macOS 12+ (better compatibility)
- ✅ Can use SwiftUI for settings window while AppKit manages menu bar
- ✅ Access to NSStatusItem.button for icon state changes
- ✅ Industry standard for menu bar apps
- Sources: [sarunw.com - SwiftUI Menu Bar App](https://sarunw.com/posts/swiftui-menu-bar-app/), [Medium - Building macOS Menu Bar App](https://gaitatzis.medium.com/building-a-macos-menu-bar-app-with-swift)

**Recommendation**: **Use NSStatusItem (Option B)**
- Aligns with user decision for extended menu and icon state changes
- More reliable for macOS 14.0+ deployment target
- Established pattern for professional menu bar apps
- SwiftUI can still be used for settings window

**Implementation Pattern**:
```swift
// AppDelegate.swift (AppKit)
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // User decision: SF Symbol for icon
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Dictation")
            button.image?.isTemplate = true  // Adapts to light/dark mode
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About DictationApp", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        // Recent transcriptions submenu (placeholder for Phase 3)
        let recentMenu = NSMenu()
        let recentItem = NSMenuItem(title: "Recent Transcriptions", action: nil, keyEquivalent: "")
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Keyboard Shortcuts", action: #selector(showShortcuts), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        // Launch at login toggle
        let launchToggle = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchToggle.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchToggle)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit DictationApp", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc func openSettings() {
        // Show SwiftUI settings window (separate floating window per user decision)
        if settingsWindowController == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 500, height: 300))
            settingsWindowController = NSWindowController(window: window)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// SettingsView.swift (SwiftUI)
struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var isValidating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            // User decision: single view layout, native style
            Form {
                Section {
                    SecureField("Groq API Key", text: $apiKey)  // User decision: masked input
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("API Configuration")
                }
            }
            .formStyle(.grouped)  // Native macOS style

            HStack {
                Button("Cancel") {
                    // Close window without saving
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    Task {
                        await validateAndSave()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(apiKey.isEmpty || isValidating)
            }
            .padding()
        }
        .frame(width: 500, height: 300)
        .alert("API Key Validation Failed", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    func validateAndSave() async {
        // User decision: auto-validate on save
        isValidating = true

        // Test API key with minimal request
        do {
            try await APIClient.shared.validateAPIKey(apiKey)
            // Save to Keychain
            KeychainManager.shared.saveAPIKey(apiKey)
            NSApp.keyWindow?.close()
        } catch {
            // User decision: alert dialog on validation failure
            errorMessage = error.localizedDescription
            showError = true
        }

        isValidating = false
    }
}
```

---

### 3. API Key Storage: Keychain vs UserDefaults

**User Decision**: Secure storage required (SET-03)

**Research Findings**:

**UserDefaults** (Plain text plist):
- ❌ **NOT SECURE**: Stored in `~/Library/Preferences/[bundle-id].plist`
- ❌ Easily readable with any text editor or iExplorer
- ❌ No encryption
- ❌ Violates user expectation of "secure storage"
- Source: [Medium - UserDefaults vs Keychain](https://rohit-13.medium.com/all-about-userdefaults-keychain-and-coredata-ios-53c8d0c7a0fb)

**Keychain Services** (Encrypted system storage):
- ✅ **SECURE**: Encrypted by macOS
- ✅ Protected by device security policies
- ✅ Industry standard for credentials
- ✅ Survives app reinstalls (optional)
- ✅ Can be backed up to iCloud Keychain (optional)
- Source: [Medium - App Security in Swift](https://medium.com/@gauravharkhani01/app-security-in-swift-keychain-biometrics-secure-enclave-69359b4cffba)

**Recommendation**: **Use Keychain Services**
- Meets SET-03 requirement for secure storage
- Aligns with user decision for password-style masked input
- No performance impact (reads are cached)

**Implementation Options**:

**Option A: Native Security Framework**
```swift
import Security

func saveAPIKey(_ key: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "groq_api_key",
        kSecAttrService as String: "com.yourname.dictationapp",
        kSecValueData as String: key.data(using: .utf8)!
    ]

    SecItemDelete(query as CFDictionary)  // Delete old value
    SecItemAdd(query as CFDictionary, nil)  // Add new value
}

func loadAPIKey() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "groq_api_key",
        kSecAttrService as String: "com.yourname.dictationapp",
        kSecReturnData as String: true
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess,
          let data = result as? Data,
          let key = String(data: data, encoding: .utf8) else {
        return nil
    }

    return key
}
```
- ✅ No dependencies
- ❌ Verbose boilerplate code
- ❌ Error handling complexity

**Option B: KeychainAccess Library** (Recommended)
```swift
import KeychainAccess

let keychain = Keychain(service: "com.yourname.dictationapp")

// Save
keychain["groq_api_key"] = apiKey

// Load
if let apiKey = keychain["groq_api_key"] {
    // Use API key
}

// Delete
try? keychain.remove("groq_api_key")
```
- ✅ Clean, minimal API
- ✅ Handles edge cases automatically
- ✅ Well-maintained (4.2k+ stars, updated Jan 2025)
- ✅ Swift Package Manager support
- Source: [GitHub - KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)

**Recommendation**: **Use KeychainAccess library (Option B)**
- Reduces boilerplate by 80%
- Proven reliability across thousands of apps
- Active maintenance

**KeychainManager Wrapper**:
```swift
import KeychainAccess

class KeychainManager {
    static let shared = KeychainManager()
    private let keychain = Keychain(service: "com.yourname.dictationapp")

    private let apiKeyKey = "groq_api_key"

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
        return loadAPIKey() != nil
    }
}
```

---

### 4. Settings Window Architecture

**User Decisions**:
- Single view layout (all settings visible at once)
- Native macOS visual style
- Separate floating window
- Explicit save behavior (Save/Cancel buttons)

**Research Findings**:

**SwiftUI Form with Native Styling**:
```swift
struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var language: String = "en"
    @State private var originalAPIKey: String = ""
    @State private var isValidating = false
    @State private var showValidationError = false
    @State private var validationError: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            Form {
                // API Configuration Section
                Section {
                    SecureField("Groq API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .help("Your API key from console.groq.com")

                    Text("Get your API key from [console.groq.com](https://console.groq.com)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("API Configuration")
                        .font(.headline)
                }

                // Language Section (for Phase 3)
                Section {
                    Picker("Language", selection: $language) {
                        Text("English").tag("en")
                        Text("German").tag("de")
                        Text("Auto-detect").tag("auto")
                    }
                    .pickerStyle(.radioGroup)
                } header: {
                    Text("Transcription")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)  // Native macOS grouped form style
            .scrollDisabled(true)  // All settings visible at once
            .padding()

            Divider()

            // Button bar (Save/Cancel per user decision)
            HStack(spacing: 12) {
                Button("Cancel") {
                    // Restore original values
                    apiKey = originalAPIKey
                    NSApp.keyWindow?.close()
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
        .frame(width: 500, height: 350)  // Fixed size, all content visible
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
        // Load from Keychain
        if let savedKey = KeychainManager.shared.loadAPIKey() {
            apiKey = savedKey
            originalAPIKey = savedKey
        }

        // Load language from UserDefaults (Phase 3)
        language = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "auto"
    }

    private func validateAndSave() async {
        // User decision: auto-validate on save
        isValidating = true

        do {
            // Validate API key with Groq
            try await APIClient.shared.validateAPIKey(apiKey)

            // Save to Keychain
            try KeychainManager.shared.saveAPIKey(apiKey)

            // Save other settings to UserDefaults
            UserDefaults.standard.set(language, forKey: "selectedLanguage")

            // Close window
            NSApp.keyWindow?.close()
        } catch let error as APIError {
            // User decision: alert dialog on validation failure
            validationError = error.userMessage
            showValidationError = true
        } catch {
            validationError = "Unable to validate API key. Please check your internet connection."
            showValidationError = true
        }

        isValidating = false
    }
}
```

**Window Configuration** (AppKit):
```swift
func openSettings() {
    if settingsWindowController == nil {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "DictationApp Settings"
        window.styleMask = [.titled, .closable]  // No resize per user decision (fixed layout)
        window.setContentSize(NSSize(width: 500, height: 350))
        window.center()  // Center on screen

        // Floating window per user decision
        window.level = .floating
        window.isMovableByWindowBackground = true

        settingsWindowController = NSWindowController(window: window)
    }

    settingsWindowController?.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)  // Bring to front
}
```

---

### 5. API Key Validation Strategy

**User Decision**: Auto-validate on save, alert on failure, notify on first failed transcription (not app launch)

**Validation Approaches**:

**Option A: Test Transcription Endpoint**
```swift
// Make actual API call to transcriptions endpoint
// PRO: Tests exact endpoint we'll use
// CON: Requires audio file, slower, costs credits
```

**Option B: Test Models Endpoint** (Recommended)
```swift
func validateAPIKey(_ key: String) async throws {
    let url = URL(string: "https://api.groq.com/openai/v1/models")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
    }

    switch httpResponse.statusCode {
    case 200:
        // Valid API key
        return
    case 401:
        throw APIError.invalidAPIKey
    case 429:
        throw APIError.rateLimitExceeded
    default:
        throw APIError.serverError(httpResponse.statusCode)
    }
}
```
- ✅ Fast (GET request, no upload)
- ✅ Free (doesn't consume transcription credits)
- ✅ Tests authentication
- ✅ Validates key format and activation
- Source: [Groq API Reference](https://console.groq.com/docs/api-reference)

**Recommendation**: **Use models endpoint (Option B)** for validation

**Error Handling**:
```swift
enum APIError: LocalizedError {
    case invalidAPIKey
    case rateLimitExceeded
    case serverError(Int)
    case networkError(Error)
    case invalidResponse

    var userMessage: String {
        switch self {
        case .invalidAPIKey:
            return "The API key you entered is invalid. Please check your key at console.groq.com"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait a few minutes and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .networkError:
            return "Unable to connect to Groq API. Please check your internet connection."
        case .invalidResponse:
            return "Unexpected response from API. Please try again."
        }
    }
}
```

---

### 6. Launch at Login Implementation

**User Decisions**:
- Toggle in menu bar menu only (not settings window)
- No first-run prompt
- Show guidance to System Settings if macOS blocks

**macOS 13+ Approach (SMAppService)** - Recommended:
```swift
import ServiceManagement

class LoginItemManager {
    static let shared = LoginItemManager()

    private let service = SMAppService.mainApp

    func isEnabled() -> Bool {
        return service.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if service.status == .enabled {
                return  // Already enabled
            }

            do {
                try service.register()
            } catch {
                // User decision: show guidance if blocked
                showSystemSettingsGuidance()
                throw LoginItemError.registrationFailed
            }
        } else {
            if service.status == .notRegistered {
                return  // Already disabled
            }

            try service.unregister()
        }
    }

    private func showSystemSettingsGuidance() {
        let alert = NSAlert()
        alert.messageText = "Unable to Enable Launch at Login"
        alert.informativeText = """
        macOS blocked the request to launch at login.

        To enable manually:
        1. Open System Settings
        2. Go to General → Login Items
        3. Add DictationApp to "Open at Login"
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Open System Settings to Login Items
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
        }
    }
}

enum LoginItemError: LocalizedError {
    case registrationFailed

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Unable to register login item"
        }
    }
}
```
- ✅ Modern API (macOS 13+)
- ✅ User-controlled (system manages it)
- ✅ No helper app needed
- Source: [Apple - SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)

**Menu Bar Toggle Implementation**:
```swift
@objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
    let manager = LoginItemManager.shared
    let currentState = manager.isEnabled()

    do {
        try manager.setEnabled(!currentState)

        // User decision: reflect actual system state
        sender.state = manager.isEnabled() ? .on : .off
    } catch {
        // Show error but don't change toggle state
        let alert = NSAlert()
        alert.messageText = "Unable to Change Launch at Login"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
```

**macOS 12 Fallback** (if needed):
- Use LSSharedFileList (deprecated but functional on macOS 12)
- Phase 1 can skip this if macOS 13+ deployment target is acceptable
- Source: [Stack Overflow - Launch at Login](https://stackoverflow.com/questions/26877701/how-to-launch-app-at-login-start-on-mac-os-x)

**Recommendation**: **Use SMAppService** (macOS 13+ only)
- Aligns with macOS 14.0 deployment target from stack decision
- User decision to show System Settings guidance handles blocked cases
- Simpler, more reliable than legacy approaches

---

### 7. SF Symbol Selection for Menu Bar Icon

**User Decision**: SF Symbol for icon, matches system aesthetic

**Candidate Symbols**:

| Symbol | Appearance | Meaning | Recommendation |
|--------|------------|---------|----------------|
| `waveform` | ∿∿∿ | Audio waveform | ⭐ **Best** - clearly audio-related |
| `waveform.circle` | (∿∿∿) | Waveform in circle | Good but might be too large |
| `mic` | 🎤 | Microphone | Good but generic |
| `mic.circle` | (🎤) | Microphone in circle | Too large for menu bar |
| `text.bubble` | 💬 | Speech bubble | Good for transcription concept |
| `text.microphone` | 📝🎤 | Text + microphone | Too detailed for menu bar |

**Recommendation**: **`waveform`**
- Clean, recognizable at menu bar size (16-22pt)
- Clearly audio-related
- Works well in both light and dark mode (template image)
- Distinct from other menu bar icons

**Icon State Changes** (User Decision: recording status via icon change):
```swift
enum MenuBarIconState {
    case idle
    case recording
    case processing

    var symbol: String {
        switch self {
        case .idle:
            return "waveform"
        case .recording:
            return "waveform.circle.fill"  // Filled = active
        case .processing:
            return "ellipsis.circle"  // Processing indicator
        }
    }

    var tint: NSColor? {
        switch self {
        case .idle:
            return nil  // System default
        case .recording:
            return .systemRed  // Red = recording
        case .processing:
            return nil
        }
    }
}

func updateMenuBarIcon(state: MenuBarIconState) {
    guard let button = statusItem?.button else { return }

    button.image = NSImage(systemSymbolName: state.symbol, accessibilityDescription: "Dictation")
    button.image?.isTemplate = state.tint == nil  // Template adapts to light/dark
    button.contentTintColor = state.tint
}
```

---

## Known Pitfalls (Phase 1 Specific)

### Pitfall 1: Menu Bar Icon Hidden by Notch

**Problem**: MacBook Pro notch can hide menu bar icons if too many apps installed.
**Source**: [Jesse Squires - MacBook notch fixes](https://www.jessesquires.com/blog/2023/12/16/macbook-notch-and-menu-bar-fixes/)

**Prevention**:
- Use SF Symbol (scales properly)
- Keep icon simple (waveform, not complex graphic)
- Test on MacBook Pro with notch + many menu bar apps
- User can always access via hotkey if icon hidden

### Pitfall 2: Settings Window State Corruption

**Problem**: Settings values out of sync if window closed without Save/Cancel.

**Prevention** (User Decision: explicit save behavior):
```swift
// Track original values on window open
@State private var originalAPIKey: String = ""

// Restore on Cancel
Button("Cancel") {
    apiKey = originalAPIKey  // Discard changes
    NSApp.keyWindow?.close()
}

// Save on explicit Save button only
Button("Save") {
    // Validate and persist
}
```

### Pitfall 3: Keychain Access Fails Silently

**Problem**: Keychain calls can fail due to macOS security policies, no errors shown.

**Prevention**:
```swift
do {
    try KeychainManager.shared.saveAPIKey(apiKey)
} catch {
    // Show error to user
    let alert = NSAlert()
    alert.messageText = "Unable to Save API Key"
    alert.informativeText = "Keychain access was denied. Please check your security settings."
    alert.runModal()
}
```

### Pitfall 4: Launch at Login Silent Failures

**Problem**: SMAppService.register() can fail silently on some macOS versions.

**Prevention** (User Decision: show guidance if blocked):
```swift
do {
    try service.register()
} catch {
    // User decision: show System Settings guidance
    showSystemSettingsGuidance()
}

// Also verify state after registration
if service.status != .enabled {
    showSystemSettingsGuidance()
}
```

---

## Phase 1 Requirements Mapping

| Requirement | Implementation | Validation |
|-------------|----------------|------------|
| **SET-01**: Menu bar only (no dock) | `LSUIElement = true` in Info.plist | App launches, no dock icon, menu bar icon visible |
| **SET-02**: Enter Groq API key | SwiftUI SecureField in settings window | User can type key, see dots, save |
| **SET-03**: Secure storage | Keychain Services via KeychainAccess library | Key persists after quit, not in plist |
| **SET-04**: Settings accessible from menu | NSMenu with "Settings" item opens SwiftUI window | Click menu → Settings opens |
| **SET-05**: Launch at login | SMAppService toggle in menu bar menu | Toggle on → app launches after reboot |

---

## Dependencies for Phase 1

| Dependency | Version | Purpose | Installation |
|------------|---------|---------|--------------|
| **KeychainAccess** | 4.2.2+ | Simplified Keychain API | SPM: `https://github.com/kishikawakatsumi/KeychainAccess` |

**No other dependencies needed for Phase 1** - All features use native frameworks:
- AppKit (NSStatusItem, NSMenu, NSWindow)
- SwiftUI (Settings window)
- ServiceManagement (Launch at login)
- Security (Keychain, via KeychainAccess wrapper)

---

## Testing Strategy for Phase 1

### Unit Tests
```swift
class KeychainManagerTests: XCTestCase {
    func testSaveAndLoadAPIKey() {
        let testKey = "test-api-key-123"
        try? KeychainManager.shared.saveAPIKey(testKey)
        XCTAssertEqual(KeychainManager.shared.loadAPIKey(), testKey)
    }

    func testDeleteAPIKey() {
        try? KeychainManager.shared.saveAPIKey("test")
        try? KeychainManager.shared.deleteAPIKey()
        XCTAssertNil(KeychainManager.shared.loadAPIKey())
    }
}

class LoginItemManagerTests: XCTestCase {
    func testEnableDisableLaunchAtLogin() {
        let manager = LoginItemManager.shared
        try? manager.setEnabled(true)
        XCTAssertTrue(manager.isEnabled())
        try? manager.setEnabled(false)
        XCTAssertFalse(manager.isEnabled())
    }
}
```

### Manual Testing Checklist
- [ ] App launches with menu bar icon visible, no dock icon
- [ ] Click icon shows menu with all items (Settings, About, etc.)
- [ ] Settings window opens as floating window
- [ ] API key field shows dots (masked), accepts input
- [ ] Save button validates API key (test with invalid key)
- [ ] Valid API key saves to Keychain, persists after quit/relaunch
- [ ] Cancel button discards changes
- [ ] Launch at login toggle works (verify in System Settings)
- [ ] Menu bar icon changes state (test with placeholder states)
- [ ] Test on MacBook Pro with notch (icon visible or accessible)
- [ ] Test light/dark mode appearance

---

## Open Questions for Planning

### High Priority
1. **Exact API key validation timeout**: How long to wait before showing error?
   - Recommendation: 10 seconds (balance between patience and frustration)

2. **Settings window persistence**: Should window remember position between opens?
   - User decision: separate floating window
   - Recommendation: Center on first open, remember position if user moves it

3. **"Check for Updates" implementation**: Sparkle framework vs manual?
   - Defer to planning phase - not critical for Phase 1 core functionality

### Medium Priority
4. **About window content**: What info to show? (Version, credits, links?)
   - Standard: App name, version, copyright, GitHub/website link

5. **Keyboard shortcuts info**: Show in window or just menu?
   - Recommendation: Simple menu with text "Option+Space to toggle recording"

---

## Success Criteria for Phase 1

**User-Facing**:
1. User can find app in menu bar after launch
2. User can open settings from menu
3. User can enter API key and it saves securely
4. User can enable launch at login
5. App never appears in dock

**Technical**:
1. Info.plist configured correctly (LSUIElement, usage descriptions)
2. NSStatusItem created and responsive
3. SwiftUI settings window displays properly
4. Keychain storage working reliably
5. SMAppService integration functional
6. All Phase 1 requirements (SET-01 to SET-05) validated

**Quality Gates**:
1. No crashes on launch or settings interaction
2. Keychain errors handled gracefully
3. Menu bar icon visible on MacBook Pro with notch
4. Settings window follows user decisions (layout, save/cancel behavior)
5. Launch at login state reflects actual system state

---

## References

### Official Documentation
- [Apple - NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem)
- [Apple - SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [Apple - Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Apple - MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)

### Implementation Guides
- [sarunw.com - SwiftUI Menu Bar App](https://sarunw.com/posts/swiftui-menu-bar-app/)
- [Medium - Building macOS Menu Bar App](https://gaitatzis.medium.com/building-a-macos-menu-bar-app-with-swift)
- [nilcoalescing.com - MenuBarExtra Tutorial](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/)

### Security & Best Practices
- [Medium - Keychain vs UserDefaults](https://medium.com/@gauravharkhani01/app-security-in-swift-keychain-biometrics-secure-enclave-69359b4cffba)
- [jano.dev - Accessibility Permission](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)

### Pitfalls
- [Jesse Squires - MacBook Notch Fixes](https://www.jessesquires.com/blog/2023/12/16/macbook-notch-and-menu-bar-fixes/)
- [Apple Forums - Sandboxing & Accessibility](https://developer.apple.com/forums/thread/707680)

---

**Research Complete**: 2026-02-02
**Ready for Planning**: Yes
**Next Step**: Create 02-PLAN.md with detailed implementation tasks
