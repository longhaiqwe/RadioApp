import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                NeonColors.darkBg.ignoresSafeArea()
                
                List {
                    Section(header: Text("法律与合规").foregroundColor(NeonColors.cyan)) {
                        NavigationLink(destination: EULAView()) {
                            Label("服务条款 (EULA)", systemImage: "doc.text")
                        }
                        
                        NavigationLink(destination: PrivacyPolicyView()) {
                            Label("隐私政策", systemImage: "hand.raised")
                        }
                        
                        // 简单的管理入口（可选，查看已屏蔽电台）
                        NavigationLink(destination: BlockedStationsView()) {
                            Label("已屏蔽电台", systemImage: "slash.circle")
                        }
                    }
                    
                    Section(header: Text("关于").foregroundColor(NeonColors.cyan)) {
                        HStack {
                            Text("版本")
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                // 适配暗色模式列表背景
                .onAppear {
                    UITableView.appearance().backgroundColor = .clear
                }
                .background(NeonColors.darkBg) // 强制背景色
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(NeonColors.cyan)
                }
            }
        }
    }
}

struct EULAView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("最终用户许可协议 (EULA)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("""
                1. 内容来源说明
                本应用（拾音FM）是一款电台发现工具，接入 Radio Browser 社区数据库。本应用不托管、不上传、不分发任何音频流媒体内容。所有电台链接均来自公共网络。

                2. 用户生成内容与社区准则
                由于电台目录由社区维护，可能包含未被及时发现的违规内容。我们对令人反感的内容（包括但不限于色情、暴力、仇恨言论、版权侵权）实行零容忍政策。

                3. 过滤与举报机制
                为保障您的体验与合规：
                - 我们已内置关键词过滤系统，自动屏蔽已知违规电台。
                - **举报与屏蔽**：如果您发现任何不当内容，请点击播放页面的“举报/屏蔽”按钮。该电台将立即从您的应用中隐藏（加入本地黑名单）。
                - 我们会定期审查举报信息，并更新全局黑名单。

                4. 免责声明
                用户需自行承担使用第三方音频流的风险。应用开发者不对第三方电台内容的合法性、准确性或可用性承担责任。

                5. 同意条款
                下载并使用本应用即表示您同意本协议。
                """)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(6)
            }
            .padding()
        }
        .background(NeonColors.darkBg.ignoresSafeArea())
        .navigationTitle("服务条款")
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("隐私政策")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("""
                1. 数据收集
                本应用尊重您的隐私。我们不收集您的个人身份信息。
                
                2. 本地数据
                您的收藏列表、屏蔽列表和偏好设置仅存储在您的设备本地（UserDefaults/CoreData），不会上传至任何服务器。
                
                3. 第三方服务
                - **Radio Browser**: 为了获取电台列表，应用会向 Radio Browser API 发送匿名请求。
                - **ShazamKit**: 音乐识别功能由 Apple ShazamKit 提供，音频指纹处理在设备端或通过 Apple 安全服务器进行，我们无法获取您的原始音频数据。
                - **ACRCloud**: 高级识别功能会将音频指纹发送至 ACRCloud 进行匹配（仅限 Pro 用户主动触发）。

                4. 变更通知
                随着法律法规或业务变动，我们可能会更新本政策。
                """)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(6)
            }
            .padding()
        }
        .background(NeonColors.darkBg.ignoresSafeArea())
        .navigationTitle("隐私政策")
    }
}

struct BlockedStationsView: View {
    @ObservedObject var blockManager = StationBlockManager.shared
    
    var body: some View {
        List {
            if blockManager.blockedUUIDs.isEmpty {
                Text("暂无屏蔽电台")
                    .foregroundColor(.gray)
            } else {
                ForEach(Array(blockManager.blockedUUIDs).sorted(), id: \.self) { uuid in
                    VStack(alignment: .leading) {
                        Text(blockManager.blockedStationNames[uuid] ?? "未知电台")
                            .font(.body)
                            .foregroundColor(.white)
                        Text("UUID: \(uuid)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .onDelete { indexSet in
                     // 支持解除屏蔽（可选）
                     let sortedUUIDs = Array(blockManager.blockedUUIDs).sorted()
                    indexSet.forEach { index in
                        if index < sortedUUIDs.count {
                            let uuid = sortedUUIDs[index]
                            blockManager.unblock(stationUUID: uuid)
                        }
                    }
                }
            }
        }
        .navigationTitle("已屏蔽电台")
        .background(NeonColors.darkBg)
    }
}
