# Codebase Concerns

**Analysis Date:** 2025-02-23

## Tech Debt

**URLSession Configuration Duplication:**
- Issue: `APIClient.swift` creates two separate URLSession instances with custom timeout configurations, duplicating session setup logic
- Files: `Sources/Services/APIClient.swift` (lines 50-61)
- Impact: Difficult to maintain consistent session behavior, timeout configurations scattered across multiple instances
- Fix approach: Extract shared URLSession factory method or use dependency injection to manage session lifecycle

**Accessibility API Force Casts:**
- Issue: Multiple force casts of AXUIElement in `PasteManager.swift` without proper type validation
- Files: `Sources/Services/PasteManager.swift` (lines 169, 182)
- Impact: Runtime crashes if accessibility API returns unexpected types; no graceful error handling
- Fix approach: Use safe casting with optional binding and proper error handling

**Hardcoded Virtual Key Code:**
- Issue: Virtual key code for V key hardcoded as literal `9` in `PasteManager.swift`
- Files: `Sources/Services/PasteManager.swift` (line 80)
- Impact: Magic number reduces code clarity; should use symbolic constant or kVK_ANSI_V from Carbon framework
- Fix approach: Define keyboard constant or use proper CGKeyCode enumeration

**Main Actor Annotation Inconsistency:**
- Issue: Some services use `@MainActor` correctly, but `PermissionManager.requestAccessibilityPermission()` is marked `nonisolated` despite needing main thread
- Files: `Sources/Services/PermissionManager.swift` (line 76)
- Impact: Potential threading issues; nonisolated function calls MainActor code indirectly
- Fix approach: Remove nonisolated and let Swift's concurrency system enforce proper threading

**Manual String Encoding in Multipart:**
- Issue: Multipart form-data body constructed with string concatenation and manual byte encoding
- Files: `Sources/Services/APIClient.swift` (lines 138-160)
- Impact: Error-prone; boundary handling could fail with special characters; no validation
- Fix approach: Use URLComponents or multipart encoding library for robust implementation

## Known Bugs

**Error Icon Auto-Reset Race Condition:**
- Symptoms: Error icon may not reset properly if user starts recording immediately after error
- Files: `Sources/App/AppDelegate.swift` (lines 226-235)
- Trigger: User sees error state, then immediately presses hotkey to start new recording before 2-second timer completes
- Impact: Stale error indicator in menu bar despite successful new recording
- Workaround: Icon eventually resets on next state change; user can ignore
- Fix approach: Store state enum on icon button or use coordinated state machine instead of timer-based reset

**Permission Request Called Without Authorization Check:**
- Symptoms: System accessibility prompt may appear unexpectedly at launch
- Files: `Sources/App/AppDelegate.swift` (lines 51-55)
- Trigger: App always calls requestAccessibilityPermission() unconditionally at launch
- Impact: Aggressive permission prompts even on first launch when users may not understand why it's needed
- Fix approach: Show educational dialog first, then request permission only after user consent

**Empty Transcription Silent Failure:**
- Symptoms: User records audio, transcription completes, but nothing appears
- Files: `Sources/Services/PasteManager.swift` (line 24-26)
- Trigger: Groq API returns empty string in transcription result
- Impact: Confusing user experience; no notification that transcription was empty
- Workaround: User records again with clearer audio
- Fix approach: Show user notification when transcription is empty so they know what happened

**Settings Window Memory Leak:**
- Symptoms: Creating settings window multiple times could accumulate WindowController instances
- Files: `Sources/App/AppDelegate.swift` (lines 295-315)
- Trigger: User opens and closes settings window multiple times
- Impact: Gradual memory accumulation; multiple window controllers kept in memory
- Fix approach: Release windowController when window closes using didEndSheet delegate or NSWindowDelegate

**APIClient Timeout Silently Discards Request Data:**
- Symptoms: Request timeout shows generic "timed out" message without context about what was being sent
- Files: `Sources/Services/APIClient.swift` (lines 167-172)
- Trigger: Network timeout during large audio file transcription
- Impact: User has no way to know if their audio was partially received or lost completely
- Fix approach: Track request state to report whether timeout occurred before, during, or after upload

## Security Considerations

**Hardened Runtime Compatibility:**
- Risk: App requires audio-input and paste-event entitlements; Hardened Runtime enforcement may block clipboard/keyboard simulation
- Files: `Sources/Services/PasteManager.swift` (entire file for paste simulation)
- Current mitigation: app-sandbox and com.apple.security.device.audio-input entitlements in place
- Recommendations:
  - Test paste simulation thoroughly on notarized build with Hardened Runtime enabled
  - Consider fallback to notification-based approach if CGEvent fails
  - Document accessibility requirement clearly to users

**API Key Exposure in Memory:**
- Risk: API key loaded into String variable and stored in URLRequest; could be exposed in crash reports or memory dumps
- Files: `Sources/Services/APIClient.swift` (line 119), `Sources/Services/KeychainManager.swift`
- Current mitigation: Keys stored in system Keychain; accessed only when needed
- Recommendations:
  - Consider wrapping API key in SecureString or similar memory-protected type
  - Add process memory protection (mlock) for sensitive data
  - Validate that URLRequest doesn't log the Authorization header in debug builds

**Accessibility API Access Without Scope Validation:**
- Risk: PasteManager uses Accessibility API to read text before cursor; could be used to monitor other applications
- Files: `Sources/Services/PasteManager.swift` (lines 99-203)
- Current mitigation: macOS requires explicit user permission via Privacy & Security settings
- Recommendations:
  - Document to users that accessibility access is required only for cursor-aware pasting
  - Consider alternative approaches that don't require system-wide accessibility (e.g., app-specific APIs)
  - Log accessibility API usage for audit trail

**Notification Throttling Insufficient for DDoS:**
- Risk: NotificationThrottler provides only 5-second throttling; malicious code could still spam notifications
- Files: `Sources/Services/NotificationThrottler.swift` (line 13)
- Current mitigation: 5-second minimum interval per category
- Recommendations:
  - Implement exponential backoff instead of fixed interval
  - Add maximum-per-day limit per error category
  - Monitor notification rate and alert if suspicious pattern detected

## Performance Bottlenecks

**Synchronous File I/O on Main Thread:**
- Problem: AudioRecorder creates temp files synchronously; file existence check and attribute reading block UI
- Files: `Sources/Services/APIClient.swift` (lines 106-116), `Sources/Services/AudioRecorder.swift` (lines 47-56)
- Cause: FileManager operations are synchronous and executed on main thread
- Impact: UI freezes briefly when starting recording or checking file size
- Improvement path:
  - Move file operations to background thread using DispatchQueue or async/await
  - Implement lazy file validation only when needed

**URLSession Data Accumulation:**
- Problem: Entire audio file loaded into memory before multipart encoding
- Files: `Sources/Services/APIClient.swift` (line 124)
- Cause: Large audio files (up to 25MB) read entirely with `Data(contentsOf:)`
- Impact: Memory spike during transcription of large files; potential app crash on older Macs
- Improvement path:
  - Implement streaming upload using URLSession.UploadTask with file URL
  - Add progress reporting for upload/download
  - Implement cancellation support for long-running requests

**No Request Caching or Deduplication:**
- Problem: Identical validation requests could be made repeatedly within short timeframe
- Files: `Sources/Services/APIClient.swift` (lines 65-97)
- Cause: No caching layer for validation results
- Impact: Unnecessary API calls when user clicks "Save" multiple times
- Improvement path:
  - Add in-memory validation result cache with 5-minute TTL
  - Debounce validation requests during rapid changes

**Error Notification Creation Overhead:**
- Problem: UNNotificationCenter operations are async but not awaited properly in some paths
- Files: `Sources/Services/ErrorNotifier.swift` (line 114)
- Cause: async/await used but errors silently swallowed
- Impact: Slow notification display or missing notifications on error paths
- Improvement path:
  - Add timeout and retry logic for notification delivery
  - Queue notifications if UNUserNotificationCenter is busy

## Fragile Areas

**Notification-Based State Coordination:**
- Files: `Sources/App/AppDelegate.swift` (entire file for transcription coordination)
- Why fragile: Multiple notifications (recordingDidStart, recordingDidStop, transcriptionWillStart, transcriptionDidComplete, transcriptionDidFail) must fire in precise order; no validation that all observers are registered
- Safe modification:
  - Add state validation at each notification boundary
  - Consider replacing with structured state machine pattern
  - Log each state transition for debugging
- Test coverage: No unit tests for notification flow; manual testing only

**Accessibility API Integration:**
- Files: `Sources/Services/PasteManager.swift` (lines 99-203)
- Why fragile: Accessibility API is platform-dependent and breaks easily with system updates; force casts assume specific AXElement types
- Safe modification:
  - Wrap all AXUIElement operations in try-catch with proper type validation
  - Add version-specific handling for macOS compatibility
  - Test on multiple macOS versions (12.x, 13.x, 14.x, 15.x)
- Test coverage: No tests for accessibility API; manual testing only

**Menu Bar Icon State Management:**
- Files: `Sources/App/AppDelegate.swift` (lines 196-236)
- Why fragile: State tracking via NSImage accessibilityDescription; timer-based auto-reset creates race conditions
- Safe modification:
  - Store explicit state enum on AppDelegate or ViewController
  - Remove timer-based resets; use explicit state transitions only
  - Add assertions to validate state transitions
- Test coverage: No tests for icon state machine; visual verification only

**Settings Window Lifecycle:**
- Files: `Sources/App/AppDelegate.swift` (lines 295-315)
- Why fragile: Single windowController reference reused across open/close cycles; no proper lifecycle management
- Safe modification:
  - Implement NSWindowDelegate to clean up windowController on close
  - Or create new window instance each time instead of reusing
  - Add window restoration using window.contentViewController property
- Test coverage: No tests; manual verification only

**Hotkey Handler Weak Capture:**
- Files: `Sources/Services/HotkeyManager.swift` (line 35)
- Why fragile: Weak self capture in closure could cause handler to silently fail if HotkeyManager is deallocated
- Safe modification:
  - HotkeyManager should be held by AppDelegate (currently is via .shared)
  - Add assertion to verify self is available when handler fires
  - Consider making HotkeyManager strong reference if needed
- Test coverage: No tests for hotkey lifecycle

## Scaling Limits

**Single-File Audio Limitation:**
- Current capacity: 25MB maximum file size (Groq free tier limit)
- Limit: Users cannot transcribe recordings longer than approximately 15-20 minutes at 16kHz mono
- Scaling path:
  - Implement audio chunking/segmentation for longer recordings
  - Add fallback transcription service for large files
  - Provide clear UI warning when approaching size limit

**API Rate Limiting Not Exposed:**
- Current capacity: Groq API rate limits unknown to user
- Limit: Repeated transcription attempts could trigger rate limit (429 response)
- Scaling path:
  - Add local rate limiting queue to throttle requests
  - Implement exponential backoff for 429 responses
  - Display estimated wait time to user

**No Queue for Concurrent Transcriptions:**
- Current capacity: One transcription at a time (sequential)
- Limit: Users recording while previous transcription still processing will block new recording
- Scaling path:
  - Implement TranscriptionQueue to handle multiple pending transcriptions
  - Add UI to show pending transcription count
  - Implement cancellation for pending transcriptions

## Dependencies at Risk

**KeyboardShortcuts Package (3rd-party):**
- Risk: Depends on community-maintained package for hotkey registration; not part of standard macOS frameworks
- Impact: Breaking changes in package could require significant refactoring of HotkeyManager
- Migration plan:
  - Evaluate Carbon/Cocoa native alternatives (CGEventTap, NSGlobalHotkey)
  - Create abstraction layer to isolate HotkeyManager from package details

**KeychainAccess Package (3rd-party):**
- Risk: Third-party wrapper around Security.framework; adds maintenance dependency
- Impact: Security updates or breaking changes require coordination with package maintainer
- Migration plan:
  - Framework is well-maintained but consider direct Security.framework usage
  - Create KeychainManager adapter to isolate from direct dependency
  - Document keychain schema for data recovery if library becomes unmaintained

**Groq API Dependency:**
- Risk: Entire application depends on single external API; no fallback transcription service
- Impact: Service outage makes app completely unusable; no offline capability
- Migration plan:
  - Implement adapter pattern for transcription to support multiple providers (OpenAI Whisper, local ML models)
  - Add offline transcription fallback (Core ML Whisper model)
  - Cache successful transcriptions locally for reference

## Test Coverage Gaps

**No Unit Tests:**
- Untested area: All services (APIClient, AudioRecorder, PasteManager, etc.)
- Files: All files in `Sources/Services/`
- Risk: Changes to core logic could introduce regressions without detection
- Priority: High - critical business logic in transcription and error handling paths

**No Integration Tests:**
- Untested area: Notification flow, state coordination between services
- Files: `Sources/App/AppDelegate.swift`, entire notification system
- Risk: Multi-component interactions could fail in production despite individual service testing
- Priority: High - notification-based state machine is fragile

**No E2E Tests:**
- Untested area: Complete user workflows (record → transcribe → paste)
- Files: Integration across all services and UI
- Risk: End-to-end failures in real usage patterns undetected
- Priority: Medium - manual testing covers basic scenarios but automated verification needed

**No Permission Tests:**
- Untested area: Permission request flows and fallback behaviors
- Files: `Sources/Services/PermissionManager.swift`, `Sources/App/AppDelegate.swift`
- Risk: Permission denial scenarios untested; UI behavior unknown if permissions refused
- Priority: Medium - affects user experience on restricted systems

**No UI Tests:**
- Untested area: Settings UI validation, menu bar icon states
- Files: `Sources/Views/SettingsView.swift`, `Sources/App/AppDelegate.swift`
- Risk: UI bugs (invalid input acceptance, state display errors) undetected
- Priority: Low - visual verification currently sufficient but scalability concern

**No Network Error Tests:**
- Untested area: Network timeout, partial upload failure, connection loss during transcription
- Files: `Sources/Services/APIClient.swift`, `Sources/Services/TranscriptionManager.swift`
- Risk: Network failure scenarios unpredictable; error handling paths untested
- Priority: High - common real-world scenarios completely untested

**No Accessibility API Tests:**
- Untested area: Cursor detection, text extraction, paste simulation
- Files: `Sources/Services/PasteManager.swift` (lines 99-203)
- Risk: Accessibility API failures crash or silently fail; behavior varies by app
- Priority: High - complex platform integration with no automated verification

---

*Concerns audit: 2025-02-23*
