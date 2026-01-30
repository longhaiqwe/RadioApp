import Foundation
import AVFoundation
import Combine
import MediaPlayer

@MainActor
class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    private var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentStation: Station?
    
    // Playlist context
    private var playlist: [Station] = []
    @Published var playlistTitle: String = "播放列表"
    @Published var playlistStations: [Station] = [] // Expose playlist for UI binding if needed, or just access current property
    
    // Live Metadata (ICY) - Removed due to low accuracy
    // @Published var currentStreamTitle: String?
    // private var metadataObserver: NSKeyValueObservation?
    
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
        
        guard let url = URL(string: station.urlResolved) else { return }
        
        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 5.0
        
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
}
