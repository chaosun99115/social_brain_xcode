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
        var result = AttributedString("")
        var currentIndex = processedText.startIndex
        
        while currentIndex < processedText.endIndex {
            // Check for parenthesized mentions first: @(name with spaces) or #(circle with spaces)
            if let parenthesizedMention = extractParenthesizedMention(from: processedText, at: currentIndex) {
                // Add any text before the mention
                if currentIndex < parenthesizedMention.range.lowerBound {
                    let beforeText = String(processedText[currentIndex..<parenthesizedMention.range.lowerBound])
                    result.append(AttributedString(beforeText))
                }
                
                // Add the mention with green styling for both contact and circle
                var mentionString = AttributedString(parenthesizedMention.text)
                mentionString.foregroundColor = .green
                mentionString.font = .systemFont(ofSize: 17, weight: .medium)
                result.append(mentionString)
                
                currentIndex = parenthesizedMention.range.upperBound
            }
            // Check for simple mentions: @name or #circle
            else if let simpleMention = extractSimpleMention(from: processedText, at: currentIndex) {
                // Add any text before the mention
                if currentIndex < simpleMention.range.lowerBound {
                    let beforeText = String(processedText[currentIndex..<simpleMention.range.lowerBound])
                    result.append(AttributedString(beforeText))
                }
                
                // Add the mention with green styling for both contact and circle
                var mentionString = AttributedString(simpleMention.text)
                mentionString.foregroundColor = .green
                mentionString.font = .systemFont(ofSize: 17, weight: .medium)
                result.append(mentionString)
                
                currentIndex = simpleMention.range.upperBound
            }
            // Add regular text
            else {
                let char = processedText[currentIndex]
                result.append(AttributedString(String(char)))
                currentIndex = processedText.index(after: currentIndex)
            }
        }
        
        return result
    }
    
    private func extractParenthesizedMention(from text: String, at index: String.Index) -> (text: String, type: String, range: Range<String.Index>)? {
        guard index < text.endIndex else { return nil }
        
        let char = text[index]
        if char == "@" || char == "#" {
            let type = String(char)
            
            // Look for opening parenthesis
            let afterAt = text.index(after: index)
            guard afterAt < text.endIndex && text[afterAt] == "(" else { return nil }
            
            // Find closing parenthesis
            var parenCount = 1
            var currentIndex = text.index(after: afterAt)
            
            while currentIndex < text.endIndex && parenCount > 0 {
                let currentChar = text[currentIndex]
                if currentChar == "(" {
                    parenCount += 1
                } else if currentChar == ")" {
                    parenCount -= 1
                }
                currentIndex = text.index(after: currentIndex)
            }
            
            // If we found a matching closing parenthesis
            if parenCount == 0 {
                let startIndex = text.index(after: afterAt) // After the opening parenthesis
                let endIndex = text.index(before: currentIndex) // Before the closing parenthesis
                let mentionText = String(text[startIndex..<endIndex])
                
                // Create the full mention text for display
                let fullMentionText = "\(type)(\(mentionText))"
                
                return (fullMentionText, type, index..<currentIndex)
            }
        }
        
        return nil
    }
    
    private func extractSimpleMention(from text: String, at index: String.Index) -> (text: String, type: String, range: Range<String.Index>)? {
        guard index < text.endIndex else { return nil }
        
        let char = text[index]
        if char == "@" || char == "#" {
            let type = String(char)
            
            // Find the end of the mention (stop at whitespace or punctuation)
            var endIndex = text.index(after: index)
            while endIndex < text.endIndex {
                let currentChar = text[endIndex]
                if currentChar.isWhitespace || currentChar.isPunctuation {
                    break
                }
                endIndex = text.index(after: endIndex)
            }
            
            let range = index..<endIndex
            let mentionText = String(text[range])
            
            // Only return if it's a valid mention (not just @ or # alone)
            if mentionText.count > 1 {
                return (mentionText, type, range)
            }
        }
        
        return nil
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
            // Test new parenthesized mentions
            MentionTextView(text: "Hello @(John Smith) and #(技术圈)")
            MentionTextView(text: "Meeting with @(李四) in #(产品组)")
            MentionTextView(text: "Regular text with @(王五) and #(设计圈) mentions")
            
            // Test mixed parenthesized and unquoted mentions
            MentionTextView(text: "Mixed: @张三 and @(John Smith) with #技术圈 and #(Product Team)")
            
            // Test backward compatibility with unquoted mentions
            MentionTextView(text: "Hello @张三 and #技术圈")
            
            // Test complex scenarios
            MentionTextView(text: "Multiple mentions: @(John Doe) and @(Jane Smith) in #(Engineering Team) and #(Design Team)")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 