import Foundation
import AVFoundation
import MediaToolbox

class AudioTap {
    var onAudioBuffer: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?
    var processingFormat: AudioStreamBasicDescription?
    var isActive = false
    
    private static var bufferReceivedCount = 0
    
    init() {}
    
    func setupTap(for playerItem: AVPlayerItem) async {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque()),
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: tapUnprepare,
            process: tapProcess
        )
        
        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap)
        
        guard status == noErr, let tap = tap else {
            print("AudioTap: Failed to create tap, status: \(status)")
            return
        }
        
        // 获取所有轨道
        do {
            let tracks = try await playerItem.asset.loadTracks(withMediaType: .audio)
            
            guard let track = tracks.first else {
                print("AudioTap: ⚠️ No audio tracks available")
                return
            }
            
            // 打印轨道信息
            print("AudioTap: Found audio track: \(track)")
            print("AudioTap: Track format descriptions: \(track.formatDescriptions)")
            
            // 设置 AudioMix
            let params = AVMutableAudioMixInputParameters(track: track)
            params.audioTapProcessor = tap
            
            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = [params]
            
            // 应用到 playerItem（需要在主线程）
            await MainActor.run {
                playerItem.audioMix = audioMix
            }
            
            isActive = true
            AudioTap.bufferReceivedCount = 0
            print("AudioTap: ✅ Setup successful!")
            
        } catch {
            print("AudioTap: Error loading tracks: \(error)")
        }
    }
    
    fileprivate func prepare(maxFrames: CMItemCount, processingFormat: UnsafePointer<AudioStreamBasicDescription>) {
        self.processingFormat = processingFormat.pointee
        print("AudioTap: Prepared with format - sampleRate: \(processingFormat.pointee.mSampleRate), channels: \(processingFormat.pointee.mChannelsPerFrame)")
    }
    
    fileprivate func process(tap: MTAudioProcessingTap, numberFrames: CMItemCount, flags: MTAudioProcessingTapFlags, bufferListInOut: UnsafeMutablePointer<AudioBufferList>, numberFramesOut: UnsafeMutablePointer<CMItemCount>, flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>) {
        
        let status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
        
        if status != noErr { return }
        
        guard let format = self.processingFormat else { return }
        guard let callback = self.onAudioBuffer else { return }
        
        // 打印前几次收到的缓冲区信息
        AudioTap.bufferReceivedCount += 1
        if AudioTap.bufferReceivedCount <= 3 {
            print("AudioTap: 🎵 Received buffer #\(AudioTap.bufferReceivedCount), frames: \(numberFrames)")
        }
        
        // Create AVAudioFormat
        var localFormat = format
        guard let avAudioFormat = AVAudioFormat(streamDescription: &localFormat) else { return }
        
        // Create AVAudioPCMBuffer
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: avAudioFormat, frameCapacity: AVAudioFrameCount(numberFrames)) else { return }
        pcmBuffer.frameLength = AVAudioFrameCount(numberFrames)
        
        // Copy audio data
        if let destBuffers = pcmBuffer.floatChannelData {
            let channelCount = Int(format.mChannelsPerFrame)
            let bufferList = UnsafeMutableAudioBufferListPointer(bufferListInOut)
            
            for i in 0..<channelCount {
                if i < bufferList.count {
                    let src = bufferList[i].mData
                    let dest = destBuffers[i]
                    let bytes = Int(numberFrames) * MemoryLayout<Float>.size
                    if let src = src {
                        dest.withMemoryRebound(to: UInt8.self, capacity: bytes) { d in
                            src.withMemoryRebound(to: UInt8.self, capacity: bytes) { s in
                                d.update(from: s, count: bytes)
                            }
                        }
                    }
                }
            }
            
            // Dispatch callback
            DispatchQueue.global(qos: .userInteractive).async {
                callback(pcmBuffer, AVAudioTime(hostTime: mach_absolute_time()))
            }
        }
    }
}

// Global C functions for callbacks
private let tapInit: MTAudioProcessingTapInitCallback = { (tap, clientInfo, storageOut) in
    storageOut.pointee = clientInfo
}

private let tapFinalize: MTAudioProcessingTapFinalizeCallback = { tap in
    let storage = MTAudioProcessingTapGetStorage(tap)
    Unmanaged<AudioTap>.fromOpaque(storage).release()
}

private let tapPrepare: MTAudioProcessingTapPrepareCallback = { (tap, maxFrames, processingFormat) in
    let storage = MTAudioProcessingTapGetStorage(tap)
    let tapObject = Unmanaged<AudioTap>.fromOpaque(storage).takeUnretainedValue()
    tapObject.prepare(maxFrames: maxFrames, processingFormat: processingFormat)
}

private let tapUnprepare: MTAudioProcessingTapUnprepareCallback = { tap in
    // No-op
}

private let tapProcess: MTAudioProcessingTapProcessCallback = { (tap, numberFrames, flags, bufferListInOut, numberFramesOut, flagsOut) in
    let storage = MTAudioProcessingTapGetStorage(tap)
    let tapObject = Unmanaged<AudioTap>.fromOpaque(storage).takeUnretainedValue()
    tapObject.process(tap: tap, numberFrames: numberFrames, flags: flags, bufferListInOut: bufferListInOut, numberFramesOut: numberFramesOut, flagsOut: flagsOut)
}
