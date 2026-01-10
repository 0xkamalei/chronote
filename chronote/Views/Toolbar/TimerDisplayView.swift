import SwiftUI

struct TimerDisplayView: View {
    @Environment(AppState.self) var appState
    @State private var elapsedTime: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(timeString(from: elapsedTime))
            .font(.headline)
            .monospacedDigit()
            .onReceive(timer) { _ in
                if let startTime = appState.timerStartTime {
                    elapsedTime = Date().timeIntervalSince(startTime)
                }
            }
            .onAppear {
                if let startTime = appState.timerStartTime {
                    elapsedTime = Date().timeIntervalSince(startTime)
                }
            }
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
}
