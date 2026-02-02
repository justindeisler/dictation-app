import Foundation
import AppKit
import UserNotifications

// MARK: - Paste Manager

/// Manages clipboard operations and paste simulation for transcribed text
/// Writes text to NSPasteboard and simulates Cmd+V using CGEvent
@MainActor
final class PasteManager {
    static let shared = PasteManager()

    private init() {}

    // MARK: - Public API

    /// Paste transcribed text into the active text field
    /// - Parameter text: Transcribed text from Whisper API
    func pasteText(_ text: String) async {
        // 1. Trim whitespace (user decision: trim leading/trailing whitespace)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip empty transcriptions silently (user decision)
        guard !trimmedText.isEmpty else {
            print("Empty transcription - skipping paste")
            return
        }

        // 2. Check for focused text field (user decision: check before attempting paste)
        guard checkFocusedTextFieldExists() else {
            print("No text field focused - showing notification fallback")
            await showNotificationFallback(text: trimmedText)
            return
        }

        // 3. Apply smart spacing (user decision: add space if cursor isn't at start or after whitespace)
        let finalText = applySmartSpacing(to: trimmedText)

        // 4. Write to clipboard (user decision: overwrite, don't preserve previous)
        writeToClipboard(text: finalText)

        // 5. Wait safe delay (user decision: 100-200ms range, using 150ms)
        try? await Task.sleep(nanoseconds: 150_000_000)

        // 6. Simulate Cmd+V paste
        let pasteSuccess = simulatePaste()

        // 7. Fallback to notification if paste failed (user decision)
        if !pasteSuccess {
            print("Paste simulation failed - showing notification fallback")
            await showNotificationFallback(text: trimmedText)
        } else {
            print("Text pasted successfully: \(trimmedText.prefix(50))...")
        }
    }

    // MARK: - Clipboard Operations

    /// Write text to system clipboard
    /// - Parameter text: Text to write
    private func writeToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Paste Simulation

    /// Simulate Cmd+V keystroke using CGEvent
    /// - Returns: true if event was posted successfully
    private func simulatePaste() -> Bool {
        // Verify accessibility permission (defensive check)
        guard AXIsProcessTrusted() else {
            print("Accessibility permission not granted - cannot simulate paste")
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("Failed to create CGEventSource")
            return false
        }

        // Virtual key code 9 = V key
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            print("Failed to create CGEvent for paste")
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }

    // MARK: - Focused Element Detection

    /// Check if a text field is currently focused using Accessibility API
    /// - Returns: true if focused element is a text input field
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

        // Get role attribute of focused element
        var role: AnyObject?
        let roleError = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXRoleAttribute as CFString,
            &role
        )

        guard roleError == .success, let roleString = role as? String else {
            return false
        }

        // Common text input roles
        let textRoles = ["AXTextField", "AXTextArea", "AXComboBox"]
        return textRoles.contains(roleString)
    }

    // MARK: - Smart Spacing

    /// Apply smart spacing: add space before text if cursor isn't at start or after whitespace
    /// - Parameter transcription: The transcribed text
    /// - Returns: Text with optional leading space
    private func applySmartSpacing(to transcription: String) -> String {
        guard let textBefore = getTextBeforeCursor() else {
            // Can't determine context - paste without modification
            return transcription
        }

        // Don't add space if cursor is at start of text
        guard !textBefore.isEmpty else {
            return transcription
        }

        // Don't add space if last character is already whitespace
        if textBefore.last?.isWhitespace == true {
            return transcription
        }

        // Add space before transcription
        return " " + transcription
    }

    /// Get text before cursor position using Accessibility API
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
            return ""
        }

        let index = fullText.index(fullText.startIndex, offsetBy: cursorPosition)
        return String(fullText[..<index])
    }

    // MARK: - Notification Fallback

    /// Show notification with transcription text and copy action
    /// - Parameter text: Transcription text to display
    func showNotificationFallback(text: String) async {
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
            print("Notification shown with transcription")
        } catch {
            print("Failed to show notification: \(error)")
        }
    }
}
