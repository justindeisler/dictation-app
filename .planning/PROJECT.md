# MacWhisperDictation

## What This Is

A native macOS menu bar dictation app that captures speech via a global hotkey and pastes transcribed text into any active text field. Uses Groq's Whisper API for fast, accurate transcription. Built for coding workflows — specifically for dictating descriptions and requests while working with Claude Code.

## Core Value

Press a hotkey, speak naturally, and have your words appear as text in whatever app you're typing in — with sub-second latency and reliable error feedback.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Global toggle hotkey (Option+Space) starts/stops recording
- [ ] Visual indicator in menu bar while recording (red mic icon)
- [ ] Audio sent to Groq Whisper API for transcription
- [ ] Transcribed text pasted into active text field
- [ ] English and German language support (auto-detect or preference)
- [ ] Error notifications that explain why transcription failed
- [ ] Settings window for API key configuration
- [ ] Menu bar app (no dock icon)

### Out of Scope

- Push-to-talk mode — toggle is the chosen interaction model
- Custom hotkey configuration — Option+Space is sufficient for v1
- Transcription history — not needed for the dictate-and-paste workflow
- Visual waveform during recording — simple indicator is enough
- Sound effects — visual feedback is sufficient
- Launch at login — can be added via System Settings manually

## Context

**Primary use case:** Dictating descriptions of what to build while working with Claude Code. Natural language, not code syntax — things like "create a function that validates user input" rather than literal code.

**Why custom app:** Ownership and control. Built specifically for this workflow rather than adapting a general-purpose tool.

**Technical environment:**
- macOS (Sonoma and later)
- Requires microphone permission
- Requires Accessibility permission for keyboard simulation
- Requires network access for Groq API

**Groq API:**
- Model: `whisper-large-v3-turbo` (fastest, most accurate)
- Free tier: ~50 hours/month transcription
- Endpoint: `https://api.groq.com/openai/v1/audio/transcriptions`

## Constraints

- **Platform**: macOS only — native Swift/SwiftUI implementation
- **API**: Groq Whisper — no offline transcription, requires network
- **Permissions**: Must handle microphone + Accessibility permission flows gracefully
- **Audio format**: M4A at 16kHz mono — optimal for speech, compatible with Whisper

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Toggle mode over push-to-talk | Better for longer dictation sessions, user preference | — Pending |
| Carbon API for hotkey | Reliable global hotkey registration on macOS | — Pending |
| CGEvent for paste simulation | Standard approach for keyboard simulation | — Pending |
| UserDefaults for API key storage | Simplicity for v1; Keychain for production later | — Pending |
| Auto-detect language | Whisper handles multi-language well; reduces friction | — Pending |

---
*Last updated: 2026-02-02 after initialization*
