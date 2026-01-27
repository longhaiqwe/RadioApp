import Foundation
import Combine
import ShazamKit
import AVFoundation

class ShazamMatcher: NSObject, ObservableObject {
    static let shared = ShazamMatcher()
    
    // Published properties to update UI if needed
    @Published var isMatching = false
    @Published var lastMatch: SHMatchedMediaItem?
    @Published var lastError: Error?
    
    private var session: SHSession?
    
    override init() {
        super.init()
        // Initialize the session
        session = SHSession()
        session?.delegate = self
    }
    
    /// Matches a local audio file against the Shazam catalog
    /// - Parameter url: The file URL of the audio track
    func match(fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Demo: File not found at \(fileURL.path)")
            return
        }
        
        isMatching = true
        lastMatch = nil
        lastError = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 1. Open audio file
                let audioFile = try AVAudioFile(forReading: fileURL)
                let processingFormat = audioFile.processingFormat
                
                print("Demo: Processing audio file at \(fileURL.lastPathComponent)")
                print("Demo: Audio format: \(processingFormat)")
                print("Demo: Audio length (frames): \(audioFile.length)")
                
                // 2. Read into a buffer ensuring we capture enough audio (e.g., 12 seconds)
                // We use the file's native processing format first to verify data integrity.
                let durationToRead: TimeInterval = 12.0
                let framesToRead = AVAudioFrameCount(processingFormat.sampleRate * durationToRead)
                
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: framesToRead) else {
                    throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create input buffer"])
                }
                
                // Read from file
                try audioFile.read(into: inputBuffer)
                
                print("Demo: Read \(inputBuffer.frameLength) frames from file.")
                
                // 3. Check for silence in the input buffer
                if let channelData = inputBuffer.floatChannelData {
                    let channels = Int(processingFormat.channelCount)
                    let frames = Int(inputBuffer.frameLength)
                    var maxAmplitude: Float = 0.0
                    
                    // Check every 100th frame for efficiency, across all channels
                    for ch in 0..<channels {
                        let data = channelData[ch]
                        var i = 0
                        while i < frames {
                            let amp = abs(data[i])
                            if amp > maxAmplitude { maxAmplitude = amp }
                            i += 100
                        }
                    }
                    
                    print("Demo: Max amplitude in input buffer: \(maxAmplitude)")
                    if maxAmplitude < 0.0001 {
                        print("Demo: WARNING - Audio file appears to be silent.")
                    }
                }
                
                // 4. Force convert to Mono 44.1kHz for Shazam consistency
                // ShazamKit works best with standard formats. Since we have valid data now,
                // let's explicitly convert to the most standard format: Mono 44.1kHz.
                let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
                
                var bufferToMatch = inputBuffer
                
                // Check if we need conversion (different sample rate OR different channel count)
                // In the log we saw Stereo 44.1kHz, so this WILL trigger conversion to Mono.
                if processingFormat.sampleRate != targetFormat.sampleRate || processingFormat.channelCount != targetFormat.channelCount {
                    
                    print("Demo: Converting from \(processingFormat) to \(targetFormat)...")
                    
                    guard let converter = AVAudioConverter(from: processingFormat, to: targetFormat) else {
                        throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
                    }
                    
                    // Calculate output size
                    let ratio = targetFormat.sampleRate / processingFormat.sampleRate
                    let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio)
                    
                    guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
                        throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create output buffer"])
                    }
                    
                    var error: NSError? = nil
                    // Simple synchronous conversion
                    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                        outStatus.pointee = .haveData
                        return inputBuffer // We provide the whole buffer at once
                    }
                    
                    converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
                    
                    if let error = error { throw error }
                    
                    bufferToMatch = outputBuffer
                    print("Demo: Converted buffer length: \(outputBuffer.frameLength)")
                    
                    // Check for silence in the CONVERTED buffer
                    // This helps us verify if the Stereo -> Mono downmix worked correctly.
                    if let channelData = outputBuffer.floatChannelData {
                        let frames = Int(outputBuffer.frameLength)
                        var maxAmplitude: Float = 0.0
                        
                        // Mono, so only channel 0
                        let data = channelData[0]
                        var i = 0
                        while i < frames {
                            let amp = abs(data[i])
                            if amp > maxAmplitude { maxAmplitude = amp }
                            i += 100
                        }
                        
                        print("Demo: Max amplitude in CONVERTED buffer: \(maxAmplitude)")
                        if maxAmplitude < 0.0001 {
                            print("Demo: WARNING - Converted buffer is silent (conversion failed?).")
                        }
                    }
                } else {
                    print("Demo: Format matches target (Mono 44.1kHz), using input buffer directly.")
                }

                // 5. Generate signature
                let generator = SHSignatureGenerator()
                try generator.append(bufferToMatch, at: nil)
                let signature = generator.signature()
                
                // 6. Match
                self.session?.match(signature)
                
            } catch {
                DispatchQueue.main.async {
                    self.isMatching = false
                    self.lastError = error
                    print("Demo: Error processing file: \(error.localizedDescription)")
                }
            }
        }
    }
}
    
    // MARK: - Streaming Matching
    
    /// Starts matching the audio stream
    func startMatching() {
        isMatching = true
        lastMatch = nil
        lastError = nil
        // We ensure session is ready
        if session == nil {
            session = SHSession()
            session?.delegate = self
        }
    }
    
    /// Stops matching the audio stream
    func stopMatching() {
        isMatching = false
    }
    
    /// Matches a buffer from the audio stream
    /// - Parameters:
    ///   - buffer: The audio buffer
    ///   - time: The time of the buffer
    func match(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard isMatching else { return }
        session?.matchStreamingBuffer(buffer, at: time)
    }
}

// MARK: - SHSessionDelegate
extension ShazamMatcher: SHSessionDelegate {
    
    func session(_ session: SHSession, didFind match: SHMatch) {
        DispatchQueue.main.async {
            self.isMatching = false
            if let mediaItem = match.mediaItems.first {
                self.lastMatch = mediaItem
                print("\n=== Shazam Match Found ===")
                print("Title: \(mediaItem.title ?? "Unknown")")
                print("Artist: \(mediaItem.artist ?? "Unknown")")
                print("Apple Music URL: \(mediaItem.appleMusicURL?.absoluteString ?? "N/A")")
                print("Artwork URL: \(mediaItem.artworkURL?.absoluteString ?? "N/A")")
                print("==========================\n")
            } else {
                print("Demo: No media items found in match.")
            }
        }
    }
    
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async {
            self.isMatching = false
            self.lastError = error
            print("\n=== Shazam Match Failed ===")
            if let error = error {
                print("Error: \(error.localizedDescription)")
            } else {
                print("No match found for this audio.")
            }
            print("===========================\n")
        }
    }
}
