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
    @Environment(\.modelContext) private var modelContext
    
    // 使用ActivityQueryManager根据筛选条件动态查询数据
    @StateObject private var activityQueryManager = ActivityQueryManager()
    
    // Activity Manager integration
    @StateObject private var activityManager = ActivityManager.shared
    
    // Project Manager with SwiftData integration
    @StateObject private var projectManager = ProjectManager()
    
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
                // Current activity status bar
                if let currentActivity = activityManager.getCurrentActivity() {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text("Currently tracking: \(currentActivity.appName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Duration: \(currentActivity.durationString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    
                    Divider()
                }
                
                // Filter status indicator
                if !activityQueryManager.getCurrentFilterDescription().isEmpty && 
                   activityQueryManager.getCurrentFilterDescription() != "All Activities" {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        Text("Filters: \(activityQueryManager.getCurrentFilterDescription())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(activityQueryManager.activities.count) of \(activityQueryManager.totalCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    
                    Divider()
                }
                
                // Timeline view
                TimelineView()
                
                Divider()
                
                // Activities list with filtering based on selection
                ActivitiesView(activities: activityQueryManager.activities)
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
            // 设置查询管理器的ModelContext
            activityQueryManager.setModelContext(modelContext)
            
            // 设置项目管理器的ModelContext
            projectManager.setModelContext(modelContext)
            
            // AppState已经在init中设置了默认选择，这里不需要额外处理
            print("🚀 App launched - Using global AppState for selection management")
            print("📊 Using ActivityQueryManager for filtered data loading")
            print("📁 ProjectManager initialized with SwiftData")
            
            // Log current activity status
            if let currentActivity = activityManager.getCurrentActivity() {
                print("⏱️ Current activity: \(currentActivity.appName)")
            } else {
                print("⏱️ No current activity")
            }
        }
        .onChange(of: appState.selectedProject) { _, newProject in
            // 当选择的项目改变时，更新查询筛选条件
            activityQueryManager.setProjectFilter(newProject)
            print("🔍 Project selection changed: \(newProject?.name ?? "None")")
        }
        .onChange(of: appState.selectedSidebar) { _, newSidebar in
            // 当选择的侧边栏项目改变时，更新查询筛选条件
            activityQueryManager.setSidebarFilter(newSidebar)
            print("📊 Sidebar selection changed: \(newSidebar ?? "None")")
        }
        .onChange(of: selectedDateRange) { _, newDateRange in
            // 当日期范围改变时，更新查询筛选条件
            let dateInterval = DateInterval(start: newDateRange.startDate, end: newDateRange.endDate)
            activityQueryManager.setDateRange(dateInterval)
            print("📅 Date range changed: \(newDateRange.startDate) - \(newDateRange.endDate)")
        }
        .onChange(of: searchText) { _, newSearchText in
            // 当搜索文本改变时，更新查询筛选条件
            activityQueryManager.setSearchText(newSearchText)
            print("🔍 Search text changed: \(newSearchText)")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
