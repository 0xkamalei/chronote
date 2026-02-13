import SwiftUI

struct TimelineTooltipView: View {
    let activity: ActivitySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 应用名称 + 窗口标题
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.appName)
                    .font(.caption)
                    .fontWeight(.semibold)

                if let title = activity.appTitle, !title.isEmpty {
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()

            // 时间信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatTime(activity.startTime))
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("End")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatTime(activity.endTime ?? activity.capturedAt))
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatDuration(activity.calculatedDuration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }

            // 额外信息（如果有）
            if let filePath = activity.filePath, !filePath.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("File")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(filePath)
                        .font(.caption2)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                }
            }

            if let webUrl = activity.webUrl, !webUrl.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("URL")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(webUrl)
                        .font(.caption2)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(8)
        .frame(width: 260)
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
