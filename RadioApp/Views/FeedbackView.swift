import SwiftUI

/// 用户反馈页面
struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var feedbackType: FeedbackType = .feature
    @State private var content: String = ""
    @State private var contact: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    
    enum FeedbackType: String, CaseIterable {
        case bug = "bug"
        case feature = "feature"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .bug: return "🐛 Bug 反馈"
            case .feature: return "💡 功能建议"
            case .other: return "💬 其他"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // 背景
            NeonColors.darkBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Text("反馈")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // 占位，保持标题居中
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 说明文字
                        Text("您的反馈对我们很重要，帮助我们持续改进")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                        
                        // 反馈类型选择
                        VStack(alignment: .leading, spacing: 12) {
                            Text("反馈类型")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack(spacing: 12) {
                                ForEach(FeedbackType.allCases, id: \.self) { type in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            feedbackType = type
                                        }
                                    }) {
                                        Text(type.displayName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(feedbackType == type ? .white : .white.opacity(0.6))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(feedbackType == type ? NeonColors.purple.opacity(0.6) : .white.opacity(0.08))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(feedbackType == type ? NeonColors.cyan.opacity(0.5) : .clear, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 反馈内容
                        VStack(alignment: .leading, spacing: 12) {
                            Text("反馈内容")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            TextEditor(text: $content)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 150)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                )
                                .overlay(
                                    Group {
                                        if content.isEmpty {
                                            Text("请详细描述您的问题或建议...")
                                                .font(.system(size: 15))
                                                .foregroundColor(.white.opacity(0.3))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 20)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // 联系方式（可选）
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("联系方式")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("(可选)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            TextField("邮箱或其他联系方式，方便我们回复您", text: $contact)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // 提交按钮
                        Button(action: submitFeedback) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 8)
                                }
                                Text(isSubmitting ? "提交中..." : "提交反馈")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: content.isEmpty ? [Color.gray.opacity(0.4), Color.gray.opacity(0.4)] : [NeonColors.magenta, NeonColors.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: content.isEmpty ? .clear : NeonColors.magenta.opacity(0.4), radius: 12, y: 4)
                        }
                        .disabled(content.isEmpty || isSubmitting)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .alert("提交成功", isPresented: $showSuccess) {
            Button("好的") {
                dismiss()
            }
        } message: {
            Text("感谢您的反馈！我们会认真对待每一条建议。")
        }
    }
    
    private func submitFeedback() {
        isSubmitting = true
        
        // 上报到 PostHog
        PostHogManager.shared.trackFeedback(
            content: content,
            type: feedbackType.rawValue,
            contact: contact.isEmpty ? nil : contact
        )
        
        // 模拟短暂延迟，让用户感知到提交过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSubmitting = false
            showSuccess = true
        }
    }
}

#Preview {
    FeedbackView()
}
