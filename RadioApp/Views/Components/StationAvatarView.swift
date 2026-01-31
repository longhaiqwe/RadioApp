
import SwiftUI

struct StationAvatarView: View {
    let urlString: String
    let placeholderName: String
    let placeholderId: String
    
    @State private var image: Image?
    @State private var isLoading = false
    @State private var hasError = false
    
    var body: some View {
        Group {
            if urlString.hasPrefix("bundle://") {
                // Local Asset
                let assetName = String(urlString.dropFirst("bundle://".count))
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if !urlString.isEmpty {
                // Remote URL logic
                if let loadedImage = image {
                    loadedImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoading {
                    // Loading State
                    ZStack {
                        NeonColors.cardBg
                        ProgressView()
                            .tint(NeonColors.cyan)
                    }
                } else {
                    // Placeholder (Error or Not Loaded yet)
                    PlaceholderView(name: placeholderName, id: placeholderId)
                }
            } else {
                // Empty URL
                PlaceholderView(name: placeholderName, id: placeholderId)
            }
        }
        .task(id: urlString) {
            await loadImage()
        }
    }
    
    // MARK: - Image Loading Logic
    private func loadImage() async {
        // Reset state for new URL
        guard !urlString.isEmpty, !urlString.hasPrefix("bundle://") else { return }
        
        guard let url = URL(string: urlString) else {
            hasError = true
            return
        }
        
        // Start loading
        isLoading = true
        hasError = false
        image = nil
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let uiImage = UIImage(data: data) {
                // Convert to SwiftUI Image on main thread to be safe with UI updates
                let img = Image(uiImage: uiImage)
                await MainActor.run {
                    withAnimation {
                        self.image = img
                        self.isLoading = false
                    }
                }
            } else {
                throw URLError(.cannotDecodeContentData)
            }
        } catch {
            print("Image load failed for \(urlString): \(error.localizedDescription)")
            await MainActor.run {
                withAnimation {
                    self.hasError = true
                    self.isLoading = false
                }
            }
        }
    }
}
