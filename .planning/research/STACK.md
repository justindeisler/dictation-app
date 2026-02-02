# Stack Research: macOS Dictation App

**Research Date**: 2026-02-02
**Target Platform**: macOS Sequoia 15.0+ (Sonoma 14.0+ compatible)
**Project Type**: Native menu bar dictation app with cloud API integration

## Executive Summary

This stack prioritizes **native performance, sub-second latency, and minimal dependencies**. The recommended approach uses Swift 6.1+ with SwiftUI for modern development while maintaining backward compatibility through strategic AppKit integration where needed.

**Key Decision**: Pure Swift/native frameworks (no third-party networking libraries) with Swift Package Manager for the few dependencies needed (global hotkeys).

---

## Recommended Stack

### Language & Framework

**Swift 6.1+ with Swift 6 Language Mode**
- **Why**: Latest stable release with full async/await concurrency, improved type safety, and data race prevention
- **Confidence**: 95%
- **Sources**: [Swift Official](https://github.com/swiftlang/swift), Swift 6.1.2-RELEASE available
- **Rationale**:
  - Native async/await eliminates callback complexity for audio recording → API call → paste workflow
  - Swift Concurrency prevents data races in hotkey → record → API → paste pipeline
  - Zero-cost abstractions maintain sub-second latency requirements
  - Native to macOS ecosystem with excellent Xcode integration

**SwiftUI + Strategic AppKit Integration**
- **Primary**: SwiftUI for settings UI and modern development
- **AppKit**: For menu bar management (NSStatusItem) and advanced paste control
- **Confidence**: 90%
- **Rationale**:
  - **MenuBarExtra** (SwiftUI): Simple, clean API for basic menu bar apps BUT only macOS 13+ and limited to menu-style UI ([source](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/))
  - **NSStatusItem** (AppKit): Full control over menu bar item, custom popup windows, and broader macOS compatibility ([source](https://sarunw.com/posts/swiftui-menu-bar-app/))
  - **Decision**: Use NSStatusItem for reliability and control, SwiftUI for settings windows
  - Mixing SwiftUI + AppKit is standard practice for menu bar apps in 2025 ([source](https://gaitatzis.medium.com/building-a-macos-menu-bar-app-with-swift))

**Minimum Deployment Target**: macOS 14.0 (Sonoma)
- Balances modern Swift Concurrency features with reasonable user base
- Avoid macOS 13.0 to skip MenuBarExtra limitations

---

### Audio Recording

**AVFoundation (AVAudioRecorder + AVAudioSession)**
- **Framework**: Native Apple AVFoundation
- **Confidence**: 95%
- **Sources**: [Apple AVFoundation Docs](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/1390903-settings), [AVFoundation Guide](https://reintech.io/blog/developing-audio-video-applications-avfoundation)

**Audio Format Configuration**:
```swift
let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),  // WAV format
    AVSampleRateKey: 16000.0,                    // 16kHz (Whisper optimal)
    AVNumberOfChannelsKey: 1,                    // Mono
    AVLinearPCMBitDepthKey: 16,                  // 16-bit
    AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]
```

**Rationale**:
- **16kHz sample rate**: Groq Whisper API downsamples to 16kHz mono anyway ([Groq Docs](https://console.groq.com/docs/speech-to-text)), so recording at 44.1kHz wastes bandwidth and processing
- **Mono audio**: Speech recognition doesn't benefit from stereo
- **WAV/PCM format**: Uncompressed for fastest encoding, Groq accepts WAV ([Groq API](https://console.groq.com/docs/speech-to-text))
- **Native AVFoundation**: Zero dependencies, optimized for macOS, direct access to audio input

**Privacy Requirements**:
- Add `NSMicrophoneUsageDescription` to Info.plist
- User will see system permission prompt on first use

**Alternative Considered**: AVAudioEngine for real-time streaming
- **Rejected**: Groq API requires file upload (no streaming endpoint), AVAudioRecorder simpler for record-then-send pattern

---

### Global Hotkey

**KeyboardShortcuts by Sindre Sorhus**
- **Version**: 2.x (latest stable)
- **Repository**: [github.com/sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- **Installation**: Swift Package Manager
- **Confidence**: 92%

**Rationale**:
- **Modern Swift API**: Native async/await support, SwiftUI components included
- **User Customization**: Built-in `KeyboardShortcuts.Recorder` view for settings UI
- **Automatic Persistence**: Stores shortcuts in UserDefaults automatically
- **Conflict Detection**: Warns users if shortcut conflicts with system/app menus
- **Active Maintenance**: Well-maintained by reputable Swift developer (50k+ GitHub stars combined projects)
- **Superior to alternatives**: More modern than HotKey (older API), better than MASShortcut (Objective-C bridge)

**Sources**: [GitHub - KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [DEV Community Guide](https://dev.to/mitchartemis/creating-a-global-configurable-shortcut-for-macos-apps-in-swift-25e9)

**Implementation Pattern**:
```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let dictate = Self("dictate", default: .init(.space, modifiers: [.option]))
}

// In App
KeyboardShortcuts.onKeyUp(for: .dictate) {
    await startDictation()
}
```

**Alternative Considered**: Carbon API (RegisterEventHotKey)
- **Rejected**: Legacy API, not recommended by Apple for modern apps ([Apple Forums](https://developer.apple.com/forums/thread/735223)), requires more boilerplate

---

### Network/API Integration

**URLSession with async/await**
- **Framework**: Native Foundation URLSession
- **Confidence**: 95%
- **Sources**: [Apple WWDC21](https://developer.apple.com/videos/play/wwdc2021/10095/), [avanderlee.com](https://www.avanderlee.com/concurrency/urlsession-async-await-network-requests-in-swift/)

**Rationale**:
- **Native async/await support**: URLSession.data(for:) returns (Data, URLResponse) with natural error handling
- **Zero dependencies**: No need for Alamofire or other networking libraries
- **Linear control flow**: Avoids callback hell, runs on same concurrency context
- **Modern Swift**: Swift 6 concurrency makes URLSession elegant and safe
- **Multipart form-data**: Native support for Groq's file upload API

**Implementation Pattern**:
```swift
func transcribe(audioURL: URL) async throws -> String {
    var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    // Multipart form-data boundary
    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    let httpBody = createMultipartBody(audioURL: audioURL, boundary: boundary)
    request.httpBody = httpBody

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw APIError.invalidResponse
    }

    let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
    return result.text
}
```

**Groq API Requirements** ([Groq Docs](https://console.groq.com/docs/speech-to-text)):
- **Endpoint**: POST `https://api.groq.com/openai/v1/audio/transcriptions`
- **Model**: `whisper-large-v3-turbo` (fastest, sub-second transcription)
- **File formats**: WAV, MP3, M4A, OGG, etc. (max 25MB)
- **Language**: Optional ISO-639-1 code (e.g., "en", "de") improves latency
- **Response**: JSON with `text` field

**Error Handling Strategy**:
- Network errors: Display notification with retry option
- Rate limits: Exponential backoff
- Invalid API key: Direct user to settings
- Audio too short (<0.3s): Ignore, don't send to API

**Alternative Considered**: Third-party HTTP libraries (Alamofire, Moya)
- **Rejected**: Unnecessary dependency for simple API calls, URLSession async/await is sufficient and faster

---

### Paste Simulation

**CGEvent with Accessibility Permissions**
- **Framework**: Native ApplicationServices (CoreGraphics)
- **Confidence**: 88%
- **Sources**: [Apple Forums](https://developer.apple.com/forums/thread/659804), [jano.dev](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html), [Igor Kulman](https://blog.kulman.sk/implementing-auto-type-on-macos/)

**Rationale**:
- **CGEvent best practice**: Preferred over NSAppleScript for reliability and speed
- **System-wide paste**: Works in any application (native apps, Electron, browsers)
- **Clipboard + Cmd+V simulation**: Most reliable approach for text insertion

**Implementation Pattern**:
```swift
func pasteText(_ text: String) {
    // 1. Save current clipboard
    let pasteboard = NSPasteboard.general
    let oldContents = pasteboard.string(forType: .string)

    // 2. Set text to clipboard
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)

    // 3. Simulate Cmd+V
    let keyVDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true)
    keyVDown?.flags = .maskCommand
    keyVDown?.post(tap: .cghidEventTap)

    let keyVUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
    keyVUp?.flags = .maskCommand
    keyVUp?.post(tap: .cghidEventTap)

    // 4. Optional: Restore clipboard after delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        pasteboard.clearContents()
        if let oldContents = oldContents {
            pasteboard.setString(oldContents, forType: .string)
        }
    }
}
```

**Privacy & Security Requirements**:
- **Accessibility Permission**: Required for CGEvent posting ([Apple Support](https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac))
- **Permission Check**: Use `AXIsProcessTrusted()` or `CGEvent.RequestPostEventAccess()` ([jano.dev](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html))
- **Code Signing**: App must be properly signed with Developer ID or Mac App Store certificate
- **Permission Prompt**: System shows dialog on first CGEvent post attempt, app must be restarted if denied

**Add to Info.plist**:
```xml
<key>NSAppleEventsUsageDescription</key>
<string>DictationApp needs to paste transcribed text into other applications.</string>
```

**Debugging**:
- Check Console.app for: `type:error subsystem:com.apple.sandbox.reporting category:violation`
- Sandboxing may silently fail, disable App Sandbox during development

**Alternative Considered**: NSAppleScript ("keystroke v using command down")
- **Rejected**: Slower, less reliable, still requires accessibility permissions

---

### Storage

**Keychain Services for API Key + UserDefaults for Preferences**
- **API Key Storage**: Keychain Services (SecItemAdd/SecItemCopyMatching)
- **Preferences**: UserDefaults for hotkey config, language selection
- **Confidence**: 95%
- **Sources**: [Medium - Keychain Security](https://medium.com/@gauravharkhani01/app-security-in-swift-keychain-biometrics-secure-enclave-69359b4cffba), [Medium - UserDefaults vs Keychain](https://rohit-13.medium.com/all-about-userdefaults-keychain-and-coredata-ios-53c8d0c7a0fb)

**Rationale**:
- **Keychain for API keys**: Encrypted storage, tied to device security, protected from file-browsing tools ([source](https://mehrdad-ahmadian.medium.com/enhancing-data-security-in-swiftui-from-userdefaults-to-keychain-631dfeba5b84))
- **UserDefaults for preferences**: Plain text storage acceptable for non-sensitive config
- **Never UserDefaults for API keys**: Plain plist files, easily readable with iExplorer, zero encryption ([source](https://livsycode.com/best-practices/userdefaults-vs-filemanager-vs-keychain-vs-core-data-vs-swiftdata/))

**Keychain Implementation** (use wrapper library for convenience):
```swift
// Recommended: KeychainAccess library (SPM)
// OR native Security framework with SecItemAdd/SecItemCopyMatching
import KeychainAccess

let keychain = Keychain(service: "com.yourname.dictationapp")

// Store
keychain["groq_api_key"] = apiKey

// Retrieve
if let apiKey = keychain["groq_api_key"] {
    // Use API key
}
```

**UserDefaults Usage**:
```swift
@AppStorage("selectedLanguage") private var language = "en"
@AppStorage("autoRestoreClipboard") private var autoRestore = true
```

**What to Store Where**:
| Data Type | Storage | Rationale |
|-----------|---------|-----------|
| Groq API Key | Keychain | Sensitive credential |
| Hotkey Config | UserDefaults | KeyboardShortcuts library handles this |
| Language (en/de) | UserDefaults | User preference, not sensitive |
| Auto-restore clipboard | UserDefaults | App behavior setting |
| Audio file cache | Temporary directory | Delete after API call |

---

## Dependencies

| Dependency | Version | Purpose | Installation | Confidence |
|------------|---------|---------|--------------|------------|
| **KeyboardShortcuts** | 2.x | Global hotkey management with user customization UI | SPM: `https://github.com/sindresorhus/KeyboardShortcuts` | 92% |
| **KeychainAccess** | 4.x | Simplified Keychain wrapper (optional but recommended) | SPM: `https://github.com/kishikawakatsumi/KeychainAccess` | 85% |

**Dependency Philosophy**: Minimize dependencies. Only include libraries that provide significant value over native APIs.

**Swift Package Manager** ([SPM Best Practices 2025](https://commitstudiogs.medium.com/whats-new-in-swift-package-manager-spm-for-2025-d7ffff2765a2)):
- **Version Pinning**: Specify exact versions in Package.swift for stability
- **Signed Packages**: SPM now supports package signing for supply chain security
- **Caching**: Configure `~/Library/Developer/Xcode/DerivedData` caching in CI/CD
- **New Features**: Parallel resolution, strict mode, prebuild/postbuild plugins

**Package.swift Pattern**:
```swift
dependencies: [
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0")
]
```

---

## What NOT to Use

### ❌ Alamofire / Moya
**Why Avoid**: URLSession with async/await is sufficient for simple API calls. Third-party networking libraries add unnecessary complexity and dependency maintenance burden. Native URLSession is faster and has zero supply chain risk.

### ❌ Combine for Networking
**Why Avoid**: Swift Concurrency (async/await) is the modern standard for Swift 6+. Combine adds complexity without benefits for this use case. URLSession.data(for:) already returns async sequences.

### ❌ Electron / React Native
**Why Avoid**: Not native, massive bundle size (100MB+), sluggish performance, poor macOS integration. Swift + SwiftUI is the correct choice for macOS menu bar apps.

### ❌ Carbon API (RegisterEventHotKey)
**Why Avoid**: Legacy API from pre-OS X era, not recommended by Apple, requires boilerplate, poor Swift integration. Use modern KeyboardShortcuts library instead.

### ❌ Core Data / SwiftData
**Why Avoid**: Overkill for simple preference storage. UserDefaults + Keychain are sufficient. No need for persistent database for this app's data model.

### ❌ NSAppleScript for Paste
**Why Avoid**: Slower than CGEvent, less reliable, still requires accessibility permissions. No benefit over native CGEvent approach.

### ❌ Firebase / CloudKit
**Why Avoid**: No need for cloud storage/sync. API key and preferences are device-local. Adding cloud sync would complicate privacy and increase attack surface.

### ❌ Third-party Audio Libraries
**Why Avoid**: AVFoundation is industry-standard, optimized for macOS, and provides everything needed. Third-party audio libraries add complexity without value.

### ❌ MenuBarExtra (SwiftUI Scene)
**Why Avoid**: Only macOS 13+, limited to menu-style UI, no access to underlying NSStatusItem/NSWindow. Use NSStatusItem directly for full control and compatibility.

---

## Open Questions

### High Priority (Resolve Before Implementation)

1. **Audio Processing Latency**
   - **Question**: Should we implement voice activity detection (VAD) to auto-stop recording when user stops speaking, or require explicit stop action (release hotkey)?
   - **Impact**: UX flow, latency optimization
   - **Research Needed**: Test whether Groq's 30-second minimum padding degrades short utterances

2. **Error Feedback Strategy**
   - **Question**: What's the optimal error notification pattern? (macOS notification banner, status bar icon color change, HUD overlay, sound effect?)
   - **Impact**: User experience during API failures
   - **Recommendation**: Test multiple approaches, prioritize non-intrusive but noticeable feedback

3. **Clipboard Restoration**
   - **Question**: Should we always restore the original clipboard after paste, or make it optional? What delay is optimal?
   - **Impact**: User workflow, clipboard manager compatibility
   - **Recommendation**: Make it optional (default: on), 0.5-1s delay to ensure paste completes

### Medium Priority (Revisit During Development)

4. **Hotkey Conflict Resolution**
   - **Question**: How to handle conflicts with other apps using Option+Space (e.g., Spotlight alternatives)?
   - **Current Solution**: KeyboardShortcuts library warns user, allows customization
   - **Consider**: Auto-detect conflicts and suggest alternatives

5. **Multilingual Model Selection**
   - **Question**: Should we auto-detect language or require manual selection? Does explicit language parameter significantly improve Groq accuracy?
   - **Research Needed**: A/B test with/without language parameter for English/German
   - **API Note**: Groq docs say language parameter "improves accuracy and latency" but doesn't quantify

6. **App Sandbox Compatibility**
   - **Question**: Can we enable App Sandbox for Mac App Store distribution while maintaining CGEvent paste functionality?
   - **Known Issue**: CGEvent may silently fail with sandbox ([source](https://developer.apple.com/forums/thread/707680))
   - **Decision Point**: Distribute outside Mac App Store if sandboxing blocks core functionality

### Low Priority (Nice to Have)

7. **Offline Mode / Fallback**
   - **Question**: Should we implement offline speech recognition fallback (macOS Speech framework) when network unavailable?
   - **Trade-off**: Lower accuracy vs. offline capability
   - **Recommendation**: Skip for V1, Groq is primary value proposition

8. **Audio Format Optimization**
   - **Question**: Would Opus or other compressed formats reduce upload time enough to justify encoding overhead?
   - **Current**: WAV 16kHz mono (~1MB/minute)
   - **Research**: Benchmark Groq API upload time vs. encoding time for Opus

9. **Accessibility Alternative**
   - **Question**: Is there a more modern API than CGEvent for system-wide paste? (e.g., Shortcuts.app integration?)
   - **Status**: No known alternative as of macOS Sequoia
   - **Monitor**: Apple's accessibility APIs for future releases

---

## Validation Checklist

- [x] **Versions Current**: Swift 6.1.2, KeyboardShortcuts 2.x, macOS 14.0+ confirmed
- [x] **Rationale Documented**: Each technology choice includes "Why" explanation
- [x] **Confidence Levels Assigned**: 85-95% confidence on all primary decisions
- [x] **Official Sources**: Context7, Apple Developer docs, Groq docs, reputable Swift community sources
- [x] **Alternatives Considered**: Rejected options documented with reasons
- [x] **Open Questions Identified**: 9 questions categorized by priority

---

## Next Steps for Roadmap Creation

1. **Architecture Document**: Define app lifecycle, state management, error handling flows
2. **API Integration Spec**: Detailed Groq API request/response formats, error codes, rate limits
3. **UX Flow Diagram**: Hotkey press → record → API → paste with all error states
4. **Privacy Policy**: Microphone access, accessibility access, API key storage, data handling
5. **Testing Strategy**: Unit tests (API client), integration tests (audio → transcription), manual tests (paste in various apps)

---

## References

### Official Documentation
- [Swift Language](https://github.com/swiftlang/swift)
- [Apple AVFoundation](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/1390903-settings)
- [Apple URLSession async/await](https://developer.apple.com/videos/play/wwdc2021/10095/)
- [Groq Speech-to-Text API](https://console.groq.com/docs/speech-to-text)
- [Apple Accessibility Permissions](https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac)

### Community Resources
- [KeyboardShortcuts Library](https://github.com/sindresorhus/KeyboardShortcuts)
- [HotKey Library](https://github.com/soffes/HotKey)
- [Building macOS Menu Bar Apps (nilcoalescing.com)](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/)
- [CGEvent Paste Implementation (Igor Kulman)](https://blog.kulman.sk/implementing-auto-type-on-macos/)
- [URLSession async/await Guide (avanderlee.com)](https://www.avanderlee.com/concurrency/urlsession-async-await-network-requests-in-swift/)
- [Keychain vs UserDefaults Security (Medium)](https://medium.com/@gauravharkhani01/app-security-in-swift-keychain-biometrics-secure-enclave-69359b4cffba)
- [Swift Package Manager 2025 Updates](https://commitstudiogs.medium.com/whats-new-in-swift-package-manager-spm-for-2025-d7ffff2765a2)

### Technical Discussions
- [macOS Global Hotkeys (Apple Forums)](https://developer.apple.com/forums/thread/735223)
- [Accessibility Permissions (jano.dev)](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)
- [CGEvent Issues (Apple Forums)](https://developer.apple.com/forums/thread/103992)

---

**Document Version**: 1.0
**Last Updated**: 2026-02-02
**Next Review**: After Phase 1 (Architecture Design)
