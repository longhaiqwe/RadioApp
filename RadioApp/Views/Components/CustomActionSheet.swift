import SwiftUI

// MARK: - Action Sheet 配置模型
struct ActionSheetConfig: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let items: [ActionSheetItem]
}

enum ActionSheetItem: Identifiable {
    case button(title: String, type: ButtonType, action: () -> Void)
    case input(placeholder: String, onCommit: (String) -> Void)
    
    var id: UUID { UUID() }
    
    enum ButtonType {
        case `default`
        case destructive
        case cancel
    }
}

struct CustomActionSheet: View {
    let config: ActionSheetConfig
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // 弹窗内容
            VStack(spacing: 0) {
                // 标题和消息
                VStack(spacing: 8) {
                    Text(config.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let message = config.message {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
                
                // 分割线
                Divider()
                    .background(NeonColors.cyan.opacity(0.3))
                
                // 按钮/输入框列表
                VStack(spacing: 0) {
                    ForEach(Array(config.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                        
                        switch item {
                        case .button(let title, let type, let action):
                            Button(action: {
                                action()
                                onDismiss()
                            }) {
                                Text(title)
                                    .font(.system(size: 17, weight: type == .cancel ? .semibold : .regular))
                                    .foregroundColor(colorForButtonType(type))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .contentShape(Rectangle())
                            }
                            
                        case .input(let placeholder, let onCommit):
                            CustomInputRow(placeholder: placeholder) { text in
                                onCommit(text)
                                onDismiss()
                            }
                        }
                    }
                }
            }
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(NeonColors.cardBg.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(NeonColors.cyan.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: NeonColors.cyan.opacity(0.2), radius: 20)
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
        .zIndex(100)
    }
    
    private func colorForButtonType(_ type: ActionSheetItem.ButtonType) -> Color {
        switch type {
        case .default:
            return .white
        case .destructive:
            return NeonColors.red
        case .cancel:
            return NeonColors.cyan
        }
    }
}

// MARK: - 自定义输入行组件
struct CustomInputRow: View {
    let placeholder: String
    let onCommit: (String) -> Void
    @State private var text: String = ""
    
    var body: some View {
        HStack {
            ZStack(alignment: .center) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 17))
                        .foregroundColor(NeonColors.cyan.opacity(0.7))
                }
                
                TextField("", text: $text, onCommit: {
                    if !text.isEmpty {
                        onCommit(text)
                    }
                })
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .accentColor(NeonColors.cyan)
                .submitLabel(.done)
            }
            .frame(height: 56)
            .padding(.horizontal, 16)
            
            // 确认按钮 (箭头)
            if !text.isEmpty {
                Button(action: {
                    onCommit(text)
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(NeonColors.cyan)
                        .font(.system(size: 24))
                        .padding(.trailing, 16)
                }
            }
        }
        .background(Color.white.opacity(0.05))
    }
}
