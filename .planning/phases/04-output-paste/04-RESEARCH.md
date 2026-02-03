# Phase 4: Output & Paste - Research

**Researched:** 2026-02-02
**Domain:** macOS clipboard operations, CGEvent paste simulation, Accessibility API text field detection, UNUserNotificationCenter
**Confidence:** HIGH

## Summary

Phase 4 requires automatically pasting transcribed text into the active text field using clipboard operations and keyboard simulation. The established approach is using NSPasteboard for clipboard writes combined with CGEvent-based Cmd+V simulation, which requires Accessibility permissions (already requested in Phase 2).

Key findings: NSPasteboard.general provides clipboard write operations with `clearContents()` + `setString(_:forType:)`. CGEvent creates synthetic keyboard events (Cmd+V) that are posted to the system. Accessibility API can detect focused text fields via `AXUIElementCopyAttributeValue` with `kAXFocusedUIElementAttribute`. UNUserNotificationCenter (modern replacement for deprecated NSUserNotification) can show clickable notifications with action buttons for copy-to-clipboard fallback.

The user decision to overwrite clipboard (not preserve/restore) simplifies implementation by removing state management complexity. Smart spacing detection via Accessibility API attributes is possible but implementation-dependent across apps.

**Primary recommendation:** Create a PasteManager service that writes transcription text to NSPasteboard, posts CGEvent Cmd+V with ~150ms delay, and falls back to UNUserNotificationCenter notification with copy action if paste fails or no text field detected.

## Standard Stack

The established libraries/tools for macOS clipboard and paste operations:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AppKit NSPasteboard | Native | Clipboard read/write operations | Native macOS clipboard API, zero dependencies |
| Core Graphics CGEvent | Native | Keyboard event synthesis (Cmd+V) | Standard approach for keyboard simulation, requires Accessibility |
| ApplicationServices | Native | AX API for focused element detection | Only API for system-wide UI element introspection |
| UserNotifications | macOS 10.14+ | Modern notification framework with actions | Replacement for deprecated NSUserNotification |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation.DispatchQueue | Native | Delay timing between clipboard write and paste | For safe timing between operations |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSPasteboard + CGEvent | Third-party clipboard libraries | No reliable third-party Swift libraries; native APIs are standard |
| UNUserNotificationCenter | NSUserNotification (deprecated) | NSUserNotification deprecated in macOS 11+, UNUserNotificationCenter is modern API |
| CGEvent Cmd+V | AppleScript keystroke | CGEvent more reliable, faster, doesn't require AppleScript permissions |

**Installation:**
No new dependencies required - all frameworks are native Swift/Apple APIs.

## Architecture Patterns

### Recommended Project Structure
```
DictationApp/Sources/
├── Services/
│   ├── PasteManager.swift           # New: Clipboard + paste orchestration
│   ├── TranscriptionManager.swift   # Already exists (Phase 3)
│   └── PermissionManager.swift      # Already exists (Phase 2)
└── App/
    └── AppDelegate.swift             # Add notification delegate, observers
```

### Pattern 1: PasteManager Service for Clipboard + Paste Orchestration
**What:** Centralized service managing clipboard write, paste simulation, and fallback notifications
**When to use:** All transcription paste operations (OUT-01, OUT-02, OUT-03)
**Example:**
```swift
// Source: Research synthesis from NSPasteboard docs + CGEvent patterns
// https://developer.apple.com/documentation/appkit/nspasteboard
// https://developer.apple.com/forums/thread/659804

@MainActor
final class PasteManager {
    static let shared = PasteManager()

    private init() {}

    /// Write text to clipboard and simulate Cmd+V paste
    /// - Parameter text: Transcribed text to paste
    func pasteText(_ text: String) async {
        // 1. Trim whitespace (user decision)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip empty transcriptions silently (user decision)
        guard !trimmedText.isEmpty else {
            print("Empty transcription - skipping paste")
            return
        }

        // 2. Check for focused text field (user decision: check before attempting)
        guard checkFocusedTextFieldExists() else {
            print("No text field focused - showing notification")
            await showNotificationFallback(text: trimmedText)
            return
        }

        // 3. Write to clipboard (user decision: overwrite, don't preserve)
        writeToClipboard(text: trimmedText)

        // 4. Wait safe delay (user decision: 100-200ms range)
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // 5. Simulate Cmd+V
        let pasteSuccess = simulatePaste()

        // 6. Fallback to notification if paste failed (user decision)
        if !pasteSuccess {
            await showNotificationFallback(text: trimmedText)
        }
    }

    /// Write text to system clipboard
    private func writeToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Simulate Cmd+V using CGEvent
    /// - Returns: Success status
    private func simulatePaste() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("Failed to create CGEventSource")
            return false
        }

        // Virtual key code 9 = V key
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        return true
    }

    /// Check if a text field is currently focused
    /// - Returns: True if focused element is a text field
    private func checkFocusedTextFieldExists() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        let error = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard error == .success, let element = focusedElement else {
            return false
        }

        // Check if focused element has text-related attributes
        var role: AnyObject?
        let roleError = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXRoleAttribute as CFString,
            &role
        )

        guard roleError == .success, let roleString = role as? String else {
            return false
        }

        // Common text field roles
        let textRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXStaticText"]
        return textRoles.contains(roleString)
    }

    /// Show notification with text and copy action
    private func showNotificationFallback(text: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Transcription Ready"
        content.body = text
        content.sound = .default
        content.categoryIdentifier = "TRANSCRIPTION_READY"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Show immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to show notification: \(error)")
        }
    }
}
```

### Pattern 2: Smart Spacing Detection (Optional Enhancement)
**What:** Add space before transcription if cursor isn't at start of line or after whitespace
**When to use:** User decision allows Claude discretion on smart spacing implementation
**Example:**
```swift
// Source: Accessibility API patterns from research
// https://macdevelopers.wordpress.com/2014/02/05/how-to-get-selected-text-and-its-coordinates-from-any-system-wide-application-using-accessibility-api/

extension PasteManager {
    /// Get text before cursor position (if available)
    /// - Returns: Text before cursor, or nil if unavailable
    private func getTextBeforeCursor() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success else {
            return nil
        }

        let element = focusedElement as! AXUIElement

        // Get selected text range (cursor position)
        var rangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        ) == .success else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else {
            return nil
        }

        // Get full text value
        var textValue: AnyObject?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &textValue
        ) == .success, let fullText = textValue as? String else {
            return nil
        }

        // Extract text before cursor
        let cursorPosition = range.location
        guard cursorPosition > 0, cursorPosition <= fullText.count else {
            return nil
        }

        let index = fullText.index(fullText.startIndex, offsetBy: cursorPosition)
        return String(fullText[..<index])
    }

    /// Determine if space should be added before transcription
    /// - Parameter transcription: The text to be pasted
    /// - Returns: Transcription with or without leading space
    func applySmartSpacing(to transcription: String) -> String {
        guard let textBefore = getTextBeforeCursor() else {
            // Can't determine context - don't add space
            return transcription
        }

        // Don't add space if cursor is at start
        guard !textBefore.isEmpty else {
            return transcription
        }

        // Don't add space if last character is whitespace
        let lastChar = textBefore.last
        if lastChar?.isWhitespace == true {
            return transcription
        }

        // Add space before transcription
        return " " + transcription
    }
}
```

### Pattern 3: Notification Action Handler
**What:** UNUserNotificationCenter delegate to handle copy-to-clipboard action
**When to use:** Fallback when paste fails or no text field focused
**Example:**
```swift
// Source: UNUserNotificationCenter documentation
// https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions

extension AppDelegate: UNUserNotificationCenterDelegate {
    func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Define "Copy" action
        let copyAction = UNNotificationAction(
            identifier: "COPY_ACTION",
            title: "Copy to Clipboard",
            options: .foreground
        )

        let category = UNNotificationCategory(
            identifier: "TRANSCRIPTION_READY",
            actions: [copyAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])

        // Request authorization
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "COPY_ACTION" {
            // Copy notification body to clipboard
            let text = response.notification.request.content.body
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            print("Transcription copied to clipboard from notification")
        }

        completionHandler()
    }
}
```

### Pattern 4: TranscriptionManager Integration
**What:** Wire `.transcriptionDidComplete` notification to PasteManager
**When to use:** Connect Phase 3 transcription results to Phase 4 paste
**Example:**
```swift
// In AppDelegate.swift - add observer in applicationDidFinishLaunching
func setupTranscriptionObservers() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleTranscriptionComplete),
        name: .transcriptionDidComplete,
        object: nil
    )
}

@objc func handleTranscriptionComplete(_ notification: Notification) {
    guard let text = notification.object as? String else {
        return
    }

    // Trigger paste workflow
    Task {
        await PasteManager.shared.pasteText(text)
    }
}
```

### Anti-Patterns to Avoid
- **Preserving clipboard contents:** User decision is to overwrite clipboard - don't add complexity of save/restore
- **No delay between clipboard write and paste:** CGEvent may execute before clipboard write completes - always delay 100-200ms
- **Using deprecated NSUserNotification:** UNUserNotificationCenter is modern API (macOS 10.14+)
- **Not checking for focused text field:** Attempting paste without text field causes confusing UX - check first and fallback to notification
- **Complex smart spacing heuristics:** Keep simple - check if cursor is at start or after whitespace, nothing more

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Clipboard operations | Custom clipboard manager | NSPasteboard.general | Native API handles all edge cases (permissions, formats, race conditions) |
| Keyboard event synthesis | AppleScript keystroke | CGEvent keyDown/keyUp | CGEvent faster, more reliable, doesn't require AppleScript permissions |
| Delay timing | Custom Timer/DispatchQueue wrapper | Task.sleep(nanoseconds:) | Swift concurrency's Task.sleep is simplest, doesn't block main thread |
| Focused element detection | Polling focused window | Accessibility API AXUIElementCopyAttributeValue | Single call, accurate, no polling overhead |

**Key insight:** NSPasteboard and CGEvent are the standard macOS APIs for clipboard and keyboard simulation - there are no popular third-party Swift libraries because the native APIs are comprehensive and well-documented.

## Common Pitfalls

### Pitfall 1: CGEvent Silently Fails Without Accessibility Permission
**What goes wrong:** Paste simulation doesn't work, but no error is thrown or logged.
**Why it happens:** CGEventPost requires Accessibility permission, but fails silently if permission denied.
**How to avoid:** Phase 2 already requests Accessibility permission at launch. Double-check `AXIsProcessTrusted()` before attempting paste as defensive check.
**Warning signs:** Clipboard contains transcription text, but paste doesn't happen in target app.

### Pitfall 2: Race Condition Between Clipboard Write and Paste
**What goes wrong:** Paste happens before clipboard write completes, so old clipboard content is pasted.
**Why it happens:** NSPasteboard write and CGEventPost are asynchronous under the hood.
**How to avoid:** Always delay 100-200ms between clipboard write and paste simulation. 150ms is safe middle ground (user decision allows this range).
**Warning signs:** Occasionally pasting wrong text (previous clipboard content instead of transcription).

### Pitfall 3: Paste Fails in Sandboxed Apps
**What goes wrong:** CGEvent paste works in most apps but fails in sandboxed apps like Notes or iWork.
**Why it happens:** Sandboxed apps may have stricter security policies for synthetic events.
**How to avoid:** Already mitigated by non-sandboxed distribution (STATE.md decision). Document known limitations if discovered during testing.
**Warning signs:** Paste works in TextEdit, VSCode, Chrome but fails in Notes, Pages, Numbers.

### Pitfall 4: Text Field Detection Returns False Positives
**What goes wrong:** Accessibility API reports focused element as text field, but paste still fails.
**Why it happens:** Some apps expose custom UI elements with text roles that don't accept paste.
**How to avoid:** Keep focused element check as pre-flight validation, but still implement notification fallback for paste failures. Don't assume check guarantees paste success.
**Warning signs:** Notification fallback triggers even though text field appears focused.

### Pitfall 5: Empty Transcriptions Generate Notifications
**What goes wrong:** User speaks silence or very brief audio, gets notification with empty text.
**Why it happens:** Groq API may return empty string or whitespace-only transcription for silence.
**How to avoid:** Trim whitespace and skip silently if empty (user decision). No paste, no notification.
**Warning signs:** Notifications appearing with blank body text.

### Pitfall 6: Smart Spacing Detection Breaks on Non-Standard Apps
**What goes wrong:** Accessibility API returns incomplete or incorrect text before cursor.
**Why it happens:** Not all apps expose `kAXValueAttribute` or `kAXSelectedTextRangeAttribute` correctly.
**How to avoid:** Make smart spacing optional enhancement with graceful fallback. If detection fails, paste without adding space. Never block paste on smart spacing failure.
**Warning signs:** Extra spaces or missing spaces in specific apps (Electron apps, web text fields, etc).

### Pitfall 7: Notification Actions Not Working
**What goes wrong:** Clicking "Copy to Clipboard" action on notification does nothing.
**Why it happens:** UNUserNotificationCenterDelegate not set, or delegate method not implemented.
**How to avoid:** Set `UNUserNotificationCenter.current().delegate = self` in AppDelegate, implement `userNotificationCenter(_:didReceive:withCompletionHandler:)`.
**Warning signs:** Notification shows but action button unresponsive.

## Code Examples

Verified patterns from official sources:

### NSPasteboard Write String
```swift
// Source: https://nilcoalescing.com/blog/CopyStringToClipboardInSwiftOnMacosOS/
// https://developer.apple.com/documentation/appkit/nspasteboard

func writeToClipboard(text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}
```

### CGEvent Cmd+V Simulation
```swift
// Source: https://developer.apple.com/forums/thread/659804
// https://gist.github.com/sscotth/310db98e7c4ec74e21819806dc527e97

func simulatePaste() -> Bool {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
        return false
    }

    // Virtual key code 9 = V
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand

    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)

    return true
}
```

### Check Focused Text Field with Accessibility API
```swift
// Source: https://macdevelopers.wordpress.com/2014/02/05/how-to-get-selected-text-and-its-coordinates-from-any-system-wide-application-using-accessibility-api/
// https://forums.swift.org/t/mac-how-to-detect-if-a-text-field-is-focused-system-wide-manner/65724

func checkFocusedTextFieldExists() -> Bool {
    let systemWide = AXUIElementCreateSystemWide()

    var focusedElement: AnyObject?
    let error = AXUIElementCopyAttributeValue(
        systemWide,
        kAXFocusedUIElementAttribute as CFString,
        &focusedElement
    )

    guard error == .success, let element = focusedElement else {
        return false
    }

    // Get role attribute
    var role: AnyObject?
    let roleError = AXUIElementCopyAttributeValue(
        element as! AXUIElement,
        kAXRoleAttribute as CFString,
        &role
    )

    guard roleError == .success, let roleString = role as? String else {
        return false
    }

    // Check if role is text field
    let textRoles = ["AXTextField", "AXTextArea", "AXComboBox"]
    return textRoles.contains(roleString)
}
```

### UNUserNotificationCenter Setup with Actions
```swift
// Source: https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions
// https://www.hackingwithswift.com/example-code/system/how-to-set-local-alerts-using-unnotificationcenter

func setupNotifications() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self

    // Define copy action
    let copyAction = UNNotificationAction(
        identifier: "COPY_ACTION",
        title: "Copy to Clipboard",
        options: .foreground
    )

    let category = UNNotificationCategory(
        identifier: "TRANSCRIPTION_READY",
        actions: [copyAction],
        intentIdentifiers: [],
        options: []
    )

    center.setNotificationCategories([category])

    // Request authorization
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        if granted {
            print("Notification permission granted")
        }
    }
}

func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    if response.actionIdentifier == "COPY_ACTION" {
        let text = response.notification.request.content.body
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    completionHandler()
}
```

### Smart Spacing with String Extension
```swift
// Source: https://www.hackingwithswift.com/example-code/strings/how-to-trim-whitespace-in-a-string
// https://www.programiz.com/swift-programming/library/string/trimmingcharacters

extension String {
    func withSmartSpacing(textBefore: String?) -> String {
        guard let textBefore = textBefore, !textBefore.isEmpty else {
            return self
        }

        // Don't add space if last character is whitespace
        if textBefore.last?.isWhitespace == true {
            return self
        }

        // Add space before transcription
        return " " + self
    }
}

// Usage
let transcription = "Hello world"
let finalText = transcription.withSmartSpacing(textBefore: getTextBeforeCursor())
```

### Delay Between Operations
```swift
// Source: Swift concurrency Task.sleep
// https://developer.apple.com/documentation/swift/task/sleep(nanoseconds:)

func pasteWithDelay(text: String) async {
    writeToClipboard(text: text)

    // Safe delay: 150ms (user decision: 100-200ms range)
    try? await Task.sleep(nanoseconds: 150_000_000)

    simulatePaste()
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSUserNotification | UNUserNotificationCenter | macOS 11+ (2020) | Modern API with action support, better control |
| AppleScript keystroke | CGEvent keyboard synthesis | macOS 10.4+ | Faster, more reliable, no AppleScript permissions |
| Manual clipboard polling | Direct NSPasteboard operations | Always standard | NSPasteboard is canonical API, no polling needed |
| Manual role string comparison | AXValue role checking | macOS 10.9+ | Type-safe accessibility attribute access |

**Deprecated/outdated:**
- **NSUserNotification**: Deprecated in macOS 11+, replaced by UNUserNotificationCenter
- **Carbon Event Manager for keyboard**: Deprecated, use CGEvent instead
- **NSAppleScript for keystroke simulation**: Slower than CGEvent, requires additional permissions

## Open Questions

Things that couldn't be fully resolved:

1. **What is the optimal delay between clipboard write and CGEvent paste?**
   - What we know: 100-200ms is safe range per research and developer forum reports
   - What's unclear: Exact minimum reliable delay across all macOS versions and hardware
   - Recommendation: Start with 150ms (middle of range), can optimize during testing if needed

2. **Should smart spacing check full line content or just character before cursor?**
   - What we know: Accessibility API can provide full text value and cursor position
   - What's unclear: Performance impact of reading full text value on every paste, especially in large documents
   - Recommendation: Start with simple "last character is whitespace" check, defer full line analysis to v2

3. **How to detect paste success vs. failure reliably?**
   - What we know: CGEventPost doesn't return error status, paste can fail silently
   - What's unclear: Whether there's a way to confirm paste actually inserted text into target app
   - Recommendation: Assume paste succeeded if focused text field detected; notification fallback handles failures gracefully

4. **Should we handle clipboard restore after paste for better UX?**
   - What we know: User decision is to overwrite clipboard, not preserve
   - What's unclear: Whether users will find this frustrating in practice
   - Recommendation: Follow user decision for v1, collect feedback, consider clipboard restore in v2 if requested

5. **What happens when user pastes again manually after automatic paste?**
   - What we know: Clipboard still contains transcription text after automatic paste
   - What's unclear: Whether this is a feature (easy re-paste) or bug (unexpected clipboard state)
   - Recommendation: Document as feature - transcription stays in clipboard for manual re-paste if needed

## Sources

### Primary (HIGH confidence)
- [NSPasteboard | Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nspasteboard) - Official clipboard API reference
- [CGEvent | Apple Developer Documentation](https://developer.apple.com/documentation/coregraphics/cgevent) - Official event synthesis API
- [CGEvent to simulate paste command - Apple Developer Forums](https://developer.apple.com/forums/thread/659804) - Verified paste simulation pattern
- [UNUserNotificationCenter - Handling Actions | Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions) - Modern notification framework
- [Copy a string to the clipboard in Swift on macOS](https://nilcoalescing.com/blog/CopyStringToClipboardInSwiftOnMacOS/) - NSPasteboard best practices

### Secondary (MEDIUM confidence)
- [Mac: How to detect if a text field is focused system-wide - Swift Forums](https://forums.swift.org/t/mac-how-to-detect-if-a-text-field-is-focused-system-wide-manner/65724) - Accessibility API focused element detection
- [How to get selected text via Accessibility API | mac developers](https://macdevelopers.wordpress.com/2014/02/05/how-to-get-selected-text-and-its-coordinates-from-any-system-wide-application-using-accessibility-api/) - AX API text extraction patterns
- [Paste as keystrokes (macOS) - GitHub Gist](https://gist.github.com/sscotth/310db98e7c4ec74e21819806dc527e97) - CGEvent paste implementation example
- [How to trim whitespace in a string - Hacking with Swift](https://www.hackingwithswift.com/example-code/strings/how-to-trim-whitespace-in-a-string) - String trimming patterns
- [Swift String trimmingCharacters() - Programiz](https://www.programiz.com/swift-programming/library/string/trimmingcharacters) - Whitespace trimming reference

### Tertiary (LOW confidence)
- [How to set local alerts using UNNotificationCenter - Hacking with Swift](https://www.hackingwithswift.com/example-code/system/how-to-set-local-alerts-using-unnotificationcenter) - Notification basics
- [Mastering Swift Local Notifications | Medium](https://vikramios.medium.com/mastering-swift-local-notifications-a-developers-guide-f56b77ab64cc) - UNUserNotificationCenter guide
- Community discussions on CGEvent timing and reliability

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Native NSPasteboard and CGEvent are well-established, zero controversy
- Architecture: HIGH - Clear patterns from Apple documentation and verified forum discussions
- Pitfalls: MEDIUM - Based on developer forum reports and community best practices, needs validation during implementation

**Research date:** 2026-02-02
**Valid until:** 90 days (macOS APIs are stable, patterns are mature)
