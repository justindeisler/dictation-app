# Project State: MacWhisperDictation

**Last Updated:** 2026-02-02

## Current Status

- **Phase:** 2 of 5 (Core Recording & Permissions)
- **Active Plan:** 02-01 SUMMARY created
- **Status:** Phase 2 in progress

## Project Reference

**Core Value:** Press a hotkey, speak naturally, and have your words appear as text in whatever app you're typing in — with sub-second latency and reliable error feedback.

**Primary Use Case:** Dictating descriptions of what to build while working with Claude Code. Natural language, not code syntax.

**Technical Stack:** Swift 6.0, SwiftUI + AppKit, AVFoundation, Groq Whisper API

**See:** `.planning/PROJECT.md` for full project context

## Current Position

**Phase:** 2 of 5 (Core Recording & Permissions)
**Plan:** 02-01 complete (Permission/Audio services), continuing to 02-02
**Progress:** ●◐○○○ (1 phase complete, 1 in progress)

```
[████████████████────────────────────────] ~28%
```

## Phase Progress

| Phase | Name | Status | Plans | Requirements |
|-------|------|--------|-------|--------------|
| 1 | Foundation & Settings | ● Complete | 3/3 | 5 (SET-01 to SET-05) |
| 2 | Core Recording & Permissions | ◐ In Progress | 1/? | 7 (REC-01 to REC-04, PRM-01 to PRM-03) |
| 3 | Transcription & API | ○ Pending | 0/? | 5 (TRX-01 to TRX-05) |
| 4 | Output & Paste | ○ Pending | 0/? | 3 (OUT-01 to OUT-03) |
| 5 | Error Handling & Polish | ○ Pending | 0/? | 4 (ERR-01 to ERR-04) |

**Legend:** ○ Pending | ◐ In Progress | ● Completed

## Performance Metrics

**Velocity:** 2 tasks in ~4 min (Plan 02-01)
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

### Active TODOs

- [x] Review and approve roadmap
- [x] Execute Plan 01-01 (Xcode Project Foundation)
- [x] Execute Plan 01-02 (Settings Window)
- [x] Execute Plan 01-03 (Launch at Login)
- [x] Phase 1 complete (all 3 plans done)
- [x] Execute Plan 02-01 (Permission/Audio services)
- [ ] Execute Plan 02-02 (Hotkey and Recording integration)
- [ ] Complete Phase 2

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

## Session Continuity

**Last Session:** 2026-02-02T13:56:00Z
**Stopped at:** Completed Plan 02-01 SUMMARY
**Resume file:** None

**Next Step:** Execute Plan 02-02 (Hotkey and Recording integration)

**Context for Next Session:**
- Phase 2 Plan 1 complete: PermissionManager and AudioRecorder services
- PermissionManager handles microphone + accessibility permissions with guidance alerts
- AudioRecorder creates 16kHz mono WAV files for Groq API
- Both follow @MainActor singleton pattern
- Requirements partially covered: PRM-01, PRM-02, PRM-03, REC-04

---

*State initialized: 2026-02-02*
*Last plan completed: 02-01 SUMMARY (2026-02-02)*
