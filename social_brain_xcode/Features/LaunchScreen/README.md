# Launch Screen Feature

This feature provides a configurable extended launch screen that displays after the system launch screen and before the main app content.

## Overview

The launch screen feature consists of three main components:

1. **LaunchScreenConfiguration.swift** - Configuration settings
2. **LaunchScreenView.swift** - The actual launch screen view
3. **LaunchScreenManager.swift** - Manager to handle the launch screen logic

## Configuration

All configuration is done in `LaunchScreenConfiguration.swift`. Here are the available options:

### Timing Configuration

```swift
// Duration to show the launch screen (default: 2.0 seconds)
static let displayDuration: TimeInterval = 2.0

// Animation duration for fade out (default: 0.5 seconds)
static let fadeOutDuration: TimeInterval = 0.5

// Fade in animation duration (default: 0.3 seconds)
static let fadeInDuration: TimeInterval = 0.3
```

### Display Configuration

```swift
// Enable/disable the extended launch screen
static let isEnabled: Bool = true

// Background color (should match your storyboard)
static let backgroundColor = UIColor.white

// Show loading indicator for longer durations
static let showLoadingIndicator: Bool = false
```

### Content Configuration

```swift
// Custom text to display (set to nil to hide)
static let customText: String? = nil

// Text styling
static let textColor = UIColor.systemGray
static let textFont = UIFont.systemFont(ofSize: 16, weight: .medium)
```

### Animation Configuration

```swift
// Enable fade in animation
static let enableFadeIn: Bool = true
```

### Advanced Configuration

```swift
// Show launch screen only on first app launch
static let skipOnSubsequentLaunches: Bool = false
```

## Usage Examples

### Basic Configuration

```swift
// Show launch screen for 3 seconds with loading indicator
static let displayDuration: TimeInterval = 3.0
static let showLoadingIndicator: Bool = true
```

### First Launch Only

```swift
// Show launch screen only on first app launch
static let skipOnSubsequentLaunches: Bool = true
```

### Custom Text

```swift
// Display custom text on launch screen
static let customText: String? = "Welcome to Social Brain"
static let textColor = UIColor.systemBlue
```

### Disable Launch Screen

```swift
// Completely disable the extended launch screen
static let isEnabled: Bool = false
```

## Integration

The launch screen is automatically integrated into the main app. The `LaunchScreenManager` is added to the main app file and handles the display logic.

### How it Works

1. App starts and shows the system launch screen (from storyboard)
2. System launch screen transitions to the extended launch screen
3. Extended launch screen displays for the configured duration
4. Smooth fade out transition to the main app content

### Customization

To customize the launch screen appearance:

1. **Image**: The launch screen uses the same image as your storyboard (`"l"`)
2. **Background**: Set `backgroundColor` to match your storyboard
3. **Text**: Add custom text and styling
4. **Timing**: Adjust display duration and animation timing

## Testing

The `LaunchScreenManager` provides several methods for testing:

```swift
// Skip launch screen
launchScreenManager.skipLaunchScreen()

// Reset to default state
launchScreenManager.reset()

// Force show launch screen
launchScreenManager.forceShowLaunchScreen()
```

## Best Practices

1. **Match Storyboard**: Ensure the background color matches your launch screen storyboard
2. **Reasonable Duration**: Keep display duration under 3 seconds for good UX
3. **Loading Indicator**: Use loading indicator for durations longer than 2 seconds
4. **First Launch**: Consider showing extended launch screen only on first launch
5. **Performance**: The launch screen is lightweight and doesn't impact app performance

## Troubleshooting

### Launch Screen Not Showing

- Check that `isEnabled` is set to `true`
- Verify that `shouldShowLaunchScreen` returns `true`
- Ensure the launch screen manager is properly initialized

### Animation Issues

- Adjust `fadeInDuration` and `fadeOutDuration` for smoother animations
- Check that the main app content opacity is properly managed

### Image Not Displaying

- Ensure the image asset `"l"` exists in your project
- Verify the image name matches exactly (case-sensitive) 