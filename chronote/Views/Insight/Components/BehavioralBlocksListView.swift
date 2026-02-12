import SwiftUI

/// Displays a list of behavioral blocks for the day
struct BehavioralBlocksListView: View {
    let blocks: [BehavioralBlock]
    @State private var showAll = false
    
    private var displayedBlocks: [BehavioralBlock] {
        showAll ? blocks : Array(blocks.prefix(4))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Behavioral Blocks")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Text("\(blocks.count) blocks today")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            
            // List
            VStack(spacing: 0) {
                ForEach(Array(displayedBlocks.enumerated()), id: \.element.id) { index, block in
                    BehaviorBlockRowView(block: block)
                    
                    if index < displayedBlocks.count - 1 {
                        Divider()
                    }
                }
                
                if !showAll && blocks.count > 4 {
                    Button {
                        showAll = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Show \(blocks.count - 4) more blocks")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(white: 0.98))
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

/// Single row in the behavioral blocks list
struct BehaviorBlockRowView: View {
    let block: BehavioralBlock
    
    private var blockColor: Color {
        switch block.blockType {
        case .deep: return .blue
        case .fragmented: return .orange
        case .passive: return .gray
        case .communication: return .purple
        case .idle: return Color(white: 0.85)
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Type indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(blockColor)
                .frame(width: 10, height: 40)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(block.dominantActivity ?? "Unknown")
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    Text(block.durationFormatted)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text(block.timeRangeFormatted)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    if block.contextSwitchCount > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(block.contextSwitchCount) switches")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    BehavioralBlocksListView(blocks: [
        BehavioralBlock(
            startTime: Date(),
            endTime: Date().addingTimeInterval(2400),
            blockType: .deep,
            dominantActivity: "VS Code",
            contextSwitchCount: 2
        ),
        BehavioralBlock(
            startTime: Date().addingTimeInterval(3000),
            endTime: Date().addingTimeInterval(4200),
            blockType: .fragmented,
            dominantActivity: "Chrome",
            contextSwitchCount: 8
        ),
    ])
    .padding()
}
