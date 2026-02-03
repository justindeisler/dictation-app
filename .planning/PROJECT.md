# MacWhisperDictation

## What This Is

A native macOS menu bar dictation app that captures speech via a global hotkey (Option+Space) and pastes transcribed text into any active text field. Uses Groq's Whisper API for fast, accurate transcription in English and German. Built for coding workflows — specifically for dictating descriptions and requests while working with Claude Code.

## Core Value

Press a hotkey, speak naturally, and have your words appear as text in whatever app you're typing in — with sub-second latency and reliable error feedback.

## Requirements

### Validated

- Global toggle hotkey (Option+Space) starts/stops recording — v1.0
- Visual indicator in menu bar while recording (red mic icon) — v1.0
- Audio sent to Groq Whisper API for transcription — v1.0
- Transcribed text pasted into active text field — v1.0
- English and German language support (auto-detect or preference) — v1.0
- Error notifications that explain why transcription failed — v1.0
- Settings window for API key configuration — v1.0
- Menu bar app (no dock icon) — v1.0
- Launch at login option — v1.0
- Microphone and Accessibility permission flows — v1.0

### Active

(None yet — see v2 requirements in next milestone planning)

### Out of Scope

- Push-to-talk mode — toggle is the chosen interaction model
- Custom hotkey configuration — Option+Space is sufficient for v1
- Transcription history — not needed for the dictate-and-paste workflow
- Visual waveform during recording — simple indicator is enough
- Sound effects — visual feedback is sufficient
- Real-time streaming transcription — Groq API doesn't support streaming well
- Offline transcription — network requirement is acceptable

## Context

**Current state:** Shipped v1.0 with 1,726 LOC Swift.

**Tech stack:** Swift 6.0, SwiftUI + AppKit hybrid, AVFoundation, URLSession, Groq Whisper API

**Key dependencies:**
- KeyboardShortcuts (Sindre Sorhus) — global hotkey registration
- KeychainAccess — secure API key storage

**Architecture:**
- AppDelegate-based lifecycle with NSStatusItem
- Service singletons: PermissionManager, AudioRecorder, HotkeyManager, TranscriptionManager, PasteManager, ErrorNotifier
- NotificationCenter for decoupled event handling
- CGEvent for keyboard simulation (requires non-sandboxed)

**Primary use case:** Dictating descriptions of what to build while working with Claude Code. Natural language, not code syntax.

## Constraints

- **Platform**: macOS only — native Swift/SwiftUI implementation
- **API**: Groq Whisper — no offline transcription, requires network
- **Permissions**: Must handle microphone + Accessibility permission flows gracefully
- **Audio format**: 16kHz mono WAV — optimal for speech, compatible with Whisper
- **Distribution**: Non-sandboxed — required for CGEvent.post() paste functionality

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Toggle mode over push-to-talk | Better for longer dictation sessions | Good — natural workflow |
| KeyboardShortcuts library for hotkey | Reliable global hotkey registration | Good — works perfectly |
| CGEvent for paste simulation | Standard approach for keyboard simulation | Good — works in all apps |
| Keychain for API key storage | Secure storage via KeychainAccess | Good — secure and persistent |
| Auto-detect language | Whisper handles multi-language well | Good — reduces friction |
| Non-sandboxed distribution | Required for CGEvent.post() | Necessary — no alternative |
| 60-second transcription timeout | Audio processing takes time | Good — handles long recordings |
| NSStatusItem over MenuBarExtra | Better macOS 14.0 compatibility | Good — reliable icon control |
| 5-phase quick roadmap | Compressed 7-phase research to critical path | Good — shipped in 2 days |

---
*Last updated: 2026-02-03 after v1.0 milestone*
