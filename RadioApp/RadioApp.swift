import SwiftUI

@main
struct RadioApp: App {
    
    init() {
        // 初始化 PostHog SDK
        PostHogManager.shared.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
