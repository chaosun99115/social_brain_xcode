import SwiftUI

struct ConfirmationDialog: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Text(
                    """
                    进入示例模式后，将会生成虚拟的示例数据，供你全面体验"社交大脑"的功能。示例模式不影响你的私有数据，退出示例模式后将恢复原状。
                    """
                )
                .font(.body)
                .foregroundColor(Color(.systemGray))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                
                VStack(spacing: 0) {
                    Button(action: {
                        // TODO: Handle entering sample mode
                        isPresented = false
                    }) {
                        Text("确定进入")
                            .font(.headline)
                            .foregroundColor(Color(hex: "4085F3"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemBackground))
                    }
                    Divider()
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("取消")
                            .font(.headline)
                            .foregroundColor(Color(.systemGray2))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 0)
            }
            .padding(.bottom, 32)
        }
        .background(Color.black.opacity(0.25).ignoresSafeArea())
    }
} 