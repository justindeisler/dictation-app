# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Full build + install to /Applications (ad-hoc signed, no Apple Developer account needed)
./install.sh

# Build only (Release)
xcodebuild -project DictationApp/DictationApp.xcodeproj -scheme DictationApp \
  -configuration Release CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" \
  CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO \
  -derivedDataPath build -quiet

# Resolve SPM dependencies separately
xcodebuild -resolvePackageDependencies \
  -project DictationApp/DictationApp.xcodeproj -scheme DictationApp
```

There is no test target. Xcode 15.4+ with Swift 6.0 is required. Deployment target is macOS 14.0+.

## Architecture

Menu bar-only macOS app (`LSUIElement=true`) that records speech, sends it to Groq's Whisper API, and pastes the transcription into the frontmost app.

### Core Flow

**Hotkey (Option+Space)** → `HotkeyManager` → `AudioRecorder.startRecording()` (16kHz mono WAV to temp file) → **Hotkey again** → `AudioRecorder.stopRecording()` → posts `recordingDidStop` notification → `TranscriptionManager` picks it up → `APIClient.transcribe()` (multipart POST to `api.groq.com/openai/v1/audio/transcriptions`, model `whisper-large-v3-turbo`) → `PasteManager.pasteText()` (writes to clipboard, simulates Cmd+V via Accessibility API)

### Wiring

- **AppDelegate** (`Sources/App/AppDelegate.swift`) is the orchestrator — sets up the menu bar, registers NotificationCenter observers, and updates the menu bar icon state machine (idle/recording/processing/error)
- **Services are singletons** (`ServiceName.shared`), all `@MainActor`, communicate via `NotificationCenter` (not direct references)
- **Notification names** follow `verbDidNoun` pattern: `.recordingDidStart`, `.transcriptionDidComplete`, `.transcriptionDidFail`
- **DictationAppApp.swift** is the SwiftUI `@main` entry point — it only creates the `AppDelegate` via `@NSApplicationDelegateAdaptor`

### Key Services

| Service | Purpose |
|---------|---------|
| `TranscriptionManager` | Orchestrates record → API → paste pipeline |
| `APIClient` | Groq API client with error classification, separate URLSessions (10s validation, 60s transcription) |
| `PasteManager` | Clipboard write + Cmd+V simulation via `CGEventCreateKeyboardEvent` / Accessibility API |
| `ErrorNotifier` | User-facing error notifications, uses `NotificationThrottler` (5s minimum interval per category) |
| `KeychainManager` | API key storage in macOS Keychain (service: `com.dictationapp.DictationApp`, key: `groq_api_key`) |

### Entitlements

- `com.apple.security.device.audio-input` — microphone access
- `com.apple.security.automation.apple-events` — paste simulation into other apps

## Conventions

- Swift 6 strict concurrency: all UI-touching classes are `@MainActor`, `APIClient` conforms to `Sendable`
- Error enums have a `userMessage` property for display text (see `APIError` in `APIClient.swift`)
- `// MARK: - Section` for code organization
- Two SPM dependencies only: `KeyboardShortcuts` (global hotkey) and `KeychainAccess` (keychain wrapper)
- User preferences via `@AppStorage` / `UserDefaults` (e.g., `transcriptionLanguage`)
- `@preconcurrency import UserNotifications` needed for Xcode 16.4+ compatibility

## CI/CD

GitHub Actions workflow (`.github/workflows/release.yml`) triggers on `v*` tags, builds the app, zips it, and creates a GitHub Release with the artifact. To release:

```bash
git tag v1.x.x && git push origin v1.x.x
```

## Repo Layout

The Xcode project lives in `DictationApp/` (subdirectory). The repo root has `install.sh`, `README.md`, `SETUP.md`, and the `.github/` workflows. The `.planning/` directory contains architecture analysis docs from initial development.
