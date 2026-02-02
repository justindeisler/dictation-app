# Roadmap: MacWhisperDictation

**Created:** 2026-02-02
**Phases:** 5
**Requirements Coverage:** 24/24 (100%)
**Depth:** Quick (3-5 phases, focused on critical path)

## Phase Overview

| # | Name | Goal | Requirements | Success Criteria |
|---|------|------|--------------|------------------|
| 1 | Foundation & Settings | User can configure the app with API credentials | SET-01, SET-02, SET-03, SET-04, SET-05 | 5 criteria |
| 2 | Core Recording & Permissions | User can record audio via global hotkey with visual feedback | REC-01, REC-02, REC-03, REC-04, PRM-01, PRM-02, PRM-03 | 4 criteria |
| 3 | Transcription & API | User's recorded audio is transcribed accurately in English and German | TRX-01, TRX-02, TRX-03, TRX-04, TRX-05 | 3 criteria |
| 4 | Output & Paste | Transcribed text appears automatically in active text field | OUT-01, OUT-02, OUT-03 | 3 criteria |
| 5 | Error Handling & Polish | User receives clear feedback when things go wrong | ERR-01, ERR-02, ERR-03, ERR-04 | 4 criteria |

## Phase Details

### Phase 1: Foundation & Settings
**Goal:** User can configure the app with API credentials

**Requirements:**
- SET-01: App appears only in menu bar (no dock icon)
- SET-02: User can enter Groq API key in settings window
- SET-03: API key is stored securely (Keychain or encrypted)
- SET-04: Settings window is accessible from menu bar menu
- SET-05: App can be configured to launch at login

**Success Criteria:**
1. User can find the app icon in menu bar and click to open menu
2. User can access settings window from menu bar dropdown
3. User can enter and save Groq API key that persists across app restarts
4. User can enable/disable launch at login from settings
5. App never appears in dock (menu bar only presence)

**Dependencies:** None (foundation phase)

**Plans:** 3 plans in 2 waves

Plans:
- [x] 01-01-PLAN.md — Create Xcode project with menu bar presence (no dock icon)
- [x] 01-02-PLAN.md — Implement settings window with API key storage and validation
- [x] 01-03-PLAN.md — Implement launch at login with SMAppService

**Notes:** Establishes basic app infrastructure and settings management. Research suggests early testing of sandboxing decisions here.

---

### Phase 2: Core Recording & Permissions
**Goal:** User can record audio via global hotkey with visual feedback

**Requirements:**
- REC-01: User can press Option+Space to start recording
- REC-02: User can press Option+Space again to stop recording
- REC-03: Menu bar icon changes to red/filled while recording
- REC-04: Audio is recorded in format compatible with Groq API (M4A/WAV, 16kHz mono)
- PRM-01: App requests microphone permission on first use
- PRM-02: App requests accessibility permission for keyboard simulation
- PRM-03: App guides user to grant permissions if denied

**Success Criteria:**
1. User can press Option+Space to toggle recording on/off
2. User sees visual indicator (red menu bar icon) while recording is active
3. User is prompted clearly for microphone and accessibility permissions
4. User receives guidance to System Settings if permissions are denied

**Dependencies:** Phase 1 (needs menu bar infrastructure and settings)

**Plans:** 2 plans in 2 waves

Plans:
- [x] 02-01-PLAN.md — Create PermissionManager and AudioRecorder foundation services
- [x] 02-02-PLAN.md — Implement hotkey detection and visual recording feedback

**Notes:** Implements hotkey detection, audio capture, and permission flows. Critical for testing accessibility + sandboxing conflicts early.

---

### Phase 3: Transcription & API
**Goal:** User's recorded audio is transcribed accurately in English and German

**Requirements:**
- TRX-01: Audio is sent to Groq Whisper API after recording stops
- TRX-02: Transcription uses whisper-large-v3-turbo model
- TRX-03: English speech is transcribed accurately
- TRX-04: German speech is transcribed accurately
- TRX-05: Language is auto-detected or configurable in settings

**Success Criteria:**
1. User's recorded English speech returns accurate text transcription
2. User's recorded German speech returns accurate text transcription
3. User can configure language preference in settings or rely on auto-detection

**Dependencies:** Phase 1 (needs API key from settings), Phase 2 (needs recorded audio)

**Plans:** 2 plans in 2 waves

Plans:
- [x] 03-01-PLAN.md — Implement Groq Whisper API transcription and language settings
- [x] 03-02-PLAN.md — Integrate transcription workflow with recording completion

**Notes:** Integrates Groq Whisper API with timeout handling and retry logic. Research suggests 3+ minute timeout and chunking for longer recordings.

---

### Phase 4: Output & Paste
**Goal:** Transcribed text appears automatically in active text field

**Requirements:**
- OUT-01: Transcribed text is pasted into the currently active text field
- OUT-02: Paste works across all standard macOS applications
- OUT-03: User does not need to manually paste (automatic insertion)

**Success Criteria:**
1. User sees transcribed text automatically appear in active text field after recording
2. User can dictate into any standard macOS app (TextEdit, Notes, VS Code, browsers)
3. User does not need to press Cmd+V manually (paste is automatic)

**Dependencies:** Phase 2 (needs accessibility permission), Phase 3 (needs transcribed text)

**Notes:** Implements CGEvent keyboard simulation and clipboard management. Completes end-to-end hotkey → record → API → paste flow.

---

### Phase 5: Error Handling & Polish
**Goal:** User receives clear feedback when things go wrong

**Requirements:**
- ERR-01: User receives notification when transcription fails
- ERR-02: Error notification explains why it failed (network, API key, timeout)
- ERR-03: App handles missing API key gracefully (prompts to configure)
- ERR-04: App handles network unavailable gracefully

**Success Criteria:**
1. User sees notification when transcription fails with clear explanation
2. User is prompted to configure API key if missing or invalid
3. User receives feedback about network issues preventing transcription
4. User understands what went wrong and how to fix it from error messages

**Dependencies:** All previous phases (error handling touches all workflows)

**Notes:** Adds UNUserNotificationCenter notifications and edge case handling. Refines visual states and UX polish.

---

## Dependency Graph

```
Phase 1 (Foundation & Settings)
    ↓
Phase 2 (Core Recording & Permissions)
    ↓
Phase 3 (Transcription & API)
    ↓
Phase 4 (Output & Paste)
    ↓
Phase 5 (Error Handling & Polish)
```

**Linear dependency chain:** Each phase builds on the previous. Phase 1 provides settings infrastructure needed by all components. Phase 2 enables recording. Phase 3 adds transcription. Phase 4 completes the paste workflow. Phase 5 adds robustness.

## Progress Tracking

| Phase | Status | Completion |
|-------|--------|------------|
| 1 - Foundation & Settings | ● Complete | 5/5 requirements |
| 2 - Core Recording & Permissions | ● Complete | 7/7 requirements |
| 3 - Transcription & API | ● Complete | 5/5 requirements |
| 4 - Output & Paste | ○ Pending | 0/3 requirements |
| 5 - Error Handling & Polish | ○ Pending | 0/4 requirements |

**Legend:** ○ Pending | ◐ In Progress | ● Completed

---

## Research Integration

Research identified 7-phase, 14-day build order. Quick depth setting compressed this to 5 phases:

- **Phases 1-2** in research (Foundation + Settings) → **Phase 1** (Foundation & Settings)
- **Phases 3-4** in research (Hotkey + Audio) → **Phase 2** (Core Recording & Permissions)
- **Phase 5** in research (API Integration) → **Phase 3** (Transcription & API)
- **Phase 6** in research (Text Pasting) → **Phase 4** (Output & Paste)
- **Phase 7** in research (Polish) → **Phase 5** (Error Handling & Polish)

**Critical pitfalls to address:**
- Phase 1: Sandboxing decision (accessibility + CGEvent conflict)
- Phase 2: Microphone permission silent failures, audio device switching
- Phase 3: API timeout billing issues, chunking strategy
- Phase 4: Text pasting context loss, clipboard restoration
- Phase 5: Notification spam, menu bar icon clarity

---

*Roadmap created: 2026-02-02*
*Phase 2 completed: 2026-02-02*
*Phase 3 completed: 2026-02-02*
*Next step: `/gsd:plan-phase 4` or `/gsd:discuss-phase 4`*
