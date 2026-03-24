import Foundation
import AVFoundation
import os

struct GroqLyricSnippet: Hashable, Sendable {
    let text: String
    let start: TimeInterval?
    let end: TimeInterval?
    let confidenceScore: Double
}

struct GroqLyricsTranscription: Sendable {
    let text: String
    let segments: [GroqTranscriptionSegment]
}

struct GroqTranscriptionSegment: Decodable, Sendable {
    let id: Int?
    let start: Double?
    let end: Double?
    let text: String
    let avgLogprob: Double?
    let compressionRatio: Double?
    let noSpeechProb: Double?

    var confidenceScore: Double {
        let logScore = max(0, min(1, ((avgLogprob ?? -1.2) + 1.2) / 1.2))
        let noSpeechScore = 1 - min(max(noSpeechProb ?? 0.5, 0), 1)
        return (logScore * 0.7) + (noSpeechScore * 0.3)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case start
        case end
        case text
        case avgLogprob = "avg_logprob"
        case compressionRatio = "compression_ratio"
        case noSpeechProb = "no_speech_prob"
    }
}

private struct GroqTranscriptionResponse: Decodable {
    let text: String
    let segments: [GroqTranscriptionSegment]?
}

enum GroqSpeechToTextError: LocalizedError {
    case missingAPIKey
    case invalidResponse(statusCode: Int, message: String)
    case emptyTranscript
    case audioPreparationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未配置 Groq API Key"
        case .invalidResponse(let statusCode, let message):
            return "Groq 转写失败 (\(statusCode)): \(message)"
        case .emptyTranscript:
            return "Groq 未返回可用歌词文本"
        case .audioPreparationFailed(let message):
            return "Groq 音频预处理失败: \(message)"
        }
    }
}

final class GroqSpeechToTextService {
    static let shared = GroqSpeechToTextService()

    private let logger = Logger(subsystem: "com.longhai.radioapp", category: "GroqSpeechToTextService")

    private init() {}

    var isConfigured: Bool {
        !(apiKey?.isEmpty ?? true)
    }

    func transcribeLyrics(fileURL: URL, languageHint: String? = nil) async throws -> GroqLyricsTranscription {
        guard let apiKey, !apiKey.isEmpty else {
            throw GroqSpeechToTextError.missingAPIKey
        }

        let uploadURL = try await prepareUploadAudio(from: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try multipartBody(
            fileURL: uploadURL,
            boundary: boundary,
            languageHint: normalizedLanguageHint(languageHint)
        )

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        guard (200..<300).contains(statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown_error"
            logger.error("Groq transcription failed: \(message, privacy: .public)")
            throw GroqSpeechToTextError.invalidResponse(statusCode: statusCode, message: message)
        }

        let decoder = JSONDecoder()
        let transcription = try decoder.decode(GroqTranscriptionResponse.self, from: data)
        let cleanedText = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedText.isEmpty else {
            throw GroqSpeechToTextError.emptyTranscript
        }

        logger.info("Groq transcription success, text length: \(cleanedText.count)")
        print(
            """

            === Groq Lyrics Transcript ===
            Full Text:
            \(cleanedText)
            =============================

            """
        )

        if let segments = transcription.segments, !segments.isEmpty {
            print("Groq Segments:")
            for (index, segment) in segments.enumerated() {
                let startText = segment.start.map { String(format: "%.2f", $0) } ?? "nil"
                let endText = segment.end.map { String(format: "%.2f", $0) } ?? "nil"
                let avgLogprobText = segment.avgLogprob.map { String(format: "%.2f", $0) } ?? "nil"
                let noSpeechText = segment.noSpeechProb.map { String(format: "%.2f", $0) } ?? "nil"
                print("[\(index)] \(startText)s-\(endText)s conf=\(String(format: "%.2f", segment.confidenceScore)) avgLogprob=\(avgLogprobText) noSpeech=\(noSpeechText) text=\(segment.text)")
            }
        }

        return GroqLyricsTranscription(text: cleanedText, segments: transcription.segments ?? [])
    }

    func extractLikelyLyricSnippets(from transcription: GroqLyricsTranscription, maxCount: Int = 4) -> [GroqLyricSnippet] {
        var snippets: [GroqLyricSnippet] = []
        var seen = Set<String>()

        for segment in transcription.segments.sorted(by: segmentPriority) {
            let cleaned = cleanedSnippetText(segment.text)
            let normalized = normalizedComparisonText(cleaned)

            guard normalized.count >= 6 else { continue }
            guard (segment.noSpeechProb ?? 0) <= 0.55 else { continue }
            guard (segment.avgLogprob ?? -1.5) >= -1.1 else { continue }
            guard seen.insert(normalized).inserted else { continue }

            snippets.append(
                GroqLyricSnippet(
                    text: cleaned,
                    start: segment.start,
                    end: segment.end,
                    confidenceScore: segment.confidenceScore
                )
            )

            if snippets.count >= maxCount {
                return snippets
            }
        }

        if snippets.isEmpty {
            let fallbackText = cleanedSnippetText(transcription.text)
            let normalized = normalizedComparisonText(fallbackText)
            if normalized.count >= 6 {
                snippets.append(
                    GroqLyricSnippet(
                        text: fallbackText,
                        start: nil,
                        end: nil,
                        confidenceScore: 0.3
                    )
                )
            }
        }

        if snippets.isEmpty {
            print("Groq Lyrics Snippets: none")
        } else {
            print("Groq Lyrics Snippets:")
            for (index, snippet) in snippets.enumerated() {
                let startText = snippet.start.map { String(format: "%.2f", $0) } ?? "nil"
                let endText = snippet.end.map { String(format: "%.2f", $0) } ?? "nil"
                print("[\(index)] \(startText)s-\(endText)s conf=\(String(format: "%.2f", snippet.confidenceScore)) text=\(snippet.text)")
            }
        }

        return snippets
    }

    private var apiKey: String? {
        if let environmentValue = ProcessInfo.processInfo.environment["GROQ_API_KEY"],
           !environmentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "GROQ_API_KEY") as? String,
           !plistValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private var model: String {
        if let environmentValue = ProcessInfo.processInfo.environment["GROQ_SPEECH_MODEL"],
           !environmentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "GROQ_SPEECH_MODEL") as? String,
           !plistValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return "whisper-large-v3"
    }

    private func normalizedLanguageHint(_ languageHint: String?) -> String? {
        guard let languageHint else { return nil }

        let trimmed = languageHint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        if trimmed.count == 2 {
            return trimmed
        }

        if trimmed.hasPrefix("zh") { return "zh" }
        if trimmed.hasPrefix("en") { return "en" }
        if trimmed.hasPrefix("ja") { return "ja" }
        if trimmed.hasPrefix("ko") { return "ko" }

        return String(trimmed.prefix(2))
    }

    private func multipartBody(fileURL: URL, boundary: String, languageHint: String?) throws -> Data {
        let audioData = try Data(contentsOf: fileURL)
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "model", value: model)
        appendField(name: "response_format", value: "verbose_json")
        appendField(name: "temperature", value: "0")
        appendField(name: "timestamp_granularities[]", value: "segment")

        if let languageHint {
            appendField(name: "language", value: languageHint)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"lyrics_fallback.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    private func prepareUploadAudio(from fileURL: URL) async throws -> URL {
        do {
            let buffer = try await readAudioBuffer(from: fileURL)
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            )!
            let convertedBuffer = try convertBuffer(buffer, to: targetFormat)
            return try writeWAVFile(from: convertedBuffer)
        } catch {
            logger.error("Groq audio preparation failed: \(error.localizedDescription, privacy: .public)")
            throw GroqSpeechToTextError.audioPreparationFailed(error.localizedDescription)
        }
    }

    private func readAudioBuffer(from url: URL) async throws -> AVAudioPCMBuffer {
        if url.pathExtension.lowercased() == "ts" {
            return try readTSAudio(from: url)
        }

        do {
            return try readAudioWithAudioFile(from: url)
        } catch {
            logger.info("AVAudioFile read failed, falling back to AVAssetReader")
            return try await readAudioWithAsset(from: url)
        }
    }

    private func readAudioWithAudioFile(from url: URL) throws -> AVAudioPCMBuffer {
        let audioFile = try AVAudioFile(forReading: url)
        let processingFormat = audioFile.processingFormat
        let maxFrames = AVAudioFrameCount(processingFormat.sampleRate * 15)
        let framesToRead = min(AVAudioFrameCount(audioFile.length), maxFrames)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: framesToRead) else {
            throw GroqSpeechToTextError.audioPreparationFailed("无法创建音频缓冲区")
        }

        try audioFile.read(into: buffer)
        return buffer
    }

    private func readAudioWithAsset(from url: URL) async throws -> AVAudioPCMBuffer {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)

        guard let track = tracks.first else {
            throw GroqSpeechToTextError.audioPreparationFailed("无法读取音频轨道")
        }

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)

        guard reader.startReading() else {
            throw GroqSpeechToTextError.audioPreparationFailed(reader.error?.localizedDescription ?? "AssetReader 启动失败")
        }

        var samples = Data()
        let maxSamples = Int(15 * 44_100)
        var totalSamples = 0

        while reader.status == .reading && totalSamples < maxSamples {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = [UInt8](repeating: 0, count: length)
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &data)
            samples.append(contentsOf: data)
            totalSamples += length / 4
        }

        if reader.status == .failed {
            throw GroqSpeechToTextError.audioPreparationFailed(reader.error?.localizedDescription ?? "读取音频失败")
        }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        ) else {
            throw GroqSpeechToTextError.audioPreparationFailed("无法构造音频格式")
        }

        let frameCount = AVAudioFrameCount(samples.count / MemoryLayout<Float>.size)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw GroqSpeechToTextError.audioPreparationFailed("无法构造 PCM Buffer")
        }

        samples.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: Float.self) {
                pcmBuffer.floatChannelData?.pointee.update(from: baseAddress, count: Int(frameCount))
            }
        }
        pcmBuffer.frameLength = frameCount

        return pcmBuffer
    }

    private func readTSAudio(from url: URL) throws -> AVAudioPCMBuffer {
        let tsData = try Data(contentsOf: url)
        let aacData = TSUnpacker.extractAudio(from: tsData)

        guard !aacData.isEmpty else {
            throw GroqSpeechToTextError.audioPreparationFailed("TS 解包失败")
        }

        let tempAACURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("groq_transcribe_\(UUID().uuidString).aac")

        try aacData.write(to: tempAACURL)
        return try readAudioWithAudioFile(from: tempAACURL)
    }

    private func convertBuffer(_ inputBuffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard let converter = AVAudioConverter(from: inputBuffer.format, to: targetFormat) else {
            throw GroqSpeechToTextError.audioPreparationFailed("无法创建音频转换器")
        }

        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            throw GroqSpeechToTextError.audioPreparationFailed("无法创建输出音频缓冲区")
        }

        final class ConverterState: @unchecked Sendable {
            var sentBuffer = false
        }

        let state = ConverterState()
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if state.sentBuffer {
                outStatus.pointee = .endOfStream
                return nil
            }

            state.sentBuffer = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError, withInputFrom: inputBlock)

        if let conversionError {
            throw conversionError
        }

        return outputBuffer
    }

    private func writeWAVFile(from buffer: AVAudioPCMBuffer) throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("groq_transcribe_\(UUID().uuidString).wav")

        let audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: buffer.format.settings,
            commonFormat: buffer.format.commonFormat,
            interleaved: buffer.format.isInterleaved
        )
        try audioFile.write(from: buffer)
        return outputURL
    }

    private func segmentPriority(lhs: GroqTranscriptionSegment, rhs: GroqTranscriptionSegment) -> Bool {
        if lhs.confidenceScore == rhs.confidenceScore {
            return lhs.text.count > rhs.text.count
        }
        return lhs.confidenceScore > rhs.confidenceScore
    }

    private func cleanedSnippetText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedComparisonText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "[^\\p{Han}\\p{Latin}\\p{Nd}]", with: "", options: .regularExpression)
    }
}
