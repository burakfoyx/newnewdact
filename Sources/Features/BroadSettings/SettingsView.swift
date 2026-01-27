import SwiftUI

struct SettingsView: View {
    let serverId: String
    @Environment(\.dismiss) var dismiss
    
    // In a real app we might fetch server details to edit them
    // For now we just provide "Logout" or App Info
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Server Info Card
                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Server Information")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Divider().background(.white.opacity(0.3))
                        
                        InfoRow(label: "UUID", value: serverId)
                        // In reality we would pass the whole Server object or fetch it
                    }
                    .padding()
                }
                
                // App Info
                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("App Settings")
                            .font(.headline)
                            .foregroundStyle(.white)
                         
                        Divider().background(.white.opacity(0.3))
                        
                        Toggle("Face ID", isOn: .constant(true))
                            .tint(.blue)
                        
                        Button(action: {
                            // Logout Logic
                            KeychainHelper.standard.delete(account: "current_session")
                            // This needs to trigger a root state change. 
                            // For now just clear key.
                        }) {
                             Text("Log Out")
                                .foregroundStyle(.red)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                
                Text("XYIdactyl v1.0.0")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
