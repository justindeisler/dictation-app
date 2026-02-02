# Architecture Research: macOS Dictation App

## Executive Summary

This architecture document outlines the component structure, data flow, and build order for a native macOS menu bar dictation app. The app uses Swift/SwiftUI with AppKit integration for menu bar functionality, AVFoundation for audio recording, and Groq's Whisper API for transcription.

**Key Architectural Decision**: Use AppKit as the foundation (not pure SwiftUI) to control the startup sequence, menu bar lifecycle, and system-level integration, while leveraging SwiftUI for any UI components needed.

---

## Components

### 1. App Shell (NSApplicationDelegate + AppKit)

**Purpose**: Application lifecycle management, menu bar initialization, and coordination hub.

**Responsibilities**:
- Initialize as menu-bar-only app (LSUIElement = true in Info.plist)
- Create and manage NSStatusBar/NSStatusItem
- Coordinate component lifecycle
- Handle app activation/deactivation states
- Provide centralized error handling

**Technology Stack**:
- `NSApplication` and `NSApplicationDelegate` for app lifecycle
- `NSStatusBar.system` to access the system menu bar
- `NSStatusItem` with variable length for menu bar presence
- AppKit for bootstrap control (not SwiftUI App entry point)

**Key Classes**:
- `AppDelegate`: Main coordinator
- `StatusBarController`: Manages NSStatusItem, icon states, and menu

**References**:
- [Building a MacOS Menu Bar App with Swift](https://gaitatzis.medium.com/building-a-macos-menu-bar-app-with-swift-d6e293cd48eb)
- [What I Learned Building a Native macOS Menu Bar App](https://dev.to/heocoi/what-i-learned-building-a-native-macos-menu-bar-app-4im6)
- [A menu bar only macOS app using AppKit](https://www.polpiella.dev/a-menu-bar-only-macos-app-using-appkit/)

---

### 2. Hotkey Manager (Global Keyboard Shortcut Handler)

**Purpose**: Register and handle global keyboard shortcuts (Option+Space) to trigger recording start/stop.

**Responsibilities**:
- Register global hotkey using Carbon API wrappers
- Handle hotkey events system-wide (even when app not focused)
- Toggle recording state (start on first press, stop on second press)
- Provide user-configurable shortcut UI (optional enhancement)

**Technology Stack**:
- **Recommended**: [KeyboardShortcuts package](https://github.com/sindresorhus/KeyboardShortcuts) (maintained Jan 2025)
  - User-customizable shortcuts with built-in UI
  - Stores shortcuts in UserDefaults
  - Warns about system conflicts
- **Alternative**: [HotKey package](https://github.com/soffes/HotKey) (updated Feb 2025)
  - Simpler for hardcoded shortcuts
  - Wraps Carbon API directly

**Key Implementation**:
```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.option]))
}

KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
    self?.toggleRecording()
}
```

**References**:
- [GitHub - sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- [GitHub - soffes/HotKey](https://github.com/soffes/HotKey)
- [Creating a global configurable shortcut for MacOS apps in Swift](https://dev.to/mitchartemis/creating-a-global-configurable-shortcut-for-macos-apps-in-swift-25e9)

---

### 3. Audio Recorder (AVFoundation Recording Manager)

**Purpose**: Capture microphone input and save to temporary audio file.

**Responsibilities**:
- Request microphone permission (mandatory user authorization)
- Configure AVAudioSession for recording
- Initialize AVAudioRecorder with proper settings
- Start/stop recording based on hotkey events
- Manage temporary file storage (.m4a or .wav format)
- Clean up audio files after transcription

**Technology Stack**:
- `AVFoundation` framework
- `AVAudioRecorder` for recording
- `AVAudioSession` for audio configuration (iOS) / audio setup for macOS
- File system for temporary storage

**Key Configuration**:
```swift
let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 16000.0,  // 16kHz optimal for Whisper
    AVNumberOfChannelsKey: 1,   // Mono
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]
```

**Supported Formats** (per Groq API): flac, mp3, m4a, wav, webm
**Recommended**: m4a (MPEG4AAC) for balance of quality and file size

**References**:
- [Recording from the microphone with AVAudioRecorder](https://www.hackingwithswift.com/read/33/2/recording-from-the-microphone-with-avaudiorecorder)
- [How to record audio using AVAudioRecorder](https://www.hackingwithswift.com/example-code/media/how-to-record-audio-using-avaudiorecorder)
- [AVAudioRecorder - Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avaudiorecorder)
- [Mastering Audio Recording in iOS with AVFoundation](https://www.bomberbot.com/school/mastering-audio-recording-in-ios-with-avfoundation-an-expert-guide/)

---

### 4. Transcription Client (Groq Whisper API Integration)

**Purpose**: Send audio file to Groq API and receive transcribed text.

**Responsibilities**:
- Create multipart/form-data HTTP request
- Upload audio file to Groq Whisper endpoint
- Handle API authentication (API key from Settings)
- Parse JSON response and extract transcription text
- Implement error handling and retry logic
- Provide loading state feedback

**Technology Stack**:
- `URLSession` for HTTP networking
- `JSONDecoder` for response parsing
- Groq Whisper API: `https://api.groq.com/openai/v1/audio/transcriptions`

**API Details**:
- **Model**: `whisper-large-v3-turbo` (216x real-time speed)
- **Pricing**: $0.04/hour (12x cheaper than OpenAI)
- **Request Format**: multipart/form-data with audio file
- **Response Format**: JSON with transcription text
- **Authentication**: Bearer token in Authorization header

**Key Implementation**:
```swift
var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
// Add multipart form data with audio file and model parameter
```

**Optional Enhancements**:
- Language detection or explicit language parameter (improves accuracy)
- Verbose JSON format for timestamps and confidence scores

**References**:
- [Speech to Text - GroqDocs](https://console.groq.com/docs/speech-to-text)
- [Groq API Reference](https://console.groq.com/docs/api-reference)
- [GitHub - writingmate/aidictation](https://github.com/writingmate/aidictation) (Swift/SwiftUI reference implementation)
- [Whisper Large v3 Turbo on Groq](https://groq.com/blog/whisper-large-v3-turbo-now-available-on-groq-combining-speed-quality-for-speech-recognition)

---

### 5. Text Paster (Clipboard + Keyboard Simulation)

**Purpose**: Insert transcribed text into the active application.

**Responsibilities**:
- Copy transcription text to system clipboard
- Simulate Cmd+V keyboard shortcut to paste
- Restore previous clipboard content (optional UX enhancement)
- Handle accessibility permission requirements

**Technology Stack**:
- `NSPasteboard` for clipboard operations
- `CGEvent` for keyboard event simulation
- Accessibility permissions (required for CGEvent posting)

**Critical Requirement**: App must request Accessibility permissions to use `CGEvent.post()`. This is required for keyboard simulation but blocks Mac App Store distribution (must use Developer ID instead).

**Key Implementation**:
```swift
// Copy to clipboard
let pasteboard = NSPasteboard.general
pasteboard.clearContents()
pasteboard.setString(transcription, forType: .string)

// Simulate Cmd+V
let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true)
keyDown?.flags = .maskCommand
keyDown?.post(tap: .cghidEventTap)

let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
keyUp?.flags = .maskCommand
keyUp?.post(tap: .cghidEventTap)
```

**Alternative Approaches**:
- Clipboard-only: Skip keyboard simulation, user manually pastes
- AppleScript/NSAppleScript: Send paste command to frontmost app
- AXUIElement: Direct text insertion via Accessibility API (more complex)

**References**:
- [Paste as keystrokes (macOS) - GitHub Gist](https://gist.github.com/sscotth/310db98e7c4ec74e21819806dc527e97)
- [CGEvent to simulate paste command - Apple Developer Forums](https://developer.apple.com/forums/thread/659804)
- [Sending "paste" events to other apps - Apple Developer Forums](https://developer.apple.com/forums/thread/61387)

---

### 6. Settings Manager (UserDefaults Storage)

**Purpose**: Persist user configuration and preferences.

**Responsibilities**:
- Store Groq API key securely (consider Keychain for production)
- Save user preferences (language, model, shortcuts)
- Provide default values via `register(defaults:)`
- Expose settings UI (SwiftUI sheet or NSPanel)

**Technology Stack**:
- `UserDefaults.standard` for simple preferences
- `Keychain` (Security framework) for API keys and sensitive data
- Optional: [sindresorhus/Defaults](https://github.com/sindresorhus/Defaults) for type-safe SwiftUI integration

**Storage Locations**:
- Non-sandboxed: `~/Library/Preferences/[bundle-id].plist`
- Sandboxed: `~/Library/Containers/[bundle-id]/Data/Library/Preferences/[bundle-id].plist`

**Key Settings**:
```swift
enum Settings {
    static let groqAPIKey = "groqAPIKey"  // Consider Keychain instead
    static let selectedModel = "selectedModel"  // Default: whisper-large-v3-turbo
    static let inputLanguage = "inputLanguage"  // Optional: en, es, fr, etc.
    static let globalShortcut = "globalShortcut"  // Handled by KeyboardShortcuts
}

// Set defaults
UserDefaults.standard.register(defaults: [
    Settings.selectedModel: "whisper-large-v3-turbo",
    Settings.inputLanguage: "en"
])
```

**Security Consideration**: API keys should use Keychain Services, not UserDefaults, for production apps.

**References**:
- [UserDefaults - Apple Developer Documentation](https://developer.apple.com/documentation/foundation/userdefaults)
- [User Defaults reading and writing in Swift](https://www.avanderlee.com/swift/user-defaults-preferences/)
- [GitHub - sindresorhus/Defaults](https://github.com/sindresorhus/Defaults)
- [Setting default values for NSUserDefaults](https://sarunw.com/posts/setting-default-value-for-nsuserdefaults/)

---

### 7. Notification Manager (User Feedback System)

**Purpose**: Provide visual feedback for recording status and errors.

**Responsibilities**:
- Show recording status (recording, processing, completed)
- Display error notifications (API failures, permission denials)
- Update menu bar icon state (idle, recording, processing)
- Provide non-intrusive feedback

**Technology Stack**:
- `UNUserNotificationCenter` (modern notification API)
- Menu bar icon state changes (NSStatusItem.button.image)
- Optional: NSAlert for critical errors requiring user action

**Implementation Notes**:
- UNUserNotificationCenter is the modern API (replaces deprecated NSUserNotificationCenter)
- Menu bar icon changes provide immediate visual feedback without notification spam
- Notifications should be used sparingly (errors and completion only)

**Icon States**:
- Idle: Microphone icon (gray)
- Recording: Microphone icon (red) or recording indicator
- Processing: Spinner or cloud icon
- Error: Warning icon (yellow/red)

**Notification Scenarios**:
- Recording started (optional, icon change may be sufficient)
- Transcription completed (optional, paste action may be sufficient)
- API error (mandatory: "Transcription failed: [reason]")
- Permission denied (mandatory: "Microphone/Accessibility access required")

**References**:
- [UNUserNotificationCenter - Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Scheduling notifications with UNUserNotificationCenter](https://www.hackingwithswift.com/read/21/2/scheduling-notifications-unusernotificationcenter-and-unnotificationrequest)
- [Exploring MacOS Development: Creating a Menu Bar App](https://capgemini.github.io/development/macos-development-with-swift/)

---

## Data Flow

### Primary Flow: Successful Transcription

```
┌─────────────┐
│   User      │
│ Presses     │ (1) Option+Space pressed
│ Hotkey      │
└──────┬──────┘
       │
       ▼
┌─────────────────────────┐
│   Hotkey Manager        │ (2) Detects hotkey event
│   (KeyboardShortcuts)   │     Toggles recording state
└──────┬──────────────────┘
       │
       │ (3) Start recording
       ▼
┌─────────────────────────┐
│   Audio Recorder        │ (4) Requests mic permission (if needed)
│   (AVAudioRecorder)     │     Configures audio session
│                         │     Starts recording to temp file
└──────┬──────────────────┘     Updates icon: recording state
       │
       │ User speaks...
       │
       │ (5) Option+Space pressed again
       ▼
┌─────────────────────────┐
│   Hotkey Manager        │ (6) Detects hotkey event
│                         │     Signals stop recording
└──────┬──────────────────┘
       │
       │ (7) Stop recording
       ▼
┌─────────────────────────┐
│   Audio Recorder        │ (8) Stops recording
│                         │     Finalizes audio file
└──────┬──────────────────┘     Updates icon: processing state
       │
       │ (9) Audio file path
       ▼
┌─────────────────────────┐
│   Transcription Client  │ (10) Reads API key from Settings
│   (URLSession)          │      Creates multipart request
│                         │      Uploads audio to Groq API
└──────┬──────────────────┘      Waits for response (1-3s)
       │
       │ (11) JSON response with transcription text
       ▼
┌─────────────────────────┐
│   Text Paster           │ (12) Requests accessibility permission (if needed)
│   (CGEvent)             │      Copies text to clipboard
│                         │      Simulates Cmd+V keypress
└──────┬──────────────────┘      Updates icon: completed state
       │
       │ (13) Text appears in active application
       ▼
┌─────────────┐
│   User sees │
│   text in   │
│   active    │
│   field     │
└─────────────┘

(14) Audio Recorder cleans up temp file
(15) Notification Manager shows success (optional)
```

### Error Flow: Transcription Failure

```
┌─────────────────────────┐
│   Transcription Client  │ API request fails
│                         │ (network error, auth failure, etc.)
└──────┬──────────────────┘
       │
       │ Error object
       ▼
┌─────────────────────────┐
│   App Shell             │ Receives error
│   (AppDelegate)         │ Logs error details
└──────┬──────────────────┘
       │
       │ (1) Update icon: error state
       │ (2) Trigger notification
       ▼
┌─────────────────────────┐
│   Notification Manager  │ Shows error notification
│   (UNUserNotificationCenter)│ "Transcription failed: [reason]"
└─────────────────────────┘ User can retry or check settings
```

### Configuration Flow

```
┌─────────────┐
│   User      │ Opens settings from menu bar
└──────┬──────┘
       │
       ▼
┌─────────────────────────┐
│   App Shell             │ Presents settings window
│                         │ (SwiftUI sheet or NSPanel)
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│   Settings Manager      │ Loads current values from UserDefaults
│   (UserDefaults)        │ User edits API key, language, etc.
│                         │ Saves changes on commit
└──────┬──────────────────┘
       │
       │ Settings updated
       ▼
┌─────────────────────────┐
│   Components            │ Components read new settings
│   (Transcription Client,│ API key, model, language
│    Hotkey Manager, etc.)│ Reconfigure as needed
└─────────────────────────┘
```

---

## Component Dependencies

### Dependency Graph

```
┌──────────────────────────────────────────────────────────────┐
│                         App Shell                            │
│                    (NSApplicationDelegate)                   │
│                                                              │
│  • Initializes all components                               │
│  • Coordinates lifecycle                                    │
│  • Handles errors                                           │
└──┬───────────────┬───────────────┬───────────────┬──────────┘
   │               │               │               │
   │               │               │               │
   ▼               ▼               ▼               ▼
┌─────────┐  ┌──────────┐  ┌─────────────┐  ┌──────────┐
│ Hotkey  │  │  Audio   │  │Transcription│  │ Settings │
│ Manager │  │ Recorder │  │   Client    │  │ Manager  │
└────┬────┘  └─────┬────┘  └──────┬──────┘  └────┬─────┘
     │             │               │               │
     │             │               │               │
     │   triggers  │  provides     │  reads        │
     └────────────>│  audio file   │  API key      │
                   └──────────────>│<──────────────┘
                                   │
                                   │ returns text
                                   │
                                   ▼
                            ┌──────────────┐
                            │ Text Paster  │
                            │  (CGEvent)   │
                            └──────────────┘
                                   │
                                   │ uses
                                   ▼
                            ┌──────────────┐
                            │ Notification │
                            │   Manager    │
                            └──────────────┘
```

### Dependency Matrix

| Component              | Depends On                                | Depended On By                |
|------------------------|-------------------------------------------|-------------------------------|
| App Shell              | All components                            | None (top-level)              |
| Hotkey Manager         | Settings Manager                          | App Shell, Audio Recorder     |
| Audio Recorder         | Settings Manager                          | App Shell, Transcription Client|
| Transcription Client   | Settings Manager, Audio Recorder          | App Shell, Text Paster        |
| Text Paster            | Transcription Client                      | App Shell                     |
| Settings Manager       | None (leaf dependency)                    | All components                |
| Notification Manager   | None (optional utility)                   | All components                |

### Key Coupling Points

1. **App Shell → All**: Central coordinator, high coupling acceptable
2. **Settings Manager ← All**: Shared configuration source, read-only coupling
3. **Hotkey → Audio**: Tight coupling for recording state (consider event bus)
4. **Audio → Transcription**: File path coupling (loose via file system)
5. **Transcription → Text Paster**: Text string coupling (loose)

### Decoupling Recommendations

- Use protocol-based design for testability
- Implement observer pattern for status updates (recording, processing, error)
- Consider NotificationCenter for cross-component events
- Use dependency injection in AppDelegate for easier testing

---

## Suggested Build Order

### Phase 1: Foundation (Days 1-2)

**Goal**: Menu bar app that shows up and responds to clicks

1. **App Shell** (Priority: Critical)
   - Create AppKit-based application with LSUIElement = true
   - Implement NSApplicationDelegate
   - Create NSStatusItem in menu bar
   - Add basic menu (Quit, Settings placeholder)
   - Verify app shows in menu bar and menu responds

**Rationale**: Establishes the foundation and feedback loop. You need the menu bar presence to test all other features.

**Validation**: Click menu bar icon, see menu with Quit option, can quit app.

---

### Phase 2: Input Detection (Days 3-4)

**Goal**: Detect hotkey presses globally

2. **Settings Manager** (Priority: High - needed before Hotkey Manager)
   - Implement UserDefaults wrapper
   - Register default values
   - Create simple settings window (SwiftUI or AppKit)
   - Add API key input field (store in UserDefaults for now)

**Rationale**: Settings infrastructure needed before components that read settings.

**Validation**: Open settings window, enter API key, verify persistence across app restarts.

3. **Hotkey Manager** (Priority: Critical)
   - Add KeyboardShortcuts package via SPM
   - Register Option+Space as default shortcut
   - Add hotkey handler that logs to console
   - Update menu bar icon on hotkey press (visual feedback)

**Rationale**: Critical for core functionality. Test early before adding complexity.

**Validation**: Press Option+Space anywhere on macOS, see console log and icon change.

---

### Phase 3: Audio Capture (Days 5-7)

**Goal**: Record audio to file

4. **Audio Recorder** (Priority: Critical)
   - Request microphone permission
   - Implement AVAudioRecorder setup
   - Add start/stop recording methods
   - Save to temp file with unique names
   - Log recording status and file paths

**Rationale**: Core functionality, no external dependencies beyond AVFoundation.

**Validation**: Press hotkey twice (start/stop), verify audio file exists in temp directory, playback manually confirms recording.

5. **Integrate Hotkey → Audio Recorder**
   - Connect hotkey presses to recording start/stop
   - Implement toggle state (first press = start, second = stop)
   - Update menu bar icon based on recording state
   - Add menu item to show current state

**Validation**: Press Option+Space, speak, press again, see audio file created with voice recorded.

---

### Phase 4: Transcription (Days 8-10)

**Goal**: Send audio to API and receive text

6. **Transcription Client** (Priority: Critical)
   - Implement URLSession multipart upload
   - Add Groq API authentication with stored API key
   - Parse JSON response and extract text
   - Add error handling and logging
   - Test with sample audio files first

**Rationale**: External API dependency, test independently before full integration.

**Validation**: Call transcription client with test audio file, receive transcription text in console.

7. **Integrate Audio → Transcription**
   - Trigger transcription after recording stops
   - Show "processing" state in menu bar icon
   - Log transcription result
   - Clean up audio file after successful transcription

**Validation**: Record voice, wait, see transcription text in console, verify temp file deleted.

---

### Phase 5: Text Insertion (Days 11-12)

**Goal**: Paste transcription into active app

8. **Text Paster** (Priority: High)
   - Request Accessibility permission
   - Implement clipboard copy
   - Implement CGEvent keyboard simulation (Cmd+V)
   - Add fallback to clipboard-only mode if accessibility denied

**Rationale**: Requires system permissions, may need user action.

**Validation**: Manually call text paster with sample text, verify it appears in focused text field.

9. **Integrate Transcription → Text Paster**
   - Trigger paste after transcription completes
   - Handle empty transcriptions gracefully
   - Add optional notification on completion

**Validation**: End-to-end flow: press hotkey, speak, press hotkey, see text pasted in active app.

---

### Phase 6: Polish & Feedback (Days 13-14)

**Goal**: User-friendly feedback and error handling

10. **Notification Manager** (Priority: Medium)
    - Implement UNUserNotificationCenter setup
    - Add error notifications (API failures, permission denials)
    - Add optional completion notifications
    - Improve menu bar icon states

**Rationale**: UX polish, not critical for core functionality.

**Validation**: Trigger various errors, verify appropriate notifications appear.

11. **Error Handling & Edge Cases**
    - Handle no microphone permission
    - Handle no accessibility permission
    - Handle API key missing or invalid
    - Handle network failures and timeouts
    - Handle empty or silent recordings

**Rationale**: Production-readiness requires robust error handling.

**Validation**: Test all failure scenarios, verify graceful degradation and helpful error messages.

---

### Phase 7: Enhancement (Days 15+)

**Optional improvements after MVP**:

- Custom hotkey configuration UI (KeyboardShortcuts.Recorder)
- Language selection dropdown (improves Whisper accuracy)
- Model selection (whisper-large-v3 vs whisper-large-v3-turbo)
- Recording indicator (system-wide overlay or animated icon)
- Clipboard history preservation (save/restore previous clipboard)
- Keyboard shortcut to cancel recording mid-way
- Unit tests for components
- Integration tests for flows

---

## Integration Points

### Critical Integration Points (High Risk)

1. **Hotkey → Audio Recorder State Management**
   - **Risk**: Race conditions if user presses hotkey rapidly
   - **Mitigation**: Implement state machine (idle, recording, processing)
   - **Testing**: Rapid hotkey presses, verify single recording at a time

2. **Audio File → Transcription Client**
   - **Risk**: File not ready when transcription starts, or file missing
   - **Mitigation**: Use file system notifications or completion handlers
   - **Testing**: Verify file exists and is readable before upload

3. **Transcription → Text Paster**
   - **Risk**: Empty transcription, extremely long transcription, special characters
   - **Mitigation**: Validate transcription text, sanitize if needed
   - **Testing**: Test with silence, long recordings, special characters

4. **CGEvent.post() Accessibility Permission**
   - **Risk**: Permission denied silently, paste fails without feedback
   - **Mitigation**: Check permission status before posting, prompt user if denied
   - **Testing**: Test with permission granted and denied, verify fallback behavior

### Moderate Integration Points

5. **Settings → Multiple Components**
   - **Risk**: Settings changes during operation cause inconsistent state
   - **Mitigation**: Reload settings on app activation or use KVO/Combine publishers
   - **Testing**: Change settings while recording, verify graceful handling

6. **Error Propagation (Component → Notification Manager)**
   - **Risk**: Errors lost or not visible to user
   - **Mitigation**: Centralized error handling in AppDelegate, always notify user
   - **Testing**: Trigger errors, verify user notification

### Low Risk Integration Points

7. **Menu Bar Icon Updates**
   - **Risk**: Icon doesn't update or updates incorrectly
   - **Mitigation**: Ensure main thread execution for UI updates
   - **Testing**: Visual inspection during each state transition

8. **Temp File Cleanup**
   - **Risk**: Orphaned files accumulate over time
   - **Mitigation**: Clean up in finally blocks, implement periodic cleanup on launch
   - **Testing**: Create multiple recordings, verify files deleted

---

## Technology Decisions Summary

| Component              | Primary Technology                | Alternative                     | Decision Rationale                |
|------------------------|-----------------------------------|---------------------------------|-----------------------------------|
| App Foundation         | AppKit (NSApplication)            | SwiftUI App                     | Better lifecycle control, menu bar integration |
| Menu Bar               | NSStatusBar/NSStatusItem          | None                            | Standard macOS API                |
| Global Hotkeys         | KeyboardShortcuts package         | HotKey package                  | User-customizable, maintained     |
| Audio Recording        | AVAudioRecorder                   | AVCaptureDevice                 | Simpler API for file-based recording |
| HTTP Networking        | URLSession                        | Third-party (Alamofire)         | Native, sufficient for simple API |
| JSON Parsing           | Codable/JSONDecoder               | SwiftyJSON                      | Native, type-safe                 |
| Text Insertion         | CGEvent + NSPasteboard            | AppleScript, AXUIElement        | Most reliable, fastest            |
| Settings Storage       | UserDefaults                      | Keychain (for API keys)         | Simple, recommend Keychain upgrade |
| Notifications          | UNUserNotificationCenter          | NSUserNotificationCenter (deprecated) | Modern API                        |
| UI (if needed)         | SwiftUI                           | AppKit                          | Modern, declarative               |

---

## Architectural Principles

### 1. Separation of Concerns
- Each component has a single, well-defined responsibility
- Components communicate through clear interfaces
- Avoid tight coupling between unrelated components

### 2. Fail-Safe Design
- Graceful degradation when permissions denied (clipboard-only mode)
- Clear error messages guide user to fix issues
- Never crash due to network or permission errors

### 3. Privacy & Security
- Request only necessary permissions (microphone, accessibility)
- Explain permission usage to user
- Consider Keychain for API key storage in production
- Clean up audio files immediately after use

### 4. User Experience
- Provide immediate visual feedback (icon state changes)
- Minimize notifications (use icon states primarily)
- Fast transcription (Groq Whisper turbo model)
- Non-blocking operations (async/await for network calls)

### 5. Testability
- Protocol-based design for dependency injection
- Separate business logic from UI/system integration
- Mock external dependencies (API, file system) in tests

---

## Deployment Considerations

### macOS App Distribution

**Developer ID (Recommended)**:
- Required for CGEvent.post() accessibility features
- Distributed outside Mac App Store
- Notarization required for macOS 10.15+
- No sandboxing restrictions

**Mac App Store (Limited)**:
- Cannot use CGEvent.post() (sandbox restriction)
- Would require different text insertion approach (less reliable)
- Stricter review guidelines
- Limited to App Sandbox entitlements

### Required Entitlements & Permissions

```xml
<!-- Info.plist -->
<key>LSUIElement</key>
<true/>

<key>NSMicrophoneUsageDescription</key>
<string>Record audio for voice transcription</string>

<!-- Accessibility permission request at runtime -->
```

### Build Configuration

- Minimum macOS version: 12.0+ (for modern UNUserNotificationCenter)
- Swift 5.5+ (for async/await)
- Xcode 14+

---

## Conclusion

This architecture provides a clear separation of concerns with well-defined component boundaries. The suggested build order follows a logical progression from foundation to core functionality to polish, allowing for incremental testing and validation at each phase.

The key architectural decisions prioritize:
1. **Reliability**: AppKit foundation for stable menu bar integration
2. **Performance**: Groq Whisper turbo model for fast transcription
3. **User Experience**: Clear visual feedback, minimal notifications
4. **Maintainability**: Protocol-based design, separation of concerns

The architecture is designed for rapid prototyping while maintaining clean component boundaries for future enhancements and testing.
