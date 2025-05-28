import SwiftUI

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.primaryAction)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FeatureRow_Previews: PreviewProvider {
    static var previews: some View {
        FeatureRow(
            icon: "star.fill",
            title: "示例功能",
            description: "这是一个示例功能描述"
        )
        .padding()
    }
} 