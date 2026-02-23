# External Integrations

**Analysis Date:** 2025-02-23

## APIs & External Services

**Speech-to-Text:**
- Groq Whisper API - Cloud-based audio transcription
  - SDK/Client: Custom implementation via URLSession in `APIClient.swift`
  - Auth: API key stored in macOS Keychain (`groq_api_key`)
  - Base URL: `https://api.groq.com/openai/v1`
  - Endpoints:
    - `GET /models` - API key validation (10s timeout)
    - `POST /audio/transcriptions` - Audio transcription (60s timeout)
  - Model: `whisper-large-v3-turbo` (TRX-02)
  - Input format: WAV, 16kHz mono, max 25MB (free tier limit)
  - Output format: JSON with `text` field containing transcription
  - Language support: Auto-detection or explicit language codes (e.g., "en", "de")
  - Error handling:
    - 401: Invalid API key
    - 429: Rate limit exceeded
    - 413/other: Server errors with HTTP status codes
    - Network errors with timeout handling

**Console & Configuration:**
- Groq Console - Web interface for API key management
  - URL: `https://console.groq.com/keys`
  - Purpose: User obtains and manages API credentials
  - Linked from: Settings view and missing API key alert

## Data Storage

**Credentials Storage:**
- macOS Keychain (built-in secure storage)
  - Service identifier: `com.dictationapp.DictationApp`
  - Stores: Groq API key (`groq_api_key` key)
  - Client: KeychainAccess library
  - Access: `KeychainManager.swift` singleton
  - Scope: Per-user system keychain

**File Storage:**
- Local filesystem only (no cloud storage)
  - Temporary audio files: `FileManager.default.temporaryDirectory`
  - Format: WAV (16kHz mono PCM)
  - Cleanup: Files deleted by OS or application
  - User Defaults: Settings and preferences
    - `transcriptionLanguage` - Language preference ("auto" or language code)
    - Stored by: SettingsView via `@AppStorage`

**Caching:**
- None - Direct API calls without intermediate caching layer
- URLSession default caching applies to HTTP responses

## Authentication & Identity

**Auth Provider:**
- Custom API key authentication with Groq
  - Implementation: Bearer token in Authorization header
  - Format: `Authorization: Bearer <api_key>`
  - Validation endpoint: `GET /models` (returns 401 if invalid)
  - Storage: macOS Keychain via KeychainAccess
  - UI: SettingsView for API key input and validation

**Session Management:**
- Two URLSession configurations in `APIClient`:
  - `session`: 10s timeout for validation requests
  - `transcriptionSession`: 60s timeout for transcription (audio processing delay)
- Both use default URLSessionConfiguration
- No persistent session tokens

## Monitoring & Observability

**Error Tracking:**
- None - No external error tracking service (Sentry, etc.)
- Local error handling via:
  - Console logging: `print()` statements throughout
  - Notifications: User-facing error alerts via UserNotifications
  - Menu bar icon: Visual error indicator (yellow waveform)

**Logs:**
- Console output only (via `print()`)
- No persistent logging infrastructure
- Logs available via Xcode console or Console.app

**Notification Infrastructure:**
- macOS User Notifications (UNUserNotificationCenter)
  - Transcription ready notifications
  - Error notifications with throttling
  - Requires user permission at launch
  - Categories defined in `AppDelegate.setupNotifications()`

## CI/CD & Deployment

**Hosting:**
- Self-hosted macOS application (menu bar app)
- Distribution via direct .app bundle download or App Store (future)
- No backend servers or cloud deployment

**CI Pipeline:**
- None configured - Manual builds via Xcode
- Build system: Xcode (Swift compiler + linker)
- Code signing: Required for distribution (Hardened Runtime entitlements)
- Notarization: Required for distribution outside App Store

**Build Requirements:**
- Swift 6.0 compiler
- macOS deployment target: 14.0+
- Frameworks: AppKit, SwiftUI, AVFoundation, ApplicationServices, UserNotifications

## Environment Configuration

**Required env vars:**
- None - No environment variables used
- API key stored in Keychain, not environment

**API Endpoint Configuration:**
- Groq API: Hardcoded base URL `https://api.groq.com/openai/v1` in `APIClient.swift:43`
- No environment-specific switching (dev/staging/prod)
- No configuration file support

**Secrets location:**
- macOS Keychain (system-level encryption)
- Service: `com.dictationapp.DictationApp`
- Scope: Per-user, per-machine
- No backup or sync with iCloud Keychain

**Permissions Required:**
- Microphone (via `NSMicrophoneUsageDescription` in Info.plist)
- AppleEvents (via `NSAppleEventsUsageDescription` in Info.plist)
- Accessibility (via system request at launch)
- Notifications (optional, requested at launch)

## Webhooks & Callbacks

**Incoming:**
- None - No webhooks received by the application

**Outgoing:**
- None - Unidirectional API calls to Groq only
- No callback URLs or event subscriptions

**Internal Communication:**
- NotificationCenter-based events for internal coordination:
  - `transcriptionWillStart` - Transcription processing begins
  - `transcriptionDidComplete` - Transcription succeeded (text passed as object)
  - `transcriptionDidFail` - Transcription failed (error in userInfo)
  - `recordingDidStart` - Recording started
  - `recordingDidStop` - Recording stopped (URL in object)

## System Integration

**Accessibility API:**
- Query focused text element (via `AXUIElementCreateSystemWide()`)
- Retrieve text before cursor for smart spacing
- Simulate Cmd+V paste via CGEvent
- Files: `PasteManager.swift` (lines 99-204)

**Global Hotkeys:**
- KeyboardShortcuts library: Option+Space for toggle recording
- Registered via `HotkeyManager.setupHotkey()`
- Works across all applications

**Login Item Management:**
- SMAppService (macOS 13.0+) for launch-at-login
- Managed by: `LoginItemManager.swift`
- Controlled via menu bar toggle

**Menu Bar Integration:**
- NSStatusBar for menu bar presence
- Automatic icon state management
- Menu with Settings, About, Shortcuts, Launch at Login, Quit

---

*Integration audit: 2025-02-23*
