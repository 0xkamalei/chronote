import SwiftUI

struct Activity: Identifiable {
    let id = UUID()
    let appName: String
    let duration: String
    let icon: String // systemName or asset name
    let minutes: Int // Store actual minutes for sorting
}