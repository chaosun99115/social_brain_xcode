import SwiftUI

/// App-wide theme definitions for consistent styling
struct AppTheme {
    /// Defines all semantic colors used throughout the app
    struct Colors {
        // Primary colors
        static let primaryAction = Color.accentColor
        static let secondaryAction = Color(.systemBlue)
        
        // Content colors
        static let primaryText = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText = Color(.tertiaryLabel)
        
        // Background colors
        static let primaryBackground = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)
        static let cardBackground = Color(.secondarySystemGroupedBackground)
        
        // Interactive elements
        static let inputBackground = Color(.systemGray6)
        static let divider = Color(.separator)
        
        // Semantic colors
        static let mentionHighlight = Color(.systemBlue)
        static let positiveAction = Color(.systemGreen)
        static let warningElement = Color(.systemOrange)
        static let errorElement = Color(.systemRed)
        static let infoElement = Color(.systemIndigo)
    }
    
    /// Defines typography styles used throughout the app
    struct Typography {
        // Title styles
        static let largeTitle = Font.largeTitle
        static let title = Font.title
        
        // Content styles
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        
        // Supporting styles
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        
        // Custom styles
        static let mentionText = Font.subheadline.bold()
    }
    
    /// Defines dimensions and spacing used throughout the app
    struct Layout {
        // Standard spacing
        static let smallSpacing: CGFloat = 4
        static let mediumSpacing: CGFloat = 8
        static let defaultSpacing: CGFloat = 12
        static let largeSpacing: CGFloat = 16
        static let extraLargeSpacing: CGFloat = 24
        
        // Corner radii
        static let buttonRadius: CGFloat = 10
        static let cardRadius: CGFloat = 12
        
        // Icon sizes
        static let smallIcon: CGFloat = 16
        static let mediumIcon: CGFloat = 22
        static let largeIcon: CGFloat = 28
    }
}

// Color extension for backward compatibility with existing code
extension Color {
    // Primary colors
    static let primaryAction = AppTheme.Colors.primaryAction
    static let secondaryAction = AppTheme.Colors.secondaryAction
    
    // Content colors
    static let primaryText = AppTheme.Colors.primaryText
    static let secondaryText = AppTheme.Colors.secondaryText
    static let tertiaryText = AppTheme.Colors.tertiaryText
    
    // Background colors
    static let primaryBackground = AppTheme.Colors.primaryBackground
    static let secondaryBackground = AppTheme.Colors.secondaryBackground
    static let groupedBackground = AppTheme.Colors.groupedBackground
    static let cardBackground = AppTheme.Colors.cardBackground
    
    // Interactive elements
    static let inputBackground = AppTheme.Colors.inputBackground
    static let divider = AppTheme.Colors.divider
    
    // Semantic colors
    static let mentionHighlight = AppTheme.Colors.mentionHighlight
    static let positiveAction = AppTheme.Colors.positiveAction
    static let warningElement = AppTheme.Colors.warningElement
    static let errorElement = AppTheme.Colors.errorElement
    static let infoElement = AppTheme.Colors.infoElement
}
