# Requirements: MacWhisperDictation

**Defined:** 2026-02-02
**Core Value:** Press a hotkey, speak naturally, and have your words appear as text in whatever app you're typing in — with sub-second latency and reliable error feedback.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Recording

- [ ] **REC-01**: User can press Option+Space to start recording
- [ ] **REC-02**: User can press Option+Space again to stop recording
- [ ] **REC-03**: Menu bar icon changes to red/filled while recording
- [ ] **REC-04**: Audio is recorded in format compatible with Groq API (M4A/WAV, 16kHz mono)

### Transcription

- [ ] **TRX-01**: Audio is sent to Groq Whisper API after recording stops
- [ ] **TRX-02**: Transcription uses whisper-large-v3-turbo model
- [ ] **TRX-03**: English speech is transcribed accurately
- [ ] **TRX-04**: German speech is transcribed accurately
- [ ] **TRX-05**: Language is auto-detected or configurable in settings

### Output

- [ ] **OUT-01**: Transcribed text is pasted into the currently active text field
- [ ] **OUT-02**: Paste works across all standard macOS applications
- [ ] **OUT-03**: User does not need to manually paste (automatic insertion)

### Settings

- [ ] **SET-01**: App appears only in menu bar (no dock icon)
- [ ] **SET-02**: User can enter Groq API key in settings window
- [ ] **SET-03**: API key is stored securely (Keychain or encrypted)
- [ ] **SET-04**: Settings window is accessible from menu bar menu
- [ ] **SET-05**: App can be configured to launch at login

### Error Handling

- [ ] **ERR-01**: User receives notification when transcription fails
- [ ] **ERR-02**: Error notification explains why it failed (network, API key, timeout)
- [ ] **ERR-03**: App handles missing API key gracefully (prompts to configure)
- [ ] **ERR-04**: App handles network unavailable gracefully

### Permissions

- [ ] **PRM-01**: App requests microphone permission on first use
- [ ] **PRM-02**: App requests accessibility permission for keyboard simulation
- [ ] **PRM-03**: App guides user to grant permissions if denied

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Enhanced Recording

- **REC-05**: Customizable hotkey (not just Option+Space)
- **REC-06**: Sound effects for recording start/stop
- **REC-07**: Push-to-talk mode as alternative to toggle

### Enhanced Transcription

- **TRX-06**: Custom vocabulary for technical terms
- **TRX-07**: Offline transcription fallback (CoreML Whisper)

### Enhanced Output

- **OUT-04**: Clipboard restoration after paste
- **OUT-05**: Text formatting modes (code, prose, list)

### Enhanced UI

- **SET-06**: Transcription history view
- **SET-07**: Usage statistics (minutes transcribed)
- **SET-08**: Visual waveform during recording

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Real-time streaming transcription | Adds complexity, Groq API doesn't support streaming well |
| Multiple hotkey profiles | Over-engineering for v1, single hotkey sufficient |
| Cloud sync of settings | Local-only app, no account system |
| iOS/mobile version | macOS-only focus for v1 |
| Voice commands (Dragon-style) | Different product category, not dictation |
| Meeting recording/transcription | Different use case, not quick dictation |
| Built-in AI text rewriting | Scope creep, Claude Code handles this |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SET-01 | Phase 1 | Pending |
| SET-02 | Phase 1 | Pending |
| SET-03 | Phase 1 | Pending |
| SET-04 | Phase 1 | Pending |
| SET-05 | Phase 1 | Pending |
| REC-01 | Phase 2 | Pending |
| REC-02 | Phase 2 | Pending |
| REC-03 | Phase 2 | Pending |
| REC-04 | Phase 2 | Pending |
| PRM-01 | Phase 2 | Pending |
| PRM-02 | Phase 2 | Pending |
| PRM-03 | Phase 2 | Pending |
| TRX-01 | Phase 3 | Pending |
| TRX-02 | Phase 3 | Pending |
| TRX-03 | Phase 3 | Pending |
| TRX-04 | Phase 3 | Pending |
| TRX-05 | Phase 3 | Pending |
| OUT-01 | Phase 4 | Pending |
| OUT-02 | Phase 4 | Pending |
| OUT-03 | Phase 4 | Pending |
| ERR-01 | Phase 5 | Pending |
| ERR-02 | Phase 5 | Pending |
| ERR-03 | Phase 5 | Pending |
| ERR-04 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 24 total
- Mapped to phases: 24 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-02-02*
*Last updated: 2026-02-02 after roadmap creation*
