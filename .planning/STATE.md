# Project State: MacWhisperDictation

**Last Updated:** 2026-02-02

## Current Status

- **Phase:** 1 of 5 (Foundation & Settings)
- **Active Plan:** 01-03 completed
- **Status:** In progress

## Project Reference

**Core Value:** Press a hotkey, speak naturally, and have your words appear as text in whatever app you're typing in — with sub-second latency and reliable error feedback.

**Primary Use Case:** Dictating descriptions of what to build while working with Claude Code. Natural language, not code syntax.

**Technical Stack:** Swift 6.0, SwiftUI + AppKit, AVFoundation, Groq Whisper API

**See:** `.planning/PROJECT.md` for full project context

## Current Position

**Phase:** 1 of 5 (Foundation & Settings)
**Plan:** 01-03 completed (Launch at Login)
**Progress:** ◐○○○○ (1/5 phases in progress)

```
[████████────────────────────────────────] ~15%
```

## Phase Progress

| Phase | Name | Status | Plans | Requirements |
|-------|------|--------|-------|--------------|
| 1 | Foundation & Settings | ◐ In Progress | 3/? | 5 (SET-01 to SET-05) |
| 2 | Core Recording & Permissions | ○ Pending | 0/? | 7 (REC-01 to REC-04, PRM-01 to PRM-03) |
| 3 | Transcription & API | ○ Pending | 0/? | 5 (TRX-01 to TRX-05) |
| 4 | Output & Paste | ○ Pending | 0/? | 3 (OUT-01 to OUT-03) |
| 5 | Error Handling & Polish | ○ Pending | 0/? | 4 (ERR-01 to ERR-04) |

**Legend:** ○ Pending | ◐ In Progress | ● Completed

## Performance Metrics

**Velocity:** 2 tasks in ~5 min (Plan 01-03)
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

### Active TODOs

- [x] Review and approve roadmap
- [x] Execute Plan 01-01 (Xcode Project Foundation)
- [x] Execute Plan 01-02 (Settings Window) - completed externally
- [x] Execute Plan 01-03 (Launch at Login)
- [ ] Complete remaining Phase 1 plans (if any)
- [ ] Begin Phase 2 (Core Recording & Permissions)

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

**Patterns Established (Plan 01-03):**
- @MainActor for Swift 6 concurrency on singleton services
- NSMenuDelegate for dynamic menu state updates
- System Settings deep links (x-apple.systempreferences:)
- SMAppService.mainApp for launch at login

## Session Continuity

**Last Session:** 2026-02-02T12:21:07Z
**Stopped at:** Completed Plan 01-03 (Launch at Login)
**Resume file:** None

**Next Step:** Execute remaining Phase 1 plans or begin Phase 2

**Context for Next Session:**
- Xcode project builds successfully
- Menu bar with Launch at Login toggle functional
- Settings window available (from Plan 01-02)
- LoginItemManager wraps SMAppService
- All Phase 1 settings requirements covered

---

*State initialized: 2026-02-02*
*Last plan completed: 01-03 (2026-02-02)*
