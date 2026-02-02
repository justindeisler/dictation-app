---
phase: 02-core-recording-permissions
plan: 02
subsystem: hotkey-integration
tags: [KeyboardShortcuts, hotkey, menu-bar-icon, visual-feedback, Option+Space]

# Dependency graph
requires:
  - phase: 02-core-recording-permissions
    plan: 01
    provides: "PermissionManager, AudioRecorder services"
provides:
  - HotkeyManager service for Option+Space toggle
  - Menu bar icon visual recording feedback (red when recording)
  - NotificationCenter-based recording state coordination
affects: [03-transcription-api, 04-output-paste]

# Tech tracking
tech-stack:
  added: [KeyboardShortcuts-2.4.0]
  patterns:
    - "KeyboardShortcuts.onKeyUp for global hotkey registration"
    - "NSImage.SymbolConfiguration(paletteColors:) for colored SF Symbols"
    - "NotificationCenter for decoupled recording state updates"

key-files:
  created:
    - DictationApp/Sources/Services/HotkeyManager.swift
  modified:
    - DictationApp/Sources/App/AppDelegate.swift
    - DictationApp/DictationApp.xcodeproj/project.pbxproj

key-decisions:
  - "KeyboardShortcuts library (Sindre Sorhus) for reliable global hotkey"
  - "SF Symbol palette configuration for red icon (contentTintColor unreliable)"
  - "NotificationCenter pattern for decoupled icon state updates"

patterns-established:
  - "KeyboardShortcuts.Name extension for defining app hotkeys"
  - "Notification.Name extensions for custom app notifications"
  - "NSImage.SymbolConfiguration(paletteColors:) for menu bar colored icons"

# Metrics
duration: 8min
completed: 2026-02-02
---

# Phase 2 Plan 2: Hotkey and Visual Feedback Summary

**Option+Space hotkey toggle with red menu bar icon during recording**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-02T14:00:00Z
- **Completed:** 2026-02-02T14:08:00Z
- **Tasks:** 3 (2 auto + 1 human checkpoint)
- **Files modified:** 3

## Accomplishments
- Implemented Option+Space global hotkey via KeyboardShortcuts library
- Created HotkeyManager with permission checking before recording
- Added visual recording feedback with red waveform.circle.fill icon
- Integrated recording state observers in AppDelegate

## Task Commits

Each task was committed atomically:

1. **Task 1: Add KeyboardShortcuts dependency and create HotkeyManager** - `d224e51` (feat)
2. **Task 2: Update AppDelegate with icon state changes** - `ad55f91` (feat)
3. **Task 3: Human verification checkpoint** - Approved after icon color fix
4. **Icon color fix** - `a0ad357` (fix)

## Files Created/Modified
- `DictationApp/Sources/Services/HotkeyManager.swift` - Global hotkey registration and recording toggle logic
- `DictationApp/Sources/App/AppDelegate.swift` - MenuBarIconState enum, recording state observers, icon updates
- `DictationApp/DictationApp.xcodeproj/project.pbxproj` - KeyboardShortcuts package dependency

## Decisions Made
- **KeyboardShortcuts library**: Sindre Sorhus's library provides reliable cross-app hotkey registration without accessibility permission requirement for detection (only for paste in Phase 4)
- **SF Symbol palette configuration**: NSStatusBarButton.contentTintColor doesn't reliably color SF Symbols; used NSImage.SymbolConfiguration(paletteColors:) instead
- **NotificationCenter pattern**: Decouples HotkeyManager from AppDelegate - allows easy extension for Phase 3 transcription handling

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Menu bar icon not turning red**
- **Found during:** Human verification checkpoint (Task 3)
- **Issue:** `contentTintColor` on NSStatusBarButton doesn't work reliably for SF Symbols
- **Fix:** Used `NSImage.SymbolConfiguration(paletteColors: [.systemRed])` to properly color the icon
- **Files modified:** AppDelegate.swift
- **Verification:** User confirmed icon now turns red during recording
- **Committed in:** a0ad357

---

**Total deviations:** 1 auto-fixed (blocking)
**Impact on plan:** Necessary fix for visual feedback requirement. No scope creep.

## Issues Encountered
- Swift Package resolution required manual trigger via xcodebuild -resolvePackageDependencies
- SourceKit showed transient errors until packages were resolved

## User Setup Required
- Grant microphone permission on first recording attempt
- Grant accessibility permission at app launch (for Phase 4 paste)

## Phase 2 Completion Status

All Phase 2 requirements now covered:

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| REC-01 | ✅ | Option+Space starts recording via HotkeyManager |
| REC-02 | ✅ | Option+Space again stops recording (toggle) |
| REC-03 | ✅ | Menu bar icon red/filled while recording |
| REC-04 | ✅ | 16kHz mono WAV format (AudioRecorder) |
| PRM-01 | ✅ | Microphone permission requested on first use |
| PRM-02 | ✅ | Accessibility permission requested at launch |
| PRM-03 | ✅ | Guidance alerts with System Settings deep links |

## Next Phase Readiness
- Recording workflow complete: hotkey → permission check → record → stop → file URL
- NotificationCenter posts recordingDidStop with file URL for Phase 3 transcription
- Accessibility permission already requested for Phase 4 paste functionality

---
*Phase: 02-core-recording-permissions*
*Plan: 02-02*
*Completed: 2026-02-02*
