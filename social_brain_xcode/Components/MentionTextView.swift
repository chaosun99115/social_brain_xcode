import SwiftUI

struct MentionTextView: View {
    let text: String
    let preserveEmptyLines: Bool
    
    // Define mention types and their styles
    enum MentionType {
        case contact
        case group
        
        var prefix: String {
            switch self {
            case .contact: return "@"
            case .group: return "#"
            }
        }
        
        var color: Color {
            switch self {
            case .contact: return .mentionHighlight
            case .group: return .groupMentionHighlight
            }
        }
        
        var font: Font {
            switch self {
            case .contact: return .subheadline.bold()
            case .group: return .subheadline.bold()
            }
        }
    }
    
    // Default initializer that preserves empty lines (for detail views)
    init(text: String) {
        self.text = text
        self.preserveEmptyLines = true
    }
    
    // Initializer with explicit control over empty line preservation
    init(text: String, preserveEmptyLines: Bool) {
        self.text = text
        self.preserveEmptyLines = preserveEmptyLines
    }
    
    var body: some View {
        Text(attributedString)
    }
    
    private func processText(_ text: String) -> String {
        if preserveEmptyLines {
            // Preserve all lines, including empty ones
            return text
        } else {
            // Original compact behavior - filter out empty lines
            let lines = text.components(separatedBy: .newlines)
            let processedLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            return processedLines.joined(separator: "\n")
        }
    }
    
    var attributedString: AttributedString {
        let processedText = processText(text)
        let words = processedText.split(separator: " ")
        var result = AttributedString("")
        
        for (index, word) in words.enumerated() {
            let wordString = String(word)
            
            // Check for both types of mentions
            if wordString.hasPrefix(MentionType.contact.prefix) {
                var mentionText = AttributedString(wordString)
                mentionText.foregroundColor = MentionType.contact.color
                mentionText.font = MentionType.contact.font
                result.append(mentionText)
            } else if wordString.hasPrefix(MentionType.group.prefix) {
                var mentionText = AttributedString(wordString)
                mentionText.foregroundColor = MentionType.group.color
                mentionText.font = MentionType.group.font
                result.append(mentionText)
            } else {
                result.append(AttributedString(wordString))
            }
            
            if index < words.count - 1 {
                result.append(AttributedString(" "))
            }
        }
        
        return result
    }
}

// Add color extension for group mentions
extension Color {
    static let groupMentionHighlight = Color.green.opacity(0.8)
}

// Preview provider
struct MentionTextView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MentionTextView(text: "Hello @张三 and #技术圈")
            MentionTextView(text: "Meeting with @李四 in #产品组")
            MentionTextView(text: "Regular text with @王五 and #设计圈 mentions")
            
            // Test empty lines preservation
            VStack(alignment: .leading) {
                Text("With empty lines preserved (default):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                MentionTextView(text: "Line 1\n\n\n\n\n\n\nLine 2")
                    .background(Color.gray.opacity(0.1))
            }
            
            VStack(alignment: .leading) {
                Text("With compact mode (no empty lines):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                MentionTextView(text: "Line 1\n\n\n\n\n\n\nLine 2", preserveEmptyLines: false)
                    .background(Color.gray.opacity(0.1))
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 