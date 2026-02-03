# Project State: MacWhisperDictation

**Last Updated:** 2026-02-03

## Current Status

- **Phase:** 5 of 5 (Error Handling & Polish) - In Progress
- **Active Plan:** 05-02 complete
- **Status:** Phase 5 in progress (2/3 plans complete)

## Project Reference

**Core Value:** Press a hotkey, speak naturally, and have your words appear as text in whatever app you're typing in — with sub-second latency and reliable error feedback.

**Primary Use Case:** Dictating descriptions of what to build while working with Claude Code. Natural language, not code syntax.

**Technical Stack:** Swift 6.0, SwiftUI + AppKit, AVFoundation, Groq Whisper API

**See:** `.planning/PROJECT.md` for full project context

## Current Position

**Phase:** 5 of 5 (Error Handling & Polish) - In Progress
**Plan:** 2 of 3 complete
**Progress:** ●●●●◐ (4 phases complete, Phase 5 in progress)

```
[████████████████████████████████████████] ~93%
```

## Phase Progress

| Phase | Name | Status | Plans | Requirements |
|-------|------|--------|-------|--------------|
| 1 | Foundation & Settings | ● Complete | 3/3 | 5 (SET-01 to SET-05) |
| 2 | Core Recording & Permissions | ● Complete | 2/2 | 7 (REC-01 to REC-04, PRM-01 to PRM-03) |
| 3 | Transcription & API | ● Complete | 2/2 | 5 (TRX-01 to TRX-05) |
| 4 | Output & Paste | ● Complete | 2/2 | 3 (OUT-01 to OUT-03) |
| 5 | Error Handling & Polish | ◐ In Progress | 2/3 | 4 (ERR-01 to ERR-04) |

**Legend:** ○ Pending | ◐ In Progress | ● Completed

## Performance Metrics

**Velocity:** Plans executing in 2-15 min each
**Quality:** Build succeeds, all verification criteria met
**Coverage:** 23/24 requirements complete (96%)

## Accumulated Context

### Key Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| 5-phase roadmap (quick depth) | Compress research's 7 phases to critical path | 2026-02-02 |
| Linear dependency chain | Each phase builds on previous foundation | 2026-02-02 |
| Non-sandboxed distribution | Required for CGEvent.post() paste in Phase 4 | 2026-02-02 |
| NSStatusItem over MenuBarExtra | Better macOS 14.0 compatibility and icon control | 2026-02-02 |
| waveform SF Symbol | Clean, audio-related, template-mode for light/dark | 2026-02-02 |
| SMAppService for login items | Modern macOS 13+ API, no helper app needed | 2026-02-02 |
| Toggle reflects actual state | User decision - show truth, not cached preference | 2026-02-02 |
| Guidance alert when blocked | Help users enable manually via System Settings | 2026-02-02 |
| String literal for AXTrustedCheckOptionPrompt | Avoid Swift 6 concurrency warning with C global | 2026-02-02 |
| 16kHz mono WAV format | Groq Whisper API compatibility | 2026-02-02 |
| KeyboardShortcuts library | Sindre Sorhus's reliable global hotkey library | 2026-02-02 |
| SF Symbol palette configuration | contentTintColor unreliable for menu bar icons | 2026-02-02 |
| 60-second transcription timeout | Audio processing takes time; 10s too short | 2026-02-02 |
| @AppStorage for language pref | Non-destructive settings auto-save immediately | 2026-02-02 |
| NotificationCenter for transcription | Decoupled results ready for Phase 4 paste | 2026-02-02 |
| Async Task spawn from hotkey | Non-blocking transcription from sync callback | 2026-02-02 |
| 150ms paste delay | Safe timing for clipboard-to-paste workflow | 2026-02-02 |
| Skip strict text field role check | Too restrictive - attempt paste in any context | 2026-02-02 |
| Always copy to clipboard first | Guaranteed fallback if paste simulation fails | 2026-02-02 |
| Accessibility guidance on failure | Clear user guidance when permission needed | 2026-02-02 |
| 5-second throttle interval | Prevents notification spam while allowing timely error feedback | 2026-02-03 |
| Dual error format support | Handle both Error in userInfo and legacy string as object | 2026-02-03 |
| API key check before microphone | Faster feedback, no point recording if can't transcribe | 2026-02-03 |

### Active TODOs

- [x] Review and approve roadmap
- [x] Execute Plan 01-01 (Xcode Project Foundation)
- [x] Execute Plan 01-02 (Settings Window)
- [x] Execute Plan 01-03 (Launch at Login)
- [x] Phase 1 complete (all 3 plans done)
- [x] Execute Plan 02-01 (Permission/Audio services)
- [x] Execute Plan 02-02 (Hotkey and Recording integration)
- [x] Complete Phase 2
- [x] Execute Plan 03-01 (Transcription API & Language Settings)
- [x] Execute Plan 03-02 (TranscriptionManager integration)
- [x] Complete Phase 3
- [x] Plan Phase 4 (2 plans created)
- [x] Execute Plan 04-01 (PasteManager service)
- [x] Execute Plan 04-02 (AppDelegate integration)
- [x] Complete Phase 4
- [x] Plan Phase 5
- [x] Execute Plan 05-01 (Error Notification System)
- [x] Execute Plan 05-02 (Missing API Key Handling)
- [ ] Execute Plan 05-03 (Recording Failure Handling)
- [ ] Complete Phase 5 (final phase!)

### Known Blockers

None currently.

### Technical Notes

**Research Highlights:**
- Sandboxing decision made: Non-sandboxed for Developer ID distribution
- Microphone permission silent failures on Sonoma 14.2+ need careful testing
- API timeout handling critical (3+ minute timeout, chunking for long recordings)
- CGEvent paste requires accessibility permissions (enabled by non-sandbox choice)

**Patterns Established (Plan 01-01):**
- AppKit AppDelegate manages menu bar, SwiftUI for windows
- NSApplicationDelegateAdaptor bridges SwiftUI App to AppDelegate
- SF Symbols with isTemplate for menu bar icons

**Patterns Established (Plan 01-02):**
- KeychainAccess library for secure credential storage
- Async API validation before saving credentials
- SwiftUI Form with SecureField for masked input
- NSHostingController for presenting SwiftUI in floating window
- Sendable/MainActor for Swift 6 concurrency safety

**Patterns Established (Plan 01-03):**
- @MainActor for Swift 6 concurrency on singleton services
- NSMenuDelegate for dynamic menu state updates
- System Settings deep links (x-apple.systempreferences:)
- SMAppService.mainApp for launch at login

**Patterns Established (Plan 02-01):**
- nonisolated func for C API calls with concurrency-unsafe globals
- AudioRecorderError with LocalizedError for user-facing error messages
- PermissionManager for microphone/accessibility permission lifecycle
- AudioRecorder for 16kHz mono WAV recording to temp files

**Patterns Established (Plan 02-02):**
- KeyboardShortcuts.Name extension for defining app hotkeys
- NotificationCenter for decoupled recording state updates
- NSImage.SymbolConfiguration(paletteColors:) for colored menu bar SF Symbols
- HotkeyManager for centralized hotkey registration and handling

**Patterns Established (Plan 03-01):**
- Multipart form-data with Data extension for `append(_ string:)`
- Separate URLSession configs for different timeout requirements
- UUID boundary for multipart collision resistance
- @AppStorage for instant-persist preferences without Save button

**Patterns Established (Plan 03-02):**
- NotificationCenter broadcasting for transcription results
- Async Task spawning from synchronous hotkey callbacks
- Service orchestration: TranscriptionManager coordinates HotkeyManager -> APIClient
- Language preference flow: UserDefaults -> TranscriptionManager -> APIClient

**Patterns Established (Plan 04-01):**
- Clipboard operations: NSPasteboard.general clearContents + setString
- Paste simulation: CGEvent with virtualKey 9 (V) + maskCommand flag
- Text field detection: AXUIElementCopyAttributeValue with role checking
- Cursor context: AXSelectedTextRangeAttribute + AXValueAttribute for smart spacing
- Clipboard-write-then-paste workflow with 150ms delay
- Notification fallback via UNUserNotificationCenter

**Patterns Established (Plan 04-02):**
- Transcription observer: .transcriptionDidComplete -> handleTranscriptionComplete -> PasteManager.pasteText
- Notification delegate: UNUserNotificationCenterDelegate with nonisolated methods
- Permission guidance: Show alert with System Settings deep link on failure
- Always attempt paste regardless of detected element type

**Patterns Established (Plan 05-01):**
- NotificationThrottler singleton with category-based time tracking
- ErrorCategory constants for notification categorization
- Error-to-category mapping based on APIError case
- Async Task spawn from @objc handler for MainActor-isolated operations

**Patterns Established (Plan 05-02):**
- Pre-flight validation: check API key before expensive operations
- AppDelegate method invocation from service via NSApp.delegate cast
- Pre-recording validation chain: API key -> microphone permission -> start recording

## Session Continuity

**Last Session:** 2026-02-03
**Stopped at:** Completed 05-02-PLAN.md
**Resume file:** None

**Next Step:** Execute Plan 05-03 (Recording Failure Handling)

**Context for Next Session:**
- Plan 05-02 complete: API key validation before recording (ERR-03)
- checkAPIKeyBeforeRecording in HotkeyManager with blocking alert
- showMissingAPIKeyAlert provides Open Settings / Get API Key / Later options
- Remaining: ERR-04 (recording failure handling) in Plan 05-03

---

*State initialized: 2026-02-02*
*Last plan completed: 05-02 SUMMARY (2026-02-03)*
*Phase 5 in progress - Plan 05-02 complete (2/3)*
