import Foundation
import AVFoundation
import Combine

class AudioRecorder: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var isRecording = false
    private let recordingDuration: TimeInterval = 20.0 // 20 seconds
    
    @Published var isRecordingActive = false
    @Published var isPendingRecording = false
    @Published var lastRecordingURL: URL?
    
    // Directory to save recordings
    private var recordingsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Recordings")
    }
    
    init() {
        createRecordingsDirectory()
    }
    
    private func createRecordingsDirectory() {
        do {
            if !FileManager.default.fileExists(atPath: recordingsDirectory.path) {
                try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            print("AudioRecorder: Failed to create recordings directory: \(error)")
        }
    }
    
    // MARK: - 麦克风录音（主要方式）
    
    func startMicrophoneRecording() {
        guard !isRecording else {
            print("AudioRecorder: Already recording")
            return
        }
        
        // 请求麦克风权限
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.beginMicrophoneRecording()
                } else {
                    print("AudioRecorder: Microphone permission denied")
                    self?.isPendingRecording = false
                }
            }
        }
    }
    
    private func beginMicrophoneRecording() {
        do {
            // 配置音频会话
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            // 创建音频引擎
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }
            
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            // 创建录音文件
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let dateString = dateFormatter.string(from: Date())
            let fileURL = recordingsDirectory.appendingPathComponent("recording_\(dateString).wav")
            
            // 使用标准格式
            let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                 sampleRate: inputFormat.sampleRate,
                                                 channels: 1,
                                                 interleaved: false)!
            
            audioFile = try AVAudioFile(forWriting: fileURL, settings: recordingFormat.settings)
            
            // 安装音频 tap
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
                guard let self = self, self.isRecording, let file = self.audioFile else { return }
                
                // 转换为单声道
                guard let monoBuffer = self.convertToMono(buffer: buffer, targetFormat: recordingFormat) else { return }
                
                do {
                    try file.write(from: monoBuffer)
                } catch {
                    print("AudioRecorder: Error writing buffer: \(error)")
                }
            }
            
            // 启动引擎
            try audioEngine.start()
            
            isRecording = true
            isPendingRecording = false
            isRecordingActive = true
            lastRecordingURL = fileURL
            
            print("AudioRecorder: Started microphone recording to: \(fileURL.path)")
            
            // 20秒后自动停止
            DispatchQueue.main.asyncAfter(deadline: .now() + recordingDuration) { [weak self] in
                self?.stopRecording()
            }
            
        } catch {
            print("AudioRecorder: Failed to start microphone recording: \(error)")
            isPendingRecording = false
        }
    }
    
    private func convertToMono(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else { return nil }
        
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return nil }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("AudioRecorder: Conversion error: \(error)")
            return nil
        }
        
        return outputBuffer
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        isRecording = false
        
        DispatchQueue.main.async {
            self.isRecordingActive = false
        }
        
        // 恢复音频会话用于播放
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioRecorder: Failed to restore audio session: \(error)")
        }
        
        if let url = lastRecordingURL {
            print("AudioRecorder: Stopped recording. File saved at: \(url.path)")
        }
    }
    
    // MARK: - 兼容旧 API（从 AudioTap 接收缓冲区）
    
    func prepareToRecord() {
        guard !isRecording && !isPendingRecording else { return }
        isPendingRecording = true
        print("AudioRecorder: Starting microphone recording...")
        startMicrophoneRecording()
    }
    
    // 这个方法保留用于兼容，但现在主要使用麦克风录音
    func process(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // 如果使用麦克风录音，这个方法不再需要
        // 保留空实现以兼容旧代码
    }
}
