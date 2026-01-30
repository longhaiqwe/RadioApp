import SwiftUI

struct StationAvatarView: View {
    let urlString: String
    let placeholderName: String
    let placeholderId: String
    
    var body: some View {
        Group {
            if urlString.hasPrefix("bundle://") {
                // Local Asset
                let assetName = String(urlString.dropFirst("bundle://".count))
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let url = URL(string: urlString), !urlString.isEmpty {
                // Remote URL
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            NeonColors.cardBg
                            ProgressView()
                                .tint(NeonColors.cyan)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        PlaceholderView(name: placeholderName, id: placeholderId)
                    @unknown default:
                        PlaceholderView(name: placeholderName, id: placeholderId)
                    }
                }
            } else {
                // Formatting error or empty
                PlaceholderView(name: placeholderName, id: placeholderId)
            }
        }
    }
}
