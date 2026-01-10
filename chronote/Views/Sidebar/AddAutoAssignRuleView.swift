import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct AddAutoAssignRuleView: View {
    let onSave: (AutoAssignRule) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var ruleType: AutoAssignRuleType = .appBundleId
    @State private var value: String = ""
    @State private var selectedApp: NSRunningApplication?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Auto Assignment Rule")
                .font(.headline)
            
            Picker("Rule Type", selection: $ruleType) {
                ForEach(AutoAssignRuleType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            if ruleType == .appBundleId {
                VStack(alignment: .leading) {
                    Text("Select Running App or Enter Bundle ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }, id: \.bundleIdentifier) { app in
                            Button {
                                selectedApp = app
                                value = app.bundleIdentifier ?? ""
                            } label: {
                                HStack {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                    }
                                    Text(app.localizedName ?? "Unknown")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if let selectedApp = selectedApp, let icon = selectedApp.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(value.isEmpty ? "Select App..." : (selectedApp?.localizedName ?? value))
                        }
                    }
                    
                    TextField("com.example.app", text: $value)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                VStack(alignment: .leading) {
                    Text("Window Title Contains")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Keyword (e.g. 'Project A')", text: $value)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Add Rule") {
                    // Create rule WITHOUT projectId initially.
                    // The projectId will be assigned when the project is saved.
                    let rule = AutoAssignRule(ruleType: ruleType, value: value)
                    onSave(rule)
                }
                .buttonStyle(.borderedProminent)
                .disabled(value.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
