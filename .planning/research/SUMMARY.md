# Project Research Summary

**Project:** MacWhisperDictation
**Domain:** Native macOS menu bar utility with cloud API integration
**Researched:** 2026-02-02
**Confidence:** HIGH

## Executive Summary

MacWhisperDictation is a native macOS menu bar app that enables voice-to-text dictation optimized for developer workflows. The recommended approach uses **Swift 6.1+ with SwiftUI for UI components and AppKit for menu bar control**, AVFoundation for audio recording, and Groq's Whisper API (whisper-large-v3-turbo) for transcription. This stack prioritizes sub-second latency, minimal dependencies, and native macOS integration.

The critical architectural decision is **choosing between App Store distribution (sandboxed, limited keyboard control) or direct distribution (non-sandboxed, full CGEvent support for automatic paste)**. Sandboxing fundamentally conflicts with accessibility permissions needed for automatic text insertion. Research strongly recommends direct distribution via Developer ID to enable the core value proposition: seamless paste-anywhere functionality.

Key risks include microphone permission silent failures (especially on Sonoma 14.2+), API timeout billing issues, audio device switching after sleep/wake cycles, and CPU/battery drain from inefficient audio handling. All are mitigable through proper permission validation, timeout handling with chunking, audio session lifecycle management, and efficient AVFoundation usage. The 14-day suggested build order prioritizes early testing of permission flows and sandboxing decisions before building higher-level features.

## Key Findings

### Recommended Stack

The stack minimizes dependencies while maximizing native performance. Swift 6.1+ provides modern async/await concurrency for the hotkey → record → API → paste pipeline with data race prevention. AppKit (NSStatusItem) offers full menu bar control with broader macOS compatibility compared to SwiftUI's MenuBarExtra (macOS 13+ only, limited customization).

**Core technologies:**
- **Swift 6.1+ with Swift 6 Language Mode**: Native async/await eliminates callback complexity, zero-cost abstractions maintain sub-second latency requirements — 95% confidence
- **SwiftUI + AppKit Integration**: SwiftUI for settings UI, NSStatusItem for reliable menu bar control with custom popup windows — 90% confidence
- **AVFoundation (AVAudioRecorder)**: Native audio capture with 16kHz mono WAV/M4A optimized for Groq API, zero dependencies — 95% confidence
- **URLSession with async/await**: Native networking for Groq API integration, multipart form-data upload, no third-party libraries needed — 95% confidence
- **KeyboardShortcuts 2.x (SPM)**: User-customizable global hotkeys with conflict detection, modern Swift API — 92% confidence
- **CGEvent + NSPasteboard**: System-wide paste simulation requiring accessibility permissions, most reliable text insertion method — 88% confidence (blocks App Store distribution)
- **Keychain Services + UserDefaults**: API keys in encrypted Keychain storage, preferences in UserDefaults — 95% confidence

**Minimum deployment:** macOS 14.0 (Sonoma) for modern Swift Concurrency features with reasonable user base.

**Dependencies:** Only 2 SPM packages (KeyboardShortcuts, optionally KeychainAccess wrapper). Philosophy: minimize dependencies, use native frameworks wherever possible.

### Expected Features

Research identified clear market positioning as "cloud-based specialist for developer workflows" distinct from privacy-first local processing (MacWhisper, Voibe) and general productivity tools (Superwhisper).

**Must have (table stakes):**
- Global hotkey activation (Option+Space default, user-customizable) — industry standard
- Menu bar presence with visual recording indicator — all competitors use this
- Basic transcription accuracy (95%+) via Groq Whisper API — modern AI standard
- Automatic paste into active field — core value proposition
- Press-to-start/stop toggle mode — default interaction pattern
- English language support — minimum viable product
- Error handling with user feedback — 2026 expectation
- Privacy-conscious design with permission transparency — user trust requirement

**Should have (competitive differentiators):**
- **Optimized for Claude Code workflows** — PRIMARY DIFFERENTIATOR: format transcriptions for AI prompts, no competitor targets this
- German language support — underserved bilingual developer market
- Sub-second startup time — technical performance edge (Voibe claims <1s)
- Custom vocabulary for technical terms — essential for code-related terminology (API names, frameworks)
- Context-aware formatting modes — code comments, commit messages, Claude prompts, plain text
- Multi-language auto-detection — seamless English/German switching
- Text expansion rules — fix common Whisper errors ("comma" → ",", "new line" → "\n")

**Defer (v2+):**
- Offline fallback mode (local Whisper integration) — high complexity, 4-8 weeks effort, privacy gold standard but not MVP
- File transcription — different code path, separate use case
- Express Mode (always-on voice activation) — battery concerns, privacy issues, debatable value
- Real-time streaming captions — accessibility feature, not coding workflow, 3x complexity increase
- Meeting recording — different product category entirely
- Team collaboration features — massive scope expansion into SaaS territory

**Anti-features to avoid:**
- Built-in AI rewriting (users have Claude Code for this)
- Mobile apps (focus dilution, different UX paradigms)
- Dragon-style extensive voice commands (10x complexity, low value for technical dictation)
- Transcription history/search (privacy risk, contradicts "ephemeral capture" philosophy)

### Architecture Approach

AppKit-based application with LSUIElement = true (menu bar only), using NSApplicationDelegate for lifecycle control and NSStatusItem for menu bar presence. Seven core components with clear separation of concerns: App Shell (coordinator), Hotkey Manager, Audio Recorder, Transcription Client, Text Paster, Settings Manager, and Notification Manager.

**Major components:**
1. **App Shell (NSApplicationDelegate)** — Application lifecycle, menu bar initialization, centralized error handling, component coordination
2. **Hotkey Manager (KeyboardShortcuts)** — Global keyboard shortcut registration, system-wide event handling, toggle recording state, user-customizable UI
3. **Audio Recorder (AVAudioRecorder)** — Microphone permission requests, 16kHz mono audio capture, temporary file management, audio session lifecycle
4. **Transcription Client (URLSession)** — Groq API authentication, multipart form-data upload, JSON response parsing, error handling with retry logic
5. **Text Paster (CGEvent + NSPasteboard)** — Accessibility permission handling, clipboard operations, Cmd+V keyboard simulation, clipboard restoration
6. **Settings Manager (UserDefaults + Keychain)** — API key secure storage, user preferences persistence, default value registration
7. **Notification Manager (UNUserNotificationCenter)** — Menu bar icon state updates, error notifications, minimal notification strategy

**Data flow:** User presses hotkey → Hotkey Manager toggles Audio Recorder → AVAudioRecorder captures to temp file → Transcription Client uploads to Groq API → Text Paster copies to clipboard and simulates Cmd+V → text appears in active app → temp file cleanup.

**Critical dependency:** Settings Manager is leaf dependency (no deps), all components depend on it for API keys and preferences. Hotkey triggers Audio Recorder (tight coupling via recording state). Audio → Transcription is loose coupling via file path. Transcription → Text Paster is loose coupling via text string.

### Critical Pitfalls

Research identified 21 documented pitfalls from Apple Developer Forums, community reports, and competitor analysis. Top 5 by severity:

1. **Accessibility Permission + Sandboxing Conflict (CRITICAL)** — Sandboxed apps cannot reliably use CGEvent.post() for keyboard simulation even with accessibility permission granted. Core paste functionality may be impossible in App Store builds. **Prevention:** Make architectural decision immediately: sandbox (App Store, limited paste) vs non-sandbox (Developer ID, full functionality). Test fully sandboxed build in Phase 1, not at launch. Recommend non-sandboxed direct distribution for core value prop.

2. **Whisper API Timeouts & Billing Issues (HIGH)** — API calls timeout at ~100 seconds, users charged for failed requests, files >10MB frequently timeout even within 25MB limit. **Prevention:** Set HttpClient timeout to 3+ minutes, chunk audio into 5-10 minute segments, implement exponential backoff with billing awareness, show upload progress, provide cancel mechanism, warn before uploading files >5 minutes.

3. **Microphone Permission Silent Failures (HIGH)** — Permission appears granted but audio capture fails, especially on Sonoma 14.2+. Permission state can become corrupted after macOS updates or sleep/wake cycles. **Prevention:** Check AVCaptureDevice.authorizationStatus before AND during recording, add clear NSMicrophoneUsageDescription to Info.plist, implement runtime permission validation (don't assume granted = working), test across macOS versions.

4. **Audio Device Switching & Reconnection Failures (HIGH)** — Microphone becomes undetectable after Mac sleep, external mic disconnect/reconnect, or audio device changes. AVFoundation session stops within seconds after reconnection. **Prevention:** Monitor AVAudioSession.routeChangeNotification, implement automatic session restart on device changes, never cache audio device references (query on each recording start), test with built-in mic, USB mic, Bluetooth headset, AirPods across sleep/wake cycles.

5. **CPU/Battery Drain from Background Processes (MEDIUM-HIGH)** — Background dictation processes consume 30-60% CPU, 800MB-1GB RAM constantly. macOS system processes (corespeechd, speechrecognitiond) triggered by app cause system-wide performance issues. **Prevention:** Use AVAudioEngine for low-latency processing, release audio session immediately after recording stops, never keep microphone open continuously, implement efficient silence detection, profile with Instruments (target: <10% CPU recording, <1% idle, <100MB RAM).

**Other notable pitfalls:**
- Permission request timing (request just-in-time, never upfront)
- Global hotkey conflicts (make fully customizable, detect conflicts)
- Audio format mismatches (record in M4A/WAV, validate before upload)
- Background noise/VAD failures (implement local silence detection, trim silence)
- Network connectivity gaps (detect network status, save recordings locally, implement upload queue)
- Menu bar icon clutter/notch interference (minimal design, distinct visual states)
- Text pasting context loss (capture active app before recording, verify focus before paste)
- App notarization with hardened runtime (test notarized build in Phase 1)

## Implications for Roadmap

Based on architecture dependencies and pitfall severity, suggested build order follows a 7-phase, 14-day progression from foundation to polish. Early phases prioritize critical architectural decisions and permission testing before building higher-level features.

### Phase 1: Foundation & Critical Decisions (Days 1-2)
**Rationale:** Establishes menu bar presence and forces immediate resolution of sandboxing decision. Must test accessibility permissions and notarization before building dependent features. Blocks all subsequent work if sandboxing conflicts discovered late.

**Delivers:**
- Menu bar app with NSStatusItem
- Basic menu (Quit, Settings placeholder)
- Hardened runtime testing
- Sandboxing architectural decision documented

**Addresses:**
- App Shell component (Architecture)
- Foundation for all table stakes features
- Pitfall #1 (Accessibility + Sandboxing) — BLOCKING DECISION

**Avoids:**
- Discovering sandboxing conflicts after building paste functionality
- Notarization issues found at distribution time

**Research flag:** Low complexity, well-documented patterns (skip research-phase)

### Phase 2: Settings & Permissions (Days 3-4)
**Rationale:** Settings infrastructure must exist before components that read API keys. Permission flows must be tested early with clear user feedback mechanisms. JIT permission requests prevent user hostility.

**Delivers:**
- UserDefaults + Keychain integration
- Settings window (SwiftUI or AppKit)
- API key secure storage
- Microphone permission request flow with clear explanations
- Accessibility permission request (if non-sandboxed chosen)

**Addresses:**
- Settings Manager component (Architecture)
- Privacy-conscious design (table stakes)
- Pitfall #3 (Microphone Permission Silent Failures)
- Pitfall #7 (Permission Request Timing)

**Avoids:**
- Building components without configuration infrastructure
- Upfront permission requests that overwhelm users
- Silent permission failures without user feedback

**Uses:** Keychain Services, UserDefaults, SwiftUI for UI

**Research flag:** Low complexity, standard patterns (skip research-phase)

### Phase 3: Input Detection (Days 3-4)
**Rationale:** Global hotkey is critical UX and must work reliably before audio recording. Conflict detection prevents user frustration. Visual feedback (icon state changes) establishes feedback loop for testing.

**Delivers:**
- KeyboardShortcuts package integration
- Option+Space default with user customization
- Hotkey conflict detection
- Menu bar icon state changes on hotkey press

**Addresses:**
- Hotkey Manager component (Architecture)
- Global hotkey activation (table stakes)
- Visual recording indicator (table stakes)
- Pitfall #5 (Global Hotkey Conflicts)

**Avoids:**
- Hardcoded single hotkey causing user conflicts
- Silent hotkey failures without feedback

**Uses:** KeyboardShortcuts 2.x (SPM)

**Research flag:** Low complexity, library handles complexity (skip research-phase)

### Phase 4: Audio Capture & Device Management (Days 5-7)
**Rationale:** Core functionality with highest technical risk (permissions, device switching, performance). Early testing of audio session lifecycle prevents late-discovery performance issues. Audio device handling must be robust before API integration.

**Delivers:**
- AVAudioRecorder setup with 16kHz mono configuration
- Start/stop recording with unique temp files
- Audio device change monitoring
- Sleep/wake session recovery
- Recording state visual feedback
- Efficient audio session lifecycle (release immediately after recording)

**Addresses:**
- Audio Recorder component (Architecture)
- Press-to-start/stop toggle mode (table stakes)
- English language support (audio capture prerequisite)
- Pitfall #4 (Audio Device Switching)
- Pitfall #6 (CPU/Battery Drain) — target <10% CPU recording

**Avoids:**
- Microphone becoming undetectable after device changes
- Performance degradation from always-on audio sessions
- Audio session interference with background music

**Uses:** AVFoundation (AVAudioRecorder), AVAudioSession notifications

**Research flag:** Medium complexity, device management needs thorough testing, but patterns well-documented (skip research-phase)

### Phase 5: API Integration & Timeout Handling (Days 8-10)
**Rationale:** External API dependency with billing implications. Must implement robust timeout and retry logic before end-to-end integration. Chunking strategy prevents timeout issues on longer recordings.

**Delivers:**
- URLSession multipart upload to Groq API
- Groq authentication with stored API key
- JSON response parsing
- Timeout handling (3+ minute timeout)
- Audio chunking strategy (5-10 minute segments)
- Exponential backoff retry logic with billing awareness
- Error handling with user-friendly messages
- Processing state visual feedback

**Addresses:**
- Transcription Client component (Architecture)
- Basic transcription accuracy 95%+ (table stakes)
- English language support (Whisper configuration)
- Pitfall #2 (Whisper API Timeouts) — CRITICAL for reliability
- Pitfall #12 (Rate Limiting)
- Pitfall #13 (Network Connectivity)

**Avoids:**
- Users charged for failed timeout retries
- Silent failures on network issues
- API rate limit exhaustion without feedback

**Uses:** URLSession async/await, Groq Whisper API (whisper-large-v3-turbo)

**Research flag:** Medium complexity, API integration tested independently before full integration

### Phase 6: Text Insertion & Context Awareness (Days 11-12)
**Rationale:** Requires accessibility permissions already tested in Phase 2. Clipboard restoration and focus verification prevent common paste context issues. End-to-end flow validation.

**Delivers:**
- CGEvent keyboard simulation (Cmd+V)
- NSPasteboard clipboard operations
- Clipboard restoration (optional setting)
- Active window focus verification
- Fallback to clipboard-only if accessibility denied
- End-to-end hotkey → record → API → paste flow

**Addresses:**
- Text Paster component (Architecture)
- Automatic paste into active field (table stakes)
- Clipboard copy (table stakes)
- Pitfall #17 (Text Pasting Context Loss)

**Avoids:**
- Text pasting into wrong application
- Clipboard pollution without restoration
- Silent paste failures without feedback

**Uses:** CGEvent, NSPasteboard, Accessibility permissions

**Research flag:** Low complexity but critical testing needed (accessibility permissions tested in Phase 2)

### Phase 7: Polish, Feedback & Error Handling (Days 13-14)
**Rationale:** UX polish after core functionality works. Error notifications must be non-intrusive but visible. Edge case handling prevents production issues.

**Delivers:**
- UNUserNotificationCenter integration
- Error notifications (API failures, permission denials)
- Optional completion notifications
- Improved menu bar icon states (idle, recording, processing, error, completed)
- Edge case handling (empty recordings, network failures, invalid API keys)
- Menu bar icon optimized for notch compatibility

**Addresses:**
- Notification Manager component (Architecture)
- Error handling & feedback (table stakes)
- Visual recording indicator refinement
- Pitfall #15 (Menu Bar Icon Clutter)
- Pitfall #16 (Notification Spam)
- Pitfall #18 (Transcription Latency User Abandonment)

**Avoids:**
- Excessive notifications causing user fatigue
- Privacy concerns from constant microphone indicator
- User abandonment during API processing without feedback

**Uses:** UNUserNotificationCenter, SF Symbols for icons

**Research flag:** Low complexity, UX refinement (skip research-phase)

### Phase Ordering Rationale

- **Foundation first (Phase 1)**: Menu bar presence provides feedback loop for all testing, sandboxing decision blocks architecture
- **Settings before components (Phase 2)**: All components need API keys and preferences
- **Permissions early (Phase 2-4)**: Discover permission issues before building dependent features
- **Audio before API (Phase 4 before 5)**: Robust recording prerequisite for transcription
- **API before paste (Phase 5 before 6)**: Must have transcription result before testing paste
- **Polish last (Phase 7)**: Core functionality working before UX refinement
- **Testing throughout**: Each phase includes validation criteria to catch issues early

**Dependency chain:**
```
Foundation (Phase 1)
    ↓
Settings (Phase 2) → All components need configuration
    ↓
Hotkey (Phase 3) → Triggers recording
    ↓
Audio Recording (Phase 4) → Provides file to API
    ↓
API Integration (Phase 5) → Returns text to paste
    ↓
Text Pasting (Phase 6) → Completes end-to-end flow
    ↓
Polish (Phase 7) → UX refinement
```

**Pitfall mitigation by phase:**
- Phase 1: Pitfall #1 (sandboxing), #19 (notarization)
- Phase 2: Pitfall #3 (mic permissions), #7 (permission timing), #8 (TCC state)
- Phase 3: Pitfall #5 (hotkey conflicts)
- Phase 4: Pitfall #4 (device switching), #6 (CPU/battery), #9 (audio formats), #10 (background noise), #11 (audio session interference)
- Phase 5: Pitfall #2 (API timeouts), #12 (rate limiting), #13 (network), #14 (malformed responses)
- Phase 6: Pitfall #17 (paste context loss)
- Phase 7: Pitfall #15 (menu bar clutter), #16 (notification spam), #18 (latency abandonment)

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 5 (API Integration):** Groq API rate limits, timeout behavior, and chunking strategy need validation with real usage patterns
- **Phase 4 (Audio Recording):** Audio device management across macOS versions (Sonoma 14.2+ behavior changes) may need device-specific testing
- **Future (Offline Mode):** If implementing local Whisper fallback, CoreML integration and model management needs extensive research (4-8 weeks complexity)

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Foundation):** NSStatusItem menu bar patterns well-documented, hundreds of examples
- **Phase 2 (Settings):** UserDefaults + Keychain standard storage patterns
- **Phase 3 (Hotkey):** KeyboardShortcuts library abstracts complexity
- **Phase 6 (Text Pasting):** CGEvent paste patterns documented in multiple sources
- **Phase 7 (Polish):** UNUserNotificationCenter standard notification patterns

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Swift 6.1+, AVFoundation, URLSession all verified with official Apple docs and Context7. KeyboardShortcuts library actively maintained (Jan 2025). Groq API confirmed via official docs. All core technologies have 90-95% confidence ratings. |
| Features | HIGH | Table stakes identified from 12+ competitor analysis sources (Superwhisper, MacWhisper, Voibe, Wispr Flow). Market positioning validated across multiple comparison articles. User expectations clear from App Store reviews and community discussions. |
| Architecture | HIGH | Component structure based on proven menu bar app patterns from developer community (Medium articles, Apple forums). 7-component separation follows single-responsibility principle. Data flow validated against similar apps (aidictation GitHub reference). 14-day build order tested via dependency analysis. |
| Pitfalls | HIGH | 21 pitfalls sourced from Apple Developer Forums, official Apple Support, OpenAI community, GitHub issues. Focus on 2024-2026 reports ensures macOS Sonoma/Sequoia current behavior. Top 5 risks cross-validated across multiple sources. Each pitfall includes prevention strategy from real developer experiences. |

**Overall confidence:** HIGH

All four research areas achieved high confidence through multiple verified sources, official documentation, and community validation. Stack decisions backed by Apple official docs and Context7 library research. Features validated via comprehensive competitor analysis. Architecture patterns proven in production menu bar apps. Pitfalls documented with real-world developer experiences and Apple Support cases.

### Gaps to Address

**During implementation:**
- **Voice Activity Detection (VAD) implementation details:** Research identified need for silence detection but specific algorithm/threshold tuning requires implementation testing. Test with various speaking patterns and background noise levels.

- **Clipboard restoration timing:** Optimal delay (0.5-1s) may need tuning based on different paste targets (native apps, Electron apps, browsers). Make configurable and A/B test.

- **Language parameter accuracy improvement:** Groq docs claim explicit language parameter "improves accuracy and latency" but don't quantify. A/B test English/German transcriptions with/without language hint to validate.

- **App Sandbox compatibility validation:** If App Store distribution desired, thoroughly test CGEvent.post() behavior in fully sandboxed build. May need alternative paste mechanisms or accept non-sandbox distribution.

- **Audio format optimization:** Current recommendation is 16kHz mono WAV/M4A. May be worth benchmarking Opus or other compressed formats to see if encoding overhead is offset by faster upload time. Profile with 1-minute, 5-minute, 15-minute recordings.

**During roadmap planning:**
- **German language support implementation:** Straightforward parameter change to Whisper API, but needs testing to validate accuracy claims for bilingual switching.

- **Custom vocabulary implementation:** Groq API documentation doesn't specify vocabulary hints API. May need to research OpenAI Whisper vocabulary parameters or consider post-processing approach.

- **Context-aware formatting modes:** Implementation strategy not specified in research. Could be client-side string manipulation or require additional AI processing. Needs design during roadmap planning.

**Post-MVP (if pursuing):**
- **Offline fallback with local Whisper:** Requires extensive CoreML integration research, 1-3GB model management, Metal optimization. Marked as 4-8 weeks complexity, defer to v2+ unless privacy becomes primary differentiator.

- **Multi-language auto-detection:** Whisper supports language detection, but implementation details for seamless switching need research if feature prioritized.

## Sources

### Primary (HIGH confidence)

**Official Documentation:**
- Apple Swift Language Documentation (github.com/swiftlang/swift) — Swift 6.1.2 features, async/await, concurrency
- Apple AVFoundation Documentation — AVAudioRecorder configuration, audio formats, permissions
- Apple URLSession async/await WWDC21 — Native networking patterns
- Groq Speech-to-Text API Documentation (console.groq.com/docs/speech-to-text) — Whisper API, models, pricing, file formats
- Apple Accessibility Permissions Documentation — CGEvent requirements, TCC database
- Apple Developer Forums — Microphone permissions (thread/767573), Accessibility sandboxing (thread/707680), CGEvent issues (thread/724603, thread/659804)

**Context7 Libraries:**
- sindresorhus/KeyboardShortcuts (2.x) — Global hotkey management, user customization UI
- kishikawakatsumi/KeychainAccess (4.x) — Keychain wrapper for secure API key storage

### Secondary (MEDIUM confidence)

**Developer Community Resources:**
- Building macOS Menu Bar App with Swift (gaitatzis.medium.com) — AppKit + SwiftUI integration patterns
- SwiftUI Menu Bar App Guide (sarunw.com) — NSStatusItem vs MenuBarExtra comparison
- Menu Bar App with AppKit (polpiella.dev) — AppKit-only approach
- URLSession async/await Guide (avanderlee.com) — Modern networking patterns
- Keychain vs UserDefaults Security (multiple Medium articles) — Storage security best practices
- Swift Package Manager 2025 Updates (commitstudiogs.medium.com) — SPM signing, caching, parallel resolution

**Competitor Analysis:**
- Superwhisper (superwhisper.com, App Store, afadingthought.substack.com) — Feature analysis, pricing benchmarks
- MacWhisper (todayonmac.com review) — Privacy-first offline processing approach
- Voibe (getvoibe.com) — Performance benchmarks, alternative comparisons
- Wispr Flow (wisprflow.ai, getvoibe.com alternatives) — Advanced features analysis
- AudioWhisper (GitHub: mazdak/AudioWhisper) — Open source reference implementation
- aidictation (GitHub: writingmate/aidictation) — Swift/SwiftUI reference implementation

**Technical Discussions:**
- Apple Community: Sound input/output device issues (thread/253084030) — macOS Sonoma behavior
- OpenAI Community: Whisper API timeouts (multiple threads) — Billing issues, timeout behavior
- Zapier Community: 504 Gateway timeouts — API reliability patterns
- Apple Forums: Global hotkeys (thread/735223) — Carbon API deprecation
- jano.dev: Accessibility Permission in macOS — Permission flow implementation
- Igor Kulman blog: Auto-type implementation — CGEvent paste patterns

### Tertiary (LOW confidence, needs validation)

**Performance Claims:**
- Voibe sub-second startup claims — Marketing material, not independently verified
- Wispr Flow CPU/memory usage (800MB RAM, 8% CPU) — Reported by competitor, not tested
- Groq 216x real-time speed claim — From official docs but performance may vary with network latency
- macOS dictation accuracy comparisons — Subjective user reports, not standardized benchmarks

**Feature Effectiveness:**
- Custom vocabulary accuracy improvement — Documented as available but effectiveness not quantified
- Language parameter latency improvement — Groq claims improvement but doesn't provide metrics
- Multi-language auto-detection accuracy — Feature exists but switching reliability needs validation

---
*Research completed: 2026-02-02*
*Ready for roadmap: yes*
