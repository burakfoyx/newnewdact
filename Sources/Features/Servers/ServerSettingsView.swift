import SwiftUI

struct ServerSettingsView: View {
    let server: ServerAttributes
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Info Card
                VStack(spacing: 12) {
                    Label("Server Information", systemImage: "info.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider().overlay(.white.opacity(0.3))
                    
                    InfoRow(label: "Server Name", value: server.name)
                    InfoRow(label: "UUID", value: server.uuid)
                    InfoRow(label: "Identifier", value: server.identifier)
                    InfoRow(label: "Node", value: server.node)
                    InfoRow(label: "Description", value: server.description)
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                
                // SFTP Card
                VStack(spacing: 12) {
                    Label("SFTP Details", systemImage: "network")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider().overlay(.white.opacity(0.3))
                    
                    InfoRow(label: "Host", value: "\(server.sftpDetails.ip):\(server.sftpDetails.port)")
                    // Simple prediction of username, can be inaccurate but helpful
                    InfoRow(label: "Username", value: "<username>.\(server.identifier)")
                    
                    Button(action: {
                        UIPasteboard.general.string = "sftp://\(server.sftpDetails.ip):\(server.sftpDetails.port)"
                    }) {
                        Label("Copy SFTP URL", systemImage: "doc.on.doc")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(8)
                            .glassEffect(.thin, in: Capsule())
                    }
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                
                // Limits Card
                VStack(spacing: 12) {
                    Label("Resource Limits", systemImage: "gauge")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider().overlay(.white.opacity(0.3))
                    
                    InfoRow(label: "Memory", value: "\(server.limits.memory ?? 0) MB")
                    InfoRow(label: "Disk", value: "\(server.limits.disk ?? 0) MB")
                    InfoRow(label: "CPU", value: "\(server.limits.cpu ?? 0)%")
                    InfoRow(label: "Swap", value: "\(server.limits.swap ?? 0) MB")
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
            .padding(.bottom, 50)
        }
    }
}

// Reusing InfoRow from SettingsView.swift if public, or redefining. 
// SettingsView.swift defines it. I should check access level. It is internal.
// I will redefine it here or use the one in SettingsView if accessible.
// Since they are in the same module, it should be visible.
