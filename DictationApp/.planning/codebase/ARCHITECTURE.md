# Architecture

**Analysis Date:** 2026-02-23

## Pattern Overview

**Overall:** Layered architecture with clear service separation, singleton pattern for cross-app services, and notification-driven state synchronization.

**Key Characteristics:**
- Separation of concerns: UI, business logic, system integration, and external services clearly isolated
- Notification center for asynchronous event communication between services
- Singleton services for centralized management and MainActor isolation for thread safety
- Menu bar application architecture with minimal UI footprint (no main windows at launch)

## Layers

**Application Layer:**
- Purpose: Entry point, app state initialization, top-level orchestration
- Location: `Sources/App/`
- Contains: App delegate, SwiftUI app entry point, menu bar setup
- Depends on: All service and model layers
- Used by: System (macOS app runtime)

**Service Layer:**
- Purpose: Cross-cutting concerns and business logic orchestration
- Location: `Sources/Services/`
- Contains: AudioRecorder, TranscriptionManager, APIClient, PasteManager, PermissionManager, KeychainManager, HotkeyManager, ErrorNotifier, LoginItemManager, NotificationThrottler
- Depends on: Model layer, external frameworks (AVFoundation, AppKit, UserNotifications, ServiceManagement)
- Used by: App delegate, other services, views

**UI/Presentation Layer:**
- Purpose: User-facing views and settings interface
- Location: `Sources/Views/`
- Contains: SettingsView
- Depends on: Service layer (for validation and persistence)
- Used by: App delegate

**Model Layer:**
- Purpose: Data structures for API responses and internal state
- Location: `Sources/Models/`
- Contains: TranscriptionResult (API response model)
- Depends on: Foundation (Codable protocol)
- Used by: Service layer, API client

## Data Flow

**Recording → Transcription → Paste Workflow:**

1. User presses Option+Space hotkey (HotkeyManager)
2. HotkeyManager.handleHotkeyPressed() checks: API key exists, microphone permission granted
3. AudioRecorder.startRecording() initializes AVAudioRecorder with 16kHz mono WAV settings
4. User speaks into microphone, audio captured to temp file
5. User presses hotkey again to stop recording
6. AudioRecorder.stopRecording() saves WAV file to temp directory, posts `recordingDidStop` notification
7. TranscriptionManager.handleRecordingCompletion() triggered asynchronously:
   - Gets language preference from UserDefaults
   - Posts `transcriptionWillStart` notification (menu bar icon → .processing)
   - Calls APIClient.transcribe() with audio file
8. APIClient.transcribe() performs:
   - File validation and size check (max 25MB)
   - Loads API key from Keychain
   - Creates multipart form request with audio, model, optional language
   - POSTs to Groq API /audio/transcriptions endpoint
   - Decodes TranscriptionResult JSON response
9. Success path:
   - TranscriptionManager posts `transcriptionDidComplete` with text
   - AppDelegate.handleTranscriptionComplete() triggered:
     - Updates menu bar icon to .idle
     - Calls PasteManager.pasteText(text)
   - PasteManager.pasteText():
     - Trims whitespace
     - Applies smart spacing via Accessibility API
     - Writes to clipboard (NSPasteboard)
     - Simulates Cmd+V keystroke using CGEvent
     - Falls back to notification if paste simulation fails
10. Error path:
    - APIClient throws APIError (invalidAPIKey, networkError, timeout, rateLimitExceeded, fileTooLarge, serverError, invalidResponse)
    - TranscriptionManager posts `transcriptionDidFail` with APIError
    - AppDelegate.handleTranscriptionFailed() triggered:
      - Updates menu bar icon to .error (auto-resets to .idle after 2s)
      - Calls ErrorNotifier.showTranscriptionError()
    - ErrorNotifier applies throttling via NotificationThrottler and shows user notification

**State Management:**
- Recording state: `AudioRecorder.isRecording` boolean property
- API key state: Stored in macOS Keychain (KeychainManager), checked at hotkey press time
- Language preference: Stored in UserDefaults["transcriptionLanguage"]
- Launch at login state: Stored in system SMAppService registration
- Error notification throttling: Tracked in NotificationThrottler.lastNotificationTimes dictionary
- Menu bar icon state: Enum (idle, recording, processing, error) with automatic reset for transient states

## Key Abstractions

**AudioRecorder:**
- Purpose: Encapsulates AVAudioRecorder with specific audio format settings for Groq API compatibility
- Examples: `Sources/Services/AudioRecorder.swift`
- Pattern: Singleton with state tracking (isRecording, recordingURL), error type encapsulation (AudioRecorderError)

**TranscriptionManager:**
- Purpose: Orchestrates recording completion to API transcription pipeline with language support and error handling
- Examples: `Sources/Services/TranscriptionManager.swift`
- Pattern: Singleton with notification emission for state changes, language preference retrieval from UserDefaults

**APIClient:**
- Purpose: Handles all Groq API communication with specific timeout handling, error classification, and file validation
- Examples: `Sources/Services/APIClient.swift`
- Pattern: Singleton with separate URLSession instances for validation (10s timeout) and transcription (60s timeout), error enum with user-friendly messages

**PasteManager:**
- Purpose: Bridges transcribed text to application clipboard and simulates keyboard input with smart spacing
- Examples: `Sources/Services/PasteManager.swift`
- Pattern: Singleton using Accessibility API for focused element detection and cursor positioning, CGEvent for keyboard simulation, fallback to notifications

**HotkeyManager:**
- Purpose: Global hotkey registration and workflow orchestration triggering recording, transcription, and paste
- Examples: `Sources/Services/HotkeyManager.swift`
- Pattern: Singleton using KeyboardShortcuts framework, permission checks before operation, notification emission for state changes

**PermissionManager:**
- Purpose: Centralized microphone and accessibility permission checking with user guidance flows
- Examples: `Sources/Services/PermissionManager.swift`
- Pattern: Singleton managing AVCaptureDevice authorization and Accessibility API checks with helpful alert guidance to system settings

**ErrorNotifier:**
- Purpose: Categorized error notification with throttling to prevent spam and user-friendly error messages
- Examples: `Sources/Services/ErrorNotifier.swift`
- Pattern: Singleton delegating to NotificationThrottler, category-based error handling, uses APIError.userMessage for display

**KeychainManager:**
- Purpose: Secure credential storage for Groq API key using macOS Keychain
- Examples: `Sources/Services/KeychainManager.swift`
- Pattern: Singleton using KeychainAccess library, service identifier tied to app bundle ID

**NotificationThrottler:**
- Purpose: Rate limiting for error notifications by category to prevent user fatigue from repeated errors
- Examples: `Sources/Services/NotificationThrottler.swift`
- Pattern: Singleton tracking last notification time per category with 5-second minimum interval

**MenuBarIconState:**
- Purpose: State machine for menu bar icon visual representation
- Examples: `Sources/App/AppDelegate.swift` (lines 8-35)
- Pattern: Enum with computed properties for symbol names and tint colors, state-specific auto-reset behavior for transient states

## Entry Points

**Application Launch:**
- Location: `Sources/App/DictationAppApp.swift`
- Triggers: macOS app runtime on user launch or login-item auto-start
- Responsibilities: SwiftUI app structure definition, app delegate connection, settings window configuration

**Hotkey Press (Option+Space):**
- Location: `Sources/Services/HotkeyManager.swift` (line 35: setupHotkey())
- Triggers: User presses registered keyboard shortcut
- Responsibilities: Recording toggle, permission checks, transcription trigger, error handling for missing API key

**App Delegate Initialization:**
- Location: `Sources/App/AppDelegate.swift` (line 44: applicationDidFinishLaunching)
- Triggers: App startup after SwiftUI initialization
- Responsibilities: Menu bar setup, notification center observers registration, accessibility permission request, hotkey registration

**Settings Window:**
- Location: `Sources/Views/SettingsView.swift`
- Triggers: User clicks Settings menu item
- Responsibilities: API key input and validation, language preference selection, settings persistence

## Error Handling

**Strategy:** Multi-layer error handling with specific error types for different domains, user-friendly notification display with throttling, and fallback mechanisms for paste operations.

**Patterns:**

**AudioRecorderError (enum):**
- Used in: `AudioRecorder.startRecording()`
- Types: invalidURL, failedToStart, permissionDenied
- Behavior: Thrown as Swift errors with localized descriptions

**APIError (enum):**
- Used in: `APIClient.validateAPIKey()`, `APIClient.transcribe()`
- Types: invalidAPIKey, rateLimitExceeded, serverError(Int), networkError(Error), invalidResponse, timeout, fileTooLarge(size, limit)
- Behavior: Maps HTTP status codes to specific errors, includes `userMessage` property for user-facing display, wraps URLError for network-specific handling

**LoginItemError (enum):**
- Used in: `LoginItemManager.setEnabled()`
- Types: registrationFailed, unregistrationFailed
- Behavior: Thrown when SMAppService registration fails with guidance prompt to system settings

**Error Propagation Pattern:**
- Recording errors: Caught at HotkeyManager level, logged, UI not updated (silent fail)
- API errors: Caught at TranscriptionManager level, wrapped in notification center post to AppDelegate
- Permission errors: Caught at PermissionManager level, triggers user guidance alert with link to system settings
- Paste simulation errors: Caught at PasteManager level, falls back to notification with manual copy-paste instructions

**Recovery Mechanisms:**
- Network errors: TranscriptionManager posts error to ErrorNotifier, user can retry by recording again
- Invalid API key: HotkeyManager checks before recording, AppDelegate shows blocking alert with link to console.groq.com
- Paste simulation failure: PasteManager writes to clipboard as guaranteed fallback, shows notification with manual instructions
- Missing microphone permission: PermissionManager shows guidance alert with link to System Settings → Privacy & Security → Microphone
- Missing accessibility permission: PermissionManager shows guidance alert with link to System Settings → Privacy & Security → Accessibility

## Cross-Cutting Concerns

**Logging:** Print statements throughout services for debugging (AudioRecorder, TranscriptionManager, APIClient, PasteManager, ErrorNotifier). No structured logging framework in use.

**Validation:**
- API key: Validated in settings via APIClient.validateAPIKey() before saving
- Audio file: Size checked before transcription (max 25MB)
- Permissions: Checked at every operation (microphone at recording start, accessibility at paste time)
- Focused element: Accessibility API checks before attempting smart spacing or paste simulation

**Authentication:**
- API key management: Stored in macOS Keychain via KeychainManager, loaded per transcription request
- Bearer token: API key included in Authorization header for all Groq API requests
- Accessibility trust: Checked via AXIsProcessTrusted() before paste simulation

**State Coordination:**
- Recording state: Boolean on AudioRecorder singleton
- Transcription state: Notification center posts for state transitions (willStart, didComplete, didFail)
- Menu bar icon state: AppDelegate observes transcription and recording notifications, updates icon with state machine
- Permission state: Checked at operation time, not cached (ensures up-to-date system state)

**Notification Center Patterns:**
- Recording lifecycle: `recordingDidStart`, `recordingDidStop` (with audioURL)
- Transcription lifecycle: `transcriptionWillStart`, `transcriptionDidComplete` (with text), `transcriptionDidFail` (with error in userInfo)
- Subscribe in: AppDelegate.setupRecordingStateObservers(), AppDelegate.setupTranscriptionObservers(), HotkeyManager.handleHotkeyPressed()

---

*Architecture analysis: 2026-02-23*
