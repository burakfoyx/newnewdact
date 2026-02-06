import SwiftUI

struct AlertSettingsView: View {
    let server: ServerAttributes
    @AppStorage("quietHoursEnabled") private var quietHoursEnabled = false
    @AppStorage("quietHoursStart") private var quietHoursStart = Date()
    @AppStorage("quietHoursEnd") private var quietHoursEnd = Date()
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Color.clear.listRowBackground(Color.clear)
                }
                .frame(height: 240)
                .listRowBackground(Color.clear)
                
                Section {
                    Toggle("Quiet Hours", isOn: $quietHoursEnabled)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("When enabled, notifications will be suppressed during the selected time range.")
                }
                
                if quietHoursEnabled {
                    Section {
                        DatePicker("Start Time", selection: $quietHoursStart, displayedComponents: .hourAndMinute)
                        DatePicker("End Time", selection: $quietHoursEnd, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("Alert Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
