import Foundation
import AVFoundation
import os

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

private let logger = Logger(subsystem: "com.dictationapp.DictationApp", category: "AudioRecorder")

/// Records audio to WAV files compatible with Groq Whisper API (16kHz mono)
@MainActor
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    static let shared = AudioRecorder()

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private(set) var isRecording: Bool = false
    private var recordingError: Error?
    private var autoStopTask: Task<Void, Never>?

    /// Maximum recording duration in seconds (10 min → ~2.3 MB at 32 kbps AAC, well under Groq's 25 MB limit)
    private let maxRecordingDuration: TimeInterval = 600

    /// Audio settings for Groq API compatibility: AAC/m4a, 16kHz, mono, 32kbps.
    /// Using compressed AAC instead of uncompressed PCM WAV reduces file sizes ~8x
    /// (2.3 MB vs 19.2 MB for a 10-minute recording), making long recordings reliable.
    /// Groq Whisper API fully supports m4a/AAC format.
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16000.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 32000  // 32 kbps — good quality for speech, tiny files
    ]

    private override init() {
        super.init()
    }

    /// Start recording audio to a temporary file
    /// - Throws: AudioRecorderError if recording cannot start
    func startRecording() throws {
        recordingError = nil

        // Generate unique temp file path (m4a/AAC for compressed audio)
        let filename = "recording-\(UUID().uuidString).m4a"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        logger.info("Starting recording to \(tempURL.lastPathComponent, privacy: .public)")

        // Initialize recorder with settings
        do {
            recorder = try AVAudioRecorder(url: tempURL, settings: audioSettings)
        } catch {
            logger.error("Failed to create AVAudioRecorder: \(error.localizedDescription, privacy: .public)")
            throw AudioRecorderError.invalidURL
        }

        guard let recorder = recorder else {
            throw AudioRecorderError.failedToStart
        }

        recorder.delegate = self

        // Prepare and start recording
        recorder.prepareToRecord()

        guard recorder.record() else {
            logger.error("AVAudioRecorder.record() returned false")
            throw AudioRecorderError.failedToStart
        }

        recordingURL = tempURL
        isRecording = true
        logger.info("Recording started successfully")

        // Start auto-stop safety timer
        autoStopTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(self?.maxRecordingDuration ?? 600) * 1_000_000_000)
            } catch {
                return  // Task was cancelled (normal stop)
            }
            guard let self = self, self.isRecording else { return }
            logger.warning("Auto-stopping recording at \(self.maxRecordingDuration)s limit")
            if let url = self.stopRecording() {
                NotificationCenter.default.post(
                    name: .recordingDidAutoStop,
                    object: url
                )
            }
        }
    }

    /// Stop recording and return the URL of the recorded file
    /// - Returns: URL to the recorded WAV file, or nil if no recording in progress
    func stopRecording() -> URL? {
        guard isRecording, let recorder = recorder else {
            logger.warning("stopRecording called but not recording")
            return nil
        }

        recorder.stop()
        isRecording = false
        autoStopTask?.cancel()
        autoStopTask = nil

        // Check for mid-recording errors
        if let error = recordingError {
            logger.error("Recording had error during capture: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        // Verify file exists and log size
        guard let url = recordingURL,
              FileManager.default.fileExists(atPath: url.path) else {
            logger.error("Recording file missing after stop")
            return nil
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attrs[.size] as? Int64 {
            // AAC at 32kbps = 4000 bytes/s; WAV was 32000 bytes/s
            let durationEstimate = Double(fileSize) / 4000.0
            logger.info("Recording stopped: size=\(fileSize) bytes, ~\(String(format: "%.1f", durationEstimate), privacy: .public)s")
        }

        return url
    }

    // MARK: - AVAudioRecorderDelegate

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let errorDesc = error?.localizedDescription ?? "unknown"
        logger.error("Recorder encode error: \(errorDesc, privacy: .public)")
        Task { @MainActor in
            self.recordingError = error
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            logger.warning("Recorder finished unsuccessfully")
        }
    }
}
