import Foundation
import AVFoundation

/// Errors that can occur during audio recording
enum AudioRecorderError: LocalizedError {
    case invalidURL
    case failedToStart
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid recording file path"
        case .failedToStart:
            return "Failed to start audio recording"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}

/// Records audio to WAV files compatible with Groq Whisper API (16kHz mono)
@MainActor
final class AudioRecorder {
    static let shared = AudioRecorder()

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private(set) var isRecording: Bool = false

    /// Audio settings for Groq API compatibility: 16kHz, mono, 16-bit PCM WAV
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

    /// Start recording audio to a temporary file
    /// - Throws: AudioRecorderError if recording cannot start
    func startRecording() throws {
        // Generate unique temp file path
        let filename = "recording-\(UUID().uuidString).wav"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        // Initialize recorder with settings
        do {
            recorder = try AVAudioRecorder(url: tempURL, settings: audioSettings)
        } catch {
            throw AudioRecorderError.invalidURL
        }

        guard let recorder = recorder else {
            throw AudioRecorderError.failedToStart
        }

        // Prepare and start recording
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw AudioRecorderError.failedToStart
        }

        recordingURL = tempURL
        isRecording = true
    }

    /// Stop recording and return the URL of the recorded file
    /// - Returns: URL to the recorded WAV file, or nil if no recording in progress
    func stopRecording() -> URL? {
        guard isRecording, let recorder = recorder else {
            return nil
        }

        recorder.stop()
        isRecording = false

        // Verify file exists
        guard let url = recordingURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return url
    }
}
