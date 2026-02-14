import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - 分享卡片生成器
/// 负责将 ShareCardView 渲染为图片，并提供系统分享功能
@MainActor
class ShareCardGenerator {
    
    // MARK: - 生成分享卡片图片
    
    /// 生成分享卡片的 UIImage
    /// - Parameters:
    ///   - title: 歌曲名
    ///   - artist: 歌手名
    ///   - album: 专辑名（可选）
    ///   - artworkImage: 封面图片（预加载的 UIImage）
    ///   - stationName: 电台名称（可选）
    ///   - timestamp: 识别时间
    ///   - releaseDate: 发行时间（可选）
    /// - Returns: 渲染后的 UIImage，失败时返回 nil
    static func generateImage(
        title: String,
        artist: String,
        album: String? = nil,
        artworkImage: UIImage? = nil,
        stationName: String? = nil,
        timestamp: Date = Date(),
        releaseDate: Date? = nil
    ) -> UIImage? {
        let cardView = ShareCardView(
            title: title,
            artist: artist,
            album: album,
            artworkImage: artworkImage,
            stationName: stationName,
            timestamp: timestamp,
            releaseDate: releaseDate
        )
        
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = UIScreen.main.scale // Retina 分辨率
        renderer.proposedSize = ProposedViewSize(width: 360, height: nil) // 固定宽度
        
        return renderer.uiImage
    }
    
    // MARK: - 预加载封面图
    
    /// 异步下载封面图片（ImageRenderer 不支持 AsyncImage）
    /// - Parameter url: 封面图 URL
    /// - Returns: 下载后的 UIImage
    static func preloadArtwork(from url: URL?) async -> UIImage? {
        guard let url = url else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("ShareCardGenerator: 封面图下载失败 - \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 分享图片
    
    /// 通过系统分享面板分享图片
    /// - Parameters:
    ///   - image: 要分享的图片
    ///   - completion: 分享完成后的回调（成功或取消）
    static func shareImage(_ image: UIImage, completion: (() -> Void)? = nil) {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // 设置回调
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                print("ShareCardGenerator: 分享/保存成功")
                completion?()
            }
        }
        
        // 获取当前最上层 ViewController
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("ShareCardGenerator: 无法获取 rootViewController")
            return
        }
        
        // 递归找到最上层的 presented VC
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        // iPad 适配（UIActivityViewController 需要 popover）
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        topVC.present(activityVC, animated: true)
    }
    
    // MARK: - 一键生成并分享
    
    /// 完整的分享流程：预加载封面 → 生成卡片 → 弹出分享面板
    /// - Parameters:
    ///   - title: 歌曲名
    ///   - artist: 歌手名
    ///   - album: 专辑名
    ///   - artworkURL: 封面图 URL
    ///   - stationName: 电台名
    ///   - timestamp: 识别时间
    ///   - releaseDate: 发行时间
    /// - Returns: 是否成功
    @discardableResult
    static func generateAndShare(
        title: String,
        artist: String,
        album: String? = nil,
        artworkURL: URL? = nil,
        stationName: String? = nil,
        timestamp: Date = Date(),
        releaseDate: Date? = nil
    ) async -> Bool {
        // 1. 预加载封面
        let artworkImage = await preloadArtwork(from: artworkURL)
        
        // 2. 生成卡片图片
        guard let cardImage = generateImage(
            title: title,
            artist: artist,
            album: album,
            artworkImage: artworkImage,
            stationName: stationName,
            timestamp: timestamp,
            releaseDate: releaseDate
        ) else {
            print("ShareCardGenerator: 卡片图片生成失败")
            return false
        }
        
        // 3. 弹出分享面板
        shareImage(cardImage)
        return true
    }
    
    // MARK: - 仅生成图片（用于预览）
    
    /// 异步生成卡片图片
    static func generateCardImage(
        title: String,
        artist: String,
        album: String? = nil,
        artworkURL: URL? = nil,
        stationName: String? = nil,
        timestamp: Date = Date(),
        releaseDate: Date? = nil
    ) async -> UIImage? {
        // 1. 预加载封面
        let artworkImage = await preloadArtwork(from: artworkURL)
        
        // 2. 生成卡片图片
        return generateImage(
            title: title,
            artist: artist,
            album: album,
            artworkImage: artworkImage,
            stationName: stationName,
            timestamp: timestamp,
            releaseDate: releaseDate
        )
    }
}
