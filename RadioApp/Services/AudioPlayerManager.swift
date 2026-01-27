import Foundation
import AVFoundation
import Combine
import MediaPlayer

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    private var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentStation: Station?
    
    // Playlist context
    private var playlist: [Station] = []
    
    // Player item observer
    private var statusObserver: NSKeyValueObservation?
    private var audioTap: AudioTap?
    
    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play/Pause
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying {
                self.player?.play()
                self.isPlaying = true
                self.updateNowPlayingInfo()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.pause()
                return .success
            }
            return .commandFailed
        }
        
        // Next/Previous Track
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.playPrevious()
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let station = currentStation else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = station.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = station.tags
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        if let url = URL(string: station.favicon) {
            let stationId = station.id
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self else { return }
                guard let data = data, let image = UIImage(data: data) else { return }
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                
                DispatchQueue.main.async {
                    guard self.currentStation?.id == stationId else { return }
                    
                    var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                    currentInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                }
            }.resume()
        }
    }
    
    // Play a station, optionally updating the playlist context
    func play(station: Station, in newPlaylist: [Station]? = nil) {
        if let newPlaylist = newPlaylist {
            self.playlist = newPlaylist
        }
        
        if currentStation?.id == station.id {
            togglePlayPause()
            return
        }
        
        guard let url = URL(string: station.urlResolved) else { return }
        
        // 清理之前的观察者
        statusObserver?.invalidate()
        statusObserver = nil
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        // 设置缓冲
        playerItem.preferredForwardBufferDuration = 5.0
        
        // 创建 AudioTap
        self.audioTap = AudioTap()
        self.audioTap?.onAudioBuffer = { buffer, time in
            ShazamMatcher.shared.match(buffer: buffer, time: time)
        }
        
        // 使用 KVO 监听 playerItem 状态
        // 当状态变为 readyToPlay 时再设置 AudioTap
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            
            switch item.status {
            case .readyToPlay:
                print("AudioPlayerManager: PlayerItem ready, setting up AudioTap...")
                Task {
                    await self.setupAudioTapWhenReady(for: item)
                }
            case .failed:
                print("AudioPlayerManager: PlayerItem failed: \(item.error?.localizedDescription ?? "unknown")")
            case .unknown:
                break
            @unknown default:
                break
            }
        }
        
        // 设置播放器
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            player?.automaticallyWaitsToMinimizeStalling = true
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        player?.play()
        isPlaying = true
        currentStation = station
        updateNowPlayingInfo()
    }
    
    private func setupAudioTapWhenReady(for playerItem: AVPlayerItem) async {
        // 尝试多次获取音频轨道
        let maxAttempts = 10
        var tracks: [AVAssetTrack] = []
        
        for attempt in 1...maxAttempts {
            do {
                tracks = try await playerItem.asset.loadTracks(withMediaType: .audio)
                
                if !tracks.isEmpty {
                    print("AudioPlayerManager: Found \(tracks.count) audio track(s) on attempt \(attempt)")
                    break
                } else {
                    print("AudioPlayerManager: No tracks yet (attempt \(attempt)/\(maxAttempts))...")
                    if attempt < maxAttempts {
                        try await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
                    }
                }
            } catch {
                print("AudioPlayerManager: Error loading tracks: \(error)")
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }
        }
        
        guard let track = tracks.first else {
            print("AudioPlayerManager: ⚠️ No audio tracks found after \(maxAttempts) attempts")
            print("AudioPlayerManager: URL: \(playerItem.asset)")
            return
        }
        
        // 创建 AudioMix 并设置 tap
        await audioTap?.setupTap(for: playerItem)
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            player?.play()
            isPlaying = true
            updateNowPlayingInfo()
        }
    }
    
    func playNext() {
        guard !playlist.isEmpty, let current = currentStation else { return }
        
        if let index = playlist.firstIndex(where: { $0.id == current.id }) {
            let nextIndex = (index + 1) % playlist.count
            play(station: playlist[nextIndex])
        }
    }
    
    func playPrevious() {
        guard !playlist.isEmpty, let current = currentStation else { return }
        
        if let index = playlist.firstIndex(where: { $0.id == current.id }) {
            let prevIndex = (index - 1 + playlist.count) % playlist.count
            play(station: playlist[prevIndex])
        }
    }
    
    // MARK: - Audio Recorder (保留用于兼容)
    @Published var audioRecorder = AudioRecorder()
    
    func startRecording() {
        audioRecorder.prepareToRecord()
    }
}
