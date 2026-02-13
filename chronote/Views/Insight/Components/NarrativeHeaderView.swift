import SwiftUI

/// Displays the main narrative insight for the day
/// Highlighted card with headline and supporting text
struct NarrativeHeaderView: View {
    let headline: String
    let subtext: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label
            Text("DAY INSIGHT")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.blue)
            
            // Headline
            Text(headline)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
            
            // Subtext
            Text(subtext)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.08))
        )
    }
}

#Preview {
    NarrativeHeaderView(
        headline: "Your day was mostly fragmented. Only 2 deep focus sessions occurred, totaling 1h 42m.",
        subtext: "The longest uninterrupted work happened between 10:30 AM and 11:18 AM in VS Code."
    )
    .padding()
}
