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
    
    
    let activities = [
        Activity(appName: "Google Chrome", duration: "48m", icon: "globe", minutes: 48),
        Activity(appName: "Microsoft Edge", duration: "18m", icon: "safari", minutes: 18),
        Activity(appName: "Xcode", duration: "17m", icon: "hammer", minutes: 17),
        Activity(appName: "Code", duration: "13m", icon: "chevron.left.forwardslash.chevron.right", minutes: 13),
        Activity(appName: "Folo", duration: "10m", icon: "f.cursive", minutes: 10),
        Activity(appName: "WeChat", duration: "10m", icon: "message", minutes: 10),
        Activity(appName: "Universal Control", duration: "9m", icon: "arrow.left.and.right", minutes: 9),
        Activity(appName: "Telegram", duration: "8m", icon: "paperplane", minutes: 8),
        Activity(appName: "Discord", duration: "7m", icon: "bubble.left.and.bubble.right", minutes: 7),
        Activity(appName: "Slack", duration: "4m", icon: "number", minutes: 4),
        Activity(appName: "Claude", duration: "4m", icon: "brain", minutes: 4),
        Activity(appName: "Timing", duration: "3m", icon: "clock", minutes: 3),
        Activity(appName: "Alex", duration: "3m", icon: "person", minutes: 3),
        Activity(appName: "Finder", duration: "3m", icon: "folder", minutes: 3),
        Activity(appName: "Doubao", duration: "1m", icon: "d.circle", minutes: 1),
        Activity(appName: "Calendar", duration: "1m", icon: "calendar", minutes: 1),
        Activity(appName: "GitHub Copilot for Xcode Extension", duration: "1m", icon: "brain.head.profile", minutes: 1)
    ]
    
    @State private var selectedProject: Project?
    @State private var selectedSidebar: String? = "Activities"
    @State private var searchText: String = ""
    @State private var isDatePickerExpanded: Bool = false
    @State private var selectedDateRange = DateRange(startDate: Date(), endDate: Date())
    @State private var selectedPreset: DateRangePreset?
    
    @State private var isAddingProject: Bool = false
    @State private var isStartingTimer: Bool = false
    @State private var isAddingTimeEntry: Bool = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedSidebar: $selectedSidebar, selectedProject: $selectedProject)
                .navigationSplitViewColumnWidth(min: 220, ideal: 220)
        } detail: {
            VStack(spacing: 0) {
                // Timeline view
                TimelineView()
                
                Divider()
                
                // Activities list
                ActivitiesView(activities: activities)
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
    }
}

#Preview {
    ContentView()
}
