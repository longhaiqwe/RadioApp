import SwiftUI

struct ShareCardPreviewView: View {
    let image: UIImage
    let onShare: () -> Void
    let onDownload: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // 背景模糊
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 顶部关闭按钮
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // 卡片预览
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(24)
                    .shadow(radius: 20)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                // 底部按钮区域
                HStack(spacing: 16) {
                    // 保存到文件按钮 (提供下载能力)
                    Button(action: onDownload) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("保存到文件")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                        )
                    }
                    
                    // 系统分享按钮
                    Button(action: onShare) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("系统分享")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.white)
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            }
        }
    }
}
