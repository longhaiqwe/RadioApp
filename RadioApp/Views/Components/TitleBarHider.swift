
import SwiftUI
import UIKit

/// A helper view to hide the window title bar on Mac Catalyst
struct TitleBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return TitleBarHiderController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    class TitleBarHiderController: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            
            // Execute on main thread to ensure window scene is ready
            DispatchQueue.main.async { [weak self] in
                self?.hideTitleBar()
            }
        }
        
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            hideTitleBar()
        }
        
        private func hideTitleBar() {
            guard let windowScene = view.window?.windowScene else { return }
            
            #if targetEnvironment(macCatalyst)
            if let titlebar = windowScene.titlebar {
                titlebar.titleVisibility = .hidden
                titlebar.toolbar = nil
            }
            
            // 允许窗口自由调整大小
            if let sizeRestrictions = windowScene.sizeRestrictions {
                sizeRestrictions.minimumSize = CGSize(width: 800, height: 600)
                sizeRestrictions.maximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            }
            #endif
        }
    }
}
