# DictationApp

A lightweight macOS menu bar app that turns speech into text using Groq's Whisper API. Press a hotkey, speak, and the transcription is automatically pasted into whatever app you're working in.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 6](https://img.shields.io/badge/Swift-6.0-orange) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Global hotkey** (Option+Space by default, customizable) to start/stop recording
- **Instant paste** — transcription is automatically pasted into the frontmost app
- **Menu bar only** — no Dock icon, stays out of your way
- **Groq Whisper API** — fast, accurate transcription powered by `whisper-large-v3-turbo`
- **Multiple languages** — select your preferred transcription language in settings
- **Secure** — API key stored in macOS Keychain, never written to disk
- **Launch at login** — optional, configurable in settings

## Requirements

- macOS 14.0 (Sonoma) or later
- A free [Groq API key](https://console.groq.com/keys)

## Quick Start

### Download (no Xcode needed)

1. Download **DictationApp-macOS.zip** from the [latest release](https://github.com/justindeisler/DictationApp/releases/latest)
2. Unzip and drag **DictationApp.app** to your Applications folder
3. Right-click the app and choose **Open** (required once for Gatekeeper)
4. Click the menu bar icon, open **Settings**, and paste your [Groq API key](https://console.groq.com/keys)

### Build from Source

Requires Xcode 15.4+ with Swift 6.0.

```bash
git clone https://github.com/justindeisler/DictationApp.git
cd DictationApp
./install.sh
```

The script builds the app with ad-hoc signing and copies it to `/Applications`.

> **New to the command line?** See [SETUP.md](SETUP.md) for a detailed beginner-friendly guide with troubleshooting.

## Getting a Groq API Key

1. Go to [console.groq.com/keys](https://console.groq.com/keys)
2. Sign up or log in (free)
3. Create a new API key
4. Paste it into DictationApp's Settings window

Groq offers a generous free tier — more than enough for personal dictation use.

## Usage

1. **Press Option+Space** (or your custom hotkey) to start recording
2. **Speak** — a menu bar indicator shows recording is active
3. **Press the hotkey again** to stop recording
4. The transcription is **automatically pasted** into the frontmost text field

### Settings

Click the menu bar icon → Settings to configure:
- **API Key** — your Groq API key (stored in Keychain)
- **Language** — transcription language
- **Keyboard Shortcut** — change the global hotkey
- **Launch at Login** — start DictationApp when you log in

### Permissions

DictationApp needs two macOS permissions:
- **Microphone** — to record audio for transcription
- **Accessibility** — to paste transcription into other apps via simulated keystrokes

You'll be prompted to grant these on first use. They can be managed in System Settings → Privacy & Security.

## Architecture

```
DictationApp/
├── Sources/
│   ├── App/
│   │   ├── AppDelegate.swift        # Menu bar setup, app lifecycle
│   │   └── DictationAppApp.swift    # SwiftUI app entry point
│   ├── Models/
│   │   └── TranscriptionResult.swift # API response model
│   ├── Services/
│   │   ├── APIClient.swift          # Groq Whisper API communication
│   │   ├── AudioRecorder.swift      # Microphone recording (AVFoundation)
│   │   ├── ErrorNotifier.swift      # User-facing error alerts
│   │   ├── HotkeyManager.swift      # Global keyboard shortcut
│   │   ├── KeychainManager.swift    # Secure API key storage
│   │   ├── LoginItemManager.swift   # Launch at login via ServiceManagement
│   │   ├── NotificationThrottler.swift # Rate-limited notifications
│   │   ├── PasteManager.swift       # Clipboard + simulated Cmd+V paste
│   │   ├── PermissionManager.swift  # Microphone & accessibility checks
│   │   └── TranscriptionManager.swift # Orchestrates record → transcribe → paste
│   └── Views/
│       └── SettingsView.swift       # SwiftUI settings window
├── DictationApp.entitlements        # audio-input + apple-events
└── Info.plist                       # App configuration
```

The app follows a **services architecture**: `AppDelegate` sets up the menu bar and wires together independent service objects. `TranscriptionManager` orchestrates the core flow: record audio → send to Groq API → paste result.

## Dependencies

Both dependencies are managed via Swift Package Manager and resolve automatically when you open the project in Xcode.

| Package | Version | Purpose |
|---------|---------|---------|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.4.0 | Global hotkey registration |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | 4.2.2 | Secure API key storage |

## Note on Team ID

The project file (`project.pbxproj`) contains a Team ID (`YR4WG4W3YG`). This is the original developer's Apple signing identity — it's standard for Xcode projects and not a security concern. The install script bypasses this with ad-hoc signing, so you don't need to change it. If you build manually in Xcode, replace it with your own Team ID.

## License

[MIT](LICENSE)
