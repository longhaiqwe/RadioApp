import SwiftUI
import UniformTypeIdentifiers
import ShazamKit

struct ShazamTestView: View {
    @StateObject private var matcher = ShazamMatcher()
    @State private var isImporting = false
    @State private var selectedFileURL: URL?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ShazamKit Test")
                .font(.largeTitle)
                .bold()
            
            if let match = matcher.lastMatch {
                VStack {
                    AsyncImage(url: match.artworkURL) { image in
                        image.resizable()
                             .aspectRatio(contentMode: .fit)
                             .frame(width: 200, height: 200)
                             .cornerRadius(12)
                    } placeholder: {
                        Color.gray.frame(width: 200, height: 200).cornerRadius(12)
                    }
                    
                    Text(match.title ?? "Unknown Title")
                        .font(.title2)
                        .bold()
                    
                    Text(match.artist ?? "Unknown Artist")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if let appleMusicURL = match.appleMusicURL {
                        Link("Open in Apple Music", destination: appleMusicURL)
                            .padding(.top, 5)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
            } else if matcher.isMatching {
                ProgressView("Listening & Matching...")
                    .scaleEffect(1.5)
            } else if let error = matcher.lastError {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                Text("Select a song file to identify it")
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                isImporting = true
            }) {
                Label("Pick Audio File", systemImage: "music.note")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            if let url = selectedFileURL {
                Text("Selected: \(url.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [UTType.audio],
            allowsMultipleSelection: false
        ) { result in
            do {
                let selectedFiles = try result.get()
                if let file = selectedFiles.first {
                    // Start accessing security scoped resource if needed (for file picker)
                    guard file.startAccessingSecurityScopedResource() else {
                        // If we can't access it, try anyway, but it likely fails unless it's in public place
                        // Often fileImporter gives us access even without this if it's not security scoped
                        // But for user selected files, we usually need it.
                        matcher.match(fileURL: file)
                        return
                    }
                    
                    defer { file.stopAccessingSecurityScopedResource() }
                    
                    // Create a temporary file URL
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempFile = tempDir.appendingPathComponent(file.lastPathComponent)
                    
                    // Remove existing file if present
                    try? FileManager.default.removeItem(at: tempFile)
                    
                    // Copy the file
                    try FileManager.default.copyItem(at: file, to: tempFile)
                    
                    selectedFileURL = tempFile
                    matcher.match(fileURL: tempFile)
                }
            } catch {
                print("Error selecting file: \(error.localizedDescription)")
            }
        }
    }
}

struct ShazamTestView_Previews: PreviewProvider {
    static var previews: some View {
        ShazamTestView()
    }
}
