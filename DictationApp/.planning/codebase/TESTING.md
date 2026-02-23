# Testing Patterns

**Analysis Date:** 2025-02-23

## Test Framework

**Runner:**
- XCTest (native Apple testing framework)
- Testability enabled: `ENABLE_TESTABILITY = YES` in Xcode project configuration
- No separate test target configured in main project (tests currently not implemented)

**Assertion Library:**
- XCTest built-in assertions: `XCTAssert()`, `XCTAssertEqual()`, `XCTAssertNil()`, etc.
- No third-party assertion library detected

**Run Commands:**
```bash
# Via Xcode UI (Cmd+U)
# Command line not configured yet
```

## Test File Organization

**Location:**
- Not yet implemented in main project
- Convention: Co-located (test files in same target as source)
- Xcode project has testability enabled for future integration

**Naming:**
- Convention: `*Tests.swift` suffix (following XCTest standard)
- Class naming: `[ClassName]Tests` e.g., `APIClientTests`, `AudioRecorderTests`

**Structure:**
- Single test file per source file recommended
- Test classes inherit from `XCTestCase`
- Setup/teardown via `setUp()` and `tearDown()` methods

## Test Structure

**Suite Organization:**
- Typical XCTest pattern (not currently implemented in project)
- Anticipated structure:

```swift
class APIClientTests: XCTestCase {
    var sut: APIClient!

    override func setUp() {
        super.setUp()
        sut = APIClient()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testValidateAPIKeyWithValidKey() async throws {
        // Test implementation
    }
}
```

**Patterns:**
- Setup pattern: `setUp()` method initializes System Under Test (SUT)
- Teardown pattern: `tearDown()` cleans up resources
- Assertion pattern: `XCTAssert*()` methods for verification

## Mocking

**Framework:**
- Not yet implemented
- Recommended: `unittest.mock` equivalent or dependency injection for Swift

**Patterns:**
- Current architecture uses singletons which limits mockability
- Recommended approach for future tests: Dependency injection via initializers
- Example (recommended refactor):

```swift
class APIClient {
    let urlSession: URLSession

    init(urlSession: URLSession = URLSession.shared) {
        self.urlSession = urlSession
    }
}
```

**What to Mock:**
- `URLSession` - for network requests (APIClient testing)
- `AVAudioRecorder` - for audio recording (AudioRecorder testing)
- `UNUserNotificationCenter` - for notifications (ErrorNotifier testing)
- `Keychain` - for credential storage (KeychainManager testing)
- `FileManager` - for file operations (audio file handling)

**What NOT to Mock:**
- Domain models: `TranscriptionResult`, error enums
- Pure utility functions
- Notification dispatching (can stub via NotificationCenter)

## Fixtures and Factories

**Test Data:**
- Not currently implemented
- Recommended for API testing:

```swift
struct APITestFixtures {
    static let validAPIKey = "sk-test-key-123"
    static let sampleAudioURL = Bundle(for: APIClientTests.self)
        .url(forResource: "sample", withExtension: "wav")!

    static func mockTranscriptionResult(text: String) -> TranscriptionResult {
        TranscriptionResult(text: text)
    }
}
```

**Location:**
- Recommendation: `Tests/Fixtures/` directory
- Organized by domain: `Fixtures/API/`, `Fixtures/Audio/`
- Shared fixtures in `Tests/Shared/TestFixtures.swift`

## Coverage

**Requirements:**
- Not enforced (no coverage targets configured)
- Recommendation for implementation: ≥80% unit test coverage for services, ≥60% for UI

**View Coverage:**
```bash
# Via Xcode: Product → Scheme → Edit Scheme → Coverage
# Enable "Gather coverage data"
```

## Test Types

**Unit Tests:**
- Scope: Individual services and domain logic
- Testing needed for:
  - `APIClient` - validation and transcription request logic
  - `AudioRecorder` - file creation and recording state
  - `ErrorNotifier` - error categorization and notification creation
  - `NotificationThrottler` - throttling logic
  - Error enums - `userMessage` computation for all error cases

**Integration Tests:**
- Scope: Cross-service workflows (not yet implemented)
- Examples to implement:
  - Recording → Transcription → Paste flow
  - Permission checking before recording
  - Keychain save/load with validation
  - Menu bar icon state transitions

**E2E Tests:**
- Framework: Playwright or native Xcode UI testing
- Not used (no UI automation currently configured)
- Could test: Menu bar interaction, settings window, keyboard shortcuts via accessibility APIs

## Common Patterns

**Async Testing:**
- XCTest async pattern (Swift 5.5+):

```swift
func testValidateAPIKey() async throws {
    // Test implementation
    let result = try await apiClient.validateAPIKey("test-key")
}
```

- Run in test method: Automatically awaited by XCTest runner
- Timeout handling: Configure in test scheme settings

**Error Testing:**
- Expected error assertion:

```swift
func testInvalidAPIKeyThrowsError() async {
    do {
        try await apiClient.validateAPIKey("invalid")
        XCTFail("Should have thrown invalidAPIKey error")
    } catch APIError.invalidAPIKey {
        // Expected error caught
    } catch {
        XCTFail("Unexpected error: \(error)")
    }
}
```

**Notification Testing:**
```swift
func testTranscriptionCompletionNotification() {
    let expectation = expectation(forNotification: .transcriptionDidComplete, object: nil)

    Task {
        await TranscriptionManager.shared.handleRecordingCompletion(audioURL: testURL)
    }

    wait(for: [expectation], timeout: 5.0)
}
```

## Testable Architecture Recommendations

**For APIClient:**
- Mock `URLSession` to avoid network calls
- Test each HTTP status code path (200, 401, 429, 5xx)
- Verify multipart body construction
- Test timeout handling with `URLError`

**For AudioRecorder:**
- Mock `AVAudioRecorder` to verify recording state transitions
- Test file creation and temporary directory cleanup
- Verify settings match Groq API requirements (16kHz mono WAV)

**For TranscriptionManager:**
- Test language preference loading from `UserDefaults`
- Verify notification posting on completion/failure
- Test error type conversion (URLError → APIError)

**For ErrorNotifier:**
- Test error categorization (API key vs. network vs. rate limit)
- Verify throttling prevents duplicate notifications
- Test category mapping for notification routing

**For PermissionManager:**
- Mock `AVCaptureDevice` authorization checks
- Verify permission status enum conversion
- Test guidance alert presentation

**Dependency Injection Refactor Priority:**
1. `URLSession` in `APIClient` (enables network testing)
2. `Keychain` in `KeychainManager` (enables credential testing)
3. `AVAudioRecorder` in `AudioRecorder` (enables audio testing)
4. `UNUserNotificationCenter` in `ErrorNotifier` (enables notification testing)

## Testing Gaps & Recommendations

**Currently Untested Areas:**
- `APIClient.transcribe()` - full flow with multipart encoding
- `AudioRecorder` - actual recording lifecycle
- `PasteManager` - clipboard and CGEvent operations (requires accessibility)
- `PermissionManager` - permission request flows
- `TranscriptionManager` - notification routing and error handling
- `AppDelegate` - lifecycle and observer management
- `SettingsView` - UI validation and save logic

**High Priority Tests:**
1. API validation and transcription (core feature)
2. Error handling and user notifications
3. Permission checking before operations
4. Notification throttling (prevents spam)

**Integration Test Priorities:**
1. Recording → Transcription → Paste (complete happy path)
2. Missing API key → Error notification → Settings prompt
3. Permission denied → Guidance dialog → Settings redirect

---

*Testing analysis: 2025-02-23*
