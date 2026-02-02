import Foundation

/// Response model for Groq Whisper API transcription endpoint
/// Matches the JSON response: { "text": "transcribed text..." }
struct TranscriptionResult: Codable, Sendable {
    /// The transcribed text from the audio file
    let text: String
}
