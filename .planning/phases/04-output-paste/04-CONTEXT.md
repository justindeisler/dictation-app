# Phase 4: Output & Paste - Context

**Gathered:** 2026-02-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Automatically insert transcribed text into the active text field after recording stops. User should not need to manually paste — text appears where their cursor is.

</domain>

<decisions>
## Implementation Decisions

### Paste mechanism
- Use clipboard + CGEvent Cmd+V simulation (most compatible)
- Overwrite clipboard contents — don't preserve/restore previous clipboard
- Safe delay (~100-200ms) between clipboard write and paste simulation
- If paste fails (no text field), show notification with transcription text

### Text handling
- Trim leading/trailing whitespace from transcription
- Keep punctuation as-is from Whisper API (no normalization)
- Smart spacing: add space before text if cursor isn't at start of line or after whitespace
- Empty transcriptions (silence): skip silently, no paste, no notification

### Edge cases
- Check for focused text field using accessibility APIs before attempting paste
- If no text field focused: show notification only, don't attempt paste
- Paste failures: show notification with text (no special repeated-failure handling)
- Notification should be clickable to copy text to clipboard for manual paste

### Claude's Discretion
- Exact delay timing within 100-200ms range
- Accessibility API approach for detecting text field focus
- Notification styling and duration
- Smart spacing detection implementation

</decisions>

<specifics>
## Specific Ideas

- Primary use case: dictating descriptions to Claude Code — natural language, not code
- Text should appear seamlessly where user is typing
- Clipboard overwrite is acceptable (transcription stays available for re-paste)
- Notifications serve as fallback, not primary UX

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-output-paste*
*Context gathered: 2026-02-02*
