# Phase 2: Core Recording & Permissions - Research

**Researched:** 2026-02-02
**Domain:** macOS Audio Recording, Global Hotkeys, System Permissions
**Confidence:** HIGH

## Summary

Phase 2 implements the core recording functionality: global hotkey detection (Option+Space), audio capture via AVFoundation, visual recording feedback, and permission management for microphone and accessibility.

The research confirms a well-established stack using **KeyboardShortcuts** library for hotkey handling, **AVAudioRecorder** with specific 16kHz mono WAV settings for Groq API compatibility, and **AXIsProcessTrusted** for accessibility permission checks. Key patterns include just-in-time permission requests, proper audio session configuration, and SF Symbol-based recording indicators.

**Primary recommendation:** Use KeyboardShortcuts library for hotkey management, AVAudioRecorder with temporary file storage, and implement a PermissionManager service that checks both microphone and accessibility permissions with clear user guidance when denied.

## Standard Stack

The established libraries/tools for this phase:

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVFoundation | Native | Audio recording via AVAudioRecorder | Apple's standard framework for audio capture, zero dependencies |
| KeyboardShortcuts | 2.x | Global hotkey registration/handling | Industry standard by Sindre Sorhus, SwiftUI components, UserDefaults integration |
| ApplicationServices | Native | Accessibility permission checking (AXIsProcessTrusted) | Only API for checking accessibility authorization |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AVCaptureDevice | Native | Microphone permission status/request | For checking and requesting microphone authorization |
| FileManager | Native | Temporary directory for recordings | Standard API for temp file path management |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| KeyboardShortcuts | HotKey (soffes) | HotKey simpler but no UI recorder component, no UserDefaults integration |
| KeyboardShortcuts | Carbon RegisterEventHotKey | Legacy API, not recommended by Apple, requires boilerplate |
| AVAudioRecorder | AVAudioEngine | AVAudioEngine more powerful but overkill for simple file recording |

**Installation:**
```bash
# Add to Package.swift or Xcode SPM
https://github.com/sindresorhus/KeyboardShortcuts
```

## Architecture Patterns

### Recommended Project Structure
```
DictationApp/
  Sources/
    Services/
      AudioRecorder.swift        # AVAudioRecorder wrapper
      HotkeyManager.swift        # KeyboardShortcuts integration
      PermissionManager.swift    # Microphone + Accessibility permission handling
    App/
      AppDelegate.swift          # Menu bar icon state changes (existing)
```

### Pattern 1: Service Singleton with @MainActor

**What:** Services that manage system resources use @MainActor singleton pattern for Swift 6 concurrency safety.
**When to use:** All services in this app (established in Phase 1).

```swift
// Source: Established pattern from Phase 1
@MainActor
final class AudioRecorder {
    static let shared = AudioRecorder()

    private var recorder: AVAudioRecorder?
    private(set) var isRecording = false

    private init() {}

    func startRecording() throws { /* ... */ }
    func stopRecording() -> URL? { /* ... */ }
}
```

### Pattern 2: Permission Manager with Async Completion

**What:** Centralized permission handling that requests and monitors both microphone and accessibility permissions.
**When to use:** Any feature requiring system permissions.

```swift
// Source: Apple Developer Forums, jano.dev
@MainActor
final class PermissionManager {
    static let shared = PermissionManager()

    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
    }

    func checkMicrophonePermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    func requestMicrophonePermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(options)
    }
}
```

### Pattern 3: Recording State Machine

**What:** Explicit state transitions for recording lifecycle.
**When to use:** Managing the hotkey toggle behavior.

```swift
enum RecordingState {
    case idle
    case recording
    case processing  // After stop, before transcription completes (Phase 3)
}
```

### Anti-Patterns to Avoid

- **Polling for permission changes:** Don't use timers to check if user granted permission in System Settings. Use notification observers or re-check when user triggers action.
- **Keeping audio session active when idle:** Always deactivate audio session after recording stops to release microphone (removes orange indicator).
- **Hard-coding hotkey:** Use KeyboardShortcuts library defaults, but let users customize in Phase 2+ (REC-05 is v2).

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Global hotkey detection | Carbon API wrapper | KeyboardShortcuts library | Handles UserDefaults, conflict detection, SwiftUI recorder UI |
| Permission prompting | Manual alert + URL opening | AXIsProcessTrustedWithOptions | Shows system dialog automatically, handles edge cases |
| Audio format configuration | Custom encoding settings | AVAudioRecorder standard settings | Established patterns, handles codecs correctly |
| Temp file management | Manual path construction | FileManager.temporaryDirectory | Cross-version compatible, proper sandboxing support |

**Key insight:** Audio recording and permission handling have subtle edge cases (device switching, permission revocation, audio session conflicts) that native frameworks handle correctly. Custom solutions tend to fail on specific macOS versions or hardware configurations.

## Common Pitfalls

### Pitfall 1: Microphone Permission Silent Failures

**What goes wrong:** App appears to have permission but records silence. Common on macOS Sonoma 14.2+.
**Why it happens:** `AVCaptureDevice.authorizationStatus` may return stale values after user changes permission in System Settings.
**How to avoid:**
- Always call `AVCaptureDevice.requestAccess(for: .audio)` to trigger the actual dialog
- Re-check permission status before each recording attempt
- Verify audio input levels are non-zero after starting recording
**Warning signs:** Permission shows as granted but `recorder.averagePower(forChannel: 0)` returns -160 dB (silence).

### Pitfall 2: Accessibility Permission Check Returns Wrong Value

**What goes wrong:** `AXIsProcessTrusted()` returns true but CGEvent posting fails silently.
**Why it happens:** macOS Ventura+ has a bug where quickly toggling permission causes stale cached value.
**How to avoid:**
- After requesting permission, inform user they may need to restart the app
- The most reliable check is attempting `CGEventTapCreate` and checking for NULL
**Warning signs:** Permission appears granted in System Settings but keyboard simulation doesn't work.

### Pitfall 3: Audio Session Interference

**What goes wrong:** Starting recording causes background music (Spotify, Apple Music) to stutter or pause.
**Why it happens:** Default AVAudioSession category doesn't allow mixing with other audio.
**How to avoid:**
- Configure audio session category as `.record` (not `.playAndRecord`)
- Set `.mixWithOthers` option if available
- Keep audio session active only during recording
**Warning signs:** User reports music stopping when they press record hotkey.

### Pitfall 4: Hotkey Conflict with System Shortcuts

**What goes wrong:** Option+Space conflicts with input source switching or other apps (Alfred, Raycast).
**Why it happens:** System-wide shortcuts take precedence.
**How to avoid:**
- KeyboardShortcuts library warns about conflicts (leverage this)
- Document common conflicts in keyboard shortcuts info panel
- v2 feature: Make hotkey customizable (REC-05)
**Warning signs:** Hotkey works in some apps but not others, or nothing happens when pressed.

### Pitfall 5: Recording File Path Issues

**What goes wrong:** AVAudioRecorder fails to create file or file is deleted before upload.
**Why it happens:** Temporary directory is cleaned by system, or path contains invalid characters.
**How to avoid:**
- Use unique filename with UUID: `recording-\(UUID().uuidString).wav`
- Verify directory exists before creating recorder
- Don't delete recording file until API upload succeeds
**Warning signs:** Recording starts but `recorder.url` doesn't exist after stop.

## Code Examples

Verified patterns from official sources and research:

### Audio Recording Setup

```swift
// Source: Apple AVFoundation docs, Hacking with Swift
import AVFoundation

@MainActor
final class AudioRecorder {
    static let shared = AudioRecorder()

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private(set) var isRecording = false

    // Audio settings for Groq API compatibility (16kHz mono WAV)
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16000.0,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
    ]

    private init() {}

    func startRecording() throws {
        // Generate unique file in temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "recording-\(UUID().uuidString).wav"
        recordingURL = tempDir.appendingPathComponent(filename)

        guard let url = recordingURL else {
            throw AudioRecorderError.invalidURL
        }

        recorder = try AVAudioRecorder(url: url, settings: audioSettings)
        recorder?.prepareToRecord()

        guard recorder?.record() == true else {
            throw AudioRecorderError.failedToStart
        }

        isRecording = true
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        isRecording = false

        // Verify file exists and has content
        guard let url = recordingURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return url
    }
}

enum AudioRecorderError: LocalizedError {
    case invalidURL
    case failedToStart
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Failed to create recording file"
        case .failedToStart: return "Failed to start recording"
        case .permissionDenied: return "Microphone permission denied"
        }
    }
}
```

### Hotkey Registration with KeyboardShortcuts

```swift
// Source: github.com/sindresorhus/KeyboardShortcuts
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // Default: Option+Space (requirement REC-01)
    static let toggleRecording = Self(
        "toggleRecording",
        default: .init(.space, modifiers: [.option])
    )
}

// In AppDelegate or dedicated HotkeyManager
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private init() {}

    func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                await self?.handleHotkeyPressed()
            }
        }
    }

    private func handleHotkeyPressed() async {
        let recorder = AudioRecorder.shared

        if recorder.isRecording {
            // Stop recording (REC-02)
            if let recordingURL = recorder.stopRecording() {
                // Will hand off to transcription in Phase 3
                NotificationCenter.default.post(
                    name: .recordingDidStop,
                    object: recordingURL
                )
            }
        } else {
            // Start recording (REC-01)
            // Check permissions first
            let permission = PermissionManager.shared

            if permission.checkMicrophonePermission() != .granted {
                if await permission.requestMicrophonePermission() == false {
                    // Guide user to System Settings (PRM-03)
                    permission.showMicrophonePermissionGuidance()
                    return
                }
            }

            do {
                try recorder.startRecording()
                NotificationCenter.default.post(name: .recordingDidStart, object: nil)
            } catch {
                // Error handling will be expanded in Phase 5
                print("Failed to start recording: \(error)")
            }
        }
    }
}

extension Notification.Name {
    static let recordingDidStart = Notification.Name("recordingDidStart")
    static let recordingDidStop = Notification.Name("recordingDidStop")
}
```

### Microphone Permission Handling

```swift
// Source: Apple Developer Forums, AVCaptureDevice docs
import AVFoundation

extension PermissionManager {
    func checkMicrophonePermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    func requestMicrophonePermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func showMicrophonePermissionGuidance() {
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = """
        DictationApp needs microphone access to record your voice.

        To enable:
        1. Open System Settings
        2. Go to Privacy & Security > Microphone
        3. Enable DictationApp
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Open Privacy & Security > Microphone
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
```

### Accessibility Permission Handling

```swift
// Source: jano.dev, gertrude.app, Apple Developer Forums
import ApplicationServices
import AppKit

extension PermissionManager {
    func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        // This shows the system prompt automatically
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(options)
    }

    func showAccessibilityPermissionGuidance() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = """
        DictationApp needs accessibility access to paste transcribed text into other applications.

        To enable:
        1. Open System Settings
        2. Go to Privacy & Security > Accessibility
        3. Enable DictationApp

        Note: You may need to restart the app after granting permission.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
```

### Menu Bar Icon State Changes

```swift
// Source: AppCoda, Apple NSStatusItem docs
// Add to AppDelegate.swift

enum MenuBarIconState {
    case idle
    case recording

    var symbolName: String {
        switch self {
        case .idle:
            return "waveform"
        case .recording:
            return "waveform.circle.fill"  // Filled indicates active state (REC-03)
        }
    }

    var tintColor: NSColor? {
        switch self {
        case .idle:
            return nil  // System default (template mode)
        case .recording:
            return .systemRed  // Red while recording (REC-03)
        }
    }

    var isTemplate: Bool {
        switch self {
        case .idle:
            return true  // Adapts to light/dark mode
        case .recording:
            return false  // Use explicit red color
        }
    }
}

// In AppDelegate
func updateMenuBarIcon(state: MenuBarIconState) {
    guard let button = statusItem?.button else { return }

    let image = NSImage(
        systemSymbolName: state.symbolName,
        accessibilityDescription: state == .recording ? "Recording" : "Dictation"
    )
    image?.isTemplate = state.isTemplate

    button.image = image
    button.contentTintColor = state.tintColor
}

// Subscribe to notifications
func setupRecordingStateObservers() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleRecordingStarted),
        name: .recordingDidStart,
        object: nil
    )
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleRecordingStopped),
        name: .recordingDidStop,
        object: nil
    )
}

@objc func handleRecordingStarted() {
    updateMenuBarIcon(state: .recording)
}

@objc func handleRecordingStopped(_ notification: Notification) {
    updateMenuBarIcon(state: .idle)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Carbon RegisterEventHotKey | KeyboardShortcuts library | 2020+ | Modern Swift API, built-in UI components |
| AVAudioSession.setCategory() deprecated options | Modern category options | macOS 10.15+ | Use `.record` category directly |
| kAXTrustedCheckOptionPrompt pointer handling | .takeUnretainedValue() | Swift 5+ | Memory safety in Swift |

**Deprecated/outdated:**
- Carbon hotkey APIs: Still functional but deprecated, use KeyboardShortcuts wrapper
- SMLoginItemSetEnabled: Replaced by SMAppService in macOS 13+ (already using in Phase 1)

## Open Questions

Things that couldn't be fully resolved:

1. **Minimum recording duration before sending to API**
   - What we know: Groq API accepts files, very short files may fail
   - What's unclear: Exact minimum duration (0.3s? 0.5s? 1s?)
   - Recommendation: Plan for 0.5s minimum, validate during Phase 3 API integration

2. **Audio level metering for visual feedback**
   - What we know: AVAudioRecorder can provide average/peak power levels
   - What's unclear: Whether v1 needs this or if icon change is sufficient
   - Recommendation: Defer to v2 (SET-08), REC-03 only requires icon change

3. **Accessibility permission caching bug on Ventura+**
   - What we know: AXIsProcessTrusted() can return stale values
   - What's unclear: If this affects our use case (checking before paste)
   - Recommendation: Test thoroughly, consider attempting CGEventTapCreate as verification

## Sources

### Primary (HIGH confidence)
- [Apple AVFoundation - AVAudioRecorder settings](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/1390903-settings)
- [Apple AVCaptureDevice - requestAccess](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)
- [KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts) - Global hotkey library

### Secondary (MEDIUM confidence)
- [jano.dev - Accessibility Permission in macOS](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) - Verified with Apple Developer Forums
- [Hacking with Swift - AVAudioRecorder tutorial](https://www.hackingwithswift.com/read/33/2/recording-from-the-microphone-with-avaudiorecorder)
- [Apple Developer Forums - CGEvent keyboard simulation](https://developer.apple.com/forums/thread/659804)
- [gertrude.app - Request Accessibility Control](https://gertrude.app/blog/macos-request-accessibility-control)

### Tertiary (LOW confidence)
- [AppCoda - Status Bar Apps](https://www.appcoda.com/macos-status-bar-apps/) - Menu bar icon patterns
- Community discussions on macOS Sonoma permission bugs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Native frameworks well-documented, KeyboardShortcuts widely used
- Architecture: HIGH - Patterns established in Phase 1, extended with research
- Pitfalls: MEDIUM - Based on community reports, needs validation during implementation

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - stable APIs, mature libraries)
