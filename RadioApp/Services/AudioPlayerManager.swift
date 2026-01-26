import Foundation
import AVFoundation
import Combine

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    
    private var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentStation: Station?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func play(station: Station) {
        if currentStation?.id == station.id {
            togglePlayPause()
            return
        }
        
        guard let url = URL(string: station.urlResolved) else { return }
        
        let playerItem = AVPlayerItem(url: url)
        // Improve streaming stability
        playerItem.preferredForwardBufferDuration = 5.0
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            player?.automaticallyWaitsToMinimizeStalling = true
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        player?.play()
        isPlaying = true
        currentStation = station
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            player?.play()
            isPlaying = true
        }
    }
}
