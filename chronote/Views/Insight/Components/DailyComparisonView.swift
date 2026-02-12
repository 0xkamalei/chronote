import SwiftUI

/// Displays comparison metrics between today and yesterday
struct DailyComparisonView: View {
    let comparisonData: [ComparisonMetric]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compared to Yesterday")
                .font(.system(size: 16, weight: .semibold))
            
            HStack(spacing: 16) {
                ForEach(comparisonData) { metric in
                    ComparisonCardView(metric: metric)
                }
            }
        }
    }
}

/// Individual comparison card
struct ComparisonCardView: View {
    let metric: ComparisonMetric
    
    private var changeColor: Color {
        if abs(metric.change) < 1 {
            return .secondary
        }
        
        // Positive change is good for some metrics, bad for others
        let isGoodChange = metric.isPositive ? (metric.change > 0) : (metric.change < 0)
        return isGoodChange ? .green : .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.name)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            
            Text(metric.value)
                .font(.system(size: 18, weight: .semibold))
            
            HStack(spacing: 4) {
                Image(systemName: metric.changeIcon)
                    .font(.system(size: 11))
                Text(metric.changeFormatted)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(changeColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    DailyComparisonView(comparisonData: [
        ComparisonMetric(name: "Deep Focus", value: "1h 42m", change: 12, isPositive: true),
        ComparisonMetric(name: "Fragmented Time", value: "2h 15m", change: -18, isPositive: false),
        ComparisonMetric(name: "Passive Time", value: "45m", change: 5, isPositive: false),
    ])
    .padding()
}
