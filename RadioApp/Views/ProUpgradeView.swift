import SwiftUI
import StoreKit
import Combine

/// Pro 升级页面 - 展示 ¥6 终身版购买选项
struct ProUpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var subscriptionManager = SubscriptionManager.shared

    @State private var timeRemaining: String = ""
    // 使用 Timer.publish 避免在 struct 中捕获 mutating self 的问题
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // 背景
            NeonColors.darkBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部关闭按钮
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 标题
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Text("解锁")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Pro")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(NeonColors.cyan)
                                    )
                            }
                            
                            Text("一次购买，永久使用")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        
                        // 功能介绍
                        VStack(alignment: .leading, spacing: 16) {
                            FeatureRow(
                                icon: "music.note.list",
                                title: "歌曲识别",
                                description: "收听电台时可识别正在播放的歌曲，并包含 50 次 ACRCloud 高精度识别配额"
                            )
                            
                            FeatureRow(
                                icon: "text.quote",
                                title: "歌词显示",
                                description: "查看识别歌曲的歌词内容"
                            )
                            
                            FeatureRow(
                                icon: "arrow.up.forward.app",
                                title: "跳转音乐平台",
                                description: "一键跳转到主流音乐平台收听完整版"
                            )
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                        
                        // 温馨提示
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 2)
                            
                            Text("温馨提示：受电台音质、背景杂音及曲库覆盖面等因素影响，歌曲识别存在失败可能，无法保证 100% 成功。")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 24)
                        
                        // 价格卡片
                        VStack(spacing: 12) {
                            if let product = subscriptionManager.proProduct {
                                Text(product.displayPrice)
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(NeonColors.cyan)
                                
                                Text("终身版 · 一次性付费")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                // 早鸟优惠提示
                                VStack(spacing: 6) {
                                    Text("当前 ¥6 为早鸟 & 春节特惠")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(NeonColors.magenta)
                                        .padding(.top, 8)
                                    
                                    Text("优惠截止至 2026 年 3 月 3 日（元宵节）")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    if !timeRemaining.isEmpty {
                                        Text("距离恢复原价仅剩：\(timeRemaining)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(NeonColors.cyan)
                                            .monospacedDigit()
                                            .padding(.top, 2)
                                    }
                                }
                                .padding(.top, 4)
                            } else {
                                ProgressView()
                                    .tint(.white)
                                Text("加载中...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [NeonColors.purple.opacity(0.3), NeonColors.magenta.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(NeonColors.cyan.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                        
                        // 购买按钮
                        Button(action: {
                            Task {
                                await subscriptionManager.purchase()
                                if subscriptionManager.isPro {
                                    dismiss()
                                }
                            }
                        }) {
                            HStack {
                                if subscriptionManager.purchaseInProgress {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 8)
                                }
                                Text(subscriptionManager.purchaseInProgress ? "处理中..." : "立即解锁")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [NeonColors.magenta, NeonColors.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: NeonColors.magenta.opacity(0.4), radius: 12, y: 4)
                        }
                        .disabled(subscriptionManager.proProduct == nil || subscriptionManager.purchaseInProgress)
                        .padding(.horizontal, 20)
                        
                        // 错误信息
                        if let error = subscriptionManager.errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // 恢复购买
                        Button(action: {
                            Task {
                                await subscriptionManager.restorePurchases()
                                if subscriptionManager.isPro {
                                    dismiss()
                                }
                            }
                        }) {
                            Text("恢复购买")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                                .underline()
                        }
                        .disabled(subscriptionManager.purchaseInProgress)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .onAppear {
            updateTimeRemaining()
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 4
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let endDate = calendar.date(from: components) else { return }
        let now = Date()
        
        // 如果现在已经过了截止日期，直接返回
        if now >= endDate {
            timeRemaining = ""
            return
        }
        
        let diff = calendar.dateComponents([.day, .hour, .minute, .second], from: now, to: endDate)
        
        if let day = diff.day, let hour = diff.hour, let minute = diff.minute, let second = diff.second {
            if day >= 0 || hour >= 0 || minute >= 0 || second >= 0 {
                timeRemaining = String(format: "%d天 %d小时 %d分 %d秒", day, hour, minute, second)
            } else {
                timeRemaining = ""
            }
        }
    }
}

// MARK: - 功能行组件
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(NeonColors.cyan)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ProUpgradeView()
}
