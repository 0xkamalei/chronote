# Implementation Plan

Convert the feature design into a series of prompts for a code-generation LLM that will implement each step in a test-driven manner. Prioritize best practices, incremental progress, and early testing, ensuring no big jumps in complexity at any stage. Make sure that each prompt builds on the previous prompts, and ends with wiring things together. There should be no hanging or orphaned code that isn't integrated into a previous step. Focus ONLY on tasks that involve writing, modifying, or testing code.

- [x] 1. Convert existing Activity struct to SwiftData model
  - Modify `time-vscode/Models/Activity/Activity.swift` to convert struct to @Model class
  - Add required SwiftData imports and @Model annotation
  - Make `endTime` optional to support ongoing activities (nil = active)
  - Preserve existing computed properties (durationString, minutes)
  - Add new computed property `calculatedDuration` for ongoing activities
  - Add computed property `isActive` that returns `endTime == nil`
  - Update initializer to handle optional endTime parameter
  - _Requirements: 2.1, 2.2, 4.1_

- [x] 2. Update SwiftData schema configuration with migration support
  - Modify `time-vscode/time_vscodeApp.swift` to include Activity in schema
  - Add Activity.self to the Schema array alongside Item.self
  - Configure ModelConfiguration for optimal SQLite performance
  - Set up proper indexing strategy for frequently queried fields (startTime, appBundleId)
  - Ensure database is stored persistently (not in memory)
  - Add schema versioning support for future migrations
  - _Requirements: 2.1, 2.2, 4.2, 4.5, 5.2_

- [x] 2.1. Implement schema migration strategy
  - Create migration logic to handle conversion from struct-based MockData to SwiftData models
  - Add version checking to detect schema changes
  - Implement data preservation during model updates
  - Add fallback mechanisms for failed migrations
  - Create validation to ensure data integrity after migration
  - Add logging for migration process monitoring
  - _Requirements: 2.2, 2.3, 4.5_

- [x] 3. Create ActivityManager singleton class
  - Create new file `time-vscode/Models/ActivityManager.swift`
  - Implement @MainActor class with ObservableObject conformance
  - Add static shared instance for singleton pattern
  - Add private properties for currentActivity and notificationObservers
  - Implement basic structure with empty method stubs
  - Add proper SwiftData and AppKit imports
  - _Requirements: 1.1, 1.4, 4.1_

- [ ] 4. Implement NSWorkspace notification monitoring
  - Add startTracking method that registers NSWorkspace notification observers
  - Implement didActivateApplicationNotification observer for app switches
  - Implement willSleepNotification observer for system sleep events
  - Implement didWakeNotification observer for system wake events
  - Add stopTracking method that removes all notification observers
  - Add proper error handling and thread safety for notification processing
  - _Requirements: 1.1, 1.2, 3.1, 3.2_

- [ ] 5. Implement app switch tracking logic
  - Create trackAppSwitch method that handles new app activation
  - Implement logic to finish current activity (set endTime, calculate duration)
  - Create new Activity record for the newly activated app (with endTime = nil)
  - Add proper bundle identifier extraction and app name resolution
  - Implement duration calculation and validation
  - Add error handling for invalid app data
  - _Requirements: 1.1, 1.2, 1.5, 4.1_

- [ ] 6. Implement SwiftData persistence operations
  - Add database write operations using ModelContext
  - Implement saveActivity method with proper error handling
  - Add getCurrentActivity method to query activity where endTime is nil
  - Implement getRecentActivities method with date filtering
  - Add batch operations for performance optimization
  - Implement data validation before persistence
  - _Requirements: 2.1, 2.2, 2.4, 4.2, 5.2_

- [ ] 7. Implement system sleep/wake handling
  - Add handleSystemSleep method that stops current tracking
  - Ensure all pending data is saved before system sleep
  - Implement handleSystemWake method that resumes monitoring
  - Add logic to prevent artificial activity recording during sleep
  - Implement proper state management across sleep/wake cycles
  - Add option to continue tracking previously active app after wake
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 8. Add comprehensive error handling and data integrity
  - Implement robust error handling for database operations
  - Add retry logic for transient failures
  - Implement data validation rules (startTime < endTime when endTime exists, only one activity with endTime = nil)
  - Add graceful degradation when storage is unavailable
  - Implement automatic cleanup of incomplete records
  - Add logging and monitoring for system health
  - _Requirements: 2.5, 4.4, 5.1, 5.4_

- [ ] 9. Integrate ActivityManager with app lifecycle
  - Modify ContentView or app initialization to start activity tracking
  - Pass ModelContext to ActivityManager for database operations
  - Ensure tracking starts automatically when app launches
  - Add proper cleanup when app terminates
  - Test integration with existing UI components
  - Verify data persistence across app restarts
  - _Requirements: 1.4, 2.3, 4.3_

- [ ] 10. Add performance optimizations and testing
  - Implement batch database operations for better performance
  - Add background queue processing for non-critical operations
  - Create unit tests for ActivityManager core functionality
  - Test app switch tracking accuracy and timing
  - Verify database performance with large datasets
  - Add memory usage monitoring and optimization
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 11. Test schema migration and data preservation
  - Create test scenarios for schema evolution (adding/removing fields)
  - Verify existing data is preserved during model changes
  - Test migration rollback mechanisms for failed updates
  - Add integration tests for database version compatibility
  - Validate data integrity after schema migrations
  - Test performance impact of migration operations
  - _Requirements: 2.2, 2.3, 4.5_