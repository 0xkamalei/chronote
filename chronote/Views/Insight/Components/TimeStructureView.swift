import SwiftUI

/// Displays the time structure breakdown for the day
/// Shows stacked bar with percentages and legend
struct TimeStructureView: View {
    let structure: TimeStructure
    
    // Color scheme for block types
    private let deepColor = Color.blue
    private let fragmentedColor = Color.orange
    private let passiveColor = Color.gray
    private let communicationColor = Color.purple
    private let idleColor = Color(white: 0.85)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Time Structure")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Text(structure.totalTrackedFormatted + " tracked")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            
            // Stacked bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if structure.deepPercentage > 0 {
                        Rectangle()
                            .fill(deepColor)
                            .frame(width: geometry.size.width * (structure.deepPercentage / 100))
                    }
                    
                    if structure.fragmentedPercentage > 0 {
                        Rectangle()
                            .fill(fragmentedColor)
                            .frame(width: geometry.size.width * (structure.fragmentedPercentage / 100))
                    }
                    
                    if structure.passivePercentage > 0 {
                        Rectangle()
                            .fill(passiveColor)
                            .frame(width: geometry.size.width * (structure.passivePercentage / 100))
                    }
                    
                    if structure.communicationPercentage > 0 {
                        Rectangle()
                            .fill(communicationColor)
                            .frame(width: geometry.size.width * (structure.communicationPercentage / 100))
                    }
                    
                    if structure.idlePercentage > 0 {
                        Rectangle()
                            .fill(idleColor)
                            .frame(width: geometry.size.width * (structure.idlePercentage / 100))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 24)
            
            // Legend
            HStack(spacing: 24) {
                if structure.deepPercentage > 0 {
                    legendItem(color: deepColor, label: "Deep \(Int(structure.deepPercentage))%")
                }
                
                if structure.fragmentedPercentage > 0 {
                    legendItem(color: fragmentedColor, label: "Fragmented \(Int(structure.fragmentedPercentage))%")
                }
                
                if structure.passivePercentage > 0 {
                    legendItem(color: passiveColor, label: "Passive \(Int(structure.passivePercentage))%")
                }
                
                if structure.communicationPercentage > 0 {
                    legendItem(color: communicationColor, label: "Communication \(Int(structure.communicationPercentage))%")
                }
                
                if structure.idlePercentage > 0 {
                    legendItem(color: idleColor, label: "Idle \(Int(structure.idlePercentage))%")
                }
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// Preview helper - create mock structure
#Preview {
    TimeStructureView(structure: {
        let structure = TimeStructure(
            date: Date(),
            deepDuration: 1680, // 28 minutes
            fragmentedDuration: 2280, // 38 minutes
            passiveDuration: 960, // 16 minutes
            communicationDuration: 720, // 12 minutes
            idleDuration: 360 // 6 minutes
        )
        return structure
    }())
    .padding()
}
