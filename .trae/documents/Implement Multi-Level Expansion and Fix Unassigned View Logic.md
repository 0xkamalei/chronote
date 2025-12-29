I will implement the multi-level expansion and fix the "Unassigned" view bug, incorporating the `groupByAppContext` naming for clarity.

### 1. Model Updates (`ActivityGroup`)
-   **Hierarchy Support**: Update `ActivityGroup` to make `children` optional (`[ActivityGroup]?`) for SwiftUI `List` compatibility.
-   **Stable Identity**: Implement deterministic string IDs (e.g., `Project:App:Context`) to preserve list expansion state during updates.
-   **Group Levels**: Update `ActivityGroupLevel` enum to include `.appContext` for the leaf nodes (Title/URL/FilePath).

### 2. Data Processing (`ActivityDataProcessor`)
-   **Recursive Grouping**:
    -   `groupByProject`: Groups by Project -> calls `groupByApp` for children.
    -   `groupByApp`: Groups by App Bundle -> calls `groupByAppContext` for children.
    -   **`groupByAppContext`**: (New) Groups activities by their specific context (Window Title, Web URL, or File Path) to form the leaf nodes.
-   **Context Handling**: Ensure "Unassigned" activities are correctly processed and structured.

### 3. View Logic (`ActivitiesView` & `ActivityViewContainer`)
-   **Fix Unassigned Bug**:
    -   Add logic in `ActivityViewContainer` to determine the `initialGroupingLevel`.
        -   **"All Activities"**: Start at `.project`.
        -   **"Unassigned" / Specific Project**: Start at `.appName` (skipping the project folder).
    -   Pass this level to `ActivitiesView` to render the correct root hierarchy.
-   **UI Updates**:
    -   Convert `ActivitiesView` to use `List(items, children: \.children)`.
    -   Update `HierarchicalActivityRow` to render the new `.appContext` level details.

### 4. Verification
-   Verify "All Activities" displays: Project -> App -> Context.
-   Verify "Unassigned" displays: App -> Context (fixing the bug).
-   Check correct grouping of Titles/URLs/FilePaths.
