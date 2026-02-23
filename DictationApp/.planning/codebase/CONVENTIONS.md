# Coding Conventions

**Analysis Date:** 2025-02-23

## Naming Patterns

**Files:**
- PascalCase for Swift files: `AppDelegate.swift`, `TranscriptionManager.swift`, `APIClient.swift`
- Logical grouping by feature domain: `Services/`, `Models/`, `Views/`, `App/`
- One class/struct per file as primary type

**Functions:**
- camelCase for all functions and methods: `validateAPIKey()`, `startRecording()`, `pasteText()`
- Verb-first naming for actions: `handleRecordingStarted()`, `loadCurrentSettings()`, `setupHotkey()`
- Objective description following verb: `showMissingAPIKeyAlert()`, `requestMicrophonePermission()`
- Private methods marked with `private` keyword: All internal logic methods are private

**Variables:**
- camelCase for properties and local variables: `isRecording`, `apiKey`, `statusItem`
- Descriptive names with type hints: `recordingURL`, `minimumInterval`, `lastNotificationTimes`
- Underscore prefix avoided; instead use `private` modifiers for internal state

**Types:**
- PascalCase for classes, structs, enums: `AudioRecorder`, `APIError`, `PermissionStatus`
- Enum cases in camelCase: `.granted`, `.denied`, `.notDetermined`, `.processing`
- Protocol suffix avoided (not `RecordingDelegate`, just descriptive names)
- Error types explicitly suffixed with `Error`: `APIError`, `AudioRecorderError`, `LoginItemError`

## Code Style

**Formatting:**
- 4-space indentation throughout
- No SwiftLint/formatting tool detected in project configuration
- Consistent brace placement (opening brace on same line)
- MARK comments used for section organization: `// MARK: - Public API`, `// MARK: - Clipboard Operations`

**Linting:**
- No active linting configuration detected (no .swiftlint.yml in main project)
- Testability enabled in Xcode: `ENABLE_TESTABILITY = YES`
- Code follows Swift standard style conventions by convention

## Import Organization

**Order:**
1. Foundation framework (first, most common)
2. Apple system frameworks (AppKit, AVFoundation, SwiftUI, UserNotifications, etc.)
3. Third-party frameworks (KeychainAccess, KeyboardShortcuts)

**Examples:**
```swift
import Foundation
import AVFoundation
import UserNotifications

import KeychainAccess
```

**Path Aliases:**
- No custom import aliases detected
- Direct imports used throughout

## Error Handling

**Patterns:**
- Custom error enums adopting `LocalizedError` protocol: `APIError`, `AudioRecorderError`, `LoginItemError`
- `userMessage` computed property on error enums for user-facing text (see `APIError.userMessage`)
- Errors explicitly categorized: `.invalidAPIKey`, `.networkError(Error)`, `.timeout`, `.fileTooLarge`
- Associated values for context-rich errors: `.networkError(Error)`, `.serverError(Int)`, `.fileTooLarge(size:, limit:)`

**Error Propagation:**
- Async/await with `try` used throughout: `try await APIClient.shared.transcribe(...)`
- `do/catch` blocks with type-specific error handling (see `TranscriptionManager.handleRecordingCompletion()`)
- Errors converted to user-friendly notifications via `ErrorNotifier.showTranscriptionError()`
- Silent failures guarded: Empty transcriptions logged but not shown (`// Skip empty transcriptions silently`)

**Error Recovery:**
- Network errors differentiate between specific conditions (timeout vs. no connection)
- File size validation before API call prevents failed requests
- Fallback strategies: Paste simulation fails gracefully, text remains on clipboard
- Accessibility permission defensive checks before operations

## Logging

**Framework:** `print()` for all logging (no Logger framework detected)

**Patterns:**
- Informational logs on key operations: `print("Starting transcription for: \(audioURL.lastPathComponent)")`
- Error logs with context: `print("Transcription failed: \(error.userMessage)")`
- Debug output for file paths: `print("Recording stopped. File saved to: \(recordingURL.path)")`
- Completion confirmations: `print("Recording started..."), print("Text pasted successfully...")`
- Minimal logging in production paths (not verbose)

**Structured Data:**
- No structured logging (all print-based)
- User-friendly messages extracted to error types, not logged directly

## Comments

**When to Comment:**
- Section markers for code organization: `// MARK: - Public API`, `// MARK: - Microphone Permission`
- Tricky logic explanations: Comments explain *why*, not what code does
- API specification details: `// Virtual key code 9 = V key`, `// 25 MB limit for Groq free tier`
- Integration points with requirements: `// Phase 4 paste integration`, `// TRX-01: Transcription flow`

**JSDoc/TSDoc:**
- Standard Swift documentation comments (triple-slash `///`) on public APIs
- Example from `APIClient.validateAPIKey()`:
```swift
/// Validates API key by calling the models endpoint (fast, free)
func validateAPIKey(_ key: String) async throws
```
- Parameter documentation: `/// - Parameters: ... - language: Optional language code (e.g., "en", "de")`
- Return value documentation: `/// - Returns: TranscriptionResult containing the transcribed text`
- Error documentation: `/// - Throws: AudioRecorderError if recording cannot start`

## Function Design

**Size:**
- Compact functions (30-50 lines typical maximum)
- Larger functions broken into logical sections with MARK comments
- Example: `APIClient.transcribe()` at 90 lines organized with clear sections

**Parameters:**
- Minimal parameters (usually 1-3)
- Named parameters for clarity (no positional-only params)
- Type annotations always present
- Default values used sparingly: `language: String?` for optional parameter

**Return Values:**
- Explicit return types on all functions
- `async` for long-running operations (API calls, permissions)
- `throws` for error-prone operations
- `@discardableResult` on functions whose return value may be ignored

## Module Design

**Exports:**
- All types are public/available for use by default
- Private properties and methods marked with `private` keyword
- Services use singleton pattern: `static let shared = APIClient()`
- No package/visibility modifiers used (implicitly public)

**Singleton Pattern:**
```swift
@MainActor
final class AudioRecorder {
    static let shared = AudioRecorder()
    private init() {}
}
```

**Barrel Files:**
- Not used (no aggregating re-exports detected)

**Notifications as Contracts:**
- `Notification.Name` extensions define inter-module contracts
- Example: `extension Notification.Name { static let transcriptionDidComplete = ... }`
- Used for loose coupling between services

## MainActor Isolation

**Thread Safety:**
- All UI-touching classes marked `@MainActor`
- Ensures consistent behavior with AppKit and SwiftUI
- Examples: `APIClient` (shared singleton), `AudioRecorder`, `TranscriptionManager`, `ErrorNotifier`

**Async Context:**
- Functions that cross actor boundaries use `await` explicitly
- Task spawning: `Task { @MainActor in ... }` for explicit isolation

## Architecture Markers

**Phase Reference Comments:**
- Requirements mapped to comments for traceability
- Format: `// PHASE-##: Description` or `// ERR-04: Menu bar state`
- Examples: `// TRX-01: Transcription flow`, `// PRM-01: Microphone permission`, `// REC-02: Stop recording`

---

*Convention analysis: 2025-02-23*
