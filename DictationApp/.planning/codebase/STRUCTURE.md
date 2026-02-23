# Codebase Structure

**Analysis Date:** 2026-02-23

## Directory Layout

```
DictationApp/
├── Sources/                            # All application source code
│   ├── App/                           # Application entry point and app delegate
│   │   ├── DictationAppApp.swift      # SwiftUI app structure, no main window
│   │   └── AppDelegate.swift          # Menu bar setup, notification routing, icon state
│   ├── Services/                      # Business logic and system integration
│   │   ├── AudioRecorder.swift        # AVAudioRecorder wrapper, 16kHz mono WAV
│   │   ├── TranscriptionManager.swift # Recording → API transcription pipeline
│   │   ├── APIClient.swift            # Groq Whisper API client with error handling
│   │   ├── HotkeyManager.swift        # Global hotkey (Option+Space) registration
│   │   ├── PasteManager.swift         # Clipboard + Cmd+V simulation, smart spacing
│   │   ├── PermissionManager.swift    # Microphone and accessibility permission checks
│   │   ├── KeychainManager.swift      # Secure API key storage
│   │   ├── ErrorNotifier.swift        # Error notification with throttling
│   │   ├── NotificationThrottler.swift# Rate limiting for error notifications
│   │   └── LoginItemManager.swift     # Launch at login using SMAppService
│   ├── Views/                         # SwiftUI views
│   │   └── SettingsView.swift         # API key input, language selection, save/cancel
│   └── Models/                        # Data structures
│       └── TranscriptionResult.swift  # Groq API response model { text: String }
├── DictationApp.entitlements          # Sandbox entitlements (audio-input, AppleEvents)
├── Info.plist                         # Bundle configuration, usage descriptions
├── DictationApp.xcodeproj/            # Xcode project file
└── build/                             # Build artifacts (gitignored)
```

## Directory Purposes

**Sources/:**
- Purpose: All application Swift source code, organized by function (App, Services, Views, Models)
- Contains: 14 Swift files totaling ~2000 LOC
- Key files: AppDelegate.swift (orchestration), APIClient.swift (external integration), PasteManager.swift (accessibility)

**Sources/App/:**
- Purpose: Application initialization and menu bar setup
- Contains: SwiftUI app entry point (DictationAppApp.swift) and main application delegate (AppDelegate.swift)
- Key files:
  - `DictationAppApp.swift`: @main entry point, no WindowGroup (menu bar only)
  - `AppDelegate.swift`: Menu bar icon management, notification routing, state machine for icon states

**Sources/Services/:**
- Purpose: Business logic, system integration, cross-app orchestration
- Contains: 10 singleton services for recording, transcription, API, permissions, UI automation, storage
- Key files:
  - `AudioRecorder.swift`: AVAudioRecorder initialization with Groq API audio format (16kHz mono PCM)
  - `TranscriptionManager.swift`: Orchestrates recording completion to API transcription with language support
  - `APIClient.swift`: HTTP client for Groq Whisper API, multipart form handling, status code mapping
  - `HotkeyManager.swift`: KeyboardShortcuts library integration for Option+Space global hotkey
  - `PasteManager.swift`: Accessibility API for smart spacing, CGEvent for Cmd+V simulation
  - `PermissionManager.swift`: AVCaptureDevice and AXIsProcessTrusted() permission checks
  - `KeychainManager.swift`: KeychainAccess library wrapper for secure API key storage
  - `ErrorNotifier.swift`: User notifications with category-based throttling
  - `NotificationThrottler.swift`: Per-category notification rate limiting (5s minimum interval)
  - `LoginItemManager.swift`: SMAppService for launch-at-login functionality

**Sources/Views/:**
- Purpose: User-facing SwiftUI interfaces
- Contains: Settings window with API key input and language preference
- Key files: `SettingsView.swift` (API key validation, language selection, form state management)

**Sources/Models/:**
- Purpose: Data structures for external API responses and internal types
- Contains: Single Codable struct for API response
- Key files: `TranscriptionResult.swift` (Groq API JSON response: { text: String })

**DictationApp.entitlements:**
- Purpose: Sandbox security entitlements for macOS app
- Contains: com.apple.security.device.audio-input (microphone access), com.apple.security.automation.apple-events (Cmd+V simulation)
- Generated: No (manually configured)
- Committed: Yes (required for app signing)

**Info.plist:**
- Purpose: App bundle metadata and permission descriptions
- Contains:
  - CFBundleVersion, CFBundleName (app identity)
  - LSUIElement: true (menu bar only, no Dock icon)
  - NSMicrophoneUsageDescription (permission prompt text)
  - NSAppleEventsUsageDescription (permission prompt text for paste)
  - CFBundleIdentifier (computed from Xcode build settings)
- Generated: No (source control)
- Committed: Yes (part of app configuration)

## Key File Locations

**Entry Points:**
- `Sources/App/DictationAppApp.swift`: SwiftUI app structure, invokes AppDelegate
- `Sources/App/AppDelegate.swift` (line 44): applicationDidFinishLaunching() triggers menu bar setup and hotkey registration

**Configuration:**
- `Info.plist`: App bundle metadata, permission prompt text
- `DictationApp.entitlements`: Sandbox entitlements required for audio and keyboard input
- `Sources/Services/KeychainManager.swift` (line 9): Hardcoded keychain service identifier "com.dictationapp.DictationApp"
- `Sources/Services/APIClient.swift` (lines 43, 47-61): API base URL and timeout configuration

**Core Logic:**
- `Sources/Services/AudioRecorder.swift`: 16kHz mono WAV recording setup
- `Sources/Services/TranscriptionManager.swift`: Recording → transcription pipeline
- `Sources/Services/APIClient.swift`: HTTP client with error classification
- `Sources/Services/HotkeyManager.swift`: Hotkey event routing and permission checks
- `Sources/Services/PasteManager.swift`: Accessibility API integration and keyboard simulation

**Testing:**
- No test files present (no XCTest targets in project)

## Naming Conventions

**Files:**
- Pattern: PascalCase.swift (ServiceName.swift, ViewController.swift)
- Examples: AudioRecorder.swift, TranscriptionManager.swift, SettingsView.swift, APIClient.swift
- Rationale: Standard Swift convention for class/struct names matching file names

**Directories:**
- Pattern: lowercase singular or plural (Services, Views, Models, App)
- Examples: Sources/Services/, Sources/Views/, Sources/Models/
- Rationale: Lowercase convention for directory names, plural for collections of multiple file types

**Functions:**
- Pattern: camelCase for public methods, camelCase with leading underscore for private
- Examples: `startRecording()`, `handleRecordingCompletion()`, `_setupMenuBar()`
- Rationale: Standard Swift convention for instance methods

**Variables:**
- Pattern: camelCase for properties, CONSTANT_CASE for constants (rare in Swift)
- Examples: `isRecording`, `recordingURL`, `apiKey`, `minimumInterval`
- Rationale: Swift standard conventions (properties lowercase, avoid all-caps)

**Types:**
- Pattern: PascalCase for classes, structs, enums
- Examples: `AudioRecorder`, `APIError`, `MenuBarIconState`, `TranscriptionResult`
- Rationale: Swift convention for type names

**Notifications:**
- Pattern: Extension on Notification.Name with camelCase property
- Examples: `.recordingDidStart`, `.recordingDidStop`, `.transcriptionDidComplete`, `.transcriptionDidFail`
- Rationale: Verb-noun pattern for state change notifications (didStart, didStop, didComplete, didFail)

**Error Types:**
- Pattern: PascalCase enum with associated values
- Examples: `APIError`, `AudioRecorderError`, `LoginItemError`
- Rationale: Swift convention for error types, associated values for context (serverError(Int), networkError(Error))

## Where to Add New Code

**New Feature:**
- Primary code: `Sources/Services/[FeatureName]Service.swift` (for services) or `Sources/Services/[Feature]Manager.swift` (for manager pattern)
- Tests: None currently (add to Tests/ directory with XCTest structure when adding test infrastructure)
- Pattern: Implement as @MainActor singleton with shared static property, post notifications to AppDelegate for UI updates

**New View or UI Component:**
- Implementation: `Sources/Views/[ComponentName].swift`
- Pattern: Use SwiftUI with @State for local state, inject services via constructor or @StateObject
- Styling: Match SettingsView pattern (Form.grouped, frame sizing, button bar with Cancel/Save buttons)

**New Service/Manager:**
- Implementation: `Sources/Services/[ServiceName].swift`
- Pattern: @MainActor singleton using private init(), static shared property, compartmentalize a specific concern
- Integration: Register observers in AppDelegate.swift during applicationDidFinishLaunching() if state changes need UI updates

**Utilities or Helpers:**
- Shared helpers: `Sources/Services/[HelperName].swift` for cross-service utilities
- Pattern: Static utility functions with clear responsibility boundaries
- Example: NotificationThrottler.swift for error notification rate limiting (could be extracted to generic throttler)

**New Error Types:**
- Location: Define in the service file that throws it (e.g., APIError in APIClient.swift)
- Pattern: Enum conforming to LocalizedError with errorDescription and optional userMessage property
- Example: APIError (lines 3-36 in APIClient.swift) with user-friendly messages for each case

**API Integration Changes:**
- File: `Sources/Services/APIClient.swift`
- Pattern: Modify validateAPIKey() for new validation endpoints, transcribe() for transcription payload changes
- Precaution: Maintain separate URLSession instances for validation (10s) vs transcription (60s) requests

**Permission or System Integration:**
- File: `Sources/Services/PermissionManager.swift` for system permissions, create new service file for other system integrations
- Pattern: Check permission status, request if needed, show guidance alert with link to System Settings if denied
- Example: Add web camera permission following microphone pattern

**Menu Bar Items or Actions:**
- File: `Sources/App/AppDelegate.swift` (setupMenuBar(), handler methods)
- Pattern: Add NSMenuItem to menu array, implement @objc handler method
- Example: Add "Recent Transcriptions" submenu with menu item bindings

**State Enum or Complex Constant:**
- File: `Sources/App/AppDelegate.swift` or service file that uses it
- Pattern: Define enum near where it's used with computed properties for symbol names, colors, etc.
- Example: MenuBarIconState enum (lines 8-35 in AppDelegate.swift)

**Event Notifications:**
- File: Define in relevant service or AppDelegate using Notification.Name extension
- Pattern: Use verb+noun naming (.recordingDidStart, .transcriptionDidComplete), post with relevant object/userInfo
- Subscription: Add observers in AppDelegate.setupXxxObservers() during initialization

## Special Directories

**build/:**
- Purpose: Xcode build output and derived data
- Generated: Yes (created during build process)
- Committed: No (.gitignored)
- Contains: SourcePackages/, products/, intermediate build artifacts

**.planning/:**
- Purpose: Claude Code planning and codebase analysis documents
- Generated: Yes (generated by Claude Code /gsd commands)
- Committed: Yes (checked into version control)
- Contains: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md, STACK.md, INTEGRATIONS.md

**.claude/:**
- Purpose: Claude Code user instructions and configuration
- Generated: No (user-created)
- Committed: Yes (project-specific overrides to global ~/.claude/ instructions)
- Contains: Custom personas, flags, patterns specific to this project

**DictationApp.xcodeproj/:**
- Purpose: Xcode project configuration and workspace metadata
- Generated: Yes (managed by Xcode)
- Committed: Yes (required for building)
- Contains: project.pbxproj, xcschemes, user data, build settings

---

*Structure analysis: 2026-02-23*
