# SeedDataManager - Enhanced Data Management

## Overview

The enhanced `SeedDataManager` now supports preserving user data when switching between sample data scenarios. This allows users to maintain their personal data while exploring different sample scenarios.

## Key Features

### 1. Data Preservation
- **User data (type != 0)** is preserved when switching sample scenarios
- **Sample data (type == 0)** is replaced when switching scenarios
- Orphaned relationships are automatically cleaned up

### 2. Scenario Management
- Switch between different sample data scenarios
- Remove sample data while keeping user data
- Check current scenario status

### 3. Data Retrieval
- Fetch all data (sample + user)
- Fetch only sample data
- Fetch only user data
- Check data existence

## Usage Examples

### Switching Sample Scenarios

```swift
// Switch to a different scenario while preserving user data
try await SeedDataManager.shared.switchToScenario(.changedJob, in: viewContext)
try await SeedDataManager.shared.switchToScenario(.indie, in: viewContext)
```

### Data Retrieval

```swift
// Get all data (both sample and user)
let allContacts = try SeedDataManager.shared.fetchAllContacts(in: viewContext)
let allNotes = try SeedDataManager.shared.fetchAllNotes(in: viewContext)
let allCircles = try SeedDataManager.shared.fetchAllCircles(in: viewContext)

// Get only sample data
let sampleData = try SeedDataManager.shared.fetchSampleData(in: viewContext)
let sampleContacts = sampleData.contacts
let sampleNotes = sampleData.notes
let sampleCircles = sampleData.circles

// Get only user data
let userData = try SeedDataManager.shared.fetchUserData(in: viewContext)
let userContacts = userData.contacts
let userNotes = userData.notes
let userCircles = userData.circles
```

### Data Management

```swift
// Remove sample data while keeping user data
try SeedDataManager.shared.removeSampleData(from: viewContext)

// Check if data exists
let hasSample = try SeedDataManager.shared.hasSampleData(in: viewContext)
let hasUser = try SeedDataManager.shared.hasUserData(in: viewContext)

// Get current scenario
let currentScenario = try SeedDataManager.shared.getCurrentScenario(in: viewContext)
```

## Updated Views

### SocialContactView & SocialNotesView
- Updated to use `switchToScenario()` method
- Preserves user data when switching scenarios
- Simplified error handling

### DataDisplayView (New)
- Demonstrates displaying both sample and user data
- Provides UI for switching scenarios
- Shows data statistics

## Data Types

### Sample Data (type == 0)
- Pre-defined scenarios for demonstration
- Can be switched between different scenarios
- Automatically cleaned up when switching

### User Data (type != 0)
- Personal data created by the user
- Preserved across scenario switches
- Never deleted by sample data operations

## Error Handling

The manager includes comprehensive error handling:
- Validates data integrity
- Handles orphaned relationships
- Provides detailed error messages
- Graceful fallbacks for failed operations

## Troubleshooting

### Common Issues

#### "Sample data already exists" Error
**Problem**: This error occurs when trying to enter sample mode after exiting it.

**Solution**: This has been fixed in the latest version. The `importSeedData` method now automatically cleans up existing sample data before importing new data.

**Root Cause**: The previous version checked for existing sample data and threw an error instead of cleaning it up.

**Fix Applied**:
- Removed the unnecessary check for existing sample data
- Added automatic cleanup of existing sample data before import
- Enhanced logging for better debugging

#### Core Data Collection Mutation Crash
**Problem**: App crashes with error "Collection was mutated while being enumerated" when re-entering sample mode.

**Solution**: This has been fixed by using batch delete requests instead of individual deletions for orphaned relationships.

**Root Cause**: The `cleanupOrphanedRelationships` method was fetching all relationships, then iterating through them and deleting some. This caused Core Data observers to process changes while the collection was being enumerated, leading to the crash.

**Fix Applied**:
- Replaced individual deletions with batch delete requests
- Used predicates to target only orphaned relationships
- Added proper error handling for each batch operation
- Removed intermediate saves that could cause concurrency issues

#### Data Not Preserved When Switching Scenarios
**Problem**: User data is lost when switching between sample scenarios.

**Solution**: Ensure you're using the new `switchToScenario()` method instead of manually deleting data.

#### Orphaned Relationships
**Problem**: Relationships pointing to deleted sample data remain in the database.

**Solution**: The `cleanupOrphanedRelationships()` method automatically handles this using safe batch operations.

## Best Practices

1. **Always use the new methods** instead of manually deleting data
2. **Check data existence** before performing operations
3. **Handle errors gracefully** in UI
4. **Refresh UI** after data operations
5. **Use async/await** for all data operations
6. **Monitor console logs** for debugging information

## Migration Notes

If you have existing code that manually deletes sample data, replace it with the new methods:

```swift
// Old way (don't use)
let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Note.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "type == %d", 0)
let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
try viewContext.execute(deleteRequest)

// New way (recommended)
try await SeedDataManager.shared.switchToScenario(.changedJob, in: viewContext)
```

## Testing

Use the `SeedDataExample` class for testing:

```swift
// Print data statistics
SeedDataExample.printDataStatistics()

// Switch scenarios
SeedDataExample.switchToScenario(.changedJob)
SeedDataExample.switchToScenario(.indie)

// Remove sample data
SeedDataExample.removeSampleData()

// Check data status
let hasSample = SeedDataExample.hasSampleData()
let hasUser = SeedDataExample.hasUserData()
```

## Debugging

The manager now includes comprehensive logging. Check the console for messages like:

```
[SeedDataManager] Starting import of seed data...
[SeedDataManager] Cleaning up existing sample data...
[SeedDataManager] Found 5 sample Note records to delete
[SeedDataManager] Successfully deleted 5 sample Note records
[SeedDataManager] Sample data cleanup completed successfully
[SeedDataManager] Seed data loaded successfully
[SeedDataManager] Loaded scenario: changed_job
[SeedDataManager] Importing 3 contacts...
[SeedDataManager] Importing 8 notes...
[SeedDataManager] Seed data import completed successfully
```

This logging helps identify where issues occur during the import process. 