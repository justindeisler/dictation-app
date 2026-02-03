# Phase 5: Error Handling & Polish - Research

**Researched:** 2026-02-03
**Domain:** Error handling, notification systems, UX polish for macOS menu bar app
**Confidence:** HIGH

## Summary

Error handling in macOS menu bar apps requires careful balance between user awareness and notification spam prevention. The research reveals a three-tier approach: **immediate blocking errors** (NSAlert), **important async errors** (UNUserNotificationCenter with banners/alerts), and **silent recoverable errors** (logging only).

Current implementation already has excellent foundations: LocalizedError conformance for user-facing messages, UNUserNotificationCenter delegate infrastructure, and permission recovery workflows. Phase 5 focuses on surfacing errors at the right times with the right urgency levels, preventing notification spam through error coalescing, and visual polish of menu bar icon states.

**Primary recommendation:** Implement error categorization system that routes errors to appropriate presentation methods (NSAlert for blocking, notifications for async, silence for recoverable), with notification spam prevention through time-based coalescing and clear visual feedback in menu bar icon.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| UNUserNotificationCenter | macOS 10.14+ | User notifications | Standard Apple framework for notifications, replaces deprecated NSUserNotification |
| NSAlert | macOS 10.0+ | Modal error dialogs | Standard macOS UI pattern for immediate blocking errors |
| LocalizedError | Swift 5+ | User-facing error messages | Protocol for providing localized descriptions, recovery suggestions |
| AVFoundation | macOS 10.7+ | Microphone permission | Standard framework for audio permissions |
| ApplicationServices | macOS 10.0+ | Accessibility permission | Standard framework for AXIsProcessTrusted |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| UserDefaults | macOS 10.0+ | Error state tracking | Store last error timestamps for spam prevention |
| URLError | Foundation | Network error categorization | Standard network error types with built-in codes |
| AVCaptureDevice | AVFoundation | Permission status | Check/request microphone permission |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UNUserNotificationCenter | NSUserNotification (deprecated) | NSUserNotification deprecated in macOS 11+ |
| NSAlert | Custom popover | NSAlert provides consistent system UI and accessibility |
| LocalizedError | Plain Error with print() | LocalizedError provides structured user messages |

**Installation:**
```bash
# All frameworks are part of macOS SDK, no additional packages needed
```

## Architecture Patterns

### Recommended Error Handling Structure
```
Sources/
├── Models/
│   └── ErrorCategory.swift        # Error severity classification
├── Services/
│   ├── ErrorNotifier.swift        # Central error presentation logic
│   └── NotificationThrottler.swift # Spam prevention
└── Extensions/
    └── Error+UserMessage.swift    # Unified error message extraction
```

### Pattern 1: Error Categorization by Severity
**What:** Route errors to appropriate UI based on severity and blocking nature
**When to use:** All error handling throughout app
**Example:**
```swift
// Source: Research synthesis from Apple HIG and community patterns

enum ErrorSeverity {
    case blocking      // Prevents continued operation (NSAlert)
    case important     // User should know (UNNotification alert style)
    case informational // Non-critical (UNNotification banner style)
    case silent        // Log only (recoverable)
}

enum ErrorCategory {
    // Blocking errors - show NSAlert immediately
    case missingAPIKey              // ERR-03: App cannot function
    case microphonePermissionDenied // Cannot record

    // Important async errors - show notification alert
    case transcriptionFailed(reason: String) // ERR-01, ERR-02
    case networkUnavailable         // ERR-04
    case apiKeyInvalid              // After initial setup

    // Informational - banner notification
    case transcriptionSucceeded
    case pasteSucceeded

    // Silent - log only
    case emptyTranscription
    case clipboardWriteSuccess

    var severity: ErrorSeverity {
        switch self {
        case .missingAPIKey, .microphonePermissionDenied:
            return .blocking
        case .transcriptionFailed, .networkUnavailable, .apiKeyInvalid:
            return .important
        case .transcriptionSucceeded, .pasteSucceeded:
            return .informational
        case .emptyTranscription, .clipboardWriteSuccess:
            return .silent
        }
    }
}
```

### Pattern 2: Notification Spam Prevention with Time-Based Coalescing
**What:** Prevent multiple notifications for same error type within time window
**When to use:** All UNUserNotificationCenter notifications
**Example:**
```swift
// Source: Synthesized from Swift debouncing patterns and Apple notification guidelines

@MainActor
final class NotificationThrottler {
    private var lastNotificationTimes: [String: Date] = [:]
    private let minimumInterval: TimeInterval = 5.0  // 5 seconds between same error type

    func shouldShowNotification(category: String) -> Bool {
        let now = Date()

        if let lastTime = lastNotificationTimes[category] {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed < minimumInterval {
                print("Suppressing duplicate notification for \(category) (last shown \(elapsed)s ago)")
                return false
            }
        }

        lastNotificationTimes[category] = now
        return true
    }

    func reset(category: String) {
        lastNotificationTimes.removeValue(forKey: category)
    }
}
```

### Pattern 3: Unified Error Message Extraction
**What:** Extract user-facing messages consistently from any error type
**When to use:** All error presentation code
**Example:**
```swift
// Source: Swift by Sundell - Propagating user-facing errors in Swift

extension Error {
    var userMessage: String {
        // Prioritize LocalizedError conformance
        if let localizedError = self as? LocalizedError {
            return localizedError.errorDescription
                ?? localizedError.failureReason
                ?? self.localizedDescription
        }

        // Handle URLError specifically
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection. Please check your network."
            case .timedOut:
                return "Request timed out. Please try again."
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        }

        // Fallback to localized description
        return self.localizedDescription
    }

    var recoverySuggestion: String? {
        (self as? LocalizedError)?.recoverySuggestion
    }
}
```

### Pattern 4: Menu Bar Icon State Machine
**What:** Clear visual states for idle, recording, processing, error
**When to use:** All workflow state transitions
**Example:**
```swift
// Source: Current implementation extended with error/processing states

enum MenuBarIconState {
    case idle                    // Default state
    case recording              // Red recording indicator (existing)
    case processing             // Transcribing (animated or different color)
    case error                  // Transient error indication (e.g., yellow warning)

    var symbolName: String {
        switch self {
        case .idle: return "waveform"
        case .recording: return "waveform.circle.fill"
        case .processing: return "waveform.badge.ellipsis"
        case .error: return "waveform.badge.exclamationmark"
        }
    }

    var tintColor: NSColor? {
        switch self {
        case .idle: return nil  // Template mode
        case .recording: return .systemRed
        case .processing: return .systemBlue
        case .error: return .systemYellow  // Transient, returns to idle after 2s
        }
    }

    var isTemplate: Bool {
        self == .idle
    }
}
```

### Pattern 5: Error Context Preservation
**What:** Maintain full error context for debugging while showing friendly messages to users
**When to use:** All error handling, especially async operations
**Example:**
```swift
// Source: iOS Handbook - Best practices for error handling

func handleTranscriptionError(_ error: Error, audioURL: URL) {
    // Log full technical details for debugging
    print("Transcription failed for \(audioURL.lastPathComponent)")
    print("Error domain: \(error)")
    print("Error details: \(error.localizedDescription)")
    if let localizedError = error as? LocalizedError {
        print("Failure reason: \(localizedError.failureReason ?? "none")")
        print("Recovery suggestion: \(localizedError.recoverySuggestion ?? "none")")
    }

    // Show user-friendly message
    let userMessage = error.userMessage
    showNotification(title: "Transcription Failed", body: userMessage)

    // Update menu bar to indicate transient error
    updateMenuBarIcon(state: .error)

    // Reset to idle after 2 seconds
    Task {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        updateMenuBarIcon(state: .idle)
    }
}
```

### Anti-Patterns to Avoid
- **Notification Spam**: Don't show notification for every error without throttling - users will disable notifications
- **Vague Error Messages**: "Something went wrong" doesn't help users recover - always include specific reason
- **Mixed Error Channels**: Don't show blocking NSAlert for async errors - breaks workflow expectations
- **Permanent Error Icons**: Don't leave menu bar icon in error state forever - clear after 2-3 seconds
- **Silent Critical Errors**: Don't fail silently on missing API key or permissions - user needs to know
- **Technical Jargon**: Don't show developer messages to users (e.g., "URLError code -1009")

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Notification authorization | Custom permission manager | UNUserNotificationCenter.requestAuthorization | Handles system dialogs, settings integration, status tracking |
| Error localization | Manual string dictionaries | LocalizedError protocol | Framework-standard, NSLocalizedString compatible |
| Time-based throttling | Manual timer management | UserDefaults + Date comparison | Simple, persists across launches, no timers to manage |
| Permission status checking | Polling loops | AXIsProcessTrusted(), AVCaptureDevice.authorizationStatus | Synchronous, accurate, maintained by Apple |
| System Settings deep linking | Generic URL schemes | x-apple.systempreferences: URLs | Guaranteed to work across macOS versions |

**Key insight:** Apple frameworks handle complex edge cases like permission state changes, notification permission revocation, and system settings changes. Custom solutions miss these edge cases.

## Common Pitfalls

### Pitfall 1: Notification Spam from Repeated Errors
**What goes wrong:** User triggers same error multiple times rapidly (e.g., hotkey spam while network down), gets notification flood
**Why it happens:** No throttling between notifications, each error attempt triggers new notification
**How to avoid:** Implement time-based coalescing - same error category cannot trigger notification more than once per 5 seconds
**Warning signs:**
- Multiple identical notifications in Notification Center
- User reports "app keeps spamming me"
- Notifications appearing faster than user can read them

### Pitfall 2: Menu Bar Icon State Confusion
**What goes wrong:** Icon stays red after recording stops, or shows error state indefinitely
**Why it happens:** State transitions not properly managed, forgot to reset state after error
**How to avoid:**
- Use state machine pattern with explicit transitions
- Error states are transient (2-3 seconds) then return to idle
- Always pair state changes with corresponding reset logic
**Warning signs:**
- Icon color doesn't match app state
- Icon stuck in recording state after transcription complete
- No visual feedback when error occurs

### Pitfall 3: Blocking Errors in Async Context
**What goes wrong:** Show NSAlert modal from async transcription error, blocks unrelated operations
**Why it happens:** Confused blocking vs. async error handling
**How to avoid:**
- NSAlert only for blocking errors (missing API key, no permission)
- UNUserNotificationCenter for async errors (transcription failed, network timeout)
- User can continue working if error is async
**Warning signs:**
- Modal alert appears during background operations
- User cannot interact with other apps while alert showing
- Alert appears long after user action

### Pitfall 4: Missing Error Recovery Guidance
**What goes wrong:** User sees "Transcription failed" but doesn't know what to do
**Why it happens:** Error messages lack actionable recovery steps
**How to avoid:**
- Every error includes recovery suggestion (LocalizedError.recoverySuggestion)
- Network errors: "Check your internet connection"
- API key errors: "Verify API key in Settings"
- Permission errors: "Open System Settings → Privacy"
**Warning signs:**
- Users ask "what do I do now?" after error
- Support requests about error messages
- Users give up instead of recovering

### Pitfall 5: Vague Network Error Messages
**What goes wrong:** User sees "Network error" but actual cause is timeout, DNS failure, or no internet
**Why it happens:** Treating all URLError types identically
**How to avoid:**
- Check URLError.code specifically (.timedOut, .notConnectedToInternet, .networkConnectionLost)
- Provide specific guidance per error type
- Timeout: "Request timed out. Try again."
- No internet: "Check your internet connection."
- DNS failure: "Cannot reach API server."
**Warning signs:**
- Users report "network error" but internet is working
- Cannot distinguish between different network failures
- Users retry immediately without fixing underlying issue

### Pitfall 6: Notification Permission Not Handled
**What goes wrong:** App assumes notification permission granted, notifications never appear
**Why it happens:** Not checking authorization status before showing notification
**How to avoid:**
- Check UNUserNotificationCenter.current().notificationSettings().authorizationStatus
- Fallback to NSAlert if authorization is .denied or .notDetermined
- Request authorization early (app launch) not late (first error)
**Warning signs:**
- Transcription succeeds but no notification appears
- Errors fail silently
- Paste fallback notification never shows

## Code Examples

Verified patterns from research and current implementation:

### Example 1: Error-Specific Notification Content
```swift
// Source: Synthesized from APIError patterns and notification best practices

func createNotificationContent(for error: Error) -> UNNotificationContent {
    let content = UNMutableNotificationContent()

    if let apiError = error as? APIError {
        switch apiError {
        case .invalidAPIKey:
            content.title = "API Key Invalid"
            content.body = "Please check your API key in Settings"
            content.categoryIdentifier = "ERROR_API_KEY"

        case .networkError:
            content.title = "Network Error"
            content.body = "Unable to connect. Check your internet connection."
            content.categoryIdentifier = "ERROR_NETWORK"

        case .timeout:
            content.title = "Request Timed Out"
            content.body = "The transcription took too long. Try again with a shorter recording."
            content.categoryIdentifier = "ERROR_TIMEOUT"

        case .rateLimitExceeded:
            content.title = "Rate Limit Exceeded"
            content.body = "Too many requests. Please wait a moment and try again."
            content.categoryIdentifier = "ERROR_RATE_LIMIT"

        case .fileTooLarge(let size, let limit):
            let sizeMB = Double(size) / 1_000_000
            let limitMB = Double(limit) / 1_000_000
            content.title = "Audio File Too Large"
            content.body = String(format: "Recording is %.1f MB. Maximum is %.0f MB.", sizeMB, limitMB)
            content.categoryIdentifier = "ERROR_FILE_SIZE"

        default:
            content.title = "Transcription Failed"
            content.body = apiError.userMessage
            content.categoryIdentifier = "ERROR_GENERAL"
        }
    } else {
        content.title = "Error"
        content.body = error.userMessage
        content.categoryIdentifier = "ERROR_GENERAL"
    }

    content.sound = .default
    return content
}
```

### Example 2: Missing API Key Detection at Launch
```swift
// Source: Current SettingsView pattern extended for launch-time check

@MainActor
func checkAPIKeyAtLaunch() {
    // Check if API key exists on first hotkey use
    guard let apiKey = KeychainManager.shared.loadAPIKey(), !apiKey.isEmpty else {
        showMissingAPIKeyAlert()
        return
    }
}

private func showMissingAPIKeyAlert() {
    let alert = NSAlert()
    alert.messageText = "API Key Required"
    alert.informativeText = """
    DictationApp needs a Groq API key to transcribe your recordings.

    You can get a free API key from console.groq.com
    """
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Open Settings")
    alert.addButton(withTitle: "Get API Key")
    alert.addButton(withTitle: "Later")

    let response = alert.runModal()

    switch response {
    case .alertFirstButtonReturn:  // Open Settings
        // Open Settings window (existing method)
        NotificationCenter.default.post(name: .openSettings, object: nil)

    case .alertSecondButtonReturn: // Get API Key
        // Open Groq console in browser
        if let url = URL(string: "https://console.groq.com/keys") {
            NSWorkspace.shared.open(url)
        }

    default:
        break
    }
}
```

### Example 3: Enhanced TranscriptionManager Error Handling
```swift
// Source: Current TranscriptionManager extended with notification categories

func handleRecordingCompletion(audioURL: URL) async -> String? {
    let languagePreference = UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "auto"
    let language: String? = languagePreference == "auto" ? nil : languagePreference

    do {
        print("Starting transcription for: \(audioURL.lastPathComponent)")
        let result = try await APIClient.shared.transcribe(audioURL: audioURL, language: language)
        print("Transcription complete: \(result.text)")

        // Success notification
        NotificationCenter.default.post(
            name: .transcriptionDidComplete,
            object: result.text
        )

        return result.text

    } catch let error as APIError {
        print("Transcription failed: \(error.userMessage)")

        // Categorized error handling
        let errorCategory: String
        switch error {
        case .invalidAPIKey:
            errorCategory = "api_key"
        case .networkError, .timeout:
            errorCategory = "network"
        case .rateLimitExceeded:
            errorCategory = "rate_limit"
        case .fileTooLarge:
            errorCategory = "file_size"
        default:
            errorCategory = "general"
        }

        // Post categorized error notification
        NotificationCenter.default.post(
            name: .transcriptionDidFail,
            object: nil,
            userInfo: ["error": error, "category": errorCategory]
        )

        return nil

    } catch {
        print("Transcription failed: \(error.localizedDescription)")

        NotificationCenter.default.post(
            name: .transcriptionDidFail,
            object: nil,
            userInfo: ["error": error, "category": "unknown"]
        )

        return nil
    }
}
```

### Example 4: Graceful Network Unavailable Handling
```swift
// Source: Swift network reachability patterns + URLError handling

func checkNetworkAvailability() async -> Bool {
    // Lightweight check using HEAD request to Groq API
    guard let url = URL(string: "https://api.groq.com/openai/v1/models") else {
        return false
    }

    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"
    request.timeoutInterval = 5

    do {
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode != 0  // Any response means network available
        }
        return false
    } catch let error as URLError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            // Network definitely unavailable
            return false
        default:
            // Other errors might be server-side, assume network available
            return true
        }
    } catch {
        // Unknown error, assume network available
        return true
    }
}

// Use before transcription attempt
func attemptTranscription(audioURL: URL) async {
    // Check network first (ERR-04)
    guard await checkNetworkAvailability() else {
        showNetworkUnavailableNotification()
        return
    }

    // Proceed with transcription
    await handleRecordingCompletion(audioURL: audioURL)
}

private func showNetworkUnavailableNotification() {
    Task { @MainActor in
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "No Internet Connection"
        content.body = "Cannot transcribe without internet. Your recording is saved on your clipboard."
        content.categoryIdentifier = "ERROR_NETWORK"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }
}
```

### Example 5: Enhanced Menu Bar Icon State Updates
```swift
// Source: Current AppDelegate extended with processing/error states

func updateMenuBarIcon(state: MenuBarIconState) {
    guard let button = statusItem?.button else { return }

    let accessibilityDesc: String
    switch state {
    case .idle:
        accessibilityDesc = "Dictation"
    case .recording:
        accessibilityDesc = "Recording"
    case .processing:
        accessibilityDesc = "Transcribing"
    case .error:
        accessibilityDesc = "Error"
    }

    // Apply symbol and color based on state
    if state == .idle {
        // Template mode (adapts to menu bar)
        let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: accessibilityDesc)
        image?.isTemplate = true
        button.image = image
    } else {
        // Explicit color for non-idle states
        let config = NSImage.SymbolConfiguration(paletteColors: [state.tintColor ?? .controlAccentColor])
        if let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: accessibilityDesc)?
            .withSymbolConfiguration(config) {
            image.isTemplate = false
            button.image = image
        }
    }

    // Auto-reset error state to idle after 2 seconds
    if state == .error {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if button.image?.accessibilityDescription == "Error" {
                updateMenuBarIcon(state: .idle)
            }
        }
    }
}

// Workflow state transitions:
// 1. Hotkey pressed → .recording
// 2. Recording stopped → .processing
// 3. Transcription complete → .idle
// 4. Transcription error → .error (2s) → .idle
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSUserNotification | UNUserNotificationCenter | macOS 11 (2020) | Modern notification system with categories, actions, and better authorization |
| Print error messages | LocalizedError protocol | Swift 3 (2016) | Structured user-facing error messages with recovery suggestions |
| Global notification listeners | Typed NotificationCenter extensions | Swift 4+ | Type-safe notification names and payloads |
| Polling permission status | Synchronous permission checks | Always | AXIsProcessTrusted() is instant, no polling needed |
| Generic error dialogs | Error categorization by severity | Modern UX patterns | Right feedback mechanism for each error type |

**Deprecated/outdated:**
- **NSUserNotification**: Deprecated macOS 11+, replaced by UNUserNotificationCenter
- **Modal alerts for all errors**: Modern apps use notifications for async errors, reserve modals for blocking
- **"Something went wrong"**: Generic errors replaced by specific actionable messages

## Open Questions

### Question 1: Notification Permission Timing
- **What we know:** UNUserNotificationCenter requires authorization, can request at launch or first use
- **What's unclear:** Best UX for requesting notification permission - immediate at launch vs. just-in-time on first error
- **Recommendation:** Request at launch in AppDelegate.setupNotifications() - user expects notification from dictation app, early request prevents surprise permission dialog during first error

### Question 2: Error State Persistence
- **What we know:** Errors should be logged and shown to user
- **What's unclear:** Should we maintain error history (e.g., "show last 5 errors" menu item)?
- **Recommendation:** Start without history - errors are transient, user can see them in Notification Center if needed. Add history only if users request it.

### Question 3: Rate Limit Error Retry Strategy
- **What we know:** Groq API returns 429 for rate limits, should implement exponential backoff
- **What's unclear:** Should app automatically retry transcription after rate limit, or just notify user?
- **Recommendation:** Don't auto-retry for Phase 5 - show error notification with "Try again in a moment". Auto-retry adds complexity and user might not want automatic retry (uses API quota).

### Question 4: Menu Bar Icon Animation
- **What we know:** Processing state could use animation to show progress
- **What's unclear:** Is simple icon change sufficient, or should icon animate during transcription?
- **Recommendation:** Static icon changes are sufficient for Phase 5. Animation can be polish for future phase if users request it. Spinning/pulsing icons can be distracting in menu bar.

## Sources

### Primary (HIGH confidence)
- Current implementation: AudioRecorder.swift, TranscriptionManager.swift, AppDelegate.swift, PasteManager.swift, APIClient.swift, PermissionManager.swift, SettingsView.swift
- [Apple Developer: NSAlert Documentation](https://developer.apple.com/documentation/appkit/nsalert) - Alert styles and modal dialogs
- [Apple Developer: UNUserNotificationCenter Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) - Notification framework

### Secondary (MEDIUM confidence)
- [Swift by Sundell: Propagating user-facing errors in Swift](https://www.swiftbysundell.com/articles/propagating-user-facing-errors-in-swift/) - LocalizedError patterns
- [NSHipster: LocalizedError, RecoverableError, CustomNSError](https://nshipster.com/swift-foundation-error-protocols/) - Error protocol details
- [Kodeco: Push Notifications by Tutorials, Chapter 8](https://www.kodeco.com/books/push-notifications-by-tutorials/v2.0/chapters/8-handling-common-scenarios) - UNUserNotificationCenterDelegate patterns
- [DevFright: UserNotifications Framework Delegate Protocol](https://www.devfright.com/use-usernotifications-framework-delegate-protocol/) - Delegate method usage
- [Medium: What I Learned Building a Native macOS Menu Bar App](https://medium.com/@p_anhphong/what-i-learned-building-a-native-macos-menu-bar-app-eacbc16c2e14) - January 2026 real-world patterns
- [jano.dev: Accessibility Permission in macOS](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) - AXIsProcessTrusted patterns
- [Gannon Lawlor: Requesting macOS Privacy and Security Permissions](https://gannonlawlor.com/posts/macos_privacy_permissions/) - System Settings deep linking

### Tertiary (LOW confidence, flagged for validation)
- [Medium: Throttling & Debounce in Swift](https://medium.com/@estatnikov/throttling-debounce-in-swift-75e168178088) - Notification spam prevention patterns
- [SwiftLee: Optimizing your app for Network Reachability](https://www.avanderlee.com/swift/optimizing-network-reachability/) - Network availability checking
- [Medium: Handling Errors in the Network Layer in Swift](https://medium.com/@razipour1993/handling-errors-in-the-network-layer-in-swift-895f404d9126) - URLError handling patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All frameworks are standard Apple SDKs, proven patterns in current implementation
- Architecture patterns: HIGH - Error categorization and notification throttling are well-established patterns, menu bar states exist in current code
- Pitfalls: HIGH - Based on real-world issues from community reports and macOS UX guidelines
- Code examples: HIGH - Based on current implementation patterns extended with verified community patterns

**Research date:** 2026-02-03
**Valid until:** 90 days (stable macOS APIs, error handling patterns don't change rapidly)

**Critical implementation notes:**
1. **Notification spam prevention is critical** - roadmap explicitly calls out "notification spam" as Phase 5 pitfall
2. **Menu bar icon clarity is critical** - roadmap calls out "menu bar icon clarity" as Phase 5 pitfall
3. **Error categorization must route correctly** - blocking errors (missing API key) vs. async errors (transcription failed)
4. **All error types already exist** - APIError, AudioRecorderError, permission checks all implemented, just need surfacing
5. **UNUserNotificationCenter infrastructure complete** - delegate, categories, authorization all implemented in Phase 4
