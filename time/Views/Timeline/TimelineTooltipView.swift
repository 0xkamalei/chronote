import SwiftUI

struct TimelineTooltipView: View {
    let block: TimelineRenderBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let icon = block.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                Text(block.appName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            
            Divider()
            
            HStack {
                Text(formatTime(block.startTime) + " - " + formatTime(block.endTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatDuration(block.totalDuration))
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(8)
        .frame(width: 200)
        .background(Material.thick)
        .cornerRadius(8)
        .shadow(radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}
