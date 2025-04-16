import SwiftUI

struct MentionTextView: View {
    let text: String
    
    var body: some View {
        Text(attributedString)
    }
    
    var attributedString: AttributedString {
        let words = text.split(separator: " ")
        var result = AttributedString("")
        
        for (index, word) in words.enumerated() {
            if word.hasPrefix("@") {
                var mentionText = AttributedString(String(word))
                mentionText.foregroundColor = Color.mentionHighlight
                mentionText.font = .subheadline.bold()
                result.append(mentionText)
            } else {
                result.append(AttributedString(String(word)))
            }
            
            if index < words.count - 1 {
                result.append(AttributedString(" "))
            }
        }
        
        return result
    }
} 