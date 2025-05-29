import SwiftUI

struct MentionTextView: View {
    let text: String
    
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
    
    var body: some View {
        Text(attributedString)
    }
    
    private func processText(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var processedLines: [String] = []
        var emptyLineCount = 0
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyLineCount += 1
                if emptyLineCount == 5 {
                    processedLines.append("...")
                } else if emptyLineCount < 5 {
                    processedLines.append("")
                }
            } else {
                if emptyLineCount >= 5 {
                    processedLines.append("...")
                }
                emptyLineCount = 0
                processedLines.append(line)
            }
        }
        
        return processedLines.joined(separator: "\n")
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
    static let groupMentionHighlight = Color.blue.opacity(0.8)
}

// Preview provider
struct MentionTextView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MentionTextView(text: "Hello @张三 and #技术圈")
            MentionTextView(text: "Meeting with @李四 in #产品组")
            MentionTextView(text: "Regular text with @王五 and #设计圈 mentions")
            MentionTextView(text: "Line 1\n\n\n\n\n\n\nLine 2") // Test empty lines
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 