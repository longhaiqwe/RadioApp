import Foundation
import AVFoundation
import Combine
import MediaPlayer

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()
    
    private var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentStation: Station?
    @Published var volume: CGFloat = 0.5 {
        didSet {
            player?.volume = Float(volume)
        }
    }
    
    // Playlist context
    private var playlist: [Station] = []
    @Published var playlistTitle: String = "播放列表"
    @Published var playlistStations: [Station] = [] // Expose playlist for UI binding if needed, or just access current property
    
    // Live Metadata (ICY) - Removed due to low accuracy
    // @Published var currentStreamTitle: String?
    // private var metadataObserver: NSKeyValueObservation?
    
    // Shazam Integration
    private var cancellables = Set<AnyCancellable>()
    private var lyricsTimer: Timer?
    private var parsedLyrics: [LyricLine] = []
    
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        setupInterruptionObserver()
        setupShazamObservers()
    }
    
    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began (e.g., phone call or other app playing audio)
            print("Audio interruption began")
            // Update UI state to paused
            DispatchQueue.main.async {
                self.isPlaying = false
                self.updateNowPlayingInfo()
            }
            
        case .ended:
            // Interruption ended
            print("Audio interruption ended")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                // Resume playback if appropriate
                print("Should resume playback")
                DispatchQueue.main.async {
                    // For auto-resume from interruption, we might want to reload stream too if it was long
                    // But for simple interruptions, maybe just play() is fine.
                    // Let's stick to simple play() for interruption resume to be fast,
                    // OR reuse the logic in togglePlayPause if we want live.
                    // Given user request "Jump out and back... restart stream", let's reload.
                    
                    if let station = self.currentStation {
                        self.playStation(station)
                    } else {
                        self.player?.play()
                    }
                    
                    self.isPlaying = true
                    self.updateNowPlayingInfo()
                }
            }
        @unknown default:
            break
        }
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
        
        // Like Command (Used for Song Recognition - Star Icon)
        // 替换 Bookmark 为 Like，因为 iOS 锁屏更容易显示 Like 按钮
        commandCenter.likeCommand.isEnabled = true
        commandCenter.likeCommand.isActive = true // Ensure it shows up
        commandCenter.likeCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.handleLockScreenRecognition()
            return .success
        }
        
        // Disable Bookmark to avoid confusion
        commandCenter.bookmarkCommand.isEnabled = false
    }
    
    private func updateNowPlayingInfo() {
        // 1. Check Matching State
        if ShazamMatcher.shared.isMatching {
             var nowPlayingInfo = [String: Any]()
             nowPlayingInfo[MPMediaItemPropertyTitle] = "正在识别..."
             nowPlayingInfo[MPMediaItemPropertyArtist] = currentStation?.name ?? "Radio"
             MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
             return
        }
        
        // 2. Check Match Result
        if let match = ShazamMatcher.shared.customMatchResult {
            var nowPlayingInfo = [String: Any]()
            // Default Title (Song Name) - Will be overwritten by lyrics timer
            nowPlayingInfo[MPMediaItemPropertyTitle] = match.title 
            // Artist: Song Name - Artist (to mimic NetEase style)
            nowPlayingInfo[MPMediaItemPropertyArtist] = "\(match.artist) / \(match.title)"
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            
            // Info Center
            var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
            currentInfo.merge(nowPlayingInfo) { (_, new) in new }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
            
            // Artwork
             if let url = match.artworkURL {
                 URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                     guard let self = self else { return }
                     guard let data = data, let image = UIImage(data: data) else { return }
                     let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                     
                     DispatchQueue.main.async {
                         // Only update if match is still valid
                         guard ShazamMatcher.shared.customMatchResult?.title == match.title else { return }
                         
                         var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                         currentInfo[MPMediaItemPropertyArtwork] = artwork
                         MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                     }
                 }.resume()
             } else if let station = currentStation {
                 // Fallback to station artwork
                  if URL(string: station.favicon) != nil {
                      // ... reuse existing logic or simplify ...
                      // For brevity, let's just trigger the station logic if needed or skip
                  }
             }
             return
        }
    
        guard let station = currentStation else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        // Use station name for title
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
    func play(station: Station, in newPlaylist: [Station]? = nil, title: String? = nil) {
        if let newPlaylist = newPlaylist {
            self.playlist = newPlaylist
            self.playlistStations = newPlaylist
        }
        
        if let title = title {
            self.playlistTitle = title
        }
        
        if currentStation?.id == station.id {
            togglePlayPause()
            return
        }
        
        // 切歌时，清空之前的识别信息
        ShazamMatcher.shared.reset()
        
        playStation(station)
    }
    
    // Internal helper to start playing a station (fresh start)
    private func playStation(_ station: Station) {
        guard let url = URL(string: station.urlResolved) else { return }
        
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 5.0
        
        // 设置播放器
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            player?.volume = Float(volume)
            player?.automaticallyWaitsToMinimizeStalling = true
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        player?.play()
        isPlaying = true
        currentStation = station
        updateNowPlayingInfo()
    }
    
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        isPlaying = false
        currentStation = nil
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            // Resume 逻辑
            if let station = currentStation {
                 // 强制重新加载 Stream 以确保听到最新的直播内容
                 // 而不是恢复之前的缓存
                 print("AudioPlayerManager: Resuming live stream (reloading)")
                 playStation(station)
            } else {
                player?.play()
                isPlaying = true
                updateNowPlayingInfo()
            }
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
    
    // MARK: - Shazam / Lyrics Integration
    
    private func setupShazamObservers() {
        ShazamMatcher.shared.$isMatching
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateNowPlayingInfo() }
            .store(in: &cancellables)
            
        ShazamMatcher.shared.$customMatchResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateNowPlayingInfo() }
            .store(in: &cancellables)
            
        ShazamMatcher.shared.$lyrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lyrics in
                if let lyrics = lyrics {
                    self?.parsedLyrics = LRCParser.parse(lrc: lyrics)
                    self?.startLyricsTimer()
                } else {
                    self?.parsedLyrics = []
                    self?.stopLyricsTimer()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleLockScreenRecognition() {
        // Check Pro
        if !SubscriptionManager.shared.isPro {
            return
        }
        
        // Trigger
        ShazamMatcher.shared.startMatching(fromLockScreen: true)
        updateNowPlayingInfo()
    }
    
    private func startLyricsTimer() {
        stopLyricsTimer()
        lyricsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLyricsOnLockScreen()
            }
        }
    }
    
    private func stopLyricsTimer() {
        lyricsTimer?.invalidate()
        lyricsTimer = nil
    }
    
    private func updateLyricsOnLockScreen() {
        guard let _ = ShazamMatcher.shared.customMatchResult,
              !parsedLyrics.isEmpty else { return }
              
        let currentTime = ShazamMatcher.shared.currentSongTime
        
        if let currentLine = parsedLyrics.last(where: { $0.time <= currentTime }) {
             var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
             let newTitle = currentLine.text
             
             if let existingTitle = currentInfo[MPMediaItemPropertyTitle] as? String, existingTitle == newTitle {
                 return
             }
             
             currentInfo[MPMediaItemPropertyTitle] = newTitle
             MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
        }
    }
}
