# Project Structure

## Root Directory Organization

```
time/                     # Main application source code
├── Models/              # Data models and business logic
├── Views/               # SwiftUI views organized by feature
├── Assets.xcassets/     # App icons and visual assets
├── timeApp.swift        # App entry point and lifecycle
├── AppState.swift       # Global application state management
├── ContentView.swift    # Main app layout and coordination
└── time.entitlements    # App sandbox and permissions

timeTests/               # Unit and integration tests
time.xcodeproj/         # Xcode project configuration
ui/                     # UI mockups and design references
prompt/                 # Product requirements and specifications
```

## Models Architecture

```
Models/
├── Activity/           # Activity tracking domain
│   ├── Entity/        # Core data models (Activity, etc.)
│   ├── ActivityManager.swift        # Activity tracking logic
│   ├── ActivityQueryManager.swift   # Query and filtering
│   └── ActivityDataProcessor.swift  # Data processing utilities
├── Project/           # Project management domain
│   ├── Project.swift           # Project model with hierarchy
│   ├── ProjectManager.swift    # Project CRUD operations
│   └── ProjectTypes.swift      # Supporting types
├── TimeEntry/         # Time entry domain
│   └── TimeEntry.swift        # Manual time tracking
└── Shared/            # Cross-domain models
    ├── DatabaseConfiguration.swift
    ├── SchemaMigration.swift
    └── DateTypes.swift
```

## Views Architecture

```
Views/
├── Activities/        # Activity display and analysis
├── Project/          # Project management UI
├── Sidebar/          # Navigation and project tree
├── Timeline/         # Timeline visualization
└── Toolbar/          # Top-level controls and navigation
```

## Naming Conventions

### Files
- **Models**: Singular nouns (e.g., `Project.swift`, `Activity.swift`)
- **Views**: Descriptive with "View" suffix (e.g., `SidebarView.swift`)
- **Managers**: Domain + "Manager" (e.g., `ProjectManager.swift`)
- **Tests**: Class name + "Tests" (e.g., `ProjectManagerTests.swift`)

### Classes & Structs
- **Models**: `@Model final class` for SwiftData entities
- **Views**: `struct` conforming to `View` protocol
- **Managers**: `@MainActor class` as `ObservableObject`
- **State**: `@Published` properties for reactive updates

### Code Organization
- Group related functionality in folders by domain/feature
- Separate entity models from business logic managers
- Keep view-specific logic in view files, business logic in managers
- Use extensions to organize protocol conformances and computed properties

## Key Architectural Patterns

### State Management
- **AppState**: Central `@StateObject` for global app state
- **Manager Classes**: Domain-specific state and operations
- **Environment Objects**: Dependency injection for views

### Data Flow
- **SwiftData**: Persistent storage with `@Model` classes
- **Published Properties**: Reactive UI updates
- **Notification Center**: Decoupled component communication

### Testing Structure
- Tests mirror main source structure
- Use Swift Testing framework (not XCTest)
- Focus on business logic in managers and data processors