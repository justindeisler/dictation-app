# Technology Stack

**Analysis Date:** 2025-02-23

## Languages

**Primary:**
- Swift 6.0 - All application code, main development language for macOS

## Runtime

**Environment:**
- macOS 14.0+ (Sonoma and later) - Deployment target via `MACOSX_DEPLOYMENT_TARGET`
- Xcode 15.4+ - Build system and development environment

**Package Manager:**
- Swift Package Manager (SPM) - Native dependency management
- Lockfile: Present in `DictationApp.xcodeproj` (implicit via Xcode)

## Frameworks

**Core:**
- AppKit - Native macOS application framework for menu bar, windows, and system integration
- SwiftUI - Modern UI framework (used in Settings window via `NSHostingController`)
- AVFoundation - Audio capture and recording (16kHz mono PCM WAV)
- Foundation - Core networking, file I/O, JSON serialization

**System Integration:**
- ApplicationServices - Accessibility API for text field detection and paste simulation
- UserNotifications - User notification delivery for transcription results and errors
- UserNotificationCenter - Notification center management and categories

**Third-Party Dependencies:**
- KeychainAccess 4.2.2+ - Secure storage of Groq API keys in macOS Keychain
  - GitHub: `https://github.com/kishikawakatsumi/KeychainAccess`
  - Purpose: Encrypted credential storage
- KeyboardShortcuts 2.0.0+ - Global hotkey management (Option+Space default)
  - GitHub: `https://github.com/sindresorhus/KeyboardShortcuts`
  - Purpose: Keyboard shortcut registration and handling

**Build/Dev:**
- Swift Package Manager - Integrated dependency resolution
- Xcode Build System - Native compilation and linking

## Key Dependencies

**Critical:**
- KeychainAccess 4.2.2+ - Secure API key storage (required for authentication)
- KeyboardShortcuts 2.0.0+ - Global hotkey binding (required for core functionality)

**Infrastructure:**
- AVFoundation - Audio recording pipeline
- URLSession - Network communication with Groq API
- Accessibility APIs - Paste simulation into focused text fields

## Configuration

**Environment:**
- Deployment target: macOS 14.0+
- Swift version: 6.0 with strict concurrency (`@MainActor`, `Sendable`)
- Build configurations: Debug, Release
- No external configuration files (.env) - API keys stored in Keychain only

**Security Entitlements:**
Location: `DictationApp.entitlements`
- `com.apple.security.automation.apple-events` - Required for AppleEvents (paste functionality)
- `com.apple.security.device.audio-input` - Microphone access with Hardened Runtime

**App Configuration:**
- Bundle identifier: Configured via Xcode project (`$(PRODUCT_BUNDLE_IDENTIFIER)`)
- Info.plist location: `Info.plist`
  - `NSMicrophoneUsageDescription` - Microphone permission explanation
  - `NSAppleEventsUsageDescription` - AppleEvents permission explanation
  - `LSUIElement: true` - Menu bar application (no dock icon)

## Platform Requirements

**Development:**
- Xcode 15.4 or later
- Swift 6.0 toolchain
- macOS 14.0 or later (for building and running)
- Git (for dependency management via SPM)

**Production:**
- Target: macOS 14.0+ (Sonoma, Sequoia, and later releases)
- Deployment method: Signed and notarized .app bundle
- System permissions required:
  - Microphone access (AVFoundation)
  - Accessibility access (paste simulation)
  - Notification permission (optional for notifications)

**File System:**
- Temporary directory: Used for audio file recording (`FileManager.default.temporaryDirectory`)
- Keychain service identifier: `com.dictationapp.DictationApp`

---

*Stack analysis: 2025-02-23*
