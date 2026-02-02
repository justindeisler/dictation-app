# Phase 1: Foundation & Settings - Context

**Gathered:** 2026-02-02
**Status:** Ready for planning

<domain>
## Phase Boundary

User can configure the app with API credentials. Establishes basic app infrastructure: menu bar presence, settings window, API key storage (Keychain), and launch at login. This phase creates the foundation all other phases build on.

</domain>

<decisions>
## Implementation Decisions

### Settings window design
- Single view layout — all settings visible at once, no tabs or navigation
- Native macOS visual style — standard system appearance matching other Mac apps
- Opens as separate floating window — can stay open while using other apps
- Explicit save behavior — Save/Cancel buttons required, changes only apply on save

### API key handling
- Masked input (password style) — shows dots/bullets, not visible text
- Auto-validate on save — test API key automatically when user saves, no separate test button
- Alert dialog on validation failure — modal popup explaining what went wrong
- Notify on first failed transcription — don't check on app launch, only alert when key is actually used and fails

### Menu bar presence
- SF Symbol for icon — native macOS symbol (waveform or mic), matches system aesthetic
- Extended menu contents:
  - Settings
  - About
  - Check for Updates
  - Recent transcriptions
  - Shortcuts info
  - Quit
- Left-click shows dropdown menu (standard behavior)
- Recording status shown via icon change only — no status text in menu

### Launch at login UX
- Toggle in menu bar menu only — not duplicated in settings window
- No first-run prompt — user discovers and enables it themselves
- Show guidance to System Settings if macOS blocks — alert with instructions

### Claude's Discretion
- Launch at login toggle state: reflect actual system state vs app preference (pick based on implementation complexity and reliability)
- Exact SF Symbol choice for menu bar icon
- Specific layout and spacing in settings window
- "Check for Updates" implementation approach

</decisions>

<specifics>
## Specific Ideas

- Keep settings window simple since there are only a few options in v1
- Menu bar icon should feel native — like other macOS utility apps
- Alert dialogs for errors are fine since they're infrequent (validation failure, blocked login item)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-settings*
*Context gathered: 2026-02-02*
