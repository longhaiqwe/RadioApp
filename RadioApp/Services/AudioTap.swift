import Foundation
import AVFoundation
import MediaToolbox

class AudioTap {
    var onAudioBuffer: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?
    var processingFormat: AudioStreamBasicDescription?
    
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
        
        if status == noErr, let tap = tap {
            // Only audio tracks can be tapped
            // We need to wait for tracks to be loaded typically, but for AVPlayerItem(url:) they might be available or we can just try.
            // Actually, for HLS streams, tracks might not be immediately available.
            // This is a common pitfall. The tracks property of asset might be empty initially.
            // We might need to load "tracks" key asynchronously.
            
            // However, let's assume standard behavior first. If tracks are empty, we might need a different approach.
            // A safer way is to check playerItem.asset.tracks.
            
            do {
                let tracks = try await playerItem.asset.loadTracks(withMediaType: .audio)
                if let track = tracks.first {
                let params = AVMutableAudioMixInputParameters(track: track)
                params.audioTapProcessor = tap
                
                let audioMix = AVMutableAudioMix()
                audioMix.inputParameters = [params]
                playerItem.audioMix = audioMix
                print("AudioTap setup successful")
            } else {
                print("AudioTap warning: No audio tracks found on asset yet. Tap might not work immediately.")
            }
        } catch {
            print("AudioTap error loading tracks: \(error)")
        }
        } else {
            print("Failed to create audio tap: \(status)")
        }
    }
    
    fileprivate func prepare(maxFrames: CMItemCount, processingFormat: UnsafePointer<AudioStreamBasicDescription>) {
        self.processingFormat = processingFormat.pointee
    }
    
    fileprivate func process(tap: MTAudioProcessingTap, numberFrames: CMItemCount, flags: MTAudioProcessingTapFlags, bufferListInOut: UnsafeMutablePointer<AudioBufferList>, numberFramesOut: UnsafeMutablePointer<CMItemCount>, flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>) {
        
        let status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
        
        if status != noErr { return }
        
        guard let format = self.processingFormat else { return }
        
        // We only process if we have a callback
        guard let callback = self.onAudioBuffer else { return }
        
        // Create AVAudioFormat
        var localFormat = format
        guard let avAudioFormat = AVAudioFormat(streamDescription: &localFormat) else { return }
        
        // Create AVAudioPCMBuffer
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: avAudioFormat, frameCapacity: AVAudioFrameCount(numberFrames)) else { return }
        pcmBuffer.frameLength = AVAudioFrameCount(numberFrames)
        
        // Copy audio data
        // We assume non-interleaved float data usually for AVPlayer processing
        // But we must handle what we get.
        
        if let _ = UnsafeMutableAudioBufferListPointer(bufferListInOut).first,
           let destBuffers = pcmBuffer.floatChannelData {
            
            // This is a simplification. We should handle different formats/interleaving.
            // But MTAudioProcessingTap usually gives Float32 non-interleaved.
            
            // We'll iterate channels
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
