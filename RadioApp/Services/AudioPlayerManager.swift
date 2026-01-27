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
        // Set playback rate (1.0 for playing, 0.0 for paused)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Asynchronously load image if available
        if let url = URL(string: station.favicon) {
            let stationId = station.id // Capture ID
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self else { return }
                guard let data = data, let image = UIImage(data: data) else { return }
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                
                DispatchQueue.main.async {
                    // Verify if we are still playing the same station
                    guard self.currentStation?.id == stationId else { return }
                    
                    var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                    currentInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                }
            }.resume()
        }
    }
    
    private var audioTap: AudioTap?
    
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
        
        // Use AVURLAsset to allow track inspection (async)
        let asset = AVURLAsset(url: url)
        
        // We create the item immediately but setup tap when tracks match
        // Note: For HLS, tracks might load later.
        let playerItem = AVPlayerItem(asset: asset)
        
        // Setup simple tap immediately? Or wait?
        // Let's attempt to setup tap. AudioTap handles checking for tracks.
        // For robustness with HLS, we should really observe "tracks" key.
        // But for this implementation step, let's initialize the tap which will attach to the first audio track if available.
        // If not available, we might miss it.
        // Re-creating the tap on status ready is better.
        
        self.audioTap = AudioTap()
        self.audioTap?.onAudioBuffer = { buffer, time in
            // Forward to ShazamMatcher
            ShazamMatcher.shared.match(buffer: buffer, time: time)
        }
        
        // Observe status to know when tracks are ready?
        // Actually, let's just create the player item and let the tap try to attach.
        // A better approach for HLS is to wait for the player item's `tracks` property to be populated.
        // But let's restart with the straightforward approach first.
        
        // Using a small delay or KVO is safer for HLS but let's try direct attachment.
        // If it fails, our AudioTap implementation prints a warning.
        
        // Ideally we should observe `playerItem.p.tracks` using KVO.
        // But for simplicity in this step:

        Task {
            do {
                // Modern async load
                let _ = try await asset.load(.tracks)
                
                // Continue on main actor if needed, or just safely update
                // Since we are in a Task, we should be careful about self capture and threads.
                // However, play() is likely on MainActor or we should dispatch to main for player updates.
                
                // Let's verify tracks are loaded
                // Since we successfully awaited load(.tracks), the status is guaranteed to be loaded.
                await self.audioTap?.setupTap(for: playerItem)
                
                await MainActor.run {
                    // Improve streaming stability
                    playerItem.preferredForwardBufferDuration = 5.0
                    
                    if self.player == nil {
                        self.player = AVPlayer(playerItem: playerItem)
                        self.player?.automaticallyWaitsToMinimizeStalling = true
                    } else {
                        self.player?.replaceCurrentItem(with: playerItem)
                    }
                    
                    self.player?.play()
                    self.isPlaying = true
                    self.currentStation = station
                    
                    self.updateNowPlayingInfo()
                }
            } catch {
                print("Failed to load tracks: \(error)")
            }
        }
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
