---
phase: 05-error-handling-polish
plan: 02
subsystem: error-handling, user-experience
tags: [API-key-validation, NSAlert, HotkeyManager, graceful-degradation]

# Dependency graph
requires:
  - phase: 01-foundation-settings
    provides: KeychainManager with hasAPIKey() method
  - phase: 05-error-handling-polish/01
    provides: showMissingAPIKeyAlert method in AppDelegate
provides:
  - API key validation before recording starts
  - Blocking alert with Settings/Get Key/Later options
  - Prevents useless recordings when transcription will fail
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pre-flight validation: check API key before expensive operations"
    - "AppDelegate method invocation from service via NSApp.delegate cast"

key-files:
  created: []
  modified:
    - DictationApp/Sources/Services/HotkeyManager.swift

key-decisions:
  - "Check API key BEFORE microphone permission (faster, no point recording if can't transcribe)"
  - "Reuse existing showMissingAPIKeyAlert from Plan 05-01"

patterns-established:
  - "Pre-recording validation chain: API key -> microphone permission -> start recording"

# Metrics
duration: 3min
completed: 2026-02-03
---

# Phase 5 Plan 2: Missing API Key Handling Summary

**Pre-recording API key validation in HotkeyManager with blocking alert for graceful recovery (ERR-03)**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-03T09:06:53Z
- **Completed:** 2026-02-03T09:09:49Z
- **Tasks:** 2 (Task 1 already done in Plan 05-01)
- **Files modified:** 1

## Accomplishments
- checkAPIKeyBeforeRecording helper method in HotkeyManager
- API key validation runs before microphone permission check
- Blocking NSAlert provides three recovery options:
  - "Open Settings" - opens Settings window to configure API key
  - "Get API Key" - opens Groq console in browser
  - "Later" - dismisses without action
- Prevents recording when transcription would fail anyway

## Task Commits

Each task was committed atomically:

1. **Task 1: Add showMissingAPIKeyAlert to AppDelegate** - Already done in `ca3c03f` (Plan 05-01)
2. **Task 2: Add API key check in HotkeyManager** - `2620f89` (feat)

## Files Created/Modified
- `DictationApp/Sources/Services/HotkeyManager.swift` - Added checkAPIKeyBeforeRecording() and validation guard before recording

## Decisions Made
- **Check API key before microphone permission:** Faster feedback, avoids unnecessary permission prompts if API key is missing
- **Reuse showMissingAPIKeyAlert from 05-01:** Method was proactively added during Plan 05-01, reducing duplication

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Task 1 already completed in Plan 05-01**
- **Found during:** Task 1 verification
- **Issue:** showMissingAPIKeyAlert method already exists in AppDelegate from commit ca3c03f
- **Fix:** Skipped redundant Task 1, proceeded directly to Task 2
- **Verification:** Method exists and is callable from HotkeyManager
- **Committed in:** N/A (no changes needed)

---

**Total deviations:** 1 (task already complete)
**Impact on plan:** Reduced scope - Task 1 was already done, only Task 2 needed execution.

## Issues Encountered
None - build succeeded on first attempt after Task 2 implementation.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ERR-03 complete: Missing API key handled gracefully with user guidance
- Ready for next plan: ERR-04 (recording failure handling)
- Validation chain established: API key -> permissions -> recording

---
*Phase: 05-error-handling-polish*
*Completed: 2026-02-03*
