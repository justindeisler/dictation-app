# Project State: MacWhisperDictation

**Last Updated:** 2026-02-02

## Current Status

- **Phase:** 3 of 5 (Transcription & API) - In Progress
- **Active Plan:** 03-01 complete
- **Status:** Phase 3 in progress

## Project Reference

**Core Value:** Press a hotkey, speak naturally, and have your words appear as text in whatever app you're typing in — with sub-second latency and reliable error feedback.

**Primary Use Case:** Dictating descriptions of what to build while working with Claude Code. Natural language, not code syntax.

**Technical Stack:** Swift 6.0, SwiftUI + AppKit, AVFoundation, Groq Whisper API

**See:** `.planning/PROJECT.md` for full project context

## Current Position

**Phase:** 3 of 5 (Transcription & API) - In Progress
**Plan:** 03-01 complete
**Progress:** ●●◐○○ (2 phases complete, 1 in progress)

```
[██████████████████████████████──────────] ~50%
```

## Phase Progress

| Phase | Name | Status | Plans | Requirements |
|-------|------|--------|-------|--------------|
| 1 | Foundation & Settings | ● Complete | 3/3 | 5 (SET-01 to SET-05) |
| 2 | Core Recording & Permissions | ● Complete | 2/2 | 7 (REC-01 to REC-04, PRM-01 to PRM-03) |
| 3 | Transcription & API | ◐ In Progress | 1/? | 5 (TRX-01 to TRX-05) |
| 4 | Output & Paste | ○ Pending | 0/? | 3 (OUT-01 to OUT-03) |
| 5 | Error Handling & Polish | ○ Pending | 0/? | 4 (ERR-01 to ERR-04) |

**Legend:** ○ Pending | ◐ In Progress | ● Completed

## Performance Metrics

**Velocity:** 2 tasks in ~3 min (Plan 03-01)
**Quality:** Build succeeds, all verification criteria met
**Coverage:** 24/24 requirements mapped (100%)

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
- [ ] Continue Phase 3 (wire transcription to recording)
- [ ] Complete Phase 3

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

## Session Continuity

**Last Session:** 2026-02-02T17:12:00Z
**Stopped at:** Completed Plan 03-01
**Resume file:** None

**Next Step:** Continue Phase 3 (wire transcription to recording completion)

**Context for Next Session:**
- Plan 03-01 complete: Transcription API and language settings ready
- APIClient.transcribe(audioURL:language:) method implemented
- TranscriptionResult model in Sources/Models/
- Language preference stored in UserDefaults ("transcriptionLanguage")
- Next: Wire recordingDidStop notification to transcription call
- Requirements covered: TRX-01, TRX-02 (partial), TRX-03 (language setting)

---

*State initialized: 2026-02-02*
*Last plan completed: 03-01 SUMMARY (2026-02-02)*
*Phase 3 in progress*
