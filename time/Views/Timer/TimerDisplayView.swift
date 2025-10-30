import SwiftUI
import os

struct TimerDisplayView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showTimerControls = false
    
    private var timerManager: TimerManager {
        appState.timerManager
    }
    
    var body: some View {
        Group {
            if timerManager.isRunning {
                activeTimerView
            } else {
                inactiveTimerView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: timerManager.isRunning)
    }
    
    private var activeTimerView: some View {
        HStack(spacing: 8) {
            // Timer status indicator
            Circle()
                .fill(timerManager.isPaused ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
                .opacity(timerManager.isPaused ? 1.0 : 0.8)
                .scaleEffect(timerManager.isPaused ? 1.0 : 1.2)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: timerManager.isPaused)
            
            // Elapsed time display
            Text(timerManager.formattedElapsedTime)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
            
            // Project name if available
            if let session = timerManager.activeSession,
               let projectId = session.projectId {
                Text("•")
                    .foregroundColor(.secondary)
                
                ProjectNameView(projectId: projectId)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Timer controls
            HStack(spacing: 4) {
                if timerManager.isPaused {
                    Button(action: resumeTimer) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Resume Timer")
                } else {
                    Button(action: pauseTimer) {
                        Image(systemName: "pause.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Pause Timer")
                }
                
                Button(action: stopTimer) {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Stop Timer")
            }
            .opacity(showTimerControls ? 1.0 : 0.0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(timerManager.isPaused ? Color.orange : Color.green, lineWidth: 1)
                        .opacity(0.3)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                showTimerControls = hovering
            }
        }
        .contextMenu {
            timerContextMenu
        }
    }
    
    private var inactiveTimerView: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("No Timer")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    private var timerContextMenu: some View {
        Group {
            if let session = timerManager.activeSession {
                if let title = session.title {
                    Text("Timer: \(title)")
                        .font(.headline)
                }
                
                if let estimatedDuration = session.estimatedDuration {
                    let progress = session.progress
                    let progressPercent = Int(progress * 100)
                    Text("Progress: \(progressPercent)% of \(formatDuration(estimatedDuration))")
                }
                
                Divider()
                
                if timerManager.isPaused {
                    Button("Resume Timer", action: resumeTimer)
                } else {
                    Button("Pause Timer", action: pauseTimer)
                }
                
                Button("Stop Timer", action: stopTimer)
                
                Divider()
                
                Button("Stop and Create Time Entry") {
                    Task {
                        await appState.stopTimer(createTimeEntry: true)
                    }
                }
                
                Button("Stop Without Time Entry") {
                    Task {
                        await appState.stopTimer(createTimeEntry: false)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func pauseTimer() {
        do {
            try timerManager.pauseTimer()
        } catch {
            Logger.ui.error("Failed to pause timer: \(error.localizedDescription)")
        }
    }
    
    private func resumeTimer() {
        do {
            try timerManager.resumeTimer()
        } catch {
            Logger.ui.error("Failed to resume timer: \(error.localizedDescription)")
        }
    }
    
    private func stopTimer() {
        Task {
            await appState.stopTimer()
        }
    }
    
    // MARK: - Utility
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

struct ProjectNameView: View {
    let projectId: String
    @EnvironmentObject private var projectManager: ProjectManager
    
    var body: some View {
        if let project = projectManager.getProject(by: projectId) {
            Text(project.name)
        } else {
            Text("Unknown Project")
                .italic()
        }
    }
}

#Preview {
    TimerDisplayView()
        .environmentObject(AppState())
        .environmentObject(ProjectManager.shared)
        .padding()
}