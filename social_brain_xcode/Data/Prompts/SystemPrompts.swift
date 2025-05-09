import Foundation
import CoreData

/// A collection of system prompts used throughout the app
enum SystemPrompts {
    
    /// Type alias to avoid naming conflicts with the Contact enum
    typealias ContactEntity = Contact
    
    /// Base prompt that's common to all interactions
    static let basePrompt = """
                            Follow the instructions strictly. Return the result in JSON format.
                            """
    
    /// Contact-specific prompts
    enum Contact {
        /// Prompt for analyzing a specific contact
        static func insights(contactName: String, notesCount: Int) -> String {
            """
            \(SystemPrompts.basePrompt)
            
            You are analyzing the relationship with \(contactName).
            There are \(notesCount) notes available about this contact.
            
            Focus on:
            - Identifying patterns in interactions
            - Suggesting conversation topics based on shared interests
            - Providing insights about communication style
            - Recommending ways to strengthen the relationship
            """
        }
        
        /// Prompt for general contact relationship advice
        static func general(contactName: String) -> String {
            """
            \(SystemPrompts.basePrompt)
            
            You are providing advice about the relationship with \(contactName).
            
            Focus on:
            - Maintaining meaningful connections
            - Finding opportunities for deeper engagement
            - Balancing frequency and quality of interactions
            - Identifying mutual value exchange opportunities
            """
        }
    }
    
    /// General social relationship prompts
    enum General {
        static func noteUpdateSytemPrompt() -> String {
            """
            Follow the instructions strictly. Return the result in following JSON format.
            {
                "action": "improve",
                "actionExplain": "你的笔记内容需要优化"
            },
            {
                "action": "topic",
                "actionExplain": "你可以探索相关话题"
            },
            {
                "action": "followup",
                "actionExplain": "这是行动建议"
            }
            """
        }
        
        static func noteupdateUserPrompt(noteText: String, relatedNotes: [Note], contactNames: [String]) -> String {
            """
            \(SystemPrompts.basePrompt)
            
            You are analyzing a new note with the following content:
            \(noteText)
            
            Related contacts in this note:
            \(contactNames.map { "- \($0)" }.joined(separator: "\n"))
            
            Related notes context:
            \(relatedNotes.map { "- \($0.content ?? "No content")" }.joined(separator: "\n"))
            
            Focus on:
            - Identifying patterns in interactions with these contacts
            - Suggesting conversation topics based on shared interests
            - Providing insights about communication style
            - Recommending ways to strengthen the relationships
            """
        }
    }
    
    /// Memory and follow-up prompts
    enum Memory {
        /// Prompt for creating relationship memories
        static func createMemory(contactName: String) -> String {
            """
            \(SystemPrompts.basePrompt)
            
            You are helping create a meaningful memory about \(contactName).
            
            Focus on:
            - Capturing key interaction details
            - Identifying important topics discussed
            - Noting emotional context
            - Suggesting future follow-up points
            """
        }
        
        /// Prompt for reviewing past interactions
        static func reviewInteractions(contactName: String) -> String {
            """
            \(SystemPrompts.basePrompt)
            
            You are reviewing past interactions with \(contactName).
            
            Focus on:
            - Identifying patterns in communication
            - Highlighting significant moments
            - Suggesting areas for improvement
            - Recommending next steps
            """
        }
    }
} 