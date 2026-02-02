# Phase 3: Transcription & API - Research

**Researched:** 2026-02-02
**Domain:** Swift audio transcription, HTTP multipart/form-data, Groq Whisper API integration
**Confidence:** HIGH

## Summary

Phase 3 requires integrating with Groq's Whisper API to transcribe recorded WAV audio files from Phase 2. The standard approach is using Swift's native URLSession with multipart/form-data requests to upload audio files to Groq's `/audio/transcriptions` endpoint. The API is OpenAI-compatible, supports both whisper-large-v3 and whisper-large-v3-turbo models, and operates at 216x real-time speed with minimal latency.

Key findings: The existing APIClient singleton pattern should be extended with a transcription method using URLSession's async/await API. Groq's API accepts files up to 25MB (free tier) or 100MB (dev tier), accepts WAV format (already implemented in Phase 2), and supports optional language specification in ISO-639-1 format ("en", "de") which improves both accuracy and latency. Default timeout of 60 seconds is more than sufficient given the model's exceptional processing speed.

**Primary recommendation:** Extend the existing APIClient service with a `transcribe(audioURL:language:)` method using native URLSession multipart upload, leverage the established async/await + Sendable patterns from Phase 1, and implement language configuration in SettingsView with preference for manual specification over auto-detection to maximize accuracy.

## Standard Stack

The established libraries/tools for Swift audio transcription with HTTP APIs:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation URLSession | iOS 15.0+ | HTTP networking with multipart upload | Native, async/await support, zero dependencies |
| AVFoundation | iOS 15.0+ | Audio file metadata extraction | Native, required for duration/size validation |
| Swift Concurrency | Swift 5.5+ | Async/await error handling | Native, established pattern in project |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| KeychainAccess | Latest | Secure API key storage | Already integrated in Phase 1 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Native URLSession | Alamofire | URLSession is sufficient for this use case; Alamofire adds dependency without benefit |
| Native URLSession | AIProxy Swift SDK | Adds proxy layer with rate limiting/DeviceCheck; unnecessary for this app's architecture |

**Installation:**
No new dependencies required - all frameworks are native Swift/Apple APIs.

## Architecture Patterns

### Recommended Project Structure
```
DictationApp/Sources/
├── Services/
│   ├── APIClient.swift          # Extend with transcription
│   ├── AudioRecorder.swift      # Already exists (Phase 2)
│   ├── KeychainManager.swift    # Already exists (Phase 1)
│   └── TranscriptionService.swift  # Optional coordinator layer
├── Models/
│   └── TranscriptionResult.swift   # Response model
└── Views/
    └── SettingsView.swift       # Add language preference
```

### Pattern 1: Extend APIClient with Transcription
**What:** Add `transcribe(audioURL:language:)` method to existing APIClient singleton
**When to use:** Follows established Phase 1 pattern of API communication through APIClient.shared
**Example:**
```swift
// Source: Groq official documentation + Swift URLSession best practices
// https://console.groq.com/docs/speech-to-text

extension APIClient {
    func transcribe(audioURL: URL, language: String? = nil) async throws -> TranscriptionResult {
        let endpoint = "\(baseURL)/audio/transcriptions"

        // Create multipart form-data request
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Add audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // Add model field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("whisper-large-v3-turbo\r\n")

        // Add optional language field
        if let language = language {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            body.append("\(language)\r\n")
        }

        body.append("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        // Parse response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(TranscriptionResult.self, from: data)
            return result
        case 401:
            throw APIError.invalidAPIKey
        case 429:
            throw APIError.rateLimitExceeded
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
}

// Helper extension for Data multipart construction
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
```

### Pattern 2: Response Model with Codable
**What:** Struct to decode Groq's JSON transcription response
**When to use:** Simple text response (default) vs. verbose_json with metadata
**Example:**
```swift
// Source: Groq API Reference
// https://console.groq.com/docs/api-reference

struct TranscriptionResult: Codable, Sendable {
    let text: String  // For response_format: "json" (default)
}

// For verbose_json (optional, provides metadata):
struct VerboseTranscriptionResult: Codable, Sendable {
    let text: String
    let task: String
    let language: String
    let duration: Double
    let segments: [TranscriptSegment]?

    struct TranscriptSegment: Codable, Sendable {
        let id: Int
        let start: Double
        let end: Double
        let text: String
    }
}
```

### Pattern 3: Language Configuration in Settings
**What:** Add language preference to SettingsView with UserDefaults persistence
**When to use:** Allow users to configure "en", "de", or "auto" (nil) for language detection
**Example:**
```swift
// In SettingsView.swift
@AppStorage("transcriptionLanguage") private var language: String = "auto"

Picker("Language", selection: $language) {
    Text("Auto-detect").tag("auto")
    Text("English").tag("en")
    Text("German").tag("de")
}
```

### Pattern 4: Timeout Configuration for Transcription
**What:** Separate URLSessionConfiguration for transcription with appropriate timeout
**When to use:** Transcription may need longer timeout than API key validation (10s)
**Example:**
```swift
// In APIClient init or separate session:
private let transcriptionSession: URLSession

init() {
    // Validation session (10s timeout) - already exists
    let validationConfig = URLSessionConfiguration.default
    validationConfig.timeoutIntervalForRequest = 10
    validationConfig.timeoutIntervalForResource = 10
    session = URLSession(configuration: validationConfig)

    // Transcription session (60s timeout for audio upload + processing)
    let transcriptionConfig = URLSessionConfiguration.default
    transcriptionConfig.timeoutIntervalForRequest = 60
    transcriptionConfig.timeoutIntervalForResource = 60
    transcriptionSession = URLSession(configuration: transcriptionConfig)
}
```

### Anti-Patterns to Avoid
- **Breaking audio mid-sentence for chunking**: Groq recommends avoiding mid-sentence breaks as this causes context loss. Since Groq supports 25MB (free) to 100MB (dev tier) and Phase 2 records short dictations, chunking is NOT needed for v1.
- **Using completion handlers instead of async/await**: Project already uses Swift 6 concurrency; maintain consistency with async/await throughout.
- **Omitting language parameter when known**: Groq docs explicitly state "supplying the input language in ISO-639-1 format will improve accuracy and latency" - always provide when user configures preference.
- **Ignoring file size validation**: While Groq accepts up to 25MB (free tier), validate file size before upload to provide better error messages to user.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multipart form-data encoding | Custom string concatenation with manual boundary handling | Native URLSession with Data extension for boundary formatting | Edge cases around binary data, character encoding, boundary collisions |
| Retry with exponential backoff | Manual retry loop with sleep() | Swift Async Algorithms retry (proposal) or simple retry helper | Need jitter to avoid thundering herd, max attempts, error classification |
| ISO-639-1 language code mapping | Custom language code dictionary | Locale.isoLanguageCodes or hardcoded ["en", "de"] for v1 | Only need 2 languages for v1; Foundation provides complete list if needed later |
| Audio duration/size extraction | Manual WAV header parsing | AVAsset with async load(.duration) | WAV headers have multiple formats; AVFoundation handles all variants |

**Key insight:** Swift's native URLSession handles multipart/form-data encoding robustly - no need for third-party libraries like Alamofire. The complexity is in proper boundary formatting and binary data appending, which is solved with a simple Data extension pattern.

## Common Pitfalls

### Pitfall 1: API Timeout Billing Issues
**What goes wrong:** Setting timeout too long can result in billing for failed transcriptions if server processes the audio but client times out before receiving response.
**Why it happens:** Developers set conservative timeouts (3+ minutes) based on worst-case scenarios without understanding Groq's actual processing speed.
**How to avoid:** Groq Whisper processes at 216x real-time speed - even a 1-minute audio file processes in ~0.3 seconds. Use 60-second timeout (already sufficient for worst-case network latency + processing).
**Warning signs:** Transcription succeeds on server (billed) but client reports timeout error.

### Pitfall 2: Missing Language Parameter
**What goes wrong:** Auto-detection works but is slower and less accurate than explicit language specification.
**Why it happens:** Developers treat language parameter as optional and omit it.
**How to avoid:** Groq documentation explicitly recommends providing language when known: "Supplying the input language in ISO-639-1 format will improve accuracy and latency." Always send "en" or "de" based on user preference.
**Warning signs:** Transcription accuracy degrades on short audio clips; processing takes longer than expected.

### Pitfall 3: File Size Validation Missing
**What goes wrong:** User records >25MB audio (unlikely for dictation, but possible), upload fails with cryptic server error.
**Why it happens:** No client-side validation before network upload.
**How to avoid:** Check file size before upload with FileManager and provide clear error if exceeds limit.
**Warning signs:** "Server error (413)" or "Request too large" messages in production.

### Pitfall 4: Multipart Boundary Collisions
**What goes wrong:** Multipart form data malformed if boundary string appears in file content.
**Why it happens:** Using predictable boundary strings like "Boundary123".
**How to avoid:** Use UUID().uuidString for boundary (extremely low collision probability).
**Warning signs:** Intermittent "invalid request" errors that are hard to reproduce.

### Pitfall 5: Not Handling Network Unavailable
**What goes wrong:** App crashes or hangs when no internet connection available.
**Why it happens:** Assuming network is always available; not catching URLError.notConnectedToInternet.
**How to avoid:** Existing APIClient pattern catches URLError in do-catch and wraps as APIError.networkError. Extend this pattern to transcription endpoint.
**Warning signs:** App freezes when user triggers recording with WiFi disabled.

### Pitfall 6: API Key Not Loaded from Keychain
**What goes wrong:** Transcription fails with 401 error even though user configured API key in settings.
**Why it happens:** Forgetting to load API key from KeychainManager before making transcription request.
**How to avoid:** Load API key in APIClient transcription method (or cache it as property loaded on init).
**Warning signs:** Settings shows valid API key, but transcription fails with "invalid API key" error.

### Pitfall 7: Ignoring Response Format Options
**What goes wrong:** Only parsing "text" field when "verbose_json" provides valuable metadata (duration, language detected, confidence).
**Why it happens:** Using simplest response format without considering debugging/monitoring value.
**How to avoid:** For v1, "json" format returning just text is sufficient. For future versions, "verbose_json" provides avg_logprob, compression_ratio, and no_speech_prob for quality assessment.
**Warning signs:** Unable to debug transcription quality issues; no visibility into what model actually processed.

## Code Examples

Verified patterns from official sources:

### Groq API Transcription Request (cURL)
```bash
# Source: https://console.groq.com/docs/speech-to-text
curl https://api.groq.com/openai/v1/audio/transcriptions \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: multipart/form-data" \
  -F file="@./audio.wav" \
  -F model="whisper-large-v3-turbo" \
  -F language="en" \
  -F response_format="json"
```

### Swift URLSession Multipart Upload Pattern
```swift
// Source: Swift community best practices
// https://theswiftdev.com/easy-multipart-file-upload-for-swift/
// https://asynclearn.medium.com/multipart-request-with-urlsession-and-async-await-in-swift-41b16a016cb2

func createMultipartBody(boundary: String, audioURL: URL, model: String, language: String?) throws -> Data {
    var body = Data()

    // Add audio file part
    let audioData = try Data(contentsOf: audioURL)
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
    body.append("Content-Type: audio/wav\r\n\r\n")
    body.append(audioData)
    body.append("\r\n")

    // Add model part
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
    body.append("\(model)\r\n")

    // Add language part (optional)
    if let language = language {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        body.append("\(language)\r\n")
    }

    body.append("--\(boundary)--\r\n")
    return body
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
```

### Error Handling with Swift Concurrency
```swift
// Source: Existing APIClient pattern from Phase 1
// Extend with transcription-specific errors

do {
    let result = try await APIClient.shared.transcribe(audioURL: url, language: "en")
    // Handle success
} catch APIError.invalidAPIKey {
    // Show settings prompt
} catch APIError.networkError {
    // Show network error
} catch APIError.timeout {
    // Show timeout error with retry option
} catch {
    // Generic error fallback
}
```

### File Size Validation Before Upload
```swift
// Source: Swift FileManager best practices
func validateAudioFile(_ url: URL) throws {
    let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
    let maxSize: Int64 = 25 * 1024 * 1024 // 25 MB for free tier

    guard fileSize <= maxSize else {
        throw APIError.fileTooLarge(size: fileSize, limit: maxSize)
    }
}
```

### Language Preference with UserDefaults
```swift
// Source: SwiftUI @AppStorage pattern
@AppStorage("transcriptionLanguage") private var languagePreference: String = "auto"

var languageCode: String? {
    languagePreference == "auto" ? nil : languagePreference
}

// Usage in transcription:
let result = try await APIClient.shared.transcribe(audioURL: url, language: languageCode)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| whisper-large-v3 | whisper-large-v3-turbo | Late 2024 | 15% faster, ~1% lower WER, same multilingual support, lower cost ($0.04/hr vs $0.111/hr) |
| Completion handlers | async/await | Swift 5.5 (2021) | Cleaner error handling, structured concurrency, no callback hell |
| Manual retry loops | Swift Async Algorithms retry (proposed 2025) | Proposal stage | Standardized retry with backoff; not yet stable |
| Third-party multipart libraries | Native URLSession | iOS 15+ | Zero dependencies, native async/await support |

**Deprecated/outdated:**
- **distil-whisper on Groq**: Replaced by whisper-large-v3-turbo which offers better accuracy with similar speed
- **Response format "text"**: Still supported but "json" or "verbose_json" preferred for structured parsing
- **File uploads >25MB without chunking**: Groq now supports up to 100MB for dev tier, reducing need for client-side chunking

## Open Questions

Things that couldn't be fully resolved:

1. **What is Groq's exact processing time distribution for short audio clips (5-30 seconds)?**
   - What we know: 216x real-time speed means 1 minute audio processes in ~0.3 seconds
   - What's unclear: Actual p50, p95, p99 latency for typical dictation use case (5-30 second clips)
   - Recommendation: Start with 60-second timeout (conservative), monitor actual latencies in Phase 5, optimize if needed

2. **Should language preference default to "auto" or force user to choose?**
   - What we know: Manual specification improves accuracy and latency per Groq docs
   - What's unclear: How much accuracy/latency degrades with auto-detection for English/German
   - Recommendation: Default to "auto" for better UX, allow user to configure "en" or "de" in settings for power users

3. **Does Groq bill for failed transcriptions that timeout on client side?**
   - What we know: Standard API practice is to bill if server processes request, regardless of client timeout
   - What's unclear: Groq's specific billing policy for client-side timeouts
   - Recommendation: Use 60-second timeout (well above expected processing time), implement proper error handling to avoid spurious retries

4. **Should we implement retry logic with exponential backoff for Phase 3 or defer to Phase 5?**
   - What we know: Swift Async Algorithms retry proposal exists but not yet stable; simple retry is easy to implement
   - What's unclear: Whether retry logic is critical path for MVP vs. polish feature
   - Recommendation: Defer to Phase 5 (Error Handling & Polish). For Phase 3, single attempt with clear error message is sufficient.

## Sources

### Primary (HIGH confidence)
- [Groq Speech-to-Text Documentation](https://console.groq.com/docs/speech-to-text) - Official API reference
- [Groq API Reference](https://console.groq.com/docs/api-reference) - Complete endpoint specification
- [Groq Whisper Large v3 Turbo Docs](https://console.groq.com/docs/model/whisper-large-v3-turbo) - Model specifications
- [Groq Whisper Large v3 Turbo Blog](https://groq.com/blog/whisper-large-v3-turbo-now-available-on-groq-combining-speed-quality-for-speech-recognition) - Performance characteristics
- [Swift URLSession Multipart Tutorial](https://theswiftdev.com/easy-multipart-file-upload-for-swift/) - Implementation patterns
- [Swift Async Multipart](https://asynclearn.medium.com/multipart-request-with-urlsession-and-async-await-in-swift-41b16a016cb2) - Modern async/await patterns

### Secondary (MEDIUM confidence)
- [AIProxy Groq Swift Examples](https://www.aiproxy.com/docs/swift-examples/groq.html) - Alternative SDK patterns
- [Swift Error Handling Guide](https://www.dhiwise.com/post/mastering-swift-catch-error-a-guide-to-error-handling-in-swift) - Error pattern best practices
- [Swift Async Algorithms Retry Proposal](https://forums.swift.org/t/pitch-retry-backoff/82483) - Future retry patterns
- [AVFoundation Metadata Extraction](https://medium.com/@edabdallamo/extracting-mp3-metadata-using-swift-and-avfoundation-66b9adcf475c) - Audio file inspection
- [Apple Developer - Locale Language Codes](https://developer.apple.com/documentation/foundation/nslocale/1418015-isolanguagecodes) - ISO-639-1 reference

### Tertiary (LOW confidence)
- WebSearch results for timeout recommendations (no specific 2026 guidance found, extrapolated from Groq's 216x speed spec)
- WebSearch results for chunking best practices (general guidance, not Groq-specific)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Native URLSession is well-established for HTTP multipart uploads, zero controversy
- Architecture: HIGH - Groq API documentation is comprehensive and current, pattern follows existing Phase 1/2 APIClient design
- Pitfalls: MEDIUM - Some pitfalls are inferred from general API best practices rather than Groq-specific documentation

**Research date:** 2026-02-02
**Valid until:** 60 days (API is stable, documentation current, Swift/Apple APIs mature)
