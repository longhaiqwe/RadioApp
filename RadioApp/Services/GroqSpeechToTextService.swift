import Foundation
import AVFoundation
import os

struct LyricSnippet: Hashable, Sendable {
    let text: String
    let start: TimeInterval?
    let end: TimeInterval?
    let confidenceScore: Double
}

struct LyricsTranscription: Sendable {
    let text: String
    let segments: [LyricsTranscriptionSegment]
}

struct LyricsTranscriptionSegment: Hashable, Decodable, Sendable {
    let id: Int?
    let start: Double?
    let end: Double?
    let text: String
    let confidence: Double?

    var confidenceScore: Double {
        min(max(confidence ?? defaultConfidenceScore, 0), 1)
    }

    private var defaultConfidenceScore: Double {
        let normalizedLength = min(Double(text.count) / 24.0, 1)
        return 0.35 + (normalizedLength * 0.35)
    }
}

private struct OpenRouterChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct OpenRouterErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        let message: String?
    }

    let error: ErrorBody?
}

private struct LyricsAnalysisPayload: Decodable {
    let transcript: String?
    let text: String?
    let snippets: [LyricsAnalysisSnippetPayload]?
    let segments: [LyricsAnalysisSnippetPayload]?
}

private struct LyricsAnalysisSnippetPayload: Decodable {
    let text: String
    let startSeconds: Double?
    let endSeconds: Double?
    let confidence: Double?
    let confidenceScore: Double?
}

enum OpenRouterLyricsTranscriptionError: LocalizedError {
    case missingAPIKey
    case invalidResponse(statusCode: Int, message: String)
    case emptyTranscript
    case malformedModelOutput(String)
    case audioPreparationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未配置 OpenRouter API Key"
        case .invalidResponse(let statusCode, let message):
            return "OpenRouter 转写失败 (\(statusCode)): \(message)"
        case .emptyTranscript:
            return "OpenRouter 未返回可用歌词文本"
        case .malformedModelOutput(let message):
            return "OpenRouter 返回了无法解析的歌词结果: \(message)"
        case .audioPreparationFailed(let message):
            return "OpenRouter 音频预处理失败: \(message)"
        }
    }
}

final class OpenRouterLyricsTranscriptionService {
    static let shared = OpenRouterLyricsTranscriptionService()

    private let logger = Logger(subsystem: "com.longhai.radioapp", category: "OpenRouterLyricsTranscriptionService")
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 90
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)
    }

    var isConfigured: Bool {
        !(apiKey?.isEmpty ?? true)
    }

    func transcribeLyrics(fileURL: URL, languageHint: String? = nil) async throws -> LyricsTranscription {
        guard let apiKey, !apiKey.isEmpty else {
            throw OpenRouterLyricsTranscriptionError.missingAPIKey
        }

        logger.info("OpenRouter lyric transcription started")
        print("OpenRouterLyricsTranscriptionService: 开始预处理音频...")
        let preparedAudio = try await prepareUploadAudio(from: fileURL)
        let uploadURL = preparedAudio.fileURL
        defer { try? FileManager.default.removeItem(at: uploadURL) }

        let audioData = try Data(contentsOf: uploadURL)

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("拾音 FM", forHTTPHeaderField: "X-OpenRouter-Title")
        request.httpBody = try requestBody(
            audioData: audioData,
            languageHint: normalizedLanguageHint(languageHint)
        )

        print("OpenRouterLyricsTranscriptionService: 音频预处理完成，开始上传至 OpenRouter...")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("OpenRouterLyricsTranscriptionService: OpenRouter 已返回响应，状态码 \(statusCode)")

        guard (200..<300).contains(statusCode) else {
            let message = errorMessage(from: data)
            logger.error("OpenRouter transcription failed: \(message, privacy: .public)")
            throw OpenRouterLyricsTranscriptionError.invalidResponse(statusCode: statusCode, message: message)
        }

        let completion = try JSONDecoder().decode(OpenRouterChatCompletionResponse.self, from: data)
        let rawContent = completion.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let transcription = try parseTranscription(from: rawContent, audioDuration: preparedAudio.duration)
        let cleanedText = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedText.isEmpty else {
            throw OpenRouterLyricsTranscriptionError.emptyTranscript
        }

        logger.info("OpenRouter transcription success, text length: \(cleanedText.count)")
        print(
            """

            === OpenRouter Lyrics Transcript ===
            Full Text:
            \(cleanedText)
            ==================================

            """
        )

        if !transcription.segments.isEmpty {
            print("OpenRouter Segments:")
            for (index, segment) in transcription.segments.enumerated() {
                let startText = segment.start.map { String(format: "%.2f", $0) } ?? "nil"
                let endText = segment.end.map { String(format: "%.2f", $0) } ?? "nil"
                print("[\(index)] \(startText)s-\(endText)s conf=\(String(format: "%.2f", segment.confidenceScore)) text=\(segment.text)")
            }
        }

        return LyricsTranscription(text: cleanedText, segments: transcription.segments)
    }

    func extractLikelyLyricSnippets(from transcription: LyricsTranscription, maxCount: Int = 4) -> [LyricSnippet] {
        var snippets: [LyricSnippet] = []
        var seen = Set<String>()

        for segment in transcription.segments.sorted(by: segmentPriority) {
            let cleaned = cleanedSnippetText(segment.text)
            let normalized = normalizedComparisonText(cleaned)

            guard normalized.count >= 6 else { continue }
            guard segment.confidenceScore >= 0.2 else { continue }
            guard seen.insert(normalized).inserted else { continue }

            snippets.append(
                LyricSnippet(
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
                    LyricSnippet(
                        text: fallbackText,
                        start: nil,
                        end: nil,
                        confidenceScore: 0.3
                    )
                )
            }
        }

        if snippets.isEmpty {
            print("OpenRouter Lyrics Snippets: none")
        } else {
            print("OpenRouter Lyrics Snippets:")
            for (index, snippet) in snippets.enumerated() {
                let startText = snippet.start.map { String(format: "%.2f", $0) } ?? "nil"
                let endText = snippet.end.map { String(format: "%.2f", $0) } ?? "nil"
                print("[\(index)] \(startText)s-\(endText)s conf=\(String(format: "%.2f", snippet.confidenceScore)) text=\(snippet.text)")
            }
        }

        return snippets
    }

    private var apiKey: String? {
        if let environmentValue = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"],
           !environmentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String,
           !plistValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private var model: String {
        if let environmentValue = ProcessInfo.processInfo.environment["OPENROUTER_LYRIC_MODEL"],
           !environmentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let environmentValue = ProcessInfo.processInfo.environment["OPENROUTER_MODEL"],
           !environmentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environmentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_LYRIC_MODEL") as? String,
           !plistValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_MODEL") as? String,
           !plistValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return "xiaomi/mimo-v2.5"
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

    private func requestBody(audioData: Data, languageHint: String?) throws -> Data {
        var promptLines = [
            "Analyze this short radio audio clip and extract only likely sung lyric fragments.",
            "Ignore DJ speech, station IDs, advertisements, commentary, crowd noise, and purely instrumental sections.",
            "Return JSON only. Do not wrap the JSON in markdown.",
            "Use this exact shape: {\"transcript\":\"string\",\"snippets\":[{\"text\":\"string\",\"start_seconds\":number|null,\"end_seconds\":number|null,\"confidence\":number}]}",
            "Rules:",
            "1. transcript must contain only lyric text that is likely being sung.",
            "2. snippets must contain 0 to 4 unique lyric fragments most useful for song lookup.",
            "3. confidence must be between 0 and 1.",
            "4. Use null timestamps when unsure.",
            "5. If the clip is mostly speech or no lyrics are discernible, return {\"transcript\":\"\",\"snippets\":[]}.",
        ]

        if let languageHint {
            promptLines.append("Likely language: \(languageHint).")
        }

        let payload: [String: Any] = [
            "model": model,
            "temperature": 0,
            "max_tokens": 700,
            "response_format": [
                "type": "json_object"
            ],
            "messages": [
                [
                    "role": "system",
                    "content": "You extract lyric fragments from short radio audio clips and respond with JSON only."
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": promptLines.joined(separator: "\n")
                        ],
                        [
                            "type": "input_audio",
                            "input_audio": [
                                "data": audioData.base64EncodedString(),
                                "format": "wav"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        return try JSONSerialization.data(withJSONObject: payload)
    }

    private func parseTranscription(from rawContent: String, audioDuration: TimeInterval) throws -> LyricsTranscription {
        let jsonString = extractJSONPayload(from: rawContent)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw OpenRouterLyricsTranscriptionError.malformedModelOutput("无法读取模型返回的 JSON 文本")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payload = try decoder.decode(LyricsAnalysisPayload.self, from: jsonData)

        let segmentsPayload = payload.snippets ?? payload.segments ?? []
        let rawSegments = segmentsPayload.compactMap { payload -> LyricsTranscriptionSegment? in
            let cleanedText = cleanedSnippetText(payload.text)
            guard !cleanedText.isEmpty else { return nil }

            return LyricsTranscriptionSegment(
                id: nil,
                start: payload.startSeconds,
                end: payload.endSeconds,
                text: cleanedText,
                confidence: payload.confidence ?? payload.confidenceScore
            )
        }
        let segments = fillMissingSegmentTimingIfNeeded(in: rawSegments, audioDuration: audioDuration)

        let transcript = cleanedSnippetText(payload.transcript ?? payload.text ?? "")
        let finalText = transcript.isEmpty
            ? segments.map(\.text).joined(separator: " ")
            : transcript

        guard !finalText.isEmpty || !segments.isEmpty else {
            throw OpenRouterLyricsTranscriptionError.emptyTranscript
        }

        return LyricsTranscription(text: finalText, segments: segments)
    }

    private func extractJSONPayload(from rawContent: String) -> String {
        let trimmed = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)

        if let startIndex = trimmed.firstIndex(of: "{"),
           let endIndex = trimmed.lastIndex(of: "}") {
            return String(trimmed[startIndex...endIndex])
        }

        return trimmed
    }

    private func errorMessage(from data: Data) -> String {
        if let envelope = try? JSONDecoder().decode(OpenRouterErrorEnvelope.self, from: data),
           let message = envelope.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return message
        }

        let rawMessage = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (rawMessage?.isEmpty == false ? rawMessage : nil) ?? "unknown_error"
    }

    private struct PreparedAudioUpload {
        let fileURL: URL
        let duration: TimeInterval
    }

    private func prepareUploadAudio(from fileURL: URL) async throws -> PreparedAudioUpload {
        do {
            let buffer = try await readAudioBuffer(from: fileURL)
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            )!
            let convertedBuffer = try convertBuffer(buffer, to: targetFormat)
            let duration = audioDuration(for: convertedBuffer)
            return PreparedAudioUpload(
                fileURL: try writeWAVFile(from: convertedBuffer),
                duration: duration
            )
        } catch {
            logger.error("OpenRouter audio preparation failed: \(error.localizedDescription, privacy: .public)")
            throw OpenRouterLyricsTranscriptionError.audioPreparationFailed(error.localizedDescription)
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
            throw OpenRouterLyricsTranscriptionError.audioPreparationFailed("无法创建音频缓冲区")
        }

        try audioFile.read(into: buffer)
        return buffer
    }

    private func readAudioWithAsset(from url: URL) async throws -> AVAudioPCMBuffer {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)

        guard let track = tracks.first else {
            throw OpenRouterLyricsTranscriptionError.audioPreparationFailed("无法读取音频轨道")
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
            throw OpenRouterLyricsTranscriptionError.audioPreparationFailed(reader.error?.localizedDescription ?? "AssetReader 启动失败")
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
            throw OpenRouterLyricsTranscriptionError.audioPreparationFailed(reader.error?.localizedDescription ?? "读取音频失败")
        }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        ) else {
            throw OpenRouterLyricsTranscriptionError.audioPreparationFailed("无法构造音频格式")
        }

        let frameCount = AVAudioFrameCount(samples.count / MemoryLayout<Float>.size)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw OpenRouterLyricsTranscriptionError.audioPreparationFailed("无法构造 PCM Buffer")
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
            throw OpenRouterLyricsTranscriptionError.audioPreparationFailed("TS 解包失败")
        }

        let tempAACURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("openrouter_transcribe_\(UUID().uuidString).aac")

        try aacData.write(to: tempAACURL)
        defer { try? FileManager.default.removeItem(at: tempAACURL) }

        return try readAudioWithAudioFile(from: tempAACURL)
    }

    private func convertBuffer(_ inputBuffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard let converter = AVAudioConverter(from: inputBuffer.format, to: targetFormat) else {
            throw OpenRouterLyricsTranscriptionError.audioPreparationFailed("无法创建音频转换器")
        }

        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            throw OpenRouterLyricsTranscriptionError.audioPreparationFailed("无法创建输出音频缓冲区")
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
            .appendingPathComponent("openrouter_transcribe_\(UUID().uuidString).wav")

        let audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: buffer.format.settings,
            commonFormat: buffer.format.commonFormat,
            interleaved: buffer.format.isInterleaved
        )
        try audioFile.write(from: buffer)
        return outputURL
    }

    private func audioDuration(for buffer: AVAudioPCMBuffer) -> TimeInterval {
        guard buffer.format.sampleRate > 0 else { return 12 }
        return max(Double(buffer.frameLength) / buffer.format.sampleRate, 1)
    }

    private func fillMissingSegmentTimingIfNeeded(
        in segments: [LyricsTranscriptionSegment],
        audioDuration: TimeInterval
    ) -> [LyricsTranscriptionSegment] {
        guard !segments.isEmpty else { return segments }
        guard segments.allSatisfy({ $0.start == nil && $0.end == nil }) else { return segments }

        let effectiveDuration = max(audioDuration, 6)
        let weights = segments.map { max(Double(normalizedComparisonText($0.text).count), 4) }
        let totalWeight = max(weights.reduce(0, +), 1)

        var cursor: TimeInterval = 0
        var estimatedSegments: [LyricsTranscriptionSegment] = []

        for (index, segment) in segments.enumerated() {
            let isLastSegment = index == segments.count - 1
            let duration = isLastSegment
                ? max(effectiveDuration - cursor, 0)
                : effectiveDuration * (weights[index] / totalWeight)
            let start = min(cursor, effectiveDuration)
            let end = isLastSegment
                ? effectiveDuration
                : min(effectiveDuration, start + duration)

            estimatedSegments.append(
                LyricsTranscriptionSegment(
                    id: segment.id,
                    start: start,
                    end: end,
                    text: segment.text,
                    confidence: segment.confidence
                )
            )

            cursor = end
        }

        let durationText = String(format: "%.2f", effectiveDuration)
        print("OpenRouterLyricsTranscriptionService: 模型未返回分段时间戳，已按 \(durationText)s 音频时长估算时间轴")
        return estimatedSegments
    }

    private func segmentPriority(lhs: LyricsTranscriptionSegment, rhs: LyricsTranscriptionSegment) -> Bool {
        let lhsHasTiming = lhs.start != nil
        let rhsHasTiming = rhs.start != nil
        if lhsHasTiming != rhsHasTiming {
            return lhsHasTiming
        }

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
