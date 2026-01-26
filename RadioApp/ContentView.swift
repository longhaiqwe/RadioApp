import SwiftUI

struct ContentView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @State private var showPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            HomeView()
            
            // Mini Player Bar (Click to open full player)
            if playerManager.currentStation != nil {
                Button(action: {
                    showPlayer = true
                }) {
                    HStack {
                        if let url = URL(string: playerManager.currentStation?.favicon ?? "") {
                            AsyncImage(url: url) { image in
                                image.resizable()
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                        } else {
                            Image(systemName: "music.note")
                                .frame(width: 40, height: 40)
                                .background(Color.gray)
                                .cornerRadius(8)
                        }
                        
                        Text(playerManager.currentStation?.name ?? "")
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: {
                            playerManager.togglePlayPause()
                        }) {
                            Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        }
                    }
                    .padding()
                    .background(VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .sheet(isPresented: $showPlayer) {
            PlayerView()
        }
    }
}

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}
