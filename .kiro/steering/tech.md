# Technology Stack

## Build System & Platform
- **Platform**: macOS native application
- **Build System**: Xcode project with `.xcodeproj` structure
- **Minimum Deployment**: macOS 14.0
- **Swift Version**: Swift 5.0

## Core Technologies
- **UI Framework**: SwiftUI with NavigationSplitView architecture
- **Data Persistence**: SwiftData for local storage
- **Logging**: Unified Logging (os.Logger) with structured logging
- **Concurrency**: Swift async/await with @MainActor for UI updates

## Key Frameworks
- **AppKit**: For system integration and workspace notifications
- **UniformTypeIdentifiers**: For drag-and-drop operations
- **Foundation**: Core data types and utilities

## Common Development Commands

### Building
```bash
# Open in Xcode
open time.xcodeproj

# Build from command line (Debug)
xcodebuild -project time.xcodeproj -scheme time -configuration Debug build

# Build for Release
xcodebuild -project time.xcodeproj -scheme time -configuration Release build
```

### Testing
```bash
# Run tests from command line
xcodebuild test -project time.xcodeproj -scheme timeTests

# Run specific test
xcodebuild test -project time.xcodeproj -scheme timeTests -only-testing:timeTests/ActivityDataProcessorTests
```

### Development
- Use Xcode's built-in simulator and previews
- SwiftUI previews available for most views using `#Preview`
- Tests use Swift Testing framework (not XCTest)

## Architecture Patterns
- **MVVM**: ViewModels as ObservableObject classes
- **Dependency Injection**: Through environment objects and shared singletons
- **Notification Center**: For decoupled communication between components
- **Repository Pattern**: Manager classes handle data operations