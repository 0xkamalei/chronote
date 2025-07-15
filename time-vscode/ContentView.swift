//
//  ContentView.swift
//  time-vscode
//
//  Created by seven on 2025/7/1.
//

import SwiftUI
import SwiftData
import AppKit  // Added AppKit import for NSColor access

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    // Mock data
    let activities = MockData.activities
    
    // 移除本地状态管理，使用全局AppState
    @State private var searchText: String = ""
    @State private var isDatePickerExpanded: Bool = false
    @State private var selectedDateRange = AppDateRange(startDate: Date(), endDate: Date())
    @State private var selectedPreset: AppDateRangePreset?
    
    @State private var isAddingProject: Bool = false
    @State private var isStartingTimer: Bool = false
    @State private var isAddingTimeEntry: Bool = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 220)
        } detail: {
            VStack(spacing: 0) {
                // Timeline view
                TimelineView()
                
                Divider()
                
                // Activities list with filtering based on selection
                ActivitiesView(activities: filteredActivities)
            }
            .frame(minWidth: 600, minHeight: 400)
            .sheet(isPresented: $isAddingProject) {
                EditProjectView(isPresented: $isAddingProject)
            }
            .sheet(isPresented: $isAddingTimeEntry) {
                NewTimeEntryView(isPresented: $isAddingTimeEntry)
            }
            
        }
        .toolbar {
            MainToolbarView(isAddingProject: $isAddingProject, isStartingTimer: $isStartingTimer, isAddingTimeEntry: $isAddingTimeEntry, selectedDateRange: $selectedDateRange, selectedPreset: $selectedPreset, searchText: $searchText)
        }
        .onAppear {
            // AppState已经在init中设置了默认选择，这里不需要额外处理
            print("🚀 App launched - Using global AppState for selection management")
        }
    }
    
    // 使用全局AppState的选择状态进行过滤
    private var filteredActivities: [Activity] {
        if let selectedProject = appState.selectedProject {
            // Filter activities for specific project
            print("🔍 Filtering activities for project: \(selectedProject.name)")
            // TODO: Implement actual project-activity filtering
            return activities
        } else if let selectedSidebar = appState.selectedSidebar {
            switch selectedSidebar {
            case "All Activities":
                print("📊 Showing all activities")
                return activities
            case "Unassigned":
                print("❓ Showing unassigned activities")
                // TODO: Filter for unassigned activities
                return activities
            case "My Projects":
                print("📁 Showing activities assigned to projects")
                // TODO: Filter for activities assigned to any project
                return activities
            default:
                return activities
            }
        }
        
        return activities
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
