import SwiftUI

import SwiftUI
import Combine

struct PlayerView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var volume: CGFloat = 0.5
    @State private var isFavorite: Bool = false
    
    var body: some View {
        ZStack {
            // MARK: - Dynamic Background
            if let station = playerManager.currentStation, let url = URL(string: station.favicon), !station.favicon.isEmpty {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.black.overlay(
                            LinearGradient(colors: [.indigo, .purple, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    }
                }
                .ignoresSafeArea()
                .blur(radius: 60)
                .overlay(Color.black.opacity(0.3))
            } else {
                LinearGradient(gradient: Gradient(colors: [Color.indigo.opacity(0.8), Color.black]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 20) {
                // MARK: - Top Bar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("正在播放")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .textCase(.uppercase)
                        .kerning(2)
                    Spacer()
                    Button(action: {
                        isFavorite.toggle()
                    }) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundColor(isFavorite ? .red : .white.opacity(0.8))
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
                
                // MARK: - Album Art
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 300, height: 300)
                        .blur(radius: 20)
                    
                    if let station = playerManager.currentStation, let url = URL(string: station.favicon), !station.favicon.isEmpty {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "music.mic")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .frame(width: 260, height: 260)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    } else {
                        Image(systemName: "radio.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.white.opacity(0.2))
                            .frame(width: 260, height: 260)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                
                // MARK: - Visualizer
                if playerManager.isPlaying {
                    VisualizerView()
                        .frame(height: 40)
                        .padding(.vertical)
                } else {
                    Spacer().frame(height: 40).padding(.vertical)
                }
                
                // MARK: - Station Info
                VStack(spacing: 8) {
                    Text(playerManager.currentStation?.name ?? "未选择电台")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(playerManager.currentStation?.tags ?? "")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // MARK: - Controls
                HStack(spacing: 60) {
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.3)) // Disabled style
                    }
                    .disabled(true)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            playerManager.togglePlayPause()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 80, height: 80)
                                .shadow(color: .pink.opacity(0.4), radius: 15, x: 0, y: 10)
                            
                            Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.3)) // Disabled style
                    }
                    .disabled(true)
                }
                
                // MARK: - Volume Slider Placeholder
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.white.opacity(0.6))
                    Slider(value: $volume, in: 0...1)
                        .accentColor(.white)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

// Add a simple simulated visualizer
struct VisualizerView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 3, height: isAnimating ? CGFloat.random(in: 10...30) : 5)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .speed(Double.random(in: 0.5...1.5)),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

